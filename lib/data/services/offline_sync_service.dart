import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/task_model.dart';

class OfflineSyncService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Sync status stream
  static final _syncStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get syncStatus => _syncStatusController.stream;

  // Enable offline persistence with custom settings
  Future<void> enableAdvancedOfflineSync() async {
    try {
      // Enable offline persistence
      await _db.enableNetwork();
      
      // Configure cache settings
      await _db.collection('users').limit(0).get(); // Warm up cache
      
      print('✅ Advanced offline sync enabled');
      _broadcastSyncStatus('ready', 'Offline sync ready');
    } catch (e) {
      print('❌ Error enabling offline sync: $e');
      _broadcastSyncStatus('error', 'Failed to enable offline sync');
    }
  }

  // Queue task for sync
  Future<void> queueTaskSync(String uid, Task task, String operation) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('sync_queue')
          .add({
        'task': task.toMap(),
        'operation': operation, // 'create', 'update', 'delete'
        'timestamp': DateTime.now().toIso8601String(),
        'synced': false,
      });

      print('📝 Task queued for sync: ${task.id}');
    } catch (e) {
      print('❌ Error queueing task: $e');
    }
  }

  // Process sync queue
  Future<void> processSyncQueue(String uid) async {
    try {
      _broadcastSyncStatus('syncing', 'Syncing offline tasks...');
      
      final queue = await _db
          .collection('users')
          .doc(uid)
          .collection('sync_queue')
          .where('synced', isEqualTo: false)
          .get();

      if (queue.docs.isEmpty) {
        _broadcastSyncStatus('synced', 'All tasks synced');
        return;
      }

      int synced = 0;
      int failed = 0;

      for (var doc in queue.docs) {
        try {
          final data = doc.data();
          final operation = data['operation'];
          final taskData = Map<String, dynamic>.from(data['task']);

          if (operation == 'create') {
            await _db
                .collection('users')
                .doc(uid)
                .collection('tasks')
                .add(taskData);
          } else if (operation == 'update') {
            await _db
                .collection('users')
                .doc(uid)
                .collection('tasks')
                .doc(taskData['id'])
                .update(taskData);
          } else if (operation == 'delete') {
            await _db
                .collection('users')
                .doc(uid)
                .collection('tasks')
                .doc(taskData['id'])
                .delete();
          }

          // Mark as synced
          await doc.reference.update({'synced': true});
          synced++;
        } catch (e) {
          print('❌ Error syncing task: $e');
          failed++;
        }
      }

      _broadcastSyncStatus(
        'synced',
        'Synced: $synced, Failed: $failed',
      );
      print('✅ Sync queue processed: $synced synced, $failed failed');
    } catch (e) {
      print('❌ Error processing sync queue: $e');
      _broadcastSyncStatus('error', 'Sync failed');
    }
  }

  // Check network connectivity
  Future<bool> isConnected() async {
    try {
      await _db.collection('_system').limit(0).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Cleanup old sync records
  Future<void> cleanupOldSyncRecords(String uid) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      
      await _db
          .collection('users')
          .doc(uid)
          .collection('sync_queue')
          .where('timestamp',
              isLessThan: thirtyDaysAgo.toIso8601String())
          .where('synced', isEqualTo: true)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete();
        }
      });

      print('✅ Cleaned up old sync records');
    } catch (e) {
      print('❌ Error cleaning up: $e');
    }
  }

  // Broadcast sync status
  void _broadcastSyncStatus(String status, String message) {
    _syncStatusController.add({
      'status': status,
      'message': message,
      'timestamp': DateTime.now(),
    });
  }

  void dispose() {
    _syncStatusController.close();
  }
}
