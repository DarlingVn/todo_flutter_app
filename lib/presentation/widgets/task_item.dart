import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/task_model.dart';
import '../../data/services/task_service.dart';

class TaskItem extends StatefulWidget {
  final Task task;
  final String uid;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  TaskItem({
    required this.task,
    required this.uid,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  _TaskItemState createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  final service = TaskService();
  late Task currentTask;

  @override
  void initState() {
    super.initState();
    currentTask = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    final isDone = currentTask.isDone;
    final isOverdue = currentTask.isOverdue;

    return GestureDetector(
      onTap: () => _showTaskDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: isDone
              ? Colors.white.withOpacity(0.5)
              : isOverdue
                  ? Colors.red[50]
                  : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isOverdue ? Border.all(color: Colors.red[300]!, width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: GestureDetector(
                onTap: () => _toggleCompletion(),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? currentTask.priority.color
                          : isOverdue
                              ? Colors.red[300]!
                              : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: Checkbox(
                    value: isDone,
                    activeColor: currentTask.priority.color,
                    onChanged: (_) => _toggleCompletion(),
                  ),
                ),
              ),
              title: Text(
                currentTask.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                  color: isDone
                      ? Colors.grey
                      : isOverdue
                          ? Colors.red[700]
                          : Colors.black87,
                ),
              ),
              subtitle: currentTask.description.isNotEmpty
                  ? Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        currentTask.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Move up button
                  if (widget.canMoveUp)
                    IconButton(
                      icon: Icon(Icons.arrow_upward, size: 18),
                      onPressed: widget.onMoveUp,
                      tooltip: 'Move up',
                      splashRadius: 20,
                    )
                  else
                    SizedBox(width: 40),
                  
                  // Move down button
                  if (widget.canMoveDown)
                    IconButton(
                      icon: Icon(Icons.arrow_downward, size: 18),
                      onPressed: widget.onMoveDown,
                      tooltip: 'Move down',
                      splashRadius: 20,
                    )
                  else
                    SizedBox(width: 40),
                  
                  // Menu button
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                        onTap: () => _showTaskDetails(context),
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        onTap: () => _deleteTask(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Category & Priority Chips
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Category chip
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentTask.category.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentTask.category.color.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      currentTask.category.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: currentTask.category.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Priority chip
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentTask.priority.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentTask.priority.color.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag, size: 10, color: currentTask.priority.color),
                        SizedBox(width: 4),
                        Text(
                          currentTask.priority.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: currentTask.priority.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Recurrence chip (if set)
                  if (currentTask.recurrence != RecurrenceType.none)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF4ECDC4).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(0xFF4ECDC4).withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.repeat, size: 10, color: Color(0xFF4ECDC4)),
                          SizedBox(width: 4),
                          Text(
                            currentTask.recurrence.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4ECDC4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Due date section
            if (currentTask.dueDate != null)
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
                    Expanded(
                      child: Text(
                        'Due: ${DateFormat('MMM dd, yyyy - hh:mm').format(currentTask.dueDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.red[700] : Colors.grey[600],
                          fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isOverdue)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  ],
                ),
              ),
            SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  void _toggleCompletion() async {
    await service.toggleTaskCompletion(widget.uid, currentTask.id, currentTask);
    setState(() {
      currentTask.isDone = !currentTask.isDone;
      if (currentTask.isDone) {
        currentTask.completedAt = DateTime.now();
      }
    });
  }

  void _deleteTask() {
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
              service.deleteTask(widget.uid, currentTask.id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTaskDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Task Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      currentTask.title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    if (currentTask.description.isNotEmpty) ...[
                      Text(
                        'Description',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8),
                      Text(
                        currentTask.description,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 16),
                    ],
                    // Category, Priority, Recurrence selectors
                    Text('Category: ${currentTask.category.label}'),
                    SizedBox(height: 8),
                    Text('Priority: ${currentTask.priority.label}'),
                    SizedBox(height: 8),
                    Text('Recurrence: ${currentTask.recurrence.label}'),
                    
                    // Warning for recurring tasks
                    if (currentTask.recurrence != RecurrenceType.none) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[400]!, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange[700], size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This task repeats ${currentTask.recurrence.label.toLowerCase()}. Completing it will create a new task automatically.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    if (currentTask.dueDate != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'Due: ${DateFormat('EEEE, MMMM dd, yyyy - hh:mm').format(currentTask.dueDate!)}',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}