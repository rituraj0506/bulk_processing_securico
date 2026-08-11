import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/panel_record_model.dart';
import '../services/sms_command_service.dart';
import '../theme/app_colors.dart';

/// Step 1 Dialog: Prompts user for a 4-digit New Admin Code
class EnterAdminCodeDialog extends StatefulWidget {
  final int selectedCount;

  const EnterAdminCodeDialog({
    super.key,
    required this.selectedCount,
  });

  @override
  State<EnterAdminCodeDialog> createState() => _EnterAdminCodeDialogState();
}

class _EnterAdminCodeDialogState extends State<EnterAdminCodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_codeController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.password_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Admin Code',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Applies to ${widget.selectedCount} selected panel(s)',
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
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),

              Text(
                'Enter 4-Digit New Admin Code',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                autofocus: true,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  fillColor: AppColors.inputFill,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.error, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Admin code is required';
                  }
                  if (val.trim().length != 4) {
                    return 'Admin code must be exactly 4 digits';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Next',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Step 1.5 Dialog: Asks for explicit user confirmation before opening SMS dispatch
class ConfirmAdminCodeDialog extends StatelessWidget {
  final int selectedCount;
  final String newAdminCode;

  const ConfirmAdminCodeDialog({
    super.key,
    required this.selectedCount,
    required this.newAdminCode,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.help_outline_rounded, color: AppColors.warning, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirm Code Change',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Are you sure you want to proceed?',
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
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'New Admin Code:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          newAdminCode,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target Panels:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '$selectedCount panel(s)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Confirm & Proceed',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 2 Dialog: 100% Background SMS Dispatcher with Responsive Dynamic Overflow Prevention
class SmsCommandsQueueModal extends StatefulWidget {
  final List<PanelRecord> selectedRecords;
  final String newAdminCode;

  const SmsCommandsQueueModal({
    super.key,
    required this.selectedRecords,
    required this.newAdminCode,
  });

  @override
  State<SmsCommandsQueueModal> createState() => _SmsCommandsQueueModalState();
}

class _SmsCommandsQueueModalState extends State<SmsCommandsQueueModal> {
  late List<SmsCommandResult> _commandResults;
  final Set<int> _sentIndices = {};
  final Set<int> _failedIndices = {};
  final Map<int, String> _failureReasons = {};
  bool _isBatchProcessing = false;
  bool _isCompleting = false;
  bool _showDefaultSmsPrompt = false;

  @override
  void initState() {
    super.initState();
    _commandResults = widget.selectedRecords.map((record) {
      return SmsCommandService.generateChangeAdminCodeCommand(
        record: record,
        newAdminCode: widget.newAdminCode,
      );
    }).toList();
  }

  void _markSmsAsDispatchedAndMutateCode(int index) {
    final item = _commandResults[index];
    item.record.adminCode = widget.newAdminCode;

    setState(() {
      _sentIndices.add(index);
    });

    _checkCompletionAndFinish();
  }

  int get _supportedCount => _commandResults.where((c) => c.isSupported).length;

  double get _progress {
    if (_supportedCount == 0) return 0.0;
    return (_sentIndices.length + _failedIndices.length) / _supportedCount;
  }

  Future<void> _checkCompletionAndFinish() async {
    final totalProcessed = _sentIndices.length + _failedIndices.length;
    if (totalProcessed >= _supportedCount && !_isCompleting) {
      setState(() {
        _isBatchProcessing = false;
        _isCompleting = true;
      });

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      if (_sentIndices.isNotEmpty) {
        Navigator.of(context).pop(_sentIndices.length);
      } else {
        final firstError = _failureReasons.values.firstOrNull ?? 'Background SMS sending failed';
        Navigator.of(context).pop(firstError);
      }
    }
  }

  /// Dispatches SMS commands: strictly 100% background ONLY via native SmsManager MethodChannel
  Future<void> _launchSmsForIndex(int index) async {
    final item = _commandResults[index];
    if (!item.isSupported) return;

    // Send direct background SMS ONLY via native Android SmsManager MethodChannel (ZERO NAVIGATION!)
    final SmsSendResult sendResult = await SmsCommandService.sendSilentSms(
      phoneNumber: item.record.panelSimNumber,
      message: item.commandBody,
    );

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    if (sendResult.isSuccess) {
      // Background SMS send Succeeded via cellular SIM modem hardware!
      _markSmsAsDispatchedAndMutateCode(index);
    } else {
      // Background SMS send Failed - DO NOT NAVIGATE, DO NOT MUTATE CODE!
      final err = sendResult.errorMessage ?? 'Background SMS send failed';
      final isBlockedByOS = err.contains('TIMEOUT') || err.contains('16') || sendResult.requiresSmsAppRole;

      setState(() {
        _failedIndices.add(index);
        _failureReasons[index] = err;
        if (isBlockedByOS) {
          _showDefaultSmsPrompt = true;
        }
      });

      _checkCompletionAndFinish();
    }

    if (_isBatchProcessing) {
      _dispatchNextPanelInQueue();
    }
  }

  Future<void> _dispatchNextPanelInQueue() async {
    int nextIndex = -1;
    for (int i = 0; i < _commandResults.length; i++) {
      if (_commandResults[i].isSupported && !_sentIndices.contains(i) && !_failedIndices.contains(i)) {
        nextIndex = i;
        break;
      }
    }

    if (nextIndex != -1) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await _launchSmsForIndex(nextIndex);
    } else {
      _checkCompletionAndFinish();
    }
  }

  void _startBatchSmsFlow() {
    if (_isBatchProcessing || _isCompleting) return;

    setState(() {
      _isBatchProcessing = true;
      _showDefaultSmsPrompt = false;
    });

    _dispatchNextPanelInQueue();
  }

  Future<void> _handleRequestDefaultRole() async {
    await SmsCommandService.requestDefaultSmsRole();
  }

  @override
  Widget build(BuildContext context) {
    final supportedCount = _supportedCount;
    final progress = _progress;
    final maxModalHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 650, maxHeight: maxModalHeight),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header with clean title "SMS Commands"
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.sms_rounded, color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SMS Commands',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Change Admin Code → New Code: ${widget.newAdminCode} (${_sentIndices.length}/$supportedCount sent)',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isBatchProcessing && !_isCompleting)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Live Progress Bar Box
            if (_sentIndices.isNotEmpty || _failedIndices.isNotEmpty || _isBatchProcessing || _isCompleting) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isCompleting
                      ? (_sentIndices.isNotEmpty ? AppColors.successBg : AppColors.errorBg)
                      : AppColors.primaryLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isCompleting
                        ? (_sentIndices.isNotEmpty ? AppColors.success : AppColors.error)
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (_isCompleting)
                                Icon(
                                  _sentIndices.isNotEmpty ? Icons.check_circle_rounded : Icons.error_rounded,
                                  color: _sentIndices.isNotEmpty ? AppColors.success : AppColors.error,
                                  size: 18,
                                )
                              else
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _isCompleting
                                      ? (_sentIndices.isNotEmpty
                                          ? 'Background SMS Sent & Admin Code Updated! Closing in 2s...'
                                          : 'Background SMS Dispatch Failed! Admin Code Not Updated.')
                                      : 'Sending background SMS (${_sentIndices.length + _failedIndices.length}/$supportedCount)...',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _isCompleting
                                        ? (_sentIndices.isNotEmpty ? AppColors.success : AppColors.error)
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _isCompleting
                                ? (_sentIndices.isNotEmpty ? AppColors.success : AppColors.error)
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isCompleting
                              ? (_sentIndices.isNotEmpty ? AppColors.success : AppColors.error)
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Android Security Warning Card when Android OS blocks background SMS
            if (_showDefaultSmsPrompt) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Android Security Policy Restriction',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Redmi MIUI / Android 10+ blocks silent background SMS. Tap below to set Bulk Processing as Default SMS App to send 100% silently!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: _handleRequestDefaultRole,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: Flexible(
                        child: Text(
                          'Set Default SMS App (Enable Silent Send)',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // SMS Command Item List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _commandResults.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final item = _commandResults[index];
                  final isSent = _sentIndices.contains(index);
                  final isFailed = _failedIndices.contains(index);
                  final failureReason = _failureReasons[index];

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSent
                          ? AppColors.successBg
                          : isFailed
                              ? AppColors.errorBg
                              : item.isSupported
                                  ? Colors.white
                                  : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSent
                            ? AppColors.success
                            : isFailed
                                ? AppColors.error
                                : item.isSupported
                                    ? AppColors.border
                                    : AppColors.error.withValues(alpha: 0.4),
                        width: (isSent || isFailed) ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Panel Name & SIM Number header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSent
                                          ? AppColors.success
                                          : isFailed
                                              ? AppColors.error
                                              : AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${item.record.sNo}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: (isSent || isFailed) ? Colors.white : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.record.panelName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone_iphone_rounded, size: 12, color: Colors.purple),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.record.panelSimNumber,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isSent) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '✓ Code Changed to ${widget.newAdminCode}',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (isFailed) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cancel_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '❌ Failed: ${failureReason ?? "SMS send failed"}',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Code Change Transition
                        Row(
                          children: [
                            Text(
                              'Current Code: ${item.currentCode}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'New Code: ${item.newCode}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isSent ? AppColors.success : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Formatted SMS Command Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: item.isSupported ? AppColors.inputFill : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: item.isSupported ? AppColors.border : AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: SelectableText(
                            item.commandBody,
                            style: GoogleFonts.firaCode(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: item.isSupported ? AppColors.primary : AppColors.error,
                            ),
                          ),
                        ),

                        if (item.warningNote != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '⚠️ ${item.warningNote}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Clean Footer Action Bar positioned immediately below the list
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                Material(
                  color: (_isBatchProcessing || _isCompleting || supportedCount == 0)
                      ? Colors.grey
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: (_isBatchProcessing || _isCompleting || supportedCount == 0)
                        ? null
                        : _startBatchSmsFlow,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Send SMS ($supportedCount)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Material(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: (_isBatchProcessing || _isCompleting) ? null : () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        'Close',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
