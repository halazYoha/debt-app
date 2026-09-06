import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyNotificationsEnabled = 'notifications_enabled';
const String _keyReminderDays = 'reminder_days';

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  @override
  NotificationSettingsState build() {
    _loadFromPrefs();
    return const NotificationSettingsState(
      enabled: true,
      reminderDays: 15,
    );
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyNotificationsEnabled) ?? true;
    final days = prefs.getInt(_keyReminderDays) ?? 15;
    state = NotificationSettingsState(enabled: enabled, reminderDays: days);
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  Future<void> setReminderDays(int days) async {
    state = state.copyWith(reminderDays: days);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderDays, days);
  }
}

class NotificationSettingsState {
  final bool enabled;
  final int reminderDays;

  const NotificationSettingsState({
    required this.enabled,
    required this.reminderDays,
  });

  NotificationSettingsState copyWith({
    bool? enabled,
    int? reminderDays,
  }) {
    return NotificationSettingsState(
      enabled: enabled ?? this.enabled,
      reminderDays: reminderDays ?? this.reminderDays,
    );
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
  NotificationSettingsNotifier.new,
);
