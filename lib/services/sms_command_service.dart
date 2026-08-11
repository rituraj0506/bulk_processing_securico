import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/panel_record_model.dart';

class SmsCommandResult {
  final PanelRecord record;
  final String currentCode;
  final String newCode;
  final String commandBody;
  final bool isSupported;
  final String? warningNote;

  SmsCommandResult({
    required this.record,
    required this.currentCode,
    required this.newCode,
    required this.commandBody,
    required this.isSupported,
    this.warningNote,
  });
}

class SmsSendResult {
  final bool isSuccess;
  final String? errorMessage;
  final bool requiresSmsAppRole;

  SmsSendResult({
    required this.isSuccess,
    this.errorMessage,
    this.requiresSmsAppRole = false,
  });
}

class SmsCommandService {
  static const MethodChannel _channel = MethodChannel('db_channel');

  /// Prompts the Android OS system dialog to request Default SMS App role for 100% silent background SMS
  static Future<bool> requestDefaultSmsRole() async {
    if (Platform.isAndroid) {
      try {
        final bool res =
            await _channel.invokeMethod<bool>('requestDefaultSmsRole') ?? false;
        return res;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Requests runtime permission and fires the SMS via native SmsManager.
  /// Fire-and-forget: only confirms the OS accepted the send request, not
  /// that it was delivered.
  static Future<SmsSendResult> sendSilentSms({
    required String phoneNumber,
    required String message,
  }) async {
    if (Platform.isAndroid) {
      // 1. Request SMS permission at runtime
      final status = await Permission.sms.status;
      if (!status.isGranted) {
        final requestResult = await Permission.sms.request();
        if (!requestResult.isGranted) {
          return SmsSendResult(
            isSuccess: false,
            errorMessage:
                'SMS Permission Denied by User. Please grant SMS permission in phone settings.',
          );
        }
      }

      // 2. Fire the SMS via the native SmsManager and return immediately
      try {
        await _channel.invokeMethod<String>('sendSMS', {
          'phone': phoneNumber.replaceAll(RegExp(r'[^\d+]'), ''),
          'message': message,
        });
        return SmsSendResult(isSuccess: true);
      } on PlatformException catch (e) {
        final msg = e.message ?? e.code;
        return SmsSendResult(isSuccess: false, errorMessage: msg);
      } catch (e) {
        return SmsSendResult(isSuccess: false, errorMessage: 'Error: $e');
      }
    } else {
      return SmsSendResult(
        isSuccess: false,
        errorMessage: 'iOS does not support background silent SMS sending',
      );
    }
  }

  /// Generates Change Admin Code SMS command based on panel model rules
  static SmsCommandResult generateChangeAdminCodeCommand({
    required PanelRecord record,
    required String newAdminCode,
  }) {
    final rawCurrentCode = record.adminCode.trim();
    final currentCode = rawCurrentCode;
    final newCode = newAdminCode.trim();

    return SmsCommandResult(
      record: record,
      currentCode: currentCode,
      newCode: newCode,
      commandBody: '$currentCode CHANGE CODE #$newCode-$newCode* END',
      isSupported: true,
    );
  }
}
