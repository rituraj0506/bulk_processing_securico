import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/panel_record_model.dart';
import '../theme/app_colors.dart';
import 'sms_command_dialog.dart';

class DataTableView extends StatefulWidget {
  final List<PanelRecord> records;
  final VoidCallback? onRecordsUpdated;
  final Function(int count, VoidCallback triggerFlow)? onSelectionChanged;

  const DataTableView({
    super.key,
    required this.records,
    this.onRecordsUpdated,
    this.onSelectionChanged,
  });

  @override
  State<DataTableView> createState() => _DataTableViewState();
}

class _DataTableViewState extends State<DataTableView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<PanelRecord> _selectedRecords = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PanelRecord> get _filteredRecords {
    if (_searchQuery.trim().isEmpty) return widget.records;
    final q = _searchQuery.toLowerCase().trim();
    return widget.records.where((r) {
      return r.sNo.toLowerCase().contains(q) ||
          r.panelSimNumber.toLowerCase().contains(q) ||
          r.panelName.toLowerCase().contains(q) ||
          r.adminCode.toLowerCase().contains(q) ||
          r.siteAddress.toLowerCase().contains(q);
    }).toList();
  }

  bool? get _selectAllState {
    final filtered = _filteredRecords;
    if (filtered.isEmpty) return false;
    final selectedCount = filtered.where((r) => _selectedRecords.contains(r)).length;
    if (selectedCount == 0) return false;
    if (selectedCount == filtered.length) return true;
    return null; // Tristate for partial selection
  }

  void _notifySelectionChanged() {
    widget.onSelectionChanged?.call(_selectedRecords.length, _openChangeAdminCodeFlow);
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
    _notifySelectionChanged();
  }

  void _toggleSelectRow(PanelRecord r, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedRecords.add(r);
      } else {
        _selectedRecords.remove(r);
      }
    });
    _notifySelectionChanged();
  }

  Future<void> _openChangeAdminCodeFlow() async {
    if (_selectedRecords.isEmpty) return;

    // 1. Enter 4-Digit New Admin Code
    final newCode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EnterAdminCodeDialog(
        selectedCount: _selectedRecords.length,
      ),
    );

    if (newCode == null || newCode.isEmpty || !mounted) return;

    // 2. Confirmation Dialog ("Are you sure?")
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmAdminCodeDialog(
        selectedCount: _selectedRecords.length,
        newAdminCode: newCode,
      ),
    );

    if (confirmed != true || !mounted) return;

    // 3. Batch SMS Dispatch Queue Modal
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

      _notifySelectionChanged();
      widget.onRecordsUpdated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Admin code changed successfully for $result panel(s)!',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
        ),
      );
    } else if (result is String && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Background SMS Failed: $result',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Widget _buildHeader(List<PanelRecord> filtered) {
    final selectAllWidget = Row(
      children: [
        Transform.scale(
          scale: 1.1,
          child: Checkbox(
            value: _selectAllState,
            tristate: true,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: (val) => _toggleSelectAll(val == true),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select All',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Showing ${filtered.length} of ${widget.records.length} records',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final selectedBadge = _selectedRecords.isEmpty
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_selectedRecords.length} Selected',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          );

    final searchFieldWidget = TextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
      style: GoogleFonts.plusJakartaSans(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search panels, SIM, site...',
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: selectAllWidget),
              if (_selectedRecords.isNotEmpty) selectedBadge,
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 42, child: searchFieldWidget),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 48), // Checkbox spacing
          SizedBox(
            width: 60,
            child: Text('S.No', textAlign: TextAlign.center, style: _headerStyle()),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: Text('Panel Sim Number', style: _headerStyle())),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text('Panel Name', style: _headerStyle())),
          const SizedBox(width: 12),
          Expanded(flex: 1, child: Text('Admin Code', textAlign: TextAlign.center, style: _headerStyle())),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Text('Site Address', style: _headerStyle())),
        ],
      ),
    );
  }

  Widget _buildDesktopTableRow(PanelRecord r, bool isSelected) {
    return InkWell(
      onTap: () => _toggleSelectRow(r, !isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.4) : Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Checkbox(
                value: isSelected,
                activeColor: AppColors.primary,
                onChanged: (val) => _toggleSelectRow(r, val),
              ),
            ),
            SizedBox(
              width: 60,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.sNo,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(Icons.sim_card, size: 16, color: Colors.purple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.panelSimNumber,
                      overflow: TextOverflow.ellipsis,
                      style: _cellStyle(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.panelName,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.amber.shade900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.adminCode,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.teal.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      r.siteAddress,
                      overflow: TextOverflow.ellipsis,
                      style: _cellStyle(),
                    ),
                  ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 20,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive Header
              _buildHeader(filtered),
              const Divider(height: 1),

              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: AppColors.hint),
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
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    if (constraints.maxWidth > 650) {
                      return Column(
                        children: [
                          _buildTableHeader(),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final r = filtered[index];
                              final isSelected = _selectedRecords.contains(r);
                              return _buildDesktopTableRow(r, isSelected);
                            },
                          ),
                        ],
                      );
                    } else {
                      // Mobile Card List View
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final r = filtered[index];
                          final isSelected = _selectedRecords.contains(r);

                          return GestureDetector(
                            onTap: () => _toggleSelectRow(r, !isSelected),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryLight.withValues(alpha: 0.5)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: isSelected,
                                        activeColor: AppColors.primary,
                                        onChanged: (val) => _toggleSelectRow(r, val),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '#${r.sNo}',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Panel: ${r.panelName}',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.amber.shade900,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _mobileRow(Icons.sim_card, 'SIM Number',
                                      r.panelSimNumber, Colors.purple),
                                  const SizedBox(height: 6),
                                  _mobileRow(Icons.admin_panel_settings, 'Admin Code',
                                      r.adminCode, Colors.teal),
                                  const SizedBox(height: 6),
                                  _mobileRow(Icons.location_on, 'Site Address',
                                      r.siteAddress, AppColors.textSecondary),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _mobileRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  TextStyle _headerStyle() {
    return GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    );
  }

  TextStyle _cellStyle() {
    return GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
  }
}
