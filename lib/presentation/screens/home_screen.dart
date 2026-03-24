import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/task_model.dart';
import '../../data/services/task_service.dart';
import '../../data/services/auth_service.dart';
import '../widgets/task_item.dart';
import 'analytics_screen.dart';
import '../dialogs/share_list_dialog.dart';

class HomeScreen extends StatefulWidget {
  final String uid;
  HomeScreen(this.uid);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final service = TaskService();
  final controller = TextEditingController();
  final searchController = TextEditingController();
  final auth = AuthService();
  DateTime? selectedDueDate;
  TaskCategory? selectedCategory;
  TaskPriority? selectedPriority;
  RecurrenceType selectedRecurrence = RecurrenceType.none;
  String searchQuery = '';
  bool isSearching = false;
  bool isUploadingTask = false; // ← NEW: Track upload state
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

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
              // Header with Search
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!isSearching)
                      Expanded(
                        child: Column(
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
                      )
                    else
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: (value) {
                            setState(() => searchQuery = value);
                          },
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search tasks...',
                            hintStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.search, color: Colors.white),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.analytics, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AnalyticsScreen(uid: widget.uid),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            isSearching ? Icons.close : Icons.search,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              isSearching = !isSearching;
                              if (!isSearching) {
                                searchController.clear();
                                searchQuery = '';
                              }
                            });
                          },
                        ),
                        PopupMenuButton(
                          icon: Icon(Icons.more_vert, color: Colors.white),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: Row(
                                children: [
                                  Icon(Icons.share, size: 20),
                                  SizedBox(width: 8),
                                  Text('Share List'),
                                ],
                              ),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => ShareListDialog(
                                    uid: widget.uid,
                                    tasks: [],
                                  ),
                                );
                              },
                            ),
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
                                // AuthWrapper will automatically handle navigation
                                // based on authStateChanges() stream
                                if (mounted) {
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/',
                                    (route) => false,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Tab Bar
              if (!isSearching)
                Container(
                  color: Colors.white.withOpacity(0.1),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                    tabs: [
                      Tab(icon: Icon(Icons.all_inbox), text: 'All'),
                      Tab(icon: Icon(Icons.today), text: 'Today'),
                      Tab(icon: Icon(Icons.priority_high), text: 'Urgent'),
                      Tab(icon: Icon(Icons.check_circle), text: 'Completed'),
                    ],
                  ),
                ),

              // Add Task Section
              if (!isSearching)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: _buildAddTaskSection(),
                )
              else
                SizedBox(height: 0),

              // Tasks List or Search Results
              Expanded(
                child: isSearching ? _buildSearchResults() : _buildTaskTabs(),
              ),

              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddTaskSection() {
    return Column(
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
            maxLines: 1,
            enabled: !isUploadingTask,
            decoration: InputDecoration(
              hintText: 'Add a new task...',
              prefixIcon: Icon(Icons.add_circle_outline, color: Color(0xFF667EEA)),
              suffixIcon: IconButton(
                icon: Icon(Icons.send, color: isUploadingTask ? Colors.grey : Color(0xFF667EEA)),
                onPressed: isUploadingTask ? null : _addNewTask,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        SizedBox(height: 12),
        _buildTaskOptions(),
      ],
    );
  }

  Widget _buildTaskOptions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Category selector
          _buildCategoryChip(),
          SizedBox(width: 8),
          // Priority selector
          _buildPriorityChip(),
          SizedBox(width: 8),
          // Recurrence selector
          _buildRecurrenceChip(),
          SizedBox(width: 8),
          // Date picker
          _buildDateChip(),
        ],
      ),
    );
  }

  Widget _buildCategoryChip() {
    return GestureDetector(
      onTap: () {
        _showCategoryDialog();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selectedCategory?.color ?? Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.label, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text(
              selectedCategory?.label ?? 'Category',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip() {
    return GestureDetector(
      onTap: () {
        _showPriorityDialog();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selectedPriority?.color ?? Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text(
              selectedPriority?.label ?? 'Priority',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceChip() {
    return GestureDetector(
      onTap: () {
        _showRecurrenceDialog();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selectedRecurrence != RecurrenceType.none
              ? Color(0xFF4ECDC4)
              : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text(
              selectedRecurrence.label,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip() {
    return GestureDetector(
      onTap: () async {
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
              selectedDueDate ?? DateTime.now(),
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
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selectedDueDate != null
              ? Color(0xFF95E77D)
              : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text(
              selectedDueDate == null
                  ? 'Date'
                  : DateFormat('MMM dd').format(selectedDueDate!),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            if (selectedDueDate != null) ...[
              SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => selectedDueDate = null),
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTabs() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildAllTasksList(),
        _buildTodayTasksList(),
        _buildUrgentTasksList(),
        _buildCompletedTasksList(),
      ],
    );
  }

  Widget _buildAllTasksList() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<List<Task>>(
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
                    'No tasks',
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

          final tasks = snapshot.data!;
          final completedCount = tasks.where((t) => t.isDone).length;

          return Column(
            children: [
              // Progress indicator
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
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
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '$completedCount of ${tasks.length} completed',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        value: tasks.length > 0 
                            ? completedCount / tasks.length 
                            : 0,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                        backgroundColor: Colors.white.withOpacity(0.2),
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Reorderable task list
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: TaskItem(
                        task: tasks[index],
                        uid: widget.uid,
                        canMoveUp: index > 0,
                        canMoveDown: index < tasks.length - 1,
                        onMoveUp: () => _moveTask(tasks, index, index - 1),
                        onMoveDown: () => _moveTask(tasks, index, index + 1),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Handle task reordering - Move task up or down
  void _moveTask(List<Task> tasks, int oldIndex, int newIndex) {
    setState(() {
      final temp = tasks.removeAt(oldIndex);
      tasks.insert(newIndex, temp);
    });
    
    // Save new order to Firebase
    service.reorderTasks(widget.uid, tasks).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Task moved'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green[600],
        ),
      );
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to move task'),
          backgroundColor: Colors.red[600],
        ),
      );
    });
  }

  Widget _buildTodayTasksList() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<List<Task>>(
        stream: service.getTodayTasks(widget.uid),
        builder: (context, snapshot) {
          return _buildTasksList(snapshot);
        },
      ),
    );
  }

  Widget _buildUrgentTasksList() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<List<Task>>(
        stream: service.getTasksByPriority(widget.uid, TaskPriority.urgent),
        builder: (context, snapshot) {
          return _buildTasksList(snapshot);
        },
      ),
    );
  }

  Widget _buildCompletedTasksList() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<List<Task>>(
        stream: service.getTasks(widget.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            );
          }
          final completedTasks = snapshot.data!.where((t) => t.isDone).toList();
          if (completedTasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.white30),
                  SizedBox(height: 16),
                  Text(
                    'No completed tasks',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: completedTasks.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: TaskItem(task: completedTasks[i], uid: widget.uid),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<Task>>(
      future: searchQuery.isEmpty ? Future.value([]) : service.searchTasks(widget.uid, searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          );
        }

        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.white30),
                SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty ? 'Start typing to search' : 'No tasks found',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: TaskItem(task: results[i], uid: widget.uid),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTasksList(AsyncSnapshot<List<Task>> snapshot) {
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
              'No tasks',
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

    final tasks = snapshot.data!;
    final completedCount = tasks.where((t) => t.isDone).length;

    return Column(
      children: [
        // Progress indicator
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
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
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '$completedCount of ${tasks.length} completed',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: completedCount / tasks.length,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
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
  }

  Future<void> _addNewTask() async {
    if (controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    try {
      // Set uploading state
      setState(() => isUploadingTask = true);

      // Show loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('⏳ Saving task... Do not reload!'),
            ],
          ),
          duration: Duration(seconds: 10),
          backgroundColor: Colors.orange[700],
        ),
      );

      // Wait for task to be saved
      await service.addTask(
        widget.uid,
        controller.text,
        dueDate: selectedDueDate,
        category: selectedCategory ?? TaskCategory.personal,
        priority: selectedPriority ?? TaskPriority.medium,
        recurrence: selectedRecurrence,
      );

      // Clear form only after successful save
      if (mounted) {
        controller.clear();
        setState(() {
          selectedDueDate = null;
          selectedCategory = null;
          selectedPriority = null;
          selectedRecurrence = RecurrenceType.none;
          isUploadingTask = false; // ← Clear uploading state
        });
        print('✨ Form cleared: recurrence reset to ${RecurrenceType.none}');

        // Hide the loading snackbar first
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Task saved successfully!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isUploadingTask = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Category'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: TaskCategory.values
                .map((cat) => ListTile(
                      leading: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: cat.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      title: Text(cat.label),
                      onTap: () {
                        setState(() => selectedCategory = cat);
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showPriorityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Priority'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: TaskPriority.values
                .map((pri) => ListTile(
                      leading: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: pri.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      title: Text(pri.label),
                      onTap: () {
                        setState(() => selectedPriority = pri);
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showRecurrenceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Recurrence'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: RecurrenceType.values
                .map((rec) => ListTile(
                      title: Text(rec.label),
                      onTap: () {
                        setState(() => selectedRecurrence = rec);
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}