class PanelRecord {
  final String sNo;
  final String panelSimNumber;
  final String panelName;
  String adminCode;
  final String siteAddress;

  PanelRecord({
    required String sNo,
    required String panelSimNumber,
    required String panelName,
    required String adminCode,
    required String siteAddress,
  })  : sNo = cleanNumberString(sNo),
        panelSimNumber = cleanNumberString(panelSimNumber),
        panelName = cleanNumberString(panelName),
        adminCode = cleanNumberString(adminCode),
        siteAddress = siteAddress.trim();

  static String cleanNumberString(String val) {
    String str = val.trim();
    if (str.endsWith('.0') && RegExp(r'^-?\d+\.0$').hasMatch(str)) {
      return str.substring(0, str.length - 2);
    }
    return str;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PanelRecord &&
          runtimeType == other.runtimeType &&
          sNo == other.sNo &&
          panelSimNumber == other.panelSimNumber &&
          panelName == other.panelName &&
          adminCode == other.adminCode &&
          siteAddress == other.siteAddress;

  @override
  int get hashCode =>
      sNo.hashCode ^
      panelSimNumber.hashCode ^
      panelName.hashCode ^
      adminCode.hashCode ^
      siteAddress.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'sNo': sNo,
      'panelSimNumber': panelSimNumber,
      'panelName': panelName,
      'adminCode': adminCode,
      'siteAddress': siteAddress,
    };
  }

  factory PanelRecord.fromMap(Map<dynamic, dynamic> map) {
    return PanelRecord(
      sNo: cleanNumberString(map['sNo']?.toString() ?? ''),
      panelSimNumber: cleanNumberString(map['panelSimNumber']?.toString() ?? ''),
      panelName: cleanNumberString(map['panelName']?.toString() ?? ''),
      adminCode: cleanNumberString(map['adminCode']?.toString() ?? ''),
      siteAddress: map['siteAddress']?.toString() ?? '',
    );
  }
}

class ValidationResult {
  final bool isValid;
  final String fileName;
  final int totalRows;
  final List<String> requiredFields;
  final List<String> foundFields;
  final List<String> missingFields;
  final List<PanelRecord> records;
  final String? errorMessage;
  final DateTime timestamp;

  ValidationResult({
    required this.isValid,
    required this.fileName,
    required this.totalRows,
    required this.requiredFields,
    required this.foundFields,
    required this.missingFields,
    required this.records,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'fileName': fileName,
      'totalRows': totalRows,
      'requiredFields': requiredFields,
      'foundFields': foundFields,
      'missingFields': missingFields,
      'records': records.map((r) => r.toMap()).toList(),
      'errorMessage': errorMessage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ValidationResult.fromMap(Map<dynamic, dynamic> map) {
    return ValidationResult(
      isValid: map['isValid'] == true,
      fileName: map['fileName']?.toString() ?? 'Unknown File',
      totalRows: (map['totalRows'] as num?)?.toInt() ?? 0,
      requiredFields: List<String>.from(map['requiredFields'] ?? []),
      foundFields: List<String>.from(map['foundFields'] ?? []),
      missingFields: List<String>.from(map['missingFields'] ?? []),
      records: (map['records'] as List<dynamic>?)
              ?.map((r) => PanelRecord.fromMap(r as Map))
              .toList() ??
          [],
      errorMessage: map['errorMessage']?.toString(),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
