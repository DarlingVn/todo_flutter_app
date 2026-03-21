import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/task_service.dart';
import '../../data/services/auth_service.dart';
import '../widgets/task_item.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String uid;
  HomeScreen(this.uid);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final service = TaskService();
  final controller = TextEditingController();
  final auth = AuthService();
  DateTime? selectedDueDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TaskFlow',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Manage your tasks',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton(
                      icon: Icon(Icons.more_vert, color: Colors.white),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 20),
                              SizedBox(width: 8),
                              Text('Logout'),
                            ],
                          ),
                          onTap: () async {
                            await auth.logout();
                            if (mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => LoginScreen()),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Add Task Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Add a new task...',
                          prefixIcon: Icon(Icons.add_circle_outline, color: Color(0xFF667EEA)),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.send, color: Color(0xFF667EEA)),
                            onPressed: () {
                              if (controller.text.isNotEmpty) {
                                service.addTask(
                                  widget.uid,
                                  controller.text,
                                  dueDate: selectedDueDate,
                                );
                                controller.clear();
                                setState(() => selectedDueDate = null);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Task added'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    // Date picker button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, 
                              color: Color(0xFF667EEA), 
                              size: 20
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedDueDate == null
                                    ? 'Set due date (optional)'
                                    : 'Due: ${DateFormat('MMM dd, yyyy - hh:mm').format(selectedDueDate!)}',
                                style: TextStyle(
                                  color: selectedDueDate == null
                                      ? Colors.grey[500]
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            if (selectedDueDate != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() => selectedDueDate = null);
                                },
                                child: Icon(Icons.close, 
                                  color: Colors.red[400], 
                                  size: 20
                                ),
                              )
                            else
                              Icon(Icons.chevron_right, 
                                color: Color(0xFF667EEA)
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    // Date and time picker buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDueDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                    selectedDueDate ?? DateTime.now()
                                  ),
                                );
                                if (time != null) {
                                  setState(() {
                                    selectedDueDate = DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                      time.hour,
                                      time.minute,
                                    );
                                  });
                                }
                              }
                            },
                            icon: Icon(Icons.date_range, size: 18),
                            label: Text('Pick Date & Time'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF667EEA),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Tasks List
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: StreamBuilder(
                    stream: service.getTasks(widget.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.task_alt, size: 64, color: Colors.white30),
                              SizedBox(height: 16),
                              Text(
                                'No tasks yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                'Create one to get started!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      var tasks = snapshot.data!;
                      var completedCount = tasks.where((t) => t['isDone'] == true).length;

                      return Column(
                        children: [
                          // Progress indicator
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Progress',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '$completedCount of ${tasks.length} completed',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: CircularProgressIndicator(
                                    value: completedCount / tasks.length,
                                    backgroundColor: Colors.white24,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                    strokeWidth: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                              itemCount: tasks.length,
                              itemBuilder: (context, i) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: TaskItem(task: tasks[i], uid: widget.uid),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}