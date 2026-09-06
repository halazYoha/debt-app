import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_settings_provider.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.settings_rounded, color: Color(0xFF10B981)),
                  SizedBox(width: 10),
                  Text(
                    'ቅንብሮች',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
          const Divider(height: 24),
          const Text(
            '🔔 የክፍያ ማስታወሻ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFF10B981),
                    title: const Text(
                      'ማስታወሻ አንቃ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'ተበዳሪዎች ክፍያ ሳይፈጽሙ ቀናት ሲያልፉ ማስታወሻ ይላካል',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: settings.enabled,
                    onChanged: (val) => notifier.setEnabled(val),
                  ),
                  if (settings.enabled) ...[
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ከስንት ቀን በኋላ?',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'ክፍያ ሳይፈጸም ሲቀር ማስታወሻ የሚላክበት የቀን ብዛት',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<int>(
                          value: settings.reminderDays,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 3,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 7, child: Text('7 ቀን')),
                            DropdownMenuItem(value: 15, child: Text('15 ቀን')),
                            DropdownMenuItem(value: 30, child: Text('30 ቀን')),
                            DropdownMenuItem(value: 45, child: Text('45 ቀን')),
                          ],
                          onChanged: (newDays) {
                            if (newDays != null) {
                              notifier.setReminderDays(newDays);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
