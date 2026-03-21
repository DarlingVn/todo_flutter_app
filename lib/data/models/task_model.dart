class Task {
  String id;
  String title;
  bool isDone;

  Task({required this.id, required this.title, required this.isDone});

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      title: map['title'],
      isDone: map['isDone'],
    );
  }
}