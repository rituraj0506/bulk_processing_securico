import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/panel_record_model.dart';
import '../theme/app_colors.dart';
import '../widgets/sms_command_dialog.dart';

/// Full-page panel list: card-only view (Branch, Sim Number, Admin Code +
/// last-updated timestamp), with Zone and Region filters, and the
/// select -> Change Admin Code -> SMS dispatch flow.
class PanelListScreen extends StatefulWidget {
  final List<PanelRecord> records;
  final VoidCallback? onRecordsUpdated;

  const PanelListScreen({
    super.key,
    required this.records,
    this.onRecordsUpdated,
  });

  @override
  State<PanelListScreen> createState() => _PanelListScreenState();
}

class _PanelListScreenState extends State<PanelListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedZones = {};
  final Set<String> _selectedRegions = {};
  final Set<PanelRecord> _selectedRecords = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _zones {
    final set = widget.records
        .map((r) => r.zone)
        .where((z) => z.isNotEmpty)
        .toSet()
        .toList();
    set.sort();
    return set;
  }

  List<String> get _regions {
    final set = widget.records
        .map((r) => r.region)
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList();
    set.sort();
    return set;
  }

  List<PanelRecord> get _filteredRecords {
    final q = _searchQuery.toLowerCase().trim();
    return widget.records.where((r) {
      final matchesSearch =
          q.isEmpty ||
          r.branch.toLowerCase().contains(q) ||
          r.panelSimNumber.toLowerCase().contains(q) ||
          r.adminCode.toLowerCase().contains(q);
      final matchesZone =
          _selectedZones.isEmpty || _selectedZones.contains(r.zone);
      final matchesRegion =
          _selectedRegions.isEmpty || _selectedRegions.contains(r.region);
      return matchesSearch && matchesZone && matchesRegion;
    }).toList();
  }

  bool? get _selectAllState {
    final filtered = _filteredRecords;
    if (filtered.isEmpty) return false;
    final selectedCount = filtered
        .where((r) => _selectedRecords.contains(r))
        .length;
    if (selectedCount == 0) return false;
    if (selectedCount == filtered.length) return true;
    return null;
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      final filtered = _filteredRecords;
      if (value == true) {
        _selectedRecords.addAll(filtered);
      } else {
        _selectedRecords.removeAll(filtered);
      }
    });
  }

  void _toggleSelectRow(PanelRecord r, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedRecords.add(r);
      } else {
        _selectedRecords.remove(r);
      }
    });
  }

  void _showSnack(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _openChangeAdminCodeFlow() async {
    if (_selectedRecords.isEmpty) return;

    if (_selectedRecords.length > SmsCommandsQueueModal.maxBatchSize) {
      _showSnack(
        'You can send a maximum of ${SmsCommandsQueueModal.maxBatchSize} SMS at a time. Please select ${SmsCommandsQueueModal.maxBatchSize} or fewer panels.',
        AppColors.error,
        Icons.error_rounded,
      );
      return;
    }

    final newCode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          EnterAdminCodeDialog(selectedCount: _selectedRecords.length),
    );

    if (newCode == null || newCode.isEmpty || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmAdminCodeDialog(
        selectedCount: _selectedRecords.length,
        newAdminCode: newCode,
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SmsCommandsQueueModal(
        selectedRecords: _selectedRecords.toList(),
        newAdminCode: newCode,
      ),
    );

    if (result is int && result > 0 && mounted) {
      setState(() {
        _selectedRecords.clear();
      });

      widget.onRecordsUpdated?.call();

      _showSnack(
        'Admin code changed successfully for $result panel(s)!',
        AppColors.success,
        Icons.check_circle_rounded,
      );
    }
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    int hour = local.hour % 12;
    if (hour == 0) hour = 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month ${local.year}, $hour:$minute $period';
  }

  void _showMultiSelectModal({
    required String title,
    required List<String> options,
    required Set<String> selectedSet,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allSelected =
                options.isNotEmpty &&
                options.every((o) => selectedSet.contains(o));
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
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
                      Text(
                        'Select $title (${selectedSet.length}/${options.length})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            setState(() {
                              if (allSelected) {
                                selectedSet.clear();
                              } else {
                                selectedSet.addAll(options);
                              }
                            });
                          });
                        },
                        icon: Icon(
                          allSelected
                              ? Icons.deselect_rounded
                              : Icons.select_all_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          allSelected ? 'Clear All' : 'Select All',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (selectedSet.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              setState(() {
                                selectedSet.clear();
                              });
                            });
                          },
                          child: Text(
                            'Reset Filter',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.separated(
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = options[index];
                        final isChecked = selectedSet.contains(item);
                        return CheckboxListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(
                            item,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          value: isChecked,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setModalState(() {
                              setState(() {
                                if (val == true) {
                                  selectedSet.add(item);
                                } else {
                                  selectedSet.remove(item);
                                }
                              });
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Apply (${selectedSet.length} Selected)',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.inputFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected && label != 'All') ...[
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow({
    required String label,
    required List<String> options,
    required Set<String> selectedSet,
    required VoidCallback onToggleAll,
    required Function(String) onToggleOption,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (selectedSet.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${selectedSet.length} selected',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            InkWell(
              onTap: () => _showMultiSelectModal(
                title: label,
                options: options,
                selectedSet: selectedSet,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'Select Multiple',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('All', selectedSet.isEmpty, onToggleAll),
              const SizedBox(width: 8),
              ...options.map(
                (o) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChip(
                    o,
                    selectedSet.contains(o),
                    () => onToggleOption(o),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChangeCodeFab() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.45),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _openChangeAdminCodeFlow,
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
                      child: const Icon(
                        Icons.password_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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
                          '${_selectedRecords.length} panel(s) selected',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppColors.primaryDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(PanelRecord r, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleSelectRow(r, !isSelected),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.scaffold : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.hint : AppColors.border,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isSelected,
              activeColor: AppColors.primary,
              onChanged: (val) => _toggleSelectRow(r, val),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.branch.isNotEmpty ? r.branch : 'Unknown Branch',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_iphone_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          r.panelSimNumber,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Admin Code: ${r.adminCode}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  if (r.adminCodeUpdatedAt != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Updated ${_formatDateTime(r.adminCodeUpdatedAt!)}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Panel List',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: _selectedRecords.isNotEmpty
          ? _buildChangeCodeFab()
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search Branch, Sim Number, Admin Code...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.hint,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.hint,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    fillColor: AppColors.inputFill,
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildFilterRow(
                  label: 'ZONE',
                  options: _zones,
                  selectedSet: _selectedZones,
                  onToggleAll: () => setState(() => _selectedZones.clear()),
                  onToggleOption: (val) {
                    setState(() {
                      if (_selectedZones.contains(val)) {
                        _selectedZones.remove(val);
                      } else {
                        _selectedZones.add(val);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildFilterRow(
                  label: 'REGION',
                  options: _regions,
                  selectedSet: _selectedRegions,
                  onToggleAll: () => setState(() => _selectedRegions.clear()),
                  onToggleOption: (val) {
                    setState(() {
                      if (_selectedRegions.contains(val)) {
                        _selectedRegions.remove(val);
                      } else {
                        _selectedRegions.add(val);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _selectAllState,
                          tristate: true,
                          activeColor: AppColors.primary,
                          onChanged: _toggleSelectAll,
                        ),
                        Text(
                          'Select All (${filtered.length})',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedRecords.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${_selectedRecords.length} Selected',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: AppColors.hint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No matching records found',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = filtered[index];
                      final isSelected = _selectedRecords.contains(r);
                      return _buildCard(r, isSelected);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
