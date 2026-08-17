import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';

class TemplateService {
  // Clean, professional CSV content template containing only column headers
  static const String sampleCsvContent =
      'S.No,Sim Numbers,SIM_IMSI,Zone,Region,Branch,Admin Code\n';

  /// Generates a clean, professional .xlsx Excel file bytes with bold white headers
  /// on a dark green background and proper column widths.
  static Uint8List generateSampleExcelBytes() {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];

    // Professional Green Header Style (Bold White text on Dark Green background)
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E7E34'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = [
      'S.No (Unique)',
      'Sim Numbers (10 to 13 Digits)',
      'SIM_IMSI (Optional)',
      'Zone',
      'Region',
      'Branch',
      'Admin Code (4 Digits)',
    ];

    final columnWidths = [22.0, 36.0, 26.0, 18.0, 18.0, 28.0, 28.0];

    // Write Row 0: Green Bold Header & Set Column Widths
    for (int col = 0; col < headers.length; col++) {
      sheet.setColumnWidth(col, columnWidths[col]);
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  static Future<void> downloadSampleExcel(BuildContext context) async {
    try {
      final bytes = generateSampleExcelBytes();
      String savedPath = '';

      // 1. Primary Method: Native System Save dialog (safely writes to public Downloads & indexes in MediaStore)
      try {
        final pickerPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Sample Panel Excel Template',
          fileName: 'DVARA_Panel_Template.xlsx',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: bytes,
        );
        if (pickerPath != null && pickerPath.isNotEmpty) {
          final file = File(pickerPath);
          await file.writeAsBytes(bytes, flush: true);
          savedPath = file.path;
        }
      } catch (_) {}

      // 2. Direct Public Downloads Directory fallback
      if (savedPath.isEmpty && Platform.isAndroid) {
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            final file = File('${downloadDir.path}/DVARA_Panel_Template.xlsx');
            await file.writeAsBytes(bytes, flush: true);
            savedPath = file.path;
          }
        } catch (_) {}
      }

      // 3. Fallback to Documents directory
      if (savedPath.isEmpty) {
        final docDir = await getApplicationDocumentsDirectory();
        final file = File('${docDir.path}/DVARA_Panel_Template.xlsx');
        await file.writeAsBytes(bytes, flush: true);
        savedPath = file.path;
      }

      final finalPath = savedPath;
      OpenFilex.open(finalPath);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Row(
            children: [
              const Icon(
                Icons.file_download_done_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Excel Template Saved!',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Saved to: ${finalPath.split("/").last}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          action: SnackBarAction(
            label: 'OPEN FILE',
            textColor: Colors.white,
            onPressed: () {
              OpenFilex.open(finalPath);
            },
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to download template: $e',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static Future<void> downloadSampleCsv(BuildContext context) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(sampleCsvContent));
      String savedPath = '';

      if (Platform.isAndroid) {
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            final file = File('${downloadDir.path}/DVARA_Panel_Template.csv');
            await file.writeAsBytes(bytes, flush: true);
            savedPath = file.path;
          }
        } catch (_) {}
      }

      if (savedPath.isEmpty) {
        try {
          final pickerPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Sample Panel CSV Template',
            fileName: 'DVARA_Panel_Template.csv',
            type: FileType.custom,
            allowedExtensions: ['csv'],
            bytes: bytes,
          );
          if (pickerPath != null && pickerPath.isNotEmpty) {
            final file = File(pickerPath);
            await file.writeAsBytes(bytes, flush: true);
            savedPath = file.path;
          }
        } catch (_) {}
      }

      if (savedPath.isEmpty) {
        final docDir = await getApplicationDocumentsDirectory();
        final file = File('${docDir.path}/DVARA_Panel_Template.csv');
        await file.writeAsBytes(bytes, flush: true);
        savedPath = file.path;
      }

      final finalPath = savedPath;
      OpenFilex.open(finalPath);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Row(
            children: [
              const Icon(
                Icons.file_download_done_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CSV Template downloaded successfully!',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap OPEN FILE to view in Excel / Sheets',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          action: SnackBarAction(
            label: 'OPEN FILE',
            textColor: Colors.white,
            onPressed: () {
              OpenFilex.open(finalPath);
            },
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to download template: $e',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static void showExportGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.description_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload Format Guide',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Required spreadsheet columns',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To successfully upload panel records, your Excel or CSV file MUST contain these 6 required headers:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildGuideFieldRow(
                        '1. S.No',
                        'Serial Number (Unique per record)',
                      ),
                      _buildGuideFieldRow(
                        '2. Sim Numbers',
                        'SIM Number (10 to 13 digits, numeric)',
                      ),
                      _buildGuideFieldRow('3. Zone', 'Zone region name'),
                      _buildGuideFieldRow('4. Region', 'Regional branch area'),
                      _buildGuideFieldRow('5. Branch', 'Branch office name'),
                      _buildGuideFieldRow(
                        '6. Admin Code',
                        '4-digit admin security code',
                      ),
                      _buildGuideFieldRow(
                        '7. SIM_IMSI',
                        'SIM IMSI identifier (Optional)',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.table_chart_rounded, size: 20),
            label: Text(
              'Download Excel Template (.xlsx)',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              downloadSampleExcel(context);
            },
          ),
        ],
      ),
    );
  }

  static Widget _buildGuideFieldRow(String fieldName, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            fieldName,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              textAlign: TextAlign.end,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
