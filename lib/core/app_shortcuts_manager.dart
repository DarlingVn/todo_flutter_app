import 'package:flutter/services.dart';

class AppShortcutsManager {
  static const platform = MethodChannel('com.taskflow/shortcuts');

  static Future<void> initializeShortcuts() async {
    try {
      // iOS & Android app shortcuts
      await platform.invokeMethod('initShortcuts', {
        'shortcuts': [
          {
            'id': 'add_task',
            'title': 'Add Task',
            'description': 'Create a new task quickly',
            'icon': 'ic_add',
          },
          {
            'id': 'today_tasks',
            'title': 'Today',
            'description': 'View today\'s tasks',
            'icon': 'ic_today',
          },
          {
            'id': 'urgent_tasks',
            'title': 'Urgent',
            'description': 'View urgent tasks',
            'icon': 'ic_urgent',
          },
        ],
      });
    } catch (e) {
      print('❌ Error initializing shortcuts: $e');
    }
  }

  static Future<String?> handleAppShortcut() async {
    try {
      final String? action = await platform.invokeMethod('getAppShortcutAction');
      return action;
    } catch (e) {
      print('❌ Error getting shortcut: $e');
      return null;
    }
  }
}
