import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  Stream<List<Map<String, dynamic>>> getTasks(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  Future<void> addTask(String uid, String title, {DateTime? dueDate}) async {
    final docRef = await _db.collection('users').doc(uid).collection('tasks').add({
      'title': title,
      'isDone': false,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Schedule notification 1 day before deadline
    if (dueDate != null) {
      final notificationTime = dueDate.subtract(Duration(days: 1));
      if (notificationTime.isAfter(DateTime.now())) {
        await _notificationService.scheduleNotification(
          id: docRef.id.hashCode,
          title: 'Task Reminder',
          body: '$title is due tomorrow!',
          scheduledTime: notificationTime,
        );
      }
    }
  }

  Future<void> updateTask(String uid, String id, bool done) async {
    await _db.collection('users').doc(uid).collection('tasks').doc(id).update({
      'isDone': done,
    });
  }

  Future<void> deleteTask(String uid, String id) async {
    // Cancel notification
    await _notificationService.cancelNotification(id.hashCode);
    await _db.collection('users').doc(uid).collection('tasks').doc(id).delete();
  }

  Future<void> updateTaskDueDate(String uid, String id, DateTime? dueDate) async {
    await _db.collection('users').doc(uid).collection('tasks').doc(id).update({
      'dueDate': dueDate?.toIso8601String(),
    });

    // Reschedule notification
    if (dueDate != null) {
      await _notificationService.cancelNotification(id.hashCode);
      final notificationTime = dueDate.subtract(Duration(days: 1));
      if (notificationTime.isAfter(DateTime.now())) {
        await _notificationService.scheduleNotification(
          id: id.hashCode,
          title: 'Task Reminder',
          body: 'Task is due tomorrow!',
          scheduledTime: notificationTime,
        );
      }
    }
  }
}