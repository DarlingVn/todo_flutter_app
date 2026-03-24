# 🔧 TaskFlow Debugging Guide

## ✅ Những vấn đề đã sửa

### **1. Task không được lưu khi đóng app (FIXED)**

**Nguyên nhân gốc:**
- Hàm `_addNewTask()` trong HomeScreen **không await** khi gọi `service.addTask()`
- Snackbar "Task added" hiển thị ngay lập tức trước khi task thực sự được lưu lên Firestore
- Nếu user đóng app trước khi upload hoàn tất → task mất

**Sửa cách:**
```dart
// ❌ CŨ (BUG)
void _addNewTask() {
  service.addTask(...); // không await!
  ScaffoldMessenger.showSnackBar('Task added'); // hiển thị ngay
}

// ✅ MỚI (FIXED)
Future<void> _addNewTask() async {
  await service.addTask(...); // await upload
  if (mounted) {
    ScaffoldMessenger.showSnackBar('Task saved'); // hiển thị sau upload
  }
}
```

**Yêu cầu thêm:**
- Added try-catch error handling
- Better UX messages ("Saving..." → "Task saved ✅")

---

### **2. Không auto-login khi mở lại app (FIXED)**

**Nguyên nhân gốc:**
- `main.dart` luôn navigate tới `LoginScreen()` không kể user đã login hay chưa
- Khi app restart, user phải nhập lại email/password dù vừa login

**Sửa cách:**
- Tạo `AuthWrapper` widget check `FirebaseAuth.authStateChanges()`
- Nếu user logged in → tới `HomeScreen(uid)`
- Nếu user not logged in → tới `LoginScreen`
- Hiển thị loading screen khi chờ Firebase init

**File mới:**
- `lib/presentation/screens/auth_wrapper.dart`

---

### **3. Logout handling (IMPROVED)**

**Trước:**
```dart
onTap: () async {
  await auth.logout();
  Navigator.pushReplacement(context, 
    MaterialPageRoute(builder: (_) => LoginScreen())
  );
}
```

**Sau:**
```dart
onTap: () async {
  await auth.logout();
  // AuthWrapper sẽ tự động detect user logout
  // và navigate về LoginScreen
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}
```

---

## 🧪 Cách Test

### **Test 1: Task Persistence (Quan trọng nhất)**
1. ✅ Mở app
2. ✅ Login với email/password
3. ✅ Tạo task mới (vd: "Test task")
4. ✅ **Đợi to see "Task saved ✅" message**
5. ✅ Check Firestore Console → task phải có trong `users/{uid}/tasks/` collection
6. ✅ Đóng app hoàn toàn (kill process)
7. ✅ Mở lại app
8. ✅ **Task phải vẫn còn trong list!**

### **Test 2: Auto-Login**
1. ✅ Login
2. ✅ Force close app
3. ✅ Mở app
4. ✅ **Phải tự động vào HomeScreen, không cần nhập lại**

### **Test 3: Logout**
1. ✅ Login
2. ✅ Tap menu (3 dots) → Logout
3. ✅ **Phải quay về LoginScreen**
4. ✅ Mở app lại
5. ✅ **Phải tới LoginScreen, không tới HomeScreen**

---

## 📊 Firestore Collection Structure

Dữ liệu task được lưu ở:
```
users/
  └─ {uid}/
      └─ tasks/
          ├─ task1/{
          │   "title": "Buy milk",
          │   "description": "",
          │   "isDone": false,
          │   "category": "shopping",
          │   "priority": "medium",
          │   "recurrence": "none",
          │   "dueDate": "2026-03-24T10:30:00.000",
          │   "createdAt": "2026-03-23T15:45:00.000",
          │   "completedAt": null,
          │   "order": 1234567890
          │ }
          └─ task2/{ ... }
```

**Tinh chỉnh Firestore Security Rules nếu cần:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own tasks
    match /users/{userId}/tasks/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

---

## 🐛 Debugging Tips

### **Kiểm tra Console Logs:**
```
📝 Adding task: Buy milk for user: user123
✅ Task saved with ID: abc456
```

### **Firestore Emulator (Optional):**
```bash
firebase emulators:start
```

### **Clear Cache nếu có issue:**
```bash
flutter clean
flutter pub get
flutter run
```

---

## 🚀 Next Steps

1. **Giai đoạn 2 - Advanced UI:**
   - Drag & drop reorder
   - Analytics charts
   - Home widgets

2. **Giai đoạn 3 - Technical:**
   - Offline persistence advanced
   - Cloud functions
   - Real-time sync

3. **Giai đoạn 4 - AI & Collaboration**
   - Gemini AI integration
   - Share tasks with users
   - File attachments

---

**Good luck testing! 🎉 Let me know if you find any issues!**
