import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do List App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const TodoListScreen(),
    );
  }
}

class TodoSubtask {
  String task;
  bool isCompleted;

  TodoSubtask({
    required this.task,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'task': task,
      'isCompleted': isCompleted,
    };
  }

  factory TodoSubtask.fromJson(Map<String, dynamic> json) {
    return TodoSubtask(
      task: json['task'],
      isCompleted: json['isCompleted'],
    );
  }
}

class TodoItem {
  String task;
  bool isCompleted;
  DateTime createdAt;
  String notes;
  List<TodoSubtask> subtasks;
  bool isExpanded;

  TodoItem({
    required this.task,
    this.isCompleted = false,
    DateTime? createdAt,
    this.notes = '',
    List<TodoSubtask>? subtasks,
    this.isExpanded = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       subtasks = subtasks ?? [];

  Map<String, dynamic> toJson() {
    return {
      'task': task,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
      'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
      'isExpanded': isExpanded,
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      task: json['task'],
      isCompleted: json['isCompleted'],
      createdAt: DateTime.parse(json['createdAt']),
      notes: json['notes'] ?? '',
      subtasks: (json['subtasks'] as List<dynamic>?)
          ?.map((subtaskJson) => TodoSubtask.fromJson(subtaskJson))
          .toList() ?? [],
      isExpanded: json['isExpanded'] ?? false,
    );
  }

  int get completedSubtasks => subtasks.where((s) => s.isCompleted).length;
  int get totalSubtasks => subtasks.length;
  bool get allSubtasksCompleted => subtasks.isNotEmpty && completedSubtasks == totalSubtasks;
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen>
    with TickerProviderStateMixin {
  final List<TodoItem> _todoItems = [];
  final TextEditingController _textController = TextEditingController();
  late AnimationController _fabAnimationController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadTodoItems();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadTodoItems() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? todoStrings = prefs.getStringList('todo_items');
      if (todoStrings != null) {
        setState(() {
          _todoItems.clear();
          for (String todoString in todoStrings) {
            Map<String, dynamic> todoMap = json.decode(todoString);
            _todoItems.add(TodoItem.fromJson(todoMap));
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTodoItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> todoStrings = _todoItems
        .map((item) => json.encode(item.toJson()))
        .toList();
    await prefs.setStringList('todo_items', todoStrings);
  }

  void _addTodoItem(String task) {
    if (task.trim().isNotEmpty) {
      setState(() {
        _todoItems.add(TodoItem(task: task.trim()));
        _textController.clear();
      });
      _saveTodoItems();
      _fabAnimationController.forward().then((_) {
        _fabAnimationController.reverse();
      });
    }
  }

  void _removeTodoItem(int index) {
    setState(() {
      _todoItems.removeAt(index);
    });
    _saveTodoItems();
  }

  void _toggleTodoItem(int index) {
    setState(() {
      _todoItems[index].isCompleted = !_todoItems[index].isCompleted;
      // Jika main task selesai, tandai semua subtask sebagai selesai
      if (_todoItems[index].isCompleted) {
        for (var subtask in _todoItems[index].subtasks) {
          subtask.isCompleted = true;
        }
      }
    });
    _saveTodoItems();
  }

  void _toggleSubtask(int todoIndex, int subtaskIndex) {
    setState(() {
      _todoItems[todoIndex].subtasks[subtaskIndex].isCompleted = 
          !_todoItems[todoIndex].subtasks[subtaskIndex].isCompleted;
      
      // Check if all subtasks are completed to auto-complete main task
      if (_todoItems[todoIndex].allSubtasksCompleted) {
        _todoItems[todoIndex].isCompleted = true;
      } else if (_todoItems[todoIndex].isCompleted) {
        // If main task was completed but a subtask is unchecked, uncheck main task
        _todoItems[todoIndex].isCompleted = false;
      }
    });
    _saveTodoItems();
  }

  void _addSubtask(int todoIndex, String subtaskText) {
    if (subtaskText.trim().isNotEmpty) {
      setState(() {
        _todoItems[todoIndex].subtasks.add(
          TodoSubtask(task: subtaskText.trim())
        );
      });
      _saveTodoItems();
    }
  }

  void _removeSubtask(int todoIndex, int subtaskIndex) {
    setState(() {
      _todoItems[todoIndex].subtasks.removeAt(subtaskIndex);
    });
    _saveTodoItems();
  }

  void _updateNotes(int index, String notes) {
    setState(() {
      _todoItems[index].notes = notes;
    });
    _saveTodoItems();
  }

  void _toggleExpanded(int index) {
    setState(() {
      _todoItems[index].isExpanded = !_todoItems[index].isExpanded;
    });
    _saveTodoItems();
  }

  void _clearCompleted() {
    setState(() {
      _todoItems.removeWhere((item) => item.isCompleted);
    });
    _saveTodoItems();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Tambah Tugas Baru'),
          content: TextField(
            controller: _textController,
            decoration: const InputDecoration(
              hintText: 'Masukkan tugas baru...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (value) {
              _addTodoItem(value);
              Navigator.of(context).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                _addTodoItem(_textController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  void _showDetailDialog(TodoItem todoItem, int index) {
    final TextEditingController notesController = TextEditingController(text: todoItem.notes);
    final TextEditingController subtaskController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                todoItem.task,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Notes Section
                      const Text('Catatan:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          hintText: 'Tambahkan catatan...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        onChanged: (value) => _updateNotes(index, value),
                      ),
                      const SizedBox(height: 16),
                      
                      // Subtasks Section
                      Row(
                        children: [
                          const Text('Subtask:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('${todoItem.completedSubtasks}/${todoItem.totalSubtasks}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Add subtask field
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: subtaskController,
                              decoration: const InputDecoration(
                                hintText: 'Tambah subtask...',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (value) {
                                _addSubtask(index, value);
                                subtaskController.clear();
                                setDialogState(() {});
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _addSubtask(index, subtaskController.text);
                              subtaskController.clear();
                              setDialogState(() {});
                            },
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Subtasks list
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: todoItem.subtasks.length,
                          itemBuilder: (context, subtaskIndex) {
                            final subtask = todoItem.subtasks[subtaskIndex];
                            return ListTile(
                              dense: true,
                              leading: Checkbox(
                                value: subtask.isCompleted,
                                onChanged: (value) {
                                  _toggleSubtask(index, subtaskIndex);
                                  setDialogState(() {});
                                },
                              ),
                              title: Text(
                                subtask.task,
                                style: TextStyle(
                                  decoration: subtask.isCompleted 
                                      ? TextDecoration.lineThrough 
                                      : TextDecoration.none,
                                  color: subtask.isCompleted 
                                      ? Colors.grey[600] 
                                      : Colors.black87,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () {
                                  _removeSubtask(index, subtaskIndex);
                                  setDialogState(() {});
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tutup'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTodoList() {
    if (_todoItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada tugas',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap tombol + untuk menambah tugas baru',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _todoItems.length,
      itemBuilder: (context, index) {
        return _buildTodoItem(_todoItems[index], index);
      },
    );
  }

  Widget _buildTodoItem(TodoItem todoItem, int index) {
    return Dismissible(
      key: Key(todoItem.createdAt.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 24,
        ),
      ),
      onDismissed: (direction) {
        final removedItem = todoItem;
        _removeTodoItem(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tugas "${removedItem.task}" dihapus'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Transform.scale(
                scale: 1.2,
                child: Checkbox(
                  value: todoItem.isCompleted,
                  onChanged: (value) => _toggleTodoItem(index),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              title: Text(
                todoItem.task,
                style: TextStyle(
                  fontSize: 16,
                  decoration: todoItem.isCompleted 
                      ? TextDecoration.lineThrough 
                      : TextDecoration.none,
                  color: todoItem.isCompleted 
                      ? Colors.grey[600] 
                      : Colors.black87,
                  fontWeight: todoItem.isCompleted 
                      ? FontWeight.normal 
                      : FontWeight.w500,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dibuat: ${_formatDate(todoItem.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (todoItem.totalSubtasks > 0)
                    Text(
                      'Subtask: ${todoItem.completedSubtasks}/${todoItem.totalSubtasks}',
                      style: TextStyle(
                        fontSize: 12,
                        color: todoItem.allSubtasksCompleted ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (todoItem.notes.isNotEmpty)
                    Text(
                      '📝 ${todoItem.notes.length > 30 ? '${todoItem.notes.substring(0, 30)}...' : todoItem.notes}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (todoItem.subtasks.isNotEmpty || todoItem.notes.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        todoItem.isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.blue,
                      ),
                      onPressed: () => _toggleExpanded(index),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                    onPressed: () => _showDetailDialog(todoItem, index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeTodoItem(index),
                  ),
                ],
              ),
            ),
            
            // Expanded content
            if (todoItem.isExpanded && (todoItem.subtasks.isNotEmpty || todoItem.notes.isNotEmpty))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (todoItem.notes.isNotEmpty) ...[
                      const Text('Catatan:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(todoItem.notes, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 12),
                    ],
                    if (todoItem.subtasks.isNotEmpty) ...[
                      const Text('Subtask:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...todoItem.subtasks.asMap().entries.map((entry) {
                        int subtaskIndex = entry.key;
                        TodoSubtask subtask = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Transform.scale(
                                scale: 0.9,
                                child: Checkbox(
                                  value: subtask.isCompleted,
                                  onChanged: (value) => _toggleSubtask(index, subtaskIndex),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  subtask.task,
                                  style: TextStyle(
                                    decoration: subtask.isCompleted 
                                        ? TextDecoration.lineThrough 
                                        : TextDecoration.none,
                                    color: subtask.isCompleted 
                                        ? Colors.grey[600] 
                                        : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  int get _completedCount => _todoItems.where((item) => item.isCompleted).length;
  int get _totalCount => _todoItems.length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Daftar Tugas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_completedCount > 0)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Hapus Tugas Selesai'),
                    content: Text('Hapus $_completedCount tugas yang sudah selesai?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _clearCompleted();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Hapus tugas yang sudah selesai',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_totalCount > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Progress Tugas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_completedCount dari $_totalCount selesai',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _totalCount > 0 ? _completedCount / _totalCount : 0,
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildTodoList(),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.85).animate(
          CurvedAnimation(
            parent: _fabAnimationController,
            curve: Curves.elasticOut,
          ),
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add),
          label: const Text('Tambah Tugas'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}