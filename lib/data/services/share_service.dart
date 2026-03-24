import 'package:cloud_firestore/cloud_firestore.dart';

class ShareService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create shareable list
  Future<String> createShareableList(String uid, String listName, List<String> taskIds) async {
    try {
      final shareId = _db.collection('shared_lists').doc().id;
      
      await _db.collection('shared_lists').doc(shareId).set({
        'owner': uid,
        'name': listName,
        'taskIds': taskIds,
        'createdAt': DateTime.now().toIso8601String(),
        'sharedWith': [],
        'expiresAt': DateTime.now().add(Duration(days: 30)).toIso8601String(),
      });

      print('✅ Shareable list created: $shareId');
      return shareId;
    } catch (e) {
      print('❌ Error creating shareable list: $e');
      rethrow;
    }
  }

  // Get shared list
  Future<Map<String, dynamic>?> getSharedList(String shareId) async {
    try {
      final doc = await _db.collection('shared_lists').doc(shareId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting shared list: $e');
      return null;
    }
  }

  // Share list with email
  Future<void> shareListWithEmail(
    String shareId,
    String ownerUid,
    String email,
  ) async {
    try {
      await _db.collection('shared_lists').doc(shareId).update({
        'sharedWith': FieldValue.arrayUnion([email]),
      });

      // In production, you'd send an email here
      print('✅ List shared with $email');
    } catch (e) {
      print('❌ Error sharing list: $e');
      rethrow;
    }
  }

  // Generate share link
  String generateShareLink(String shareId) {
    return 'https://taskflow.app/share/$shareId';
  }

  // Import shared list
  Future<void> importSharedList(
    String uid,
    String shareId,
    List<String> selectedTaskIds,
  ) async {
    try {
      final sharedList = await getSharedList(shareId);
      if (sharedList == null) {
        throw Exception('Shared list not found');
      }

      // Copy selected tasks to user's collection
      final batch = _db.batch();
      final taskIds = List<String>.from(sharedList['taskIds'] ?? []);

      for (String taskId in selectedTaskIds) {
        if (taskIds.contains(taskId)) {
          // Get original task and copy it
          final originalTask = await _db
              .collection('users')
              .doc(sharedList['owner'])
              .collection('tasks')
              .doc(taskId)
              .get();

          if (originalTask.exists) {
            final newTaskRef =
                _db.collection('users').doc(uid).collection('tasks').doc();
            
            final data = Map<String, dynamic>.from(originalTask.data() ?? {});
            data['isDone'] = false; // Reset completion status
            data['createdAt'] = DateTime.now().toIso8601String();
            
            batch.set(newTaskRef, data);
          }
        }
      }

      await batch.commit();
      print('✅ Tasks imported successfully');
    } catch (e) {
      print('❌ Error importing shared list: $e');
      rethrow;
    }
  }
}
