import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/task_model.dart';

class SyncOptimizationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Batch operation queue
  final List<Map<String, dynamic>> _operationQueue = [];
  Timer? _batchTimer;
  static const int BATCH_SIZE = 10;
  static const int BATCH_DELAY_MS = 500;

  // Cache management
  final Map<String, List<Task>> _taskCache = {};
  final Map<String, DateTime> _cacheTimestamp = {};
  static const int CACHE_VALIDITY_MS = 60000; // 1 minute

  // Sync status
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  // Queue task update with batching
  Future<void> queueUpdate(String uid, String taskId, Map<String, dynamic> updates) async {
    _operationQueue.add({
      'uid': uid,
      'taskId': taskId,
      'updates': updates,
      'timestamp': DateTime.now(),
    });

    // Start batch timer if needed
    if (_batchTimer == null || !_batchTimer!.isActive) {
      _startBatchTimer();
    }
  }

  // Start batch processing timer
  void _startBatchTimer() {
    _batchTimer = Timer(Duration(milliseconds: BATCH_DELAY_MS), () async {
      if (_operationQueue.isNotEmpty) {
        await _processBatch();
      }
    });
  }

  // Process queued operations in batch
  Future<void> _processBatch() async {
    if (_operationQueue.isEmpty) return;

    _broadcastSyncStatus('syncing', 'Processing ${_operationQueue.length} updates...');

    try {
      // Group operations by user
      final groupedByUser = <String, List<Map<String, dynamic>>>{};
      
      for (var op in _operationQueue) {
        final uid = op['uid'] as String;
        groupedByUser.putIfAbsent(uid, () => []).add(op);
      }

      // Process each user's batch
      for (var entry in groupedByUser.entries) {
        final uid = entry.key;
        final operations = entry.value;
        
        await _executeBatch(uid, operations);
      }

      _operationQueue.clear();
      _broadcastSyncStatus('synced', 'All updates synced');
    } catch (e) {
      print('❌ Error processing batch: $e');
      _broadcastSyncStatus('error', 'Batch sync failed');
    }
  }

  // Execute batch writes
  Future<void> _executeBatch(String uid, List<Map<String, dynamic>> operations) async {
    try {
      final batch = _db.batch();
      int batchCount = 0;

      for (var op in operations) {
        final taskId = op['taskId'] as String;
        final updates = op['updates'] as Map<String, dynamic>;

        final taskRef = _db
            .collection('users')
            .doc(uid)
            .collection('tasks')
            .doc(taskId);

        batch.update(taskRef, updates);
        batchCount++;

        // Firestore has 500 operation limit per batch
        if (batchCount >= 450) {
          await batch.commit();
          print('✅ Batch committed: $batchCount operations');
        }
      }

      if (batchCount > 0) {
        await batch.commit();
        print('✅ Final batch committed: $batchCount operations');
      }

      // Invalidate cache after update
      if (_taskCache.containsKey(uid)) {
        _taskCache.remove(uid);
        _cacheTimestamp.remove(uid);
      }
    } catch (e) {
      print('❌ Error executing batch: $e');
      rethrow;
    }
  }

  // Get tasks with caching
  Future<List<Task>> getTasksWithCache(String uid) async {
    // Check cache validity
    if (_taskCache.containsKey(uid) && _cacheTimestamp.containsKey(uid)) {
      final cacheAge = DateTime.now().difference(_cacheTimestamp[uid]!).inMilliseconds;
      if (cacheAge < CACHE_VALIDITY_MS) {
        print('📦 Returning cached tasks for $uid');
        return _taskCache[uid]!;
      }
    }

    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .orderBy('order', descending: false)
          .get();

      final tasks = snapshot.docs
          .map((doc) => Task.fromMap(doc.id, doc.data()))
          .toList();

      // Store in cache
      _taskCache[uid] = tasks;
      _cacheTimestamp[uid] = DateTime.now();

      print('✅ Tasks cached for $uid');
      return tasks;
    } catch (e) {
      print('❌ Error getting tasks: $e');
      
      // Return cached version if available, even if expired
      if (_taskCache.containsKey(uid)) {
        print('⚠️ Returning expired cache for $uid');
        return _taskCache[uid]!;
      }
      rethrow;
    }
  }

  // Intelligent prefetch - load data ahead of time
  Future<void> prefetchUserData(String uid) async {
    try {
      print('📥 Prefetching data for $uid...');
      await getTasksWithCache(uid);
    } catch (e) {
      print('⚠️ Prefetch failed: $e');
    }
  }

  // Invalidate cache
  void invalidateCache(String uid) {
    _taskCache.remove(uid);
    _cacheTimestamp.remove(uid);
    print('🔄 Cache invalidated for $uid');
  }

  // Get sync stats
  Map<String, dynamic> getSyncStats() {
    return {
      'queuedOperations': _operationQueue.length,
      'cacheSize': _taskCache.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Broadcast sync status
  void _broadcastSyncStatus(String status, String message) {
    _syncStatusController.add(SyncStatus(
      status: status,
      message: message,
      timestamp: DateTime.now(),
    ));
  }

  void dispose() {
    _batchTimer?.cancel();
    _syncStatusController.close();
  }
}

class SyncStatus {
  final String status; // 'syncing', 'synced', 'error'
  final String message;
  final DateTime timestamp;

  SyncStatus({
    required this.status,
    required this.message,
    required this.timestamp,
  });
}
