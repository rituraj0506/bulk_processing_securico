import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bulkprocessing/services/file_parser_service.dart';
import 'package:bulkprocessing/services/template_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = FileParserService();

  PlatformFile createTestFile(String name, String csvContent) {
    final bytes = Uint8List.fromList(utf8.encode(csvContent));
    return PlatformFile(name: name, size: bytes.length, bytes: bytes);
  }

  group('FileParserService Validation Tests', () {
    test(
      'Valid CSV with all 6 mandatory columns and valid 10-digit SIM and 4-digit Admin Code passes validation',
      () async {
        const csv = '''S.No,Sim Numbers,SIM_IMSI,Zone,Region,Branch,Admin Code
1,9876543210,123456789,North,Delhi,Connaught,1234
2,9876543211,987654321,South,Chennai,T Nagar,5678
''';
        final file = createTestFile('valid.csv', csv);
        final result = await service.parseAndValidateFile(file);

        expect(result.isValid, isTrue);
        expect(result.totalRows, equals(2));
        expect(result.errorMessage, isNull);
        expect(result.records[0].panelSimNumber, equals('9876543210'));
        expect(result.records[0].adminCode, equals('1234'));
        expect(result.records[0].simImsi, equals('123456789'));
      },
    );

    test('Valid CSV with 13-digit SIM number passes validation', () async {
      const csv = '''S.No,Sim Numbers,Zone,Region,Branch,Admin Code
1,9198765432100,North,Delhi,Connaught,1234
''';
      final file = createTestFile('valid_13digit.csv', csv);
      final result = await service.parseAndValidateFile(file);

      expect(result.isValid, isTrue);
      expect(result.totalRows, equals(1));
      expect(result.records[0].panelSimNumber, equals('9198765432100'));
    });

    test(
      'Valid CSV without SIM_IMSI or Panel Type passes validation',
      () async {
        const csv = '''S.No,Sim Numbers,Zone,Region,Branch,Admin Code
1,9876543210,North,Delhi,Connaught,1234
''';
        final file = createTestFile('no_imsi_or_paneltype.csv', csv);
        final result = await service.parseAndValidateFile(file);

        expect(result.isValid, isTrue);
        expect(result.totalRows, equals(1));
        expect(result.records[0].simImsi, equals('N/A'));
      },
    );

    test('Invalid CSV with 9-digit SIM number fails validation', () async {
      const csv = '''S.No,Sim Numbers,Zone,Region,Branch,Admin Code
1,987654321,North,Delhi,Connaught,1234
''';
      final file = createTestFile('sim_9digits.csv', csv);
      final result = await service.parseAndValidateFile(file);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('10 to 13 digits'));
    });

    test('Invalid CSV with 14-digit SIM number fails validation', () async {
      const csv = '''S.No,Sim Numbers,Zone,Region,Branch,Admin Code
1,91987654321009,North,Delhi,Connaught,1234
''';
      final file = createTestFile('sim_14digits.csv', csv);
      final result = await service.parseAndValidateFile(file);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('10 to 13 digits'));
    });

    test('Invalid CSV with non-numeric SIM number fails validation', () async {
      const csv = '''S.No,Sim Numbers,Zone,Region,Branch,Admin Code
1,9876543210a,North,Delhi,Connaught,1234
''';
      final file = createTestFile('sim_alpha.csv', csv);
      final result = await service.parseAndValidateFile(file);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('10 to 13 digits (numeric only)'));
    });

    test('Invalid CSV with 3-digit Admin Code fails validation', () async {
      const csv = '''S.No,Sim Numbers,Zone,Region,Branch,Admin Code
1,9876543210,North,Delhi,Connaught,123
''';
      final file = createTestFile('admin_3digits.csv', csv);
      final result = await service.parseAndValidateFile(file);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('exactly 4 digits (numeric only)'));
    });

    test('Invalid CSV with 5-digit Admin Code fails validation', () async {
      const csv = '''S.No,Sim Numbers,Zone,Region,Branch,Admin Code
1,9876543210,North,Delhi,Connaught,12345
''';
      final file = createTestFile('admin_5digits.csv', csv);
      final result = await service.parseAndValidateFile(file);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('exactly 4 digits (numeric only)'));
    });

    test('Invalid CSV with non-numeric Admin Code fails validation', () async {
      const csv = '''S.No,Sim Numbers,Zone,Region,Branch,Admin Code
1,9876543210,North,Delhi,Connaught,12a4
''';
      final file = createTestFile('admin_alpha.csv', csv);
      final result = await service.parseAndValidateFile(file);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('exactly 4 digits (numeric only)'));
    });

    test('Missing mandatory header column fails validation', () async {
      const csv = '''S.No,Sim Numbers,Zone,Region,Admin Code
1,9876543210,North,Delhi,1234
''';
      final file = createTestFile('missing_branch.csv', csv);
      final result = await service.parseAndValidateFile(file);

      expect(result.isValid, isFalse);
      expect(result.missingFields, contains('Branch'));
      expect(
        result.errorMessage,
        contains('Missing required field(s): Branch'),
      );
    });

    test('Duplicate SIM number fails validation', () async {
      const csv = '''S.No,Sim Numbers,Zone,Region,Branch,Admin Code
1,9876543210,North,Delhi,Connaught,1234
2,9876543210,South,Chennai,T Nagar,5678
''';
      final file = createTestFile('duplicate_sim.csv', csv);
      final result = await service.parseAndValidateFile(file);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('SIM Number is not unique'));
    });

    test(
      'Completely blank sheet fails validation with clear error message',
      () async {
        const csv = '';
        final file = createTestFile('empty.csv', csv);
        final result = await service.parseAndValidateFile(file);

        expect(result.isValid, isFalse);
        expect(result.totalRows, equals(0));
        expect(
          result.errorMessage,
          contains('File is empty or could not be read.'),
        );
      },
    );

    test('Header-only sheet with no data rows fails validation', () async {
      const csv = '''S.No,Sim Numbers,Zone,Region,Branch,Admin Code
''';
      final file = createTestFile('header_only.csv', csv);
      final result = await service.parseAndValidateFile(file);

      expect(result.isValid, isFalse);
      expect(result.totalRows, equals(0));
      expect(
        result.errorMessage,
        contains('Spreadsheet contains no panel records below the header row'),
      );
    });

    test(
      'Headers with inline format notes match canonical fields and pass validation',
      () async {
        const csv =
            '''"S.No (Unique)","Sim Numbers (10-13 Digits)","SIM_IMSI (Optional)","Zone","Region","Branch","Admin Code (4 Digits)"
1,9876543210,8991100000000000001,North,Delhi,Connaught,1234
''';
        final file = createTestFile('inline_notes_headers.csv', csv);
        final result = await service.parseAndValidateFile(file);

        expect(result.isValid, isTrue);
        expect(result.totalRows, equals(1));
        expect(result.records[0].panelSimNumber, equals('9876543210'));
        expect(result.records[0].adminCode, equals('1234'));
      },
    );

    test(
      'Web-exported HTML table saved as .xlsx parses successfully via fallback',
      () async {
        const htmlTable = '''<table>
<tr><th>S.No</th><th>Sim Numbers</th><th>Zone</th><th>Region</th><th>Branch</th><th>Admin Code</th></tr>
<tr><td>1</td><td>9876543210</td><td>North</td><td>Delhi</td><td>Connaught</td><td>1234</td></tr>
</table>''';
        final file = createTestFile(
          'Burglar_alarm_Sim_details_final.xlsx',
          htmlTable,
        );
        final result = await service.parseAndValidateFile(file);

        expect(result.isValid, isTrue);
        expect(result.totalRows, equals(1));
        expect(result.records[0].panelSimNumber, equals('9876543210'));
        expect(result.records[0].adminCode, equals('1234'));
      },
    );

    test(
      'TemplateService generateSampleExcelBytes produces non-zero valid Excel bytes',
      () {
        final bytes = TemplateService.generateSampleExcelBytes();
        expect(bytes.length, greaterThan(1000));
      },
    );
  });
}
