import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/panel_record_model.dart';

class FileParserService {
  // Required 5 canonical fields specified by requirement
  static const List<String> requiredCanonicalFields = [
    'S No',
    'Panel Sim Number',
    'Panel Name',
    'Admin Code',
    'Site Address',
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
    return header
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  /// Maps normalized string to canonical field name if matched
  static String? matchCanonicalField(String rawHeader) {
    final norm = normalizeHeader(rawHeader);

    // 1. S No matching
    if (norm == 'sno' ||
        norm == 'sno.' ||
        norm == 's.no' ||
        norm == 'slno' ||
        norm == 'srno' ||
        norm == 'serialno' ||
        norm == 'serialnumber') {
      return 'S No';
    }

    // 2. Panel Sim Number matching
    if (norm == 'panelsimnumber' ||
        norm == 'panelsimno' ||
        norm == 'panelsim' ||
        (norm.contains('panel') && norm.contains('sim'))) {
      return 'Panel Sim Number';
    }

    // 3. Panel Name matching
    if (norm == 'panelname' ||
        (norm.contains('panel') && norm.contains('name'))) {
      return 'Panel Name';
    }

    // 4. Admin Code matching
    if (norm == 'admincode' ||
        (norm.contains('admin') && norm.contains('code'))) {
      return 'Admin Code';
    }

    // 5. Site Address matching
    if (norm == 'siteaddress' ||
        norm == 'siteaddr' ||
        (norm.contains('site') && norm.contains('address')) ||
        norm == 'address') {
      return 'Site Address';
    }

    return null;
  }

  Future<ValidationResult> parseAndValidateFile(PlatformFile file) async {
    try {
      List<List<dynamic>> rows = [];
      Uint8List? bytes = file.bytes;

      if (bytes == null && file.path != null) {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          bytes = await ioFile.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
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

      if (extension == 'xlsx' || extension == 'xls') {
        rows = _parseExcel(bytes);
      } else if (extension == 'csv' || extension == 'txt' || extension == 'tsv') {
        rows = _parseCsv(bytes);
      } else if (extension == 'pdf') {
        rows = _parsePdfTextFallback(bytes);
      } else {
        rows = _parseCsv(bytes);
      }

      if (rows.isEmpty) {
        return ValidationResult(
          isValid: false,
          fileName: file.name,
          totalRows: 0,
          requiredFields: requiredCanonicalFields,
          foundFields: [],
          missingFields: requiredCanonicalFields,
          records: [],
          errorMessage: 'No readable rows or table structure found in file.',
        );
      }

      // First non-empty row is treated as header row
      int headerRowIndex = -1;
      List<String> rawHeaders = [];

      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        if (r.any((cell) => cell != null && sanitizeCellValue(cell).isNotEmpty)) {
          headerRowIndex = i;
          rawHeaders = r.map((c) => sanitizeCellValue(c)).toList();
          break;
        }
      }

      if (headerRowIndex == -1 || rawHeaders.isEmpty) {
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

      // Identify missing required fields
      final List<String> missingFields = requiredCanonicalFields
          .where((field) => !foundCanonicalFields.contains(field))
          .toList();

      // Extract data rows if headers matched
      final List<PanelRecord> records = [];
      final int dataStartRow = headerRowIndex + 1;

      for (int i = dataStartRow; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((cell) => cell == null || sanitizeCellValue(cell).isEmpty)) {
          continue; // skip blank rows
        }

        String getColValue(String fieldName) {
          final idx = canonicalColumnIndices[fieldName];
          if (idx != null && idx < row.length && row[idx] != null) {
            return sanitizeCellValue(row[idx]);
          }
          return '';
        }

        final sNoVal = getColValue('S No');
        final simVal = getColValue('Panel Sim Number');
        final nameVal = getColValue('Panel Name');
        final adminVal = getColValue('Admin Code');
        final siteVal = getColValue('Site Address');

        // Only add if at least one column is non-empty
        if (sNoVal.isNotEmpty ||
            simVal.isNotEmpty ||
            nameVal.isNotEmpty ||
            adminVal.isNotEmpty ||
            siteVal.isNotEmpty) {
          records.add(PanelRecord(
            sNo: sNoVal,
            panelSimNumber: simVal,
            panelName: nameVal,
            adminCode: adminVal,
            siteAddress: siteVal,
          ));
        }
      }

      // Perform Uniqueness Validation for Panel Sim Number & S No
      final List<String> duplicateErrors = [];

      // 1. Check Panel Sim Number uniqueness across rows
      final Map<String, List<String>> simToSNos = {};
      for (var record in records) {
        final sim = record.panelSimNumber.trim();
        final sNo = record.sNo.trim();
        if (sim.isNotEmpty) {
          simToSNos.putIfAbsent(sim, () => []).add(sNo.isNotEmpty ? sNo : 'Unknown SNo');
        }
      }

      final List<String> simDuplicateMsgs = [];
      simToSNos.forEach((sim, sNos) {
        if (sNos.length > 1) {
          simDuplicateMsgs.add('S No ${sNos.join(" and S No ")} have the same Panel SIM number ($sim)');
        }
      });

      if (simDuplicateMsgs.isNotEmpty) {
        duplicateErrors.add(
          'Panel SIM number is not unique. For example: ${simDuplicateMsgs.join("; ")}. Please correct and re-upload file.',
        );
      }

      // 2. Check S No uniqueness across rows
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
          sNoDuplicateMsgs.add('S No "$sNo" appears multiple times (rows ${rowsList.join(", ")})');
        }
      });

      if (sNoDuplicateMsgs.isNotEmpty) {
        duplicateErrors.add(
          'Serial Number (S No) is not unique. For example: ${sNoDuplicateMsgs.join("; ")}. Please correct and re-upload file.',
        );
      }

      // Final validity check: all required headers must exist AND no duplicates allowed!
      final bool isValid = missingFields.isEmpty && duplicateErrors.isEmpty;

      String? finalErrorMessage;
      if (missingFields.isNotEmpty) {
        finalErrorMessage = 'Missing required field(s): ${missingFields.join(", ")}. Please ensure your spreadsheet has all 5 exact column headers.';
      } else if (duplicateErrors.isNotEmpty) {
        finalErrorMessage = duplicateErrors.join('\n\n');
      }

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
    } catch (e) {
      debugPrint('Error parsing file: $e');
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
      List<List<dynamic>> rows = [];
      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet != null) {
          for (var row in sheet.rows) {
            final rowValues = row.map((cell) => cell?.value).toList();
            rows.add(rowValues);
          }
        }
        if (rows.isNotEmpty) break;
      }
      return rows;
    } catch (e) {
      debugPrint('Excel parse error: $e');
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
      return const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(content);
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
