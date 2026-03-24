import 'package:flutter/material.dart';

enum TaskCategory { work, personal, learning, health, finance, shopping, other }
enum TaskPriority { low, medium, high, urgent }
enum RecurrenceType { none, daily, weekly, monthly }

extension TaskCategoryExtension on TaskCategory {
  String get label {
    switch (this) {
      case TaskCategory.work:
        return 'Công việc';
      case TaskCategory.personal:
        return 'Cá nhân';
      case TaskCategory.learning:
        return 'Học tập';
      case TaskCategory.health:
        return 'Sức khỏe';
      case TaskCategory.finance:
        return 'Tài chính';
      case TaskCategory.shopping:
        return 'Mua sắm';
      case TaskCategory.other:
        return 'Khác';
    }
  }

  Color get color {
    switch (this) {
      case TaskCategory.work:
        return Color(0xFF667EEA);
      case TaskCategory.personal:
        return Color(0xFFFF6B6B);
      case TaskCategory.learning:
        return Color(0xFF4ECDC4);
      case TaskCategory.health:
        return Color(0xFF95E77D);
      case TaskCategory.finance:
        return Color(0xFFFFA500);
      case TaskCategory.shopping:
        return Color(0xFFFF69B4);
      case TaskCategory.other:
        return Color(0xFF95A5A6);
    }
  }
}

extension TaskPriorityExtension on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Thấp';
      case TaskPriority.medium:
        return 'Trung bình';
      case TaskPriority.high:
        return 'Cao';
      case TaskPriority.urgent:
        return 'Khẩn cấp';
    }
  }

  int get value {
    switch (this) {
      case TaskPriority.low:
        return 1;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.high:
        return 3;
      case TaskPriority.urgent:
        return 4;
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return Color(0xFF95E77D);
      case TaskPriority.medium:
        return Color(0xFFFFA500);
      case TaskPriority.high:
        return Color(0xFFFF6B6B);
      case TaskPriority.urgent:
        return Color(0xFF8B0000);
    }
  }
}

extension RecurrenceTypeExtension on RecurrenceType {
  String get label {
    switch (this) {
      case RecurrenceType.none:
        return 'Không lặp';
      case RecurrenceType.daily:
        return 'Hàng ngày';
      case RecurrenceType.weekly:
        return 'Hàng tuần';
      case RecurrenceType.monthly:
        return 'Hàng tháng';
    }
  }
}

class Task {
  String id;
  String title;
  String description;
  bool isDone;
  DateTime? dueDate;
  DateTime createdAt;
  DateTime? completedAt;
  
  TaskCategory category;
  TaskPriority priority;
  RecurrenceType recurrence;
  
  // For drag & drop ordering
  int order;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.isDone,
    this.dueDate,
    required this.createdAt,
    this.completedAt,
    this.category = TaskCategory.personal,
    this.priority = TaskPriority.medium,
    this.recurrence = RecurrenceType.none,
    this.order = 0,
  });

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isDone: map['isDone'] ?? false,
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
      category: TaskCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => TaskCategory.personal,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.toString().split('.').last == map['priority'],
        orElse: () => TaskPriority.medium,
      ),
      recurrence: RecurrenceType.values.firstWhere(
        (e) => e.toString().split('.').last == map['recurrence'],
        orElse: () => RecurrenceType.none,
      ),
      order: map['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isDone': isDone,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'category': category.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'recurrence': recurrence.toString().split('.').last,
      'order': order,
    };
  }

  bool get isOverdue {
    if (isDone || dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  bool get isDueTomorrow {
    if (dueDate == null) return false;
    final tomorrow = DateTime.now().add(Duration(days: 1));
    return dueDate!.year == tomorrow.year &&
        dueDate!.month == tomorrow.month &&
        dueDate!.day == tomorrow.day;
  }
}