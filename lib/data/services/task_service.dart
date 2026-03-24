import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import 'notification_service.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Get all tasks as Stream (Firebase pure - no local caching)
  Stream<List<Task>> getTasks(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .orderBy('order', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Task.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Get tasks by category
  Stream<List<Task>> getTasksByCategory(String uid, TaskCategory category) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .where('category', isEqualTo: category.toString().split('.').last)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Task.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Get tasks by priority
  Stream<List<Task>> getTasksByPriority(String uid, TaskPriority priority) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .where('priority', isEqualTo: priority.toString().split('.').last)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Task.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Get today's tasks
  Stream<List<Task>> getTodayTasks(String uid) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs
              .map((doc) => Task.fromMap(doc.id, doc.data()))
              .where((task) => 
                  task.dueDate != null && 
                  task.dueDate!.isAfter(startOfDay) &&
                  task.dueDate!.isBefore(endOfDay.add(Duration(seconds: 1))))
              .toList();
          // Sort by dueDate
          tasks.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
          return tasks;
        });
  }

  // Get overdue tasks
  Stream<List<Task>> getOverdueTasks(String uid) {
    final now = DateTime.now();
    return _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs
              .map((doc) => Task.fromMap(doc.id, doc.data()))
              .where((task) => 
                  !task.isDone && 
                  task.dueDate != null && 
                  task.dueDate!.isBefore(now))
              .toList();
          // Sort by dueDate
          tasks.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
          return tasks;
        });
  }

  // Search tasks
  Future<List<Task>> searchTasks(String uid, String query) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .get();

    final allTasks = snapshot.docs
        .map((doc) => Task.fromMap(doc.id, doc.data()))
        .toList();

    // Filter by title and description
    return allTasks
        .where((task) =>
            task.title.toLowerCase().contains(query.toLowerCase()) ||
            task.description.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Add new task (Firebase pure)
  Future<void> addTask(
    String uid,
    String title, {
    String description = '',
    DateTime? dueDate,
    TaskCategory category = TaskCategory.personal,
    TaskPriority priority = TaskPriority.medium,
    RecurrenceType recurrence = RecurrenceType.none,
  }) async {
    try {
      final now = DateTime.now();
      
      print('📝 Adding task: $title for user: $uid');
      
      final docRef =
          await _db.collection('users').doc(uid).collection('tasks').add({
        'title': title,
        'description': description,
        'isDone': false,
        'dueDate': dueDate?.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'completedAt': null,
        'category': category.toString().split('.').last,
        'priority': priority.toString().split('.').last,
        'recurrence': recurrence.toString().split('.').last,
        'order': now.millisecondsSinceEpoch,
      });

      print('✅ Task saved to Firestore with ID: ${docRef.id}');

      // Schedule notification
      if (dueDate != null) {
        _scheduleTaskReminder(docRef.id, title, dueDate);
      }
    } catch (e) {
      print('❌ Error adding task: $e');
      rethrow;
    }
  }

  // Update task (all fields)
  Future<void> updateTask(String uid, String id, Task task) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(id)
        .update(task.toMap());
  }

  // Toggle task completion
  Future<void> toggleTaskCompletion(String uid, String id, Task task) async {
    final newStatus = !task.isDone;
    final completedAt = newStatus ? DateTime.now() : null;

    await _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(id)
        .update({
      'isDone': newStatus,
      'completedAt': completedAt?.toIso8601String(),
    });

    // Handle recurring tasks - only if recurrence is not NONE
    if (newStatus && task.recurrence != RecurrenceType.none) {
      print('📅 Creating next recurring task for: ${task.title} (${task.recurrence})');
      await _createNextRecurringTask(uid, task);
    }

    // Cancel notification
    if (newStatus) {
      await _notificationService.cancelNotification(id.hashCode);
    }
  }

  // Delete task
  Future<void> deleteTask(String uid, String id) async {
    await _notificationService.cancelNotification(id.hashCode);
    await _db.collection('users').doc(uid).collection('tasks').doc(id).delete();
  }

  // Update due date
  Future<void> updateTaskDueDate(String uid, String id, DateTime? dueDate) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(id)
        .update({
      'dueDate': dueDate?.toIso8601String(),
    });

    if (dueDate != null) {
      // Get task to get title
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(id)
          .get();
      if (doc.exists) {
        _scheduleTaskReminder(id, doc['title'], dueDate);
      }
    } else {
      await _notificationService.cancelNotification(id.hashCode);
    }
  }

  // Reorder tasks (drag and drop)
  Future<void> reorderTasks(String uid, List<Task> tasks) async {
    final batch = _db.batch();
    for (int i = 0; i < tasks.length; i++) {
      batch.update(
        _db.collection('users').doc(uid).collection('tasks').doc(tasks[i].id),
        {'order': i},
      );
    }
    await batch.commit();
  }

  // Update task category
  Future<void> updateTaskCategory(
      String uid, String id, TaskCategory category) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(id)
        .update({
      'category': category.toString().split('.').last,
    });
  }

  // Update task priority
  Future<void> updateTaskPriority(
      String uid, String id, TaskPriority priority) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(id)
        .update({
      'priority': priority.toString().split('.').last,
    });
  }

  // Get statistics
  Future<TaskStatistics> getStatistics(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .get();

    final tasks = snapshot.docs
        .map((doc) => Task.fromMap(doc.id, doc.data()))
        .toList();

    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.isDone).length;
    final pendingTasks = tasks.where((t) => !t.isDone).length;
    final overdueTasks = tasks.where((t) => t.isOverdue).length;

    // Tasks completed this week
    final now = DateTime.now();
    final weekAgo = now.subtract(Duration(days: 7));
    final thisWeekCompleted = tasks
        .where((t) => t.completedAt != null && t.completedAt!.isAfter(weekAgo))
        .length;

    return TaskStatistics(
      total: totalTasks,
      completed: completedTasks,
      pending: pendingTasks,
      overdue: overdueTasks,
      thisWeekCompleted: thisWeekCompleted,
      completionRate:
          totalTasks > 0 ? (completedTasks / totalTasks * 100).toStringAsFixed(1) : '0',
    );
  }

  // Private helper methods
  void _scheduleTaskReminder(String id, String title, DateTime dueDate) {
    try {
      final notificationTime = dueDate.subtract(Duration(days: 1));
      if (notificationTime.isAfter(DateTime.now())) {
        _notificationService.scheduleNotification(
          id: id.hashCode,
          title: 'Task Reminder',
          body: '$title is due tomorrow!',
          scheduledTime: notificationTime,
        );
      }
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  Future<void> _createNextRecurringTask(String uid, Task task) async {
    DateTime nextDueDate;
    final currentDueDate = task.dueDate ?? DateTime.now();

    switch (task.recurrence) {
      case RecurrenceType.daily:
        nextDueDate = currentDueDate.add(Duration(days: 1));
        break;
      case RecurrenceType.weekly:
        nextDueDate = currentDueDate.add(Duration(days: 7));
        break;
      case RecurrenceType.monthly:
        nextDueDate = DateTime(
          currentDueDate.year,
          currentDueDate.month + 1,
          currentDueDate.day,
        );
        break;
      default:
        return;
    }

    await addTask(
      uid,
      task.title,
      description: task.description,
      dueDate: nextDueDate,
      category: task.category,
      priority: task.priority,
      recurrence: task.recurrence,
    );
  }

  // Enable offline persistence (call once during app initialization)
  Future<void> enableOfflinePersistence() async {
    try {
      // Enable offline persistence for Firestore
      // This should be called before any Firestore operations
      print('Offline persistence is enabled by default in Flutter');
    } catch (e) {
      print('Error enabling offline persistence: $e');
    }
  }
}

class TaskStatistics {
  final int total;
  final int completed;
  final int pending;
  final int overdue;
  final int thisWeekCompleted;
  final String completionRate;

  TaskStatistics({
    required this.total,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.thisWeekCompleted,
    required this.completionRate,
  });
}