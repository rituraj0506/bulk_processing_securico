import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../models/panel_record_model.dart';
import '../services/file_parser_service.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';
import '../widgets/data_table_view.dart';
import '../widgets/file_upload_zone.dart';
import '../widgets/stats_card.dart';
import '../widgets/validation_badge.dart';
import 'login_screen.dart';

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

  int _selectedPanelCount = 0;
  VoidCallback? _triggerChangeAdminCodeFlow;

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

    final validationResult = await _fileParserService.parseAndValidateFile(file);
    await _hiveService.saveUploadHistory(validationResult);

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _lastValidationResult = validationResult;
      _uploadHistory = _hiveService.getUploadHistory();
      _selectedPanelCount = 0;
      _triggerChangeAdminCodeFlow = null;
    });
  }

  Future<void> _logout() async {
    await _hiveService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
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
                        style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
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
                            backgroundColor: item.isValid ? AppColors.successBg : AppColors.errorBg,
                            child: Icon(
                              item.isValid ? Icons.check_circle : Icons.cancel,
                              color: item.isValid ? AppColors.success : AppColors.error,
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
                              color: item.isValid ? AppColors.success : AppColors.error,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _lastValidationResult = item;
                              _selectedPanelCount = 0;
                              _triggerChangeAdminCodeFlow = null;
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
    final records = validationResult?.records ?? [];

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
              child: const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 22),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _selectedPanelCount > 0
          ? Container(
              constraints: const BoxConstraints(maxWidth: 460),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => _triggerChangeAdminCodeFlow?.call(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.password_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Change Admin Code',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '$_selectedPanelCount panel(s) selected',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Proceed',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primaryDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File Upload Zone
                FileUploadZone(
                  onSelectFile: _pickAndProcessFile,
                  isUploading: _isProcessing,
                  selectedFileName: validationResult?.fileName,
                ),
                const SizedBox(height: 20),

                // If a file was uploaded:
                if (validationResult != null) ...[
                  // Format status card
                  ValidationBadgeCard(result: validationResult),
                  const SizedBox(height: 20),

                  // If valid file -> show stats cards & data table details
                  if (validationResult.isValid && records.isNotEmpty) ...[
                    StatsSummaryRow(
                      totalRecords: records.length,
                    ),
                    const SizedBox(height: 20),

                    DataTableView(
                      key: ValueKey('data_table_${validationResult.fileName}_${records.length}'),
                      records: records,
                      onRecordsUpdated: () async {
                        await _hiveService.saveUploadHistory(validationResult);
                        setState(() {});
                      },
                      onSelectionChanged: (count, triggerFlow) {
                        setState(() {
                          _selectedPanelCount = count;
                          _triggerChangeAdminCodeFlow = triggerFlow;
                        });
                      },
                    ),

                    const SizedBox(height: 60),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
