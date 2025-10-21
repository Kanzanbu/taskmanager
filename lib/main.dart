import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(TaskApp(prefs: prefs));
}

class TaskApp extends StatefulWidget {
  final SharedPreferences prefs;
  const TaskApp({required this.prefs, Key? key}) : super(key: key);

  @override
  TaskAppState createState() => TaskAppState();
}

class TaskAppState extends State<TaskApp> {
  late bool isDarkMode;

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.prefs.getBool('isDarkMode') ?? false;
  }

  void toggleTheme(bool value) {
    setState(() {
      isDarkMode = value;
      widget.prefs.setBool('isDarkMode', isDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager CW03',
      theme: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: TaskListScreen(
        prefs: widget.prefs,
        onToggleTheme: toggleTheme,
        isDarkMode: isDarkMode,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum Priority { low, medium, high }

extension PriorityExtension on Priority {
  String get label {
    switch (this) {
      case Priority.high:
        return 'High';
      case Priority.medium:
        return 'Medium';
      case Priority.low:
      default:
        return 'Low';
    }
  }

  int get order {
    switch (this) {
      case Priority.high:
        return 3;
      case Priority.medium:
        return 2;
      case Priority.low:
      default:
        return 1;
    }
  }

  static Priority fromString(String s) {
    switch (s.toLowerCase()) {
      case 'high':
        return Priority.high;
      case 'medium':
        return Priority.medium;
      case 'low':
      default:
        return Priority.low;
    }
  }
}

class Task {
  String id;
  String name;
  bool completed;
  Priority priority;
  DateTime createdAt;

  Task({
    required this.id,
    required this.name,
    this.completed = false,
    this.priority = Priority.medium,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      name: json['name'] as String,
      completed: json['completed'] as bool,
      priority: PriorityExtension.fromString(json['priority'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'completed': completed,
    'priority': priority.label,
    'createdAt': createdAt.toIso8601String(),
  };
}

class TaskListScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final ValueChanged<bool> onToggleTheme;
  final bool isDarkMode;

  const TaskListScreen({
    required this.prefs,
    required this.onToggleTheme,
    required this.isDarkMode,
    Key? key,
  }) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> tasks = [];
  final TextEditingController _controller = TextEditingController();
  Priority _selectedAddPriority = Priority.medium;

  static const String tasksKey = 'tasks_json';

  @override
  void initState() {
    super.initState();
    loadTasksFromPrefs();
  }

  Future<void> loadTasksFromPrefs() async {
    final jsonString = widget.prefs.getString(tasksKey);
    if (jsonString != null) {
      try {
        final List decoded = json.decode(jsonString) as List;
        tasks = decoded.map((e) => Task.fromJson(e)).toList();
      } catch (_) {
        tasks = [];
      }
    } else {
      tasks = [];
    }
    setState(() {});
  }

  Future<void> saveTasksToPrefs() async {
    final encoded = json.encode(tasks.map((t) => t.toJson()).toList());
    await widget.prefs.setString(tasksKey, encoded);
  }

  void addTask() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      completed: false,
      priority: _selectedAddPriority,
    );
    setState(() {
      tasks.add(newTask);
      _controller.clear();
      _selectedAddPriority = Priority.medium;
      sortTasks();
    });
    saveTasksToPrefs();
  }

  void toggleCompleted(Task task) {
    setState(() {
      task.completed = !task.completed;
      sortTasks();
    });
    saveTasksToPrefs();
  }

  void deleteTask(Task task) {
    setState(() {
      tasks.removeWhere((t) => t.id == task.id);
    });
    saveTasksToPrefs();
  }

  void changePriority(Task task, Priority newPriority) {
    setState(() {
      task.priority = newPriority;
      sortTasks();
    });
    saveTasksToPrefs();
  }

  void sortTasks() {
    tasks.sort((a, b) {
      final pr = b.priority.order.compareTo(a.priority.order);
      if (pr != 0) return pr;
      final comp = (a.completed ? 1 : 0) - (b.completed ? 1 : 0);
      if (comp != 0) return comp;
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  Future<void> clearAllTasksConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all tasks?'),
        content: const Text('This will delete all tasks permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => tasks.clear());
      await saveTasksToPrefs();
    }
  }

  Widget _buildPriorityChip(Priority p) {
    Color bg;
    switch (p) {
      case Priority.high:
        bg = Colors.red.shade400;
        break;
      case Priority.medium:
        bg = Colors.orange.shade400;
        break;
      case Priority.low:
      default:
        bg = Colors.green.shade400;
        break;
    }
    return Chip(
      label: Text(p.label, style: const TextStyle(color: Colors.white)),
      backgroundColor: bg,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget buildTaskTile(Task task) {
    return Dismissible(
      key: Key(task.id),
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => deleteTask(task),
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          onChanged: (_) => toggleCompleted(task),
        ),
        title: Text(
          task.name,
          style: TextStyle(
            decoration:
            task.completed ? TextDecoration.lineThrough : TextDecoration.none,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Added: ${task.createdAt.toLocal().toString().split('.').first}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPriorityChip(task.priority),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  deleteTask(task);
                } else {
                  changePriority(task, PriorityExtension.fromString(value));
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                    value: Priority.high.label, child: const Text('Set High')),
                PopupMenuItem(
                    value: Priority.medium.label, child: const Text('Set Medium')),
                PopupMenuItem(
                    value: Priority.low.label, child: const Text('Set Low')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTaskList() {
    if (tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 8),
            Text('No tasks yet — add one!', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => buildTaskTile(tasks[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    sortTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager (CW03)'),
        actions: [
          Row(
            children: [
              Icon(widget.isDarkMode
                  ? Icons.nightlight_round
                  : Icons.wb_sunny),
              Switch(
                value: widget.isDarkMode,
                onChanged: (v) => widget.onToggleTheme(v),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Clear all tasks',
            icon: const Icon(Icons.delete_sweep),
            onPressed:
            tasks.isEmpty ? null : () => clearAllTasksConfirmation(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => addTask(),
                    decoration: const InputDecoration(
                      labelText: 'Enter task name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<Priority>(
                    value: _selectedAddPriority,
                    underline: const SizedBox.shrink(),
                    items: Priority.values
                        .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.label),
                    ))
                        .toList(),
                    onChanged: (p) {
                      if (p == null) return;
                      setState(() => _selectedAddPriority = p);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: addTask,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: const [
                Text('Tasks list'),
                Spacer(),
                Text('Sorted: High → Low, incomplete first'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: buildTaskList()),
        ],
      ),
    );
  }
}
