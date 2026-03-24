// Firebase Cloud Functions for TaskFlow
// Deploy: firebase deploy --only functions

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Duplicate Task
exports.duplicateTask = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');

  const { uid, taskId } = data;
  if (uid !== context.auth.uid) throw new functions.https.HttpsError('permission-denied', 'Unauthorized');

  try {
    const taskRef = db.collection('users').doc(uid).collection('tasks').doc(taskId);
    const taskDoc = await taskRef.get();

    if (!taskDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Task not found');
    }

    const taskData = taskDoc.data();
    taskData.createdAt = new Date().toISOString();
    taskData.isDone = false;
    taskData.completedAt = null;

    const newTaskRef = db.collection('users').doc(uid).collection('tasks').doc();
    await newTaskRef.set(taskData);

    return { newTaskId: newTaskRef.id };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Bulk Update Tasks
exports.bulkUpdateTasks = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');

  const { uid, taskIds, updates } = data;
  if (uid !== context.auth.uid) throw new functions.https.HttpsError('permission-denied', 'Unauthorized');

  try {
    const batch = db.batch();
    const tasksRef = db.collection('users').doc(uid).collection('tasks');

    for (const taskId of taskIds) {
      batch.update(tasksRef.doc(taskId), updates);
    }

    await batch.commit();
    return { updated: taskIds.length };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Send Task Reminder
exports.sendTaskReminder = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');

  const { uid, taskId, taskTitle } = data;
  if (uid !== context.auth.uid) throw new functions.https.HttpsError('permission-denied', 'Unauthorized');

  try {
    // Get user
    const userDoc = await admin.auth().getUser(uid);
    
    // Send email reminder (using Firebase Admin SDK)
    // In real implementation, use email service like SendGrid, Mailgun, etc
    
    console.log(`Reminder sent to ${userDoc.email} for task: ${taskTitle}`);
    return { sent: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Generate Report
exports.generateReport = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');

  const { uid, reportType } = data;
  if (uid !== context.auth.uid) throw new functions.https.HttpsError('permission-denied', 'Unauthorized');

  try {
    const tasksRef = db.collection('users').doc(uid).collection('tasks');
    const snapshot = await tasksRef.get();

    const tasks = [];
    snapshot.forEach(doc => {
      tasks.push({ id: doc.id, ...doc.data() });
    });

    const completed = tasks.filter(t => t.isDone).length;
    const pending = tasks.filter(t => !t.isDone).length;
    const overdue = tasks.filter(t => !t.isDone && t.dueDate && new Date(t.dueDate) < new Date()).length;

    const report = {
      generatedAt: new Date().toISOString(),
      type: reportType,
      total: tasks.length,
      completed,
      pending,
      overdue,
      completionRate: tasks.length > 0 ? ((completed / tasks.length) * 100).toFixed(2) : 0,
      byCategory: categorizeByField(tasks, 'category'),
      byPriority: categorizeByField(tasks, 'priority'),
    };

    return report;
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Export Tasks as PDF/CSV
exports.exportTasks = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');

  const { uid, format, taskIds } = data;
  if (uid !== context.auth.uid) throw new functions.https.HttpsError('permission-denied', 'Unauthorized');

  try {
    const tasksRef = db.collection('users').doc(uid).collection('tasks');
    const tasks = [];

    for (const taskId of taskIds) {
      const doc = await tasksRef.doc(taskId).get();
      if (doc.exists) {
        tasks.push({ id: doc.id, ...doc.data() });
      }
    }

    // Generate file based on format
    let content = '';
    if (format === 'csv') {
      content = generateCSV(tasks);
    } else if (format === 'pdf') {
      content = generatePDF(tasks);
    }

    // Upload to Cloud Storage
    const bucket = admin.storage().bucket();
    const fileName = `exports/${uid}-${Date.now()}.${format}`;
    const file = bucket.file(fileName);

    await file.save(content);
    const downloadUrl = await file.getSignedUrl({
      version: 'v4',
      action: 'read',
      expires: Date.now() + 15 * 60 * 1000, // 15 minutes
    });

    return { downloadUrl: downloadUrl[0] };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Cleanup Archived Tasks
exports.cleanupArchivedTasks = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');

  const { uid, daysOld } = data;
  if (uid !== context.auth.uid) throw new functions.https.HttpsError('permission-denied', 'Unauthorized');

  try {
    const tasksRef = db.collection('users').doc(uid).collection('tasks');
    const cutoffDate = new Date(Date.now() - daysOld * 24 * 60 * 60 * 1000);

    const snapshot = await tasksRef
      .where('isDone', '==', true)
      .where('completedAt', '<', cutoffDate.toISOString())
      .get();

    const batch = db.batch();
    let deleted = 0;

    snapshot.forEach(doc => {
      batch.delete(doc.ref);
      deleted++;
    });

    await batch.commit();
    return { deleted };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Helper function to categorize tasks
function categorizeByField(tasks, field) {
  const categories = {};
  tasks.forEach(task => {
    const value = task[field] || 'other';
    categories[value] = (categories[value] || 0) + 1;
  });
  return categories;
}

// Helper to generate CSV
function generateCSV(tasks) {
  const headers = ['Title', 'Description', 'Category', 'Priority', 'Status', 'Due Date'];
  const rows = tasks.map(t => [
    t.title,
    t.description,
    t.category,
    t.priority,
    t.isDone ? 'Done' : 'Pending',
    t.dueDate || '',
  ]);

  const csv = [headers, ...rows].map(row => row.map(cell => `"${cell}"`).join(',')).join('\n');
  return csv;
}

// Helper to generate PDF (basic)
function generatePDF(tasks) {
  // In real implementation, use a library like puppeteer or pdfkit
  let pdf = 'TaskFlow Export\n';
  pdf += `Generated: ${new Date().toISOString()}\n\n`;

  tasks.forEach(task => {
    pdf += `Title: ${task.title}\n`;
    pdf += `Status: ${task.isDone ? 'Done' : 'Pending'}\n`;
    pdf += `Category: ${task.category}\n`;
    pdf += `Priority: ${task.priority}\n`;
    pdf += '---\n';
  });

  return pdf;
}
