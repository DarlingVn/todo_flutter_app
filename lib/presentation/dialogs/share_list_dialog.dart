import 'package:flutter/material.dart';
import '../../data/models/task_model.dart';
import '../../data/services/share_service.dart';

class ShareListDialog extends StatefulWidget {
  final String uid;
  final List<Task> tasks;

  ShareListDialog({required this.uid, required this.tasks});

  @override
  _ShareListDialogState createState() => _ShareListDialogState();
}

class _ShareListDialogState extends State<ShareListDialog> {
  final shareService = ShareService();
  final listNameController = TextEditingController();
  final emailController = TextEditingController();
  List<String> selectedTaskIds = [];
  bool isSharing = false;

  @override
  void initState() {
    super.initState();
    // Select all tasks by default
    selectedTaskIds = widget.tasks.map((t) => t.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF667EEA),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Share List',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // List Name
                    Text(
                      'List Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: listNameController,
                      decoration: InputDecoration(
                        hintText: 'e.g., My Tasks, Project Beta',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Task Selection
                    Text(
                      'Tasks to Share',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      constraints: BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: widget.tasks.length,
                        itemBuilder: (context, index) {
                          final task = widget.tasks[index];
                          return CheckboxListTile(
                            value: selectedTaskIds.contains(task.id),
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  selectedTaskIds.add(task.id);
                                } else {
                                  selectedTaskIds.remove(task.id);
                                }
                              });
                            },
                            title: Text(task.title),
                            subtitle: task.description.isNotEmpty
                                ? Text(task.description)
                                : null,
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),

                    // Share Options
                    Text(
                      'Share With',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Email input
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: 'Enter email address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: Icon(Icons.email),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer buttons
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isSharing ? null : _shareList,
                    child: isSharing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text('Share'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareList() async {
    if (listNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a list name')),
      );
      return;
    }

    if (selectedTaskIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one task')),
      );
      return;
    }

    setState(() => isSharing = true);

    try {
      // Create shareable list
      final shareId = await shareService.createShareableList(
        widget.uid,
        listNameController.text,
        selectedTaskIds,
      );

      final shareLink = shareService.generateShareLink(shareId);

      // If email provided, add to shared list
      if (emailController.text.isNotEmpty) {
        await shareService.shareListWithEmail(
          shareId,
          widget.uid,
          emailController.text,
        );
      }

      if (mounted) {
        // Show share link in a copyable dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Share Link Created'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share this link with others to invite them to your list:'),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    shareLink,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Link expires in 30 days',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ List shared successfully!'),
            backgroundColor: Colors.green[600],
          ),
        );
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sharing list: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSharing = false);
      }
    }
  }

  @override
  void dispose() {
    listNameController.dispose();
    emailController.dispose();
    super.dispose();
  }
}
