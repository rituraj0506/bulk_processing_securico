import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../models/panel_record_model.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  static const String usersBoxName = 'users_box';
  static const String sessionBoxName = 'session_box';
  static const String historyBoxName = 'history_box';
  static const String panelsBoxName = 'panels_box';

  Box? _usersBox;
  Box? _sessionBox;
  Box? _historyBox;
  Box? _panelsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _usersBox = await Hive.openBox(usersBoxName);
    _sessionBox = await Hive.openBox(sessionBoxName);
    _historyBox = await Hive.openBox(historyBoxName);
    _panelsBox = await Hive.openBox(panelsBoxName);
    debugPrint('Hive database initialized successfully');
  }

  // --- Registration & User Operations ---
  Future<bool> registerUser({
    required String mobileNumber,
    required String username,
    required String password,
  }) async {
    final cleanMob = mobileNumber.trim();
    if (_usersBox == null) await init();

    if (_usersBox!.containsKey(cleanMob)) {
      // User with this mobile number already exists
      return false;
    }

    final user = UserModel(
      mobileNumber: cleanMob,
      username: username.trim(),
      password: password.trim(),
      registeredAt: DateTime.now(),
    );

    await _usersBox!.put(cleanMob, user.toMap());
    return true;
  }

  UserModel? loginUser({
    required String mobileNumber,
    required String password,
  }) {
    final cleanMob = mobileNumber.trim();
    if (_usersBox == null || !_usersBox!.containsKey(cleanMob)) {
      return null;
    }

    final userData = _usersBox!.get(cleanMob);
    if (userData != null && userData is Map) {
      final user = UserModel.fromMap(userData);
      if (user.password == password.trim()) {
        // Save to active session
        _sessionBox?.put('currentUserMob', cleanMob);
        _sessionBox?.put('isLoggedIn', true);
        return user;
      }
    }
    return null;
  }

  UserModel? getCurrentUser() {
    final cleanMob = _sessionBox?.get('currentUserMob');
    if (cleanMob != null &&
        _usersBox != null &&
        _usersBox!.containsKey(cleanMob)) {
      final userData = _usersBox!.get(cleanMob);
      if (userData is Map) {
        return UserModel.fromMap(userData);
      }
    }
    return null;
  }

  bool isLoggedIn() {
    return _sessionBox?.get('isLoggedIn') == true && getCurrentUser() != null;
  }

  Future<void> logout() async {
    await _sessionBox?.delete('currentUserMob');
    await _sessionBox?.put('isLoggedIn', false);
  }

  // --- Upload History Operations (Scoped to Current User) ---
  Future<void> saveUploadHistory(ValidationResult result) async {
    if (_historyBox == null) await init();
    final cleanMob = _sessionBox?.get('currentUserMob')?.toString();
    if (cleanMob == null || cleanMob.isEmpty) return;

    final key = 'history_$cleanMob';
    final List currentList = List.from(_historyBox!.get(key, defaultValue: []));
    currentList.add(result.toMap());
    await _historyBox!.put(key, currentList);

    // If result is valid, also persist panel records into Hive "panels_box" table
    if (result.isValid && result.records.isNotEmpty) {
      await savePanelRecordsTable(result.records);
    }
  }

  List<ValidationResult> getUploadHistory() {
    if (_historyBox == null) return [];
    final cleanMob = _sessionBox?.get('currentUserMob')?.toString();
    if (cleanMob == null || cleanMob.isEmpty) return [];

    final key = 'history_$cleanMob';
    final rawList = _historyBox!.get(key, defaultValue: []);
    if (rawList is! List) return [];

    final List<ValidationResult> history = [];
    for (var i = rawList.length - 1; i >= 0; i--) {
      final data = rawList[i];
      if (data is Map) {
        history.add(ValidationResult.fromMap(data));
      }
    }
    return history;
  }

  // --- Hive Panel Records Table Operations ---
  Future<void> savePanelRecordsTable(List<PanelRecord> records) async {
    if (_panelsBox == null) await init();
    final cleanMob = _sessionBox?.get('currentUserMob')?.toString();
    if (cleanMob == null || cleanMob.isEmpty) return;

    final key = 'panels_$cleanMob';
    final recordsMapList = records.map((r) => r.toMap()).toList();
    await _panelsBox!.put(key, recordsMapList);
    debugPrint(
      'Saved ${records.length} records into Hive table "panels_box" under key "$key"',
    );
  }

  List<PanelRecord> getSavedPanelRecords() {
    if (_panelsBox == null) return [];
    final cleanMob = _sessionBox?.get('currentUserMob')?.toString();
    if (cleanMob == null || cleanMob.isEmpty) return [];

    final key = 'panels_$cleanMob';
    final rawList = _panelsBox!.get(key, defaultValue: []);
    if (rawList is! List) return [];

    return rawList
        .whereType<Map>()
        .map((map) => PanelRecord.fromMap(map))
        .toList();
  }

  Future<void> clearCurrentUserHistory() async {
    final cleanMob = _sessionBox?.get('currentUserMob')?.toString();
    if (cleanMob != null && cleanMob.isNotEmpty) {
      await _historyBox?.delete('history_$cleanMob');
      await _panelsBox?.delete('panels_$cleanMob');
    }
  }
}
