class PanelRecord {
  final String sNo;
  final String panelSimNumber;
  final String simImsi;
  final String zone;
  final String region;
  final String branch;
  String adminCode;
  final String panelType;
  DateTime? adminCodeUpdatedAt;

  PanelRecord({
    required String sNo,
    required String panelSimNumber,
    required String simImsi,
    required String zone,
    required String region,
    required String branch,
    required String adminCode,
    String panelType = 'A1',
    this.adminCodeUpdatedAt,
  }) : sNo = cleanNumberString(sNo),
       panelSimNumber = cleanNumberString(panelSimNumber),
       simImsi = cleanNumberString(simImsi),
       zone = zone.trim(),
       region = region.trim(),
       branch = branch.trim(),
       adminCode = cleanNumberString(adminCode),
       panelType = panelType.trim();

  // Backward compatibility getters
  String get panelName => branch.isNotEmpty
      ? '$branch ($panelType)'
      : (panelType.isNotEmpty ? panelType : 'Panel');
  String get siteAddress =>
      [branch, region, zone].where((s) => s.isNotEmpty).join(', ');

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
          simImsi == other.simImsi &&
          zone == other.zone &&
          region == other.region &&
          branch == other.branch &&
          adminCode == other.adminCode &&
          panelType == other.panelType;

  @override
  int get hashCode =>
      sNo.hashCode ^
      panelSimNumber.hashCode ^
      simImsi.hashCode ^
      zone.hashCode ^
      region.hashCode ^
      branch.hashCode ^
      adminCode.hashCode ^
      panelType.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'sNo': sNo,
      'panelSimNumber': panelSimNumber,
      'simImsi': simImsi,
      'zone': zone,
      'region': region,
      'branch': branch,
      'adminCode': adminCode,
      'panelType': panelType,
      'adminCodeUpdatedAt': adminCodeUpdatedAt?.toIso8601String(),
    };
  }

  factory PanelRecord.fromMap(Map<dynamic, dynamic> map) {
    return PanelRecord(
      sNo: cleanNumberString(map['sNo']?.toString() ?? ''),
      panelSimNumber: cleanNumberString(
        map['panelSimNumber']?.toString() ?? map['simNumber']?.toString() ?? '',
      ),
      simImsi: cleanNumberString(
        map['simImsi']?.toString() ?? map['imsi']?.toString() ?? '',
      ),
      zone: map['zone']?.toString() ?? '',
      region: map['region']?.toString() ?? '',
      branch: map['branch']?.toString() ?? map['panelName']?.toString() ?? '',
      adminCode: cleanNumberString(map['adminCode']?.toString() ?? ''),
      panelType: map['panelType']?.toString() ?? 'A1',
      adminCodeUpdatedAt: map['adminCodeUpdatedAt'] != null
          ? DateTime.tryParse(map['adminCodeUpdatedAt'].toString())
          : null,
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
      records:
          (map['records'] as List<dynamic>?)
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
