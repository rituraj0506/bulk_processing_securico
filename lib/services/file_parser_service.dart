import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/panel_record_model.dart';

class FileParserService {
  // Required 6 canonical fields from Excel/CSV spreadsheet format
  static const List<String> requiredCanonicalFields = [
    'S.No',
    'Sim Numbers',
    'Zone',
    'Region',
    'Branch',
    'Admin Code',
  ];

  static String sanitizeCellValue(dynamic cellValue) {
    if (cellValue == null) return '';

    dynamic val = cellValue;

    // Unwrap package:excel CellValue object wrappers if present
    if (cellValue is TextCellValue) {
      val = cellValue.value;
    } else if (cellValue is IntCellValue) {
      val = cellValue.value;
    } else if (cellValue is DoubleCellValue) {
      val = cellValue.value;
    } else if (cellValue is DateCellValue) {
      val =
          '${cellValue.year}-${cellValue.month.toString().padLeft(2, '0')}-${cellValue.day.toString().padLeft(2, '0')}';
    } else if (cellValue is DateTimeCellValue) {
      val =
          '${cellValue.year}-${cellValue.month.toString().padLeft(2, '0')}-${cellValue.day.toString().padLeft(2, '0')}';
    } else if (cellValue is BoolCellValue) {
      val = cellValue.value;
    } else if (cellValue is FormulaCellValue) {
      val = cellValue.formula;
    }

    if (val == null) return '';

    String str = '';
    if (val is double) {
      if (val == val.truncateToDouble()) {
        return val.toInt().toString();
      }
      str = val.toStringAsFixed(0);
    } else if (val is int) {
      return val.toString();
    } else {
      str = val.toString().trim();
    }

    // Strip trailing .0 if formatted as floating point (e.g., "9876543210.0" -> "9876543210")
    if (str.endsWith('.0') && RegExp(r'^-?\d+\.0$').hasMatch(str)) {
      return str.substring(0, str.length - 2);
    }

    // Handle scientific notation formatted strings e.g. "6.202339633e+09" or "6.20234e9"
    if (RegExp(r'^\d+(\.\d+)?[eE]\+?\d+$').hasMatch(str)) {
      try {
        final d = double.parse(str);
        if (d == d.truncateToDouble()) {
          return d.toInt().toString();
        }
      } catch (_) {}
    }

    return str;
  }

  static String normalizeHeader(String header) {
    return header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
  }

  /// Maps normalized string to canonical field name if matched
  static String? matchCanonicalField(String rawHeader) {
    final norm = normalizeHeader(rawHeader);

    // 1. S.No matching
    if (norm.contains('sno') ||
        norm.contains('slno') ||
        norm.contains('srno') ||
        norm.contains('serial')) {
      return 'S.No';
    }

    // 2. SIM_IMSI matching (checked before SIM Numbers to avoid collision)
    if (norm.contains('simimsi') || norm.contains('imsi')) {
      return 'SIM_IMSI';
    }

    // 3. Sim Numbers matching
    if (norm.contains('simnumber') ||
        norm.contains('simno') ||
        norm.contains('panelsim') ||
        norm.contains('sim')) {
      return 'Sim Numbers';
    }

    // 4. Zone matching
    if (norm.contains('zone')) {
      return 'Zone';
    }

    // 5. Region matching
    if (norm.contains('region')) {
      return 'Region';
    }

    // 6. Branch matching
    if (norm.contains('branch') ||
        norm.contains('branchname') ||
        norm.contains('panelname')) {
      return 'Branch';
    }

    // 7. Admin Code matching
    if (norm.contains('admin')) {
      return 'Admin Code';
    }

    return null;
  }

