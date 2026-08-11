import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/panel_record_model.dart';

class FileParserService {
  // Required 8 canonical fields from Excel screenshot format
  static const List<String> requiredCanonicalFields = [
    'S.No',
    'Sim Numbers',
    'SIM_IMSI',
    'Zone',
    'Region',
    'Branch',
    'Admin Code',
    'Panel Type',
  ];

  static String sanitizeCellValue(dynamic cellValue) {
    if (cellValue == null) return '';

    String str = '';
    if (cellValue is double) {
      if (cellValue == cellValue.truncateToDouble()) {
        return cellValue.toInt().toString();
      }
      str = cellValue.toString();
    } else {
      str = cellValue.toString().trim();
    }

    // Strip trailing .0 if formatted as floating point (e.g., "9876543210.0" -> "9876543210")
    if (str.endsWith('.0') && RegExp(r'^-?\d+\.0$').hasMatch(str)) {
      return str.substring(0, str.length - 2);
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
    if (norm == 'sno' ||
        norm == 'sno.' ||
        norm == 's.no' ||
        norm == 'sno' ||
        norm == 'slno' ||
        norm == 'srno' ||
        norm == 'serialno' ||
        norm == 'serialnumber') {
      return 'S.No';
    }

    // 2. Sim Numbers matching
    if (norm == 'simnumbers' ||
        norm == 'simnumber' ||
        norm == 'simnos' ||
        norm == 'simno' ||
        norm == 'panelsimnumber' ||
        norm == 'panelsimno' ||
        norm == 'sim') {
      return 'Sim Numbers';
    }

    // 3. SIM_IMSI matching
    if (norm == 'simimsi' ||
        norm == 'sim_imsi' ||
        norm == 'imsi' ||
        norm == 'simimsi') {
      return 'SIM_IMSI';
    }

    // 4. Zone matching
    if (norm == 'zone' || norm.contains('zone')) {
      return 'Zone';
    }

    // 5. Region matching
    if (norm == 'region' || norm.contains('region')) {
      return 'Region';
    }

    // 6. Branch matching
    if (norm == 'branch' ||
        norm == 'branchname' ||
        norm == 'panelname' ||
        norm.contains('branch')) {
      return 'Branch';
    }

    // 7. Admin Code matching
    if (norm == 'admincode' ||
        norm == 'admincode' ||
        (norm.contains('admin') && norm.contains('code'))) {
      return 'Admin Code';
    }

    // 8. Panel Type matching
    if (norm == 'paneltype' ||
        norm == 'panel_type' ||
        norm == 'panel' ||
        norm.contains('type')) {
      return 'Panel Type';
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
          errorMessage: 'Could not find a valid header row in the file.',
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

      // Identify missing required fields
      final List<String> missingFields = requiredCanonicalFields
          .where((field) => !foundCanonicalFields.contains(field))
          .toList();

      if (missingFields.isNotEmpty) {
        debugPrint('[FileParser] Missing fields: $missingFields');
      }

      // Extract data rows if headers matched
      final List<PanelRecord> records = [];
      final int dataStartRow = headerRowIndex + 1;

      for (int i = dataStartRow; i < rows.length; i++) {
        final row = rows[i];
        if (row.every(
          (cell) => cell == null || sanitizeCellValue(cell).isEmpty,
        )) {
          // A fully blank row marks the end of the data table; anything after
          // (e.g. trailing notes) is not part of the dataset and is ignored.
          debugPrint(
            '[FileParser] Blank row at $i — stopping data extraction, ignoring remaining rows.',
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
        final panelTypeVal = getColValue('Panel Type');

        // A row must carry the core identifying data (S.No and Sim Number) to
        // be considered a real record; otherwise it's neglected rather than
        // imported as a malformed entry.
        if (sNoVal.isNotEmpty && simVal.isNotEmpty) {
          records.add(
            PanelRecord(
              sNo: sNoVal,
              panelSimNumber: simVal,
              simImsi: imsiVal.isNotEmpty ? imsiVal : 'N/A',
              zone: zoneVal,
              region: regionVal,
              branch: branchVal,
              adminCode: adminVal,
              panelType: panelTypeVal.isNotEmpty ? panelTypeVal : 'A1',
            ),
          );
        } else {
          debugPrint(
            '[FileParser] Row $i skipped — missing required S.No/Sim Number data: $row',
          );
        }
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

      final bool isValid = missingFields.isEmpty && duplicateErrors.isEmpty;

      String? finalErrorMessage;
      if (missingFields.isNotEmpty) {
        finalErrorMessage =
            'Missing required field(s): ${missingFields.join(", ")}. Please ensure your spreadsheet contains all screenshot headers (S.No, Sim Numbers, SIM_IMSI, Zone, Region, Branch, Admin Code, Panel Type).';
      } else if (duplicateErrors.isNotEmpty) {
        finalErrorMessage = duplicateErrors.join('\n\n');
      }

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
      List<List<dynamic>> rows = [];
      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        debugPrint(
          '[FileParser] Sheet "$table" row count: ${sheet?.rows.length ?? 0}',
        );
        if (sheet != null) {
          for (var row in sheet.rows) {
            final rowValues = row.map((cell) => cell?.value).toList();
            rows.add(rowValues);
          }
        }
        if (rows.isNotEmpty) break;
      }
      return rows;
    } catch (e, stackTrace) {
      debugPrint('[FileParser] Excel parse EXCEPTION: $e');
      debugPrint('[FileParser] Stack trace:\n$stackTrace');
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
