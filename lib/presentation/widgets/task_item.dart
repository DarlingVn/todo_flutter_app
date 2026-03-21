import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/task_service.dart';

class TaskItem extends StatefulWidget {
  final Map<String, dynamic> task;
  final String uid;

  TaskItem({required this.task, required this.uid});

  @override
  _TaskItemState createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  final service = TaskService();

  @override
  Widget build(BuildContext context) {
    final isDone = widget.task['isDone'] ?? false;
    final dueDate = widget.task['dueDate'];
    DateTime? parsedDate;
    
    if (dueDate != null && dueDate is String) {
      try {
        parsedDate = DateTime.parse(dueDate);
      } catch (e) {
        // Invalid date format
      }
    }

    final isOverdue = parsedDate != null && 
        parsedDate.isBefore(DateTime.now()) && 
        !isDone;

    return Container(
      decoration: BoxDecoration(
        color: isDone 
            ? Colors.white.withOpacity(0.6)
            : isOverdue 
              ? Colors.red[50]
              : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isOverdue 
            ? Border.all(color: Colors.red[300]!, width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone 
                      ? Color(0xFF667EEA)
                      : isOverdue
                        ? Colors.red[300]!
                        : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Checkbox(
                value: isDone,
                activeColor: Color(0xFF667EEA),
                onChanged: (v) {
                  setState(() {
                    service.updateTask(widget.uid, widget.task['id'], v!);
                  });
                },
              ),
            ),
            title: Text(
              widget.task['title'] ?? 'No title',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                color: isDone 
                    ? Colors.grey
                    : isOverdue
                      ? Colors.red[700]
                      : Colors.black87,
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete Task'),
                    content: Text('Are you sure you want to delete this task?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          service.deleteTask(widget.uid, widget.task['id']);
                          Navigator.pop(context);
                        },
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Due date section
          if (parsedDate != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: isOverdue ? Colors.red : Color(0xFF667EEA),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Due: ${DateFormat('MMM dd, yyyy - hh:mm').format(parsedDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? Colors.red[700] : Colors.grey[600],
                      fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (isOverdue)
                    Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Overdue',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}