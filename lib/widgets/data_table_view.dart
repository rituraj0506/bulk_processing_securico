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
          r.simImsi.toLowerCase().contains(q) ||
          r.zone.toLowerCase().contains(q) ||
          r.region.toLowerCase().contains(q) ||
          r.branch.toLowerCase().contains(q) ||
          r.adminCode.toLowerCase().contains(q) ||
          r.panelType.toLowerCase().contains(q);
    }).toList();
  }

  bool? get _selectAllState {
    final filtered = _filteredRecords;
    if (filtered.isEmpty) return false;
    final selectedCount = filtered.where((r) => _selectedRecords.contains(r)).length;
    if (selectedCount == 0) return false;
    if (selectedCount == filtered.length) return true;
    return null;
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

    final newCode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EnterAdminCodeDialog(
        selectedCount: _selectedRecords.length,
      ),
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
    }
  }

  Widget _buildHeader(List<PanelRecord> filtered) {
    final selectAllWidget = Row(
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
    );

    final selectedBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${_selectedRecords.length} Selected',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
          fontSize: 12,
        ),
      ),
    );

    final searchFieldWidget = TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: 'Search Sim Numbers, IMSI, Zone, Region, Branch...',
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.hint),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.hint),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
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
          const SizedBox(width: 44),
          SizedBox(width: 48, child: Text('S.No', textAlign: TextAlign.center, style: _headerStyle())),
          const SizedBox(width: 10),
          Expanded(flex: 3, child: Text('Sim Numbers', style: _headerStyle())),
          const SizedBox(width: 10),
          Expanded(flex: 3, child: Text('SIM_IMSI', style: _headerStyle())),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: Text('Zone', style: _headerStyle())),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: Text('Region', style: _headerStyle())),
          const SizedBox(width: 10),
          Expanded(flex: 3, child: Text('Branch', style: _headerStyle())),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text('Admin Code', textAlign: TextAlign.center, style: _headerStyle())),
          const SizedBox(width: 10),
          SizedBox(width: 70, child: Text('Type', textAlign: TextAlign.center, style: _headerStyle())),
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
              width: 44,
              child: Checkbox(
                value: isSelected,
                activeColor: AppColors.primary,
                onChanged: (val) => _toggleSelectRow(r, val),
              ),
            ),
            SizedBox(
              width: 48,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.sNo,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.primary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Text(
                r.panelSimNumber,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.purple),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Text(
                r.simImsi,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.firaCode(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Text(
                r.zone,
                overflow: TextOverflow.ellipsis,
                style: _cellStyle(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Text(
                r.region,
                overflow: TextOverflow.ellipsis,
                style: _cellStyle(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Text(
                r.branch,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.adminCode,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: Colors.teal.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.panelType,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: Colors.amber.shade900,
                    fontSize: 11,
                  ),
                ),
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(filtered),
              const Divider(height: 1),

              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: AppColors.hint),
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
                    if (constraints.maxWidth > 750) {
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'S.No #${r.sNo}',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          r.branch,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Type: ${r.panelType}',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.amber.shade900,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _mobileRow(Icons.phone_iphone_rounded, 'Sim Numbers', r.panelSimNumber, Colors.purple),
                                  const SizedBox(height: 6),
                                  _mobileRow(Icons.fingerprint_rounded, 'SIM_IMSI', r.simImsi, Colors.indigo),
                                  const SizedBox(height: 6),
                                  _mobileRow(Icons.map_rounded, 'Zone / Region', '${r.zone} / ${r.region}', AppColors.textSecondary),
                                  const SizedBox(height: 6),
                                  _mobileRow(Icons.admin_panel_settings_rounded, 'Admin Code', r.adminCode, Colors.teal),
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
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
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
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    );
  }

  TextStyle _cellStyle() {
    return GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
  }
}
