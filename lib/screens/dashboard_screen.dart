import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../models/panel_record_model.dart';
import '../services/file_parser_service.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';
import '../widgets/file_upload_zone.dart';
import '../widgets/validation_badge.dart';
import 'login_screen.dart';
import 'panel_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final HiveService _hiveService = HiveService();
  final FileParserService _fileParserService = FileParserService();

  UserModel? _currentUser;
  bool _isProcessing = false;
  ValidationResult? _lastValidationResult;
  List<ValidationResult> _uploadHistory = [];
  List<PanelRecord> _panelRecords = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    setState(() {
      _currentUser = _hiveService.getCurrentUser();
      _uploadHistory = _hiveService.getUploadHistory();
      if (_uploadHistory.isNotEmpty) {
        _lastValidationResult = _uploadHistory.first;
      }
      _panelRecords = _hiveService.getSavedPanelRecords();
    });
  }

  Future<void> _pickAndProcessFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'pdf', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        await _processFile(file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File pick error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _processFile(PlatformFile file) async {
    setState(() => _isProcessing = true);

    final validationResult = await _fileParserService.parseAndValidateFile(
      file,
    );
    await _hiveService.saveUploadHistory(validationResult);

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _lastValidationResult = validationResult;
      _uploadHistory = _hiveService.getUploadHistory();
      _panelRecords = _hiveService.getSavedPanelRecords();
    });
  }

  Future<void> _logout() async {
    await _hiveService.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _openPanelList() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PanelListScreen(
              records: _panelRecords,
              onRecordsUpdated: () async {
                await _hiveService.savePanelRecordsTable(_panelRecords);
              },
            ),
          ),
        )
        .then((_) {
          // Refresh in case admin codes were changed while on the panel list page.
          if (mounted) setState(() {});
        });
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload History',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Past uploaded documents',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: _uploadHistory.isEmpty
                  ? Center(
                      child: Text(
                        'No upload history yet.',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _uploadHistory.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _uploadHistory[index];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: item.isValid
                                ? AppColors.successBg
                                : AppColors.errorBg,
                            child: Icon(
                              item.isValid ? Icons.check_circle : Icons.cancel,
                              color: item.isValid
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          title: Text(
                            item.fileName,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            item.isValid
                                ? 'Valid • ${item.totalRows} panel records'
                                : 'Invalid • ${item.missingFields.isNotEmpty ? "Missing: ${item.missingFields.join(', ')}" : "Duplicate Data Error"}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: item.isValid
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _lastValidationResult = item;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validationResult = _lastValidationResult;
    final hasPanelData = _panelRecords.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_currentUser != null)
                  Text(
                    'Welcome, ${_currentUser!.username} (${_currentUser!.mobileNumber})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          if (hasPanelData)
            IconButton(
              icon: const Icon(
                Icons.cloud_upload_rounded,
                color: AppColors.primary,
              ),
              tooltip: 'Upload New File',
              onPressed: _isProcessing ? null : _pickAndProcessFile,
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.primary),
            tooltip: 'Upload History',
            onPressed: _showHistoryModal,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasPanelData) ...[
                  _SectionLabel(text: 'UPLOAD PANEL DATA'),
                  const SizedBox(height: 10),
                  FileUploadZone(
                    onSelectFile: _pickAndProcessFile,
                    isUploading: _isProcessing,
                    selectedFileName: validationResult?.fileName,
                  ),
                  if (validationResult != null &&
                      !validationResult.isValid) ...[
                    const SizedBox(height: 20),
                    ValidationBadgeCard(result: validationResult),
                  ],
                ] else ...[
                  if (validationResult != null &&
                      !validationResult.isValid) ...[
                    ValidationBadgeCard(result: validationResult),
                    const SizedBox(height: 20),
                  ],
                  _TotalRecordsCard(
                    totalRecords: _panelRecords.length,
                    onViewPanelList: _openPanelList,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Shown once panel data exists: total record count only, plus a button
/// through to the full Panel List page.
class _TotalRecordsCard extends StatelessWidget {
  final int totalRecords;
  final VoidCallback onViewPanelList;

  const _TotalRecordsCard({
    required this.totalRecords,
    required this.onViewPanelList,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.table_rows_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '$totalRecords',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            totalRecords == 1 ? 'Total Panel Record' : 'Total Panel Records',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 24),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onViewPanelList,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View Panel List',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