  Future<ValidationResult> parseAndValidateFile(PlatformFile file) async {
    debugPrint(
      '[FileParser] Starting parse for "${file.name}" (extension=${file.extension}, size=${file.size})',
    );
    try {
      List<List<dynamic>> rows = [];
      Uint8List? bytes = file.bytes;
      debugPrint(
        '[FileParser] file.bytes present: ${bytes != null}, file.path: ${file.path}',
      );

      if (bytes == null && file.path != null) {
        final ioFile = File(file.path!);
        final exists = await ioFile.exists();
        debugPrint('[FileParser] Reading from path, exists=$exists');
        if (exists) {
          bytes = await ioFile.readAsBytes();
        }
      }

      debugPrint('[FileParser] Bytes loaded: ${bytes?.length ?? 0} bytes');

      if (bytes == null || bytes.isEmpty) {
        debugPrint('[FileParser] ERROR: file is empty or unreadable');
        return ValidationResult(
          isValid: false,
          fileName: file.name,
          totalRows: 0,
          requiredFields: requiredCanonicalFields,
          foundFields: [],
          missingFields: requiredCanonicalFields,
          records: [],
          errorMessage: 'File is empty or could not be read.',
        );
      }

      final extension = file.extension?.toLowerCase() ?? '';
      debugPrint('[FileParser] Detected extension: "$extension"');

      if (extension == 'xlsx' || extension == 'xls') {
        rows = _parseExcel(bytes);
      } else if (extension == 'csv' ||
          extension == 'txt' ||
          extension == 'tsv') {
        rows = _parseCsv(bytes);
      } else if (extension == 'pdf') {
        rows = _parsePdfTextFallback(bytes);
      } else {
        rows = _parseCsv(bytes);
      }

      debugPrint('[FileParser] Rows parsed: ${rows.length}');
      if (rows.isNotEmpty) {
        for (int i = 0; i < rows.length && i < 3; i++) {
          debugPrint('[FileParser] Row $i raw: ${rows[i]}');
        }
      }

      if (rows.isEmpty) {
        debugPrint(
          '[FileParser] ERROR: no rows found after parsing (extension=$extension)',
        );
        final message = (extension == 'xlsx' || extension == 'xls')
            ? 'This Excel file could not be read — it appears to be corrupted or was saved by a tool that produced an invalid .xlsx structure. Please open it in Excel/Google Sheets/LibreOffice and re-save it, or export it as .csv and import that instead.'
            : 'No readable rows or table structure found in file.';
        return ValidationResult(
          isValid: false,
          fileName: file.name,
          totalRows: 0,
          requiredFields: requiredCanonicalFields,
          foundFields: [],
          missingFields: requiredCanonicalFields,
          records: [],
          errorMessage: message,
        );
      }

      // First non-empty row is treated as header row
      int headerRowIndex = -1;
      List<String> rawHeaders = [];

      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        if (r.any(
          (cell) => cell != null && sanitizeCellValue(cell).isNotEmpty,
        )) {
          headerRowIndex = i;
          rawHeaders = r.map((c) => sanitizeCellValue(c)).toList();
          break;
        }
      }

      debugPrint(
        '[FileParser] Header row index: $headerRowIndex, raw headers: $rawHeaders',
      );

      if (headerRowIndex == -1 || rawHeaders.isEmpty) {
        debugPrint('[FileParser] ERROR: could not locate header row');
        return ValidationResult(
          isValid: false,
          fileName: file.name,
          totalRows: 0,
          requiredFields: requiredCanonicalFields,
          foundFields: [],
          missingFields: requiredCanonicalFields,
          records: [],
          errorMessage:
              'Uploaded spreadsheet is completely blank. Please upload a file containing valid panel data.',
        );
      }

      // Map headers to canonical fields & find column indices
      final Map<String, int> canonicalColumnIndices = {};
      final Set<String> foundCanonicalFields = {};

      for (int col = 0; col < rawHeaders.length; col++) {
        final raw = rawHeaders[col];
        if (raw.isEmpty) continue;
        final matched = matchCanonicalField(raw);
        if (matched != null) {
          canonicalColumnIndices[matched] = col;
          foundCanonicalFields.add(matched);
        }
      }

      debugPrint('[FileParser] Canonical column map: $canonicalColumnIndices');
      debugPrint('[FileParser] Found canonical fields: $foundCanonicalFields');

      if (foundCanonicalFields.isEmpty) {
        debugPrint('[FileParser] ERROR: 0 matching headers found in file');
        final message = (extension == 'xlsx' || extension == 'xls')
            ? 'This Excel file could not be read — it appears to be corrupted or was saved by a tool that produced an invalid .xlsx structure. Please open it in Excel/Google Sheets/LibreOffice and re-save it, or export it as .csv and import that instead.'
            : 'No recognizable column headers found in file. Please ensure your spreadsheet contains the required headers (S.No, Sim Numbers, Zone, Region, Branch, Admin Code).';
        return ValidationResult(
          isValid: false,
          fileName: file.name,
          totalRows: 0,
          requiredFields: requiredCanonicalFields,
          foundFields: [],
          missingFields: requiredCanonicalFields,
          records: [],
          errorMessage: message,
        );
      }

      // Identify missing required fields
      final List<String> missingFields = requiredCanonicalFields
          .where((field) => !foundCanonicalFields.contains(field))
          .toList();

      if (missingFields.isNotEmpty) {
        debugPrint('[FileParser] Missing fields: $missingFields');
      }

      // Extract data rows & validate row content
      final List<PanelRecord> records = [];
      final List<String> rowValidationErrors = [];
      final int dataStartRow = headerRowIndex + 1;

      for (int i = dataStartRow; i < rows.length; i++) {
        final row = rows[i];
        final int rowNum = i + 1;
        if (row.every(
          (cell) => cell == null || sanitizeCellValue(cell).isEmpty,
        )) {
          // Blank row marks end of dataset
          debugPrint(
            '[FileParser] Blank row at $i — stopping data extraction.',
          );
          break;
        }

        String getColValue(String fieldName) {
          final idx = canonicalColumnIndices[fieldName];
          if (idx != null && idx < row.length && row[idx] != null) {
            return sanitizeCellValue(row[idx]);
          }
          return '';
        }

        final sNoVal = getColValue('S.No');
        final simVal = getColValue('Sim Numbers');
        final imsiVal = getColValue('SIM_IMSI');
        final zoneVal = getColValue('Zone');
        final regionVal = getColValue('Region');
        final branchVal = getColValue('Branch');
        final adminVal = getColValue('Admin Code');

        // Check mandatory fields in data row
        final List<String> missingRowFields = [];
        if (sNoVal.isEmpty) missingRowFields.add('S.No');
        if (simVal.isEmpty) missingRowFields.add('Sim Number');
        if (zoneVal.isEmpty) missingRowFields.add('Zone');
        if (regionVal.isEmpty) missingRowFields.add('Region');
        if (branchVal.isEmpty) missingRowFields.add('Branch');
        if (adminVal.isEmpty) missingRowFields.add('Admin Code');

        final String sNoLabel = sNoVal.isNotEmpty ? ' (S.No "$sNoVal")' : '';

        if (missingRowFields.isNotEmpty) {
          rowValidationErrors.add(
            'Row $rowNum$sNoLabel: Missing required field(s): ${missingRowFields.join(", ")}.',
          );
        }

        // SIM Number format check: 10 to 13 digits, numeric only
        if (simVal.isNotEmpty && !RegExp(r'^\d{10,13}$').hasMatch(simVal)) {
          rowValidationErrors.add(
            'Row $rowNum$sNoLabel: Sim Number "$simVal" must be 10 to 13 digits (numeric only).',
          );
        }

        // Admin Code format check: 4 digits, numeric only
        if (adminVal.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(adminVal)) {
          rowValidationErrors.add(
            'Row $rowNum$sNoLabel: Admin Code "$adminVal" must be exactly 4 digits (numeric only).',
          );
        }

        records.add(
          PanelRecord(
            sNo: sNoVal,
            panelSimNumber: simVal,
            simImsi: imsiVal.isNotEmpty ? imsiVal : 'N/A',
            zone: zoneVal,
            region: regionVal,
            branch: branchVal,
            adminCode: adminVal,
          ),
        );
      }

      // Uniqueness Validation for Sim Numbers & S.No
      final List<String> duplicateErrors = [];

      final Map<String, List<String>> simToSNos = {};
      for (var record in records) {
        final sim = record.panelSimNumber.trim();
        final sNo = record.sNo.trim();
        if (sim.isNotEmpty) {
          simToSNos
              .putIfAbsent(sim, () => [])
              .add(sNo.isNotEmpty ? sNo : 'Unknown SNo');
        }
      }

      final List<String> simDuplicateMsgs = [];
      simToSNos.forEach((sim, sNos) {
        if (sNos.length > 1) {
          simDuplicateMsgs.add(
            'S.No ${sNos.join(" and S.No ")} have duplicate SIM ($sim)',
          );
        }
      });

      if (simDuplicateMsgs.isNotEmpty) {
        duplicateErrors.add(
          'SIM Number is not unique. Details: ${simDuplicateMsgs.join("; ")}',
        );
      }

      final Map<String, List<int>> sNoToRowIndices = {};
      for (int idx = 0; idx < records.length; idx++) {
        final sNo = records[idx].sNo.trim();
        if (sNo.isNotEmpty) {
          sNoToRowIndices.putIfAbsent(sNo, () => []).add(idx + 1);
        }
      }

      final List<String> sNoDuplicateMsgs = [];
      sNoToRowIndices.forEach((sNo, rowsList) {
        if (rowsList.length > 1) {
          sNoDuplicateMsgs.add(
            'S.No "$sNo" appears multiple times (rows ${rowsList.join(", ")})',
          );
        }
      });

      if (sNoDuplicateMsgs.isNotEmpty) {
        duplicateErrors.add(
          'Serial Number (S.No) is not unique: ${sNoDuplicateMsgs.join("; ")}',
        );
      }

      debugPrint('[FileParser] Extracted records: ${records.length}');
      if (duplicateErrors.isNotEmpty) {
        debugPrint('[FileParser] Duplicate errors: $duplicateErrors');
      }

      final List<String> allErrors = [];
      if (missingFields.isNotEmpty) {
        allErrors.add(
          'Missing required field(s): ${missingFields.join(", ")}. Please ensure your spreadsheet contains all required headers (S.No, Sim Numbers, Zone, Region, Branch, Admin Code).',
        );
      }
      if (records.isEmpty) {
        allErrors.add(
          'Spreadsheet contains no panel records below the header row. Please add data rows before uploading.',
        );
      }
      if (duplicateErrors.isNotEmpty) {
        allErrors.addAll(duplicateErrors);
      }
      if (rowValidationErrors.isNotEmpty) {
        allErrors.addAll(rowValidationErrors);
      }

      final bool isValid =
          missingFields.isEmpty &&
          records.isNotEmpty &&
          duplicateErrors.isEmpty &&
          rowValidationErrors.isEmpty;

      final String? finalErrorMessage = allErrors.isNotEmpty
          ? allErrors.join('\n\n')
          : null;

      debugPrint(
        '[FileParser] Result: isValid=$isValid, totalRows=${records.length}, errorMessage=$finalErrorMessage',
      );

      return ValidationResult(
        isValid: isValid,
        fileName: file.name,
        totalRows: records.length,
        requiredFields: requiredCanonicalFields,
        foundFields: foundCanonicalFields.toList(),
        missingFields: missingFields,
        records: records,
        errorMessage: finalErrorMessage,
      );
    } catch (e, stackTrace) {
      debugPrint('[FileParser] EXCEPTION while parsing file: $e');
      debugPrint('[FileParser] Stack trace:\n$stackTrace');
      return ValidationResult(
        isValid: false,
        fileName: file.name,
        totalRows: 0,
        requiredFields: requiredCanonicalFields,
        foundFields: [],
        missingFields: requiredCanonicalFields,
        records: [],
        errorMessage: 'Failed to process file: ${e.toString()}',
      );
    }
  }

  List<List<dynamic>> _parseExcel(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      debugPrint(
        '[FileParser] Excel decoded. Sheet names: ${excel.tables.keys.toList()}',
      );

      List<List<dynamic>> bestRows = [];
      int maxMatchedHeaders = -1;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.rows.isEmpty) continue;

        final List<List<dynamic>> currentSheetRows = [];
        int matchedHeaderCount = 0;

        for (var row in sheet.rows) {
          final rowValues = row.map((cell) => cell?.value).toList();
          currentSheetRows.add(rowValues);

          for (var cell in rowValues) {
            final str = sanitizeCellValue(cell);
            if (str.isNotEmpty && matchCanonicalField(str) != null) {
              matchedHeaderCount++;
            }
          }
        }

        debugPrint(
          '[FileParser] Sheet "$table": rows=${currentSheetRows.length}, matchedHeaders=$matchedHeaderCount',
        );

        if (matchedHeaderCount > maxMatchedHeaders) {
          maxMatchedHeaders = matchedHeaderCount;
          bestRows = currentSheetRows;
        }
      }

      if (bestRows.isNotEmpty && maxMatchedHeaders > 0) {
        return bestRows;
      }

      if (bestRows.isNotEmpty) return bestRows;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet != null && sheet.rows.isNotEmpty) {
          return sheet.rows
              .map((row) => row.map((cell) => cell?.value).toList())
              .toList();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[FileParser] Excel parse EXCEPTION: $e');
      debugPrint('[FileParser] Stack trace:\n$stackTrace');
    }

    // Fallback: try parsing as HTML table or CSV text (for web-exported .xlsx files)
    debugPrint(
      '[FileParser] Attempting HTML/Text table fallback for Excel file...',
    );
    return _parseHtmlOrTextTable(bytes);
  }

  List<List<dynamic>> _parseHtmlOrTextTable(Uint8List bytes) {
    try {
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }

      // Check if file is actually an HTML table saved with .xlsx extension
      if (content.toLowerCase().contains('<table') ||
          content.toLowerCase().contains('<tr')) {
        final List<List<dynamic>> rows = [];
        final trRegex = RegExp(
          r'<tr[^>]*>(.*?)<\/tr>',
          caseSensitive: false,
          dotAll: true,
        );
        final tdRegex = RegExp(
          r'<(?:td|th)[^>]*>(.*?)<\/(?:td|th)>',
          caseSensitive: false,
          dotAll: true,
        );

        for (final trMatch in trRegex.allMatches(content)) {
          final trContent = trMatch.group(1) ?? '';
          final List<dynamic> row = [];
          for (final tdMatch in tdRegex.allMatches(trContent)) {
            String cell = tdMatch.group(1) ?? '';
            cell = cell.replaceAll(RegExp(r'<[^>]*>'), '').trim();
            cell = cell
                .replaceAll('&nbsp;', ' ')
                .replaceAll('&amp;', '&')
                .replaceAll('&lt;', '<')
                .replaceAll('&gt;', '>')
                .replaceAll('&quot;', '"');
            row.add(cell.trim());
          }
          if (row.isNotEmpty) {
            rows.add(row);
          }
        }
        if (rows.isNotEmpty) return rows;
      }

      return const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(content);
    } catch (e) {
      debugPrint('HTML/CSV fallback parse error: $e');
      return [];
    }
  }

  List<List<dynamic>> _parseCsv(Uint8List bytes) {
    try {
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }
      return const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(content);
    } catch (e) {
      debugPrint('CSV parse error: $e');
      return [];
    }
  }

  List<List<dynamic>> _parsePdfTextFallback(Uint8List bytes) {
    try {
      final text = String.fromCharCodes(bytes);
      final lines = text.split(RegExp(r'\r?\n'));
      final List<List<dynamic>> rows = [];
      for (var l in lines) {
        if (l.trim().isNotEmpty) {
          rows.add(l.split(RegExp(r'[\t,;|]')));
        }
      }
      return rows;
    } catch (e) {
      return [];
    }
  }
}
