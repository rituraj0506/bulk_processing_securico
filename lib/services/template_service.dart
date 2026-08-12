import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';

class TemplateService {
  // Clean, professional template containing only the required column headers
  static const String sampleCsvContent =
      'S.No,Sim Numbers,SIM_IMSI,Zone,Region,Branch,Admin Code,Panel Type\n';

  static Future<void> downloadSampleCsv(BuildContext context) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(sampleCsvContent));
      String savedPath = '';

      // On Android: Save directly into the user's public Downloads directory
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

      // Fallback via FilePicker if not written yet
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

      // Final fallback to Application Documents directory
      if (savedPath.isEmpty) {
        final docDir = await getApplicationDocumentsDirectory();
        final file = File('${docDir.path}/DVARA_Panel_Template.csv');
        await file.writeAsBytes(bytes, flush: true);
        savedPath = file.path;
      }

      // Attempt to automatically open the saved file in default app (Excel / Google Sheets / WPS Office)
      final finalPath = savedPath;
      OpenFilex.open(finalPath);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Row(
            children: [
              const Icon(Icons.file_download_done_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Template downloaded successfully!',
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To successfully upload panel records, your Excel or CSV file MUST contain these 8 required headers:',
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
                      _buildGuideFieldRow('1. S.No', 'Serial Number (Unique per record)'),
                      _buildGuideFieldRow('2. Sim Numbers', 'SIM Mobile Number'),
                      _buildGuideFieldRow('3. SIM_IMSI', 'SIM IMSI identifier'),
                      _buildGuideFieldRow('4. Zone', 'Zone region name'),
                      _buildGuideFieldRow('5. Region', 'Regional branch area'),
                      _buildGuideFieldRow('6. Branch', 'Branch office name'),
                      _buildGuideFieldRow('7. Admin Code', '6-digit admin security code'),
                      _buildGuideFieldRow('8. Panel Type', 'Model / Panel type (e.g. A1)'),
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
            icon: const Icon(Icons.download_rounded, size: 20),
            label: Text(
              'Download Sample CSV',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              downloadSampleCsv(context);
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