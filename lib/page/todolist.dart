import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' as scheduler;

import 'dart:async';
import '../services/data_service.dart';
import './todo_filters.dart';
 

// Todo Models
class TodoSubtask {
  int id;
  String task;
  bool isCompleted;
  DateTime? scheduledTime;
  DateTime? endTime;

  TodoSubtask({
    required this.id,
    required this.task,
    this.isCompleted = false,
    this.scheduledTime,
    this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task': task,
      'isCompleted': isCompleted,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }
 
  
  factory TodoSubtask.fromJson(Map<String, dynamic> json) {
    final DateTime? sched = json['scheduledTime'] != null 
        ? DateTime.parse(json['scheduledTime']) 
        : null;
    final DateTime? end = json['endTime'] != null 
        ? DateTime.parse(json['endTime']) 
        : null;
    final int computedId = _computeStableId(json['task'] ?? '', sched, end);
    return TodoSubtask(
      id: (json['id'] is int) ? json['id'] as int : computedId,
      task: json['task'],
      isCompleted: json['isCompleted'],
      scheduledTime: sched,
      endTime: end,
    );
  }

  bool get isScheduled => scheduledTime != null;
  bool get hasEndTime => endTime != null;
  
  Duration? get remainingTime {
    if (endTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(endTime!)) return null;
    return endTime!.difference(now);
  }
  
  bool get isOverdue {
    if (endTime == null) return false;
    return DateTime.now().isAfter(endTime!) && !isCompleted;
  }
  
  bool get isActive {
    if (scheduledTime == null) return false;
    final now = DateTime.now();
    return now.isAfter(scheduledTime!) && (endTime == null || now.isBefore(endTime!));
  }

  static int _computeStableId(String task, DateTime? scheduledTime, DateTime? endTime) {
    // Deterministic simple checksum based on content and times
    int sum = 0;
    for (final c in task.codeUnits) {
      sum = (sum * 31 + c) & 0x7FFFFFFF;
    }
    if (scheduledTime != null) {
      sum ^= scheduledTime.millisecondsSinceEpoch & 0x7FFFFFFF;
    }
    if (endTime != null) {
      sum ^= (endTime.millisecondsSinceEpoch >> 1) & 0x7FFFFFFF;
    }
    // Ensure non-zero positive int
    if (sum == 0) sum = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
    return sum;
  }
}

class TodoItem {
  String task;
  bool isCompleted;
  DateTime createdAt;
  String notes;
  List<TodoSubtask> subtasks;
  bool isExpanded;
  String priority;
  DateTime? dueDate;

  TodoItem({
    required this.task,
    this.isCompleted = false,
    DateTime? createdAt,
    this.notes = '',
    List<TodoSubtask>? subtasks,
    this.isExpanded = false,
    this.priority = 'Sedang',
    this.dueDate,
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
      'priority': priority,
      'dueDate': dueDate?.toIso8601String(),
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
      priority: json['priority'] ?? 'Sedang',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    );
  }

  int get completedSubtasks => subtasks.where((s) => s.isCompleted).length;
  int get totalSubtasks => subtasks.length;
  bool get allSubtasksCompleted => subtasks.isNotEmpty && completedSubtasks == totalSubtasks;
  
  Color get priorityColor {
    switch (priority) {
      case 'Tinggi':
        return Colors.red;
      case 'Sedang':
        return Colors.orange;
      case 'Rendah':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
  
  String get dueDateString {
    if (dueDate == null) return 'Tidak ada deadline';
    final now = DateTime.now();
    final difference = dueDate!.difference(now).inDays;
    
    if (difference == 0) return 'Hari ini';
    if (difference == 1) return 'Besok';
    if (difference == -1) return 'Kemarin';
    if (difference > 1) return '$difference hari lagi';
    if (difference < -1) return '${difference.abs()} hari yang lalu';
    
    return _formatDate(dueDate!);
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!) && !isCompleted;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Todo List Screen
class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final List<TodoItem> _todoItems = [];
  late AnimationController _fabAnimationController;
  bool _isLoading = true;
  Timer? _uiTimer;
  final DataService _dataService = DataService.instance;
  int _tabIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadTodoItems();
    _startUiTimer();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _uiTimer?.cancel();
    super.dispose();
  }

  void _startUiTimer() {
    // Refresh UI every minute so time-based badges/countdowns update automatically
    _uiTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  // All notification scheduling removed; UI will just reflect time-based states.

  Future<void> _loadTodoItems() async {
    try {
      final todoItems = await _dataService.loadTodoItems();
      setState(() {
        _todoItems.clear();
        _todoItems.addAll(todoItems);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading todos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveTodoItems() async {
    try {
      await _dataService.saveTodoItems(_todoItems);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving todos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      
      if (_todoItems[todoIndex].allSubtasksCompleted) {
        _todoItems[todoIndex].isCompleted = true;
      } else if (_todoItems[todoIndex].isCompleted) {
        _todoItems[todoIndex].isCompleted = false;
      }
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
  
  Future<DateTime?> _selectDateTime(BuildContext context, {DateTime? initialDate}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date == null) return null;
    
    if (!context.mounted) return null;
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate ?? DateTime.now()),
    );
    
    if (time == null) return null;
    
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _showSubtaskTimerDialog(
    BuildContext context,
    String taskText,
    Function(TodoSubtask) onAdd,
  ) async {
    DateTime? start;
    DateTime? end;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Pengaturan Waktu Subtask'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Waktu Mulai'),
                    subtitle: Text(start != null ? _formatDateTime(start!) : 'Tidak ditetapkan'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await _selectDateTime(context, initialDate: start);
                        if (picked != null) {
                          setStateDialog(() => start = picked);
                        }
                      },
                      child: const Text('Pilih'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Waktu Selesai'),
                    subtitle: Text(end != null ? _formatDateTime(end!) : 'Tidak ditetapkan'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await _selectDateTime(context, initialDate: end);
                        if (picked != null) {
                          setStateDialog(() => end = picked);
                        }
                      },
                      child: const Text('Pilih'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onAdd(TodoSubtask(
                      id: DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF,
                      task: taskText,
                      scheduledTime: start,
                      endTime: end,
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDetailDialog(TodoItem todoItem, int index) {
    final TextEditingController notesController = TextEditingController(text: todoItem.notes);
    String selectedPriority = todoItem.priority;
    DateTime? selectedDueDate = todoItem.dueDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Detail: ${todoItem.task}', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Catatan:'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Tambahkan catatan...'),
                      onChanged: (v) => _updateNotes(index, v),
                    ),
                    const SizedBox(height: 16),
                    const Text('Prioritas:'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      items: const [
                        DropdownMenuItem(value: 'Rendah', child: Text('Rendah')),
                        DropdownMenuItem(value: 'Sedang', child: Text('Sedang')),
                        DropdownMenuItem(value: 'Tinggi', child: Text('Tinggi')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _todoItems[index].priority = v;
                        });
                        setDialogState(() => selectedPriority = v);
                        _saveTodoItems();
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Deadline (opsional):'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDueDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _todoItems[index].dueDate = picked;
                          });
                          setDialogState(() => selectedDueDate = picked);
                          _saveTodoItems();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 8),
                            Text(selectedDueDate != null ? _formatDate(selectedDueDate!) : 'Pilih tanggal'),
                            const Spacer(),
                            if (selectedDueDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _todoItems[index].dueDate = null;
                                  });
                                  setDialogState(() => selectedDueDate = null);
                                  _saveTodoItems();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
    ).then((_) {
      notesController.dispose();
    });
  }

  void _showAddDialog() {
    final TextEditingController taskController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    final TextEditingController subtaskController = TextEditingController();
    final List<TodoSubtask> tempSubtasks = [];
    String selectedPriority = 'Sedang';
    DateTime? selectedDueDate;
    
    final List<String> priorities = ['Rendah', 'Sedang', 'Tinggi'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Tambah Tugas Baru'),
              content: SizedBox(
                width: double.maxFinite,
                height: 550,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Task Title Section
                      const Text('Judul Tugas:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: taskController,
                        decoration: const InputDecoration(
                          hintText: 'Masukkan judul tugas...',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      
                      // Priority Section
                      const Text('Prioritas:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPriority,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: priorities.map((priority) {
                          Color priorityColor;
                          switch (priority) {
                            case 'Tinggi':
                              priorityColor = Colors.red;
                              break;
                            case 'Sedang':
                              priorityColor = Colors.orange;
                              break;
                            case 'Rendah':
                              priorityColor = Colors.green;
                              break;
                            default:
                              priorityColor = Colors.grey;
                          }
                          return DropdownMenuItem(
                            value: priority,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: priorityColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(priority),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPriority = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Due Date Section
                      const Text('Tanggal Deadline (opsional):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDueDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() {
                              selectedDueDate = date;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today),
                              const SizedBox(width: 8),
                              Text(
                                selectedDueDate != null 
                                    ? '${selectedDueDate!.day}/${selectedDueDate!.month}/${selectedDueDate!.year}'
                                    : 'Pilih tanggal deadline',
                              ),
                              const Spacer(),
                              if (selectedDueDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    setDialogState(() {
                                      selectedDueDate = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes Section
                      const Text('Catatan (opsional):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          hintText: 'Tambahkan catatan...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      
                      // Subtasks Section
                      Row(
                        children: [
                          const Text('Subtask (opsional):', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('${tempSubtasks.length} subtask'),
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
                              onSubmitted: (value) async {
                                if (value.trim().isNotEmpty) {
                                  await _showSubtaskTimerDialog(context, value.trim(), (subtask) {
                                    setDialogState(() {
                                      tempSubtasks.add(subtask);
                                      subtaskController.clear();
                                    });
                                  });
                                }
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              if (subtaskController.text.trim().isNotEmpty) {
                                await _showSubtaskTimerDialog(context, subtaskController.text.trim(), (subtask) {
                                  setDialogState(() {
                                    tempSubtasks.add(subtask);
                                    subtaskController.clear();
                                  });
                                });
                              }
                            },
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Subtasks list
                      if (tempSubtasks.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: tempSubtasks.length,
                            itemBuilder: (context, subtaskIndex) {
                              final subtask = tempSubtasks[subtaskIndex];
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  subtask.isScheduled ? Icons.schedule : Icons.radio_button_unchecked,
                                  color: subtask.isScheduled ? Colors.blue : Colors.grey[400],
                                  size: 20,
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(subtask.task, style: const TextStyle(fontSize: 14)),
                                    if (subtask.isScheduled)
                                      Text(
                                        'Mulai: ${_formatDateTime(subtask.scheduledTime!)}',
                                        style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                                      ),
                                    if (subtask.hasEndTime)
                                      Text(
                                        'Berakhir: ${_formatDateTime(subtask.endTime!)}',
                                        style: TextStyle(fontSize: 10, color: Colors.red[600]),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Hapus Subtask'),
                                        content: Text('Yakin ingin menghapus subtask "${subtask.task}"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Batal'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                            child: const Text('Hapus'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      setDialogState(() {
                                        tempSubtasks.removeAt(subtaskIndex);
                                      });
                                    }
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
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (taskController.text.trim().isNotEmpty) {
                      final newTodo = TodoItem(
                        task: taskController.text.trim(),
                        notes: notesController.text,
                        subtasks: List.from(tempSubtasks),
                        priority: selectedPriority,
                        dueDate: selectedDueDate,
                      );
                      
                      setState(() {
                        _todoItems.add(newTodo);
                      });
                      _saveTodoItems();
                      
                      _fabAnimationController.forward().then((_) {
                        _fabAnimationController.reverse();
                      });
                      
                      Navigator.of(context).pop();
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tugas "${newTodo.task}" berhasil ditambahkan'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Judul tugas tidak boleh kosong'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Dispose controllers after dialog is fully closed to avoid 'used after dispose' during pop animation
      taskController.dispose();
      notesController.dispose();
      subtaskController.dispose();
    });
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
    final hasActiveSubtasks = todoItem.subtasks.any((s) => s.isActive);
    final hasOverdueSubtasks = todoItem.subtasks.any((s) => s.isOverdue);
    
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
      confirmDismiss: (direction) async {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Tugas'),
            content: Text('Yakin ingin menghapus tugas "${todoItem.task}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
        return result ?? false;
      },
      onDismissed: (direction) {
        final removedItem = todoItem;
        // Defer state mutation until after the current frame to avoid build scope issues
        scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
          _removeTodoItem(index);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tugas "${removedItem.task}" dihapus'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: hasOverdueSubtasks 
              ? const BorderSide(color: Colors.red, width: 2)
              : hasActiveSubtasks
                  ? const BorderSide(color: Colors.green, width: 2)
                  : BorderSide.none,
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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todoItem.task,
                    style: TextStyle(
                      fontSize: 16,
                      decoration: todoItem.isCompleted 
                          ? TextDecoration.lineThrough 
                          : TextDecoration.none,
                      color: todoItem.isCompleted 
                          ? Colors.grey[600] 
                          : hasOverdueSubtasks
                              ? Colors.red[700]
                              : Colors.black87,
                      fontWeight: todoItem.isCompleted 
                          ? FontWeight.normal 
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: todoItem.priorityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (hasActiveSubtasks) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle, size: 10, color: Colors.green[700]),
                              const SizedBox(width: 2),
                              Text('AKTIF', style: TextStyle(fontSize: 8, color: Colors.green[700], fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                      if (hasOverdueSubtasks) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning, size: 10, color: Colors.red[700]),
                              const SizedBox(width: 2),
                              Text('TERLAMBAT', style: TextStyle(fontSize: 8, color: Colors.red[700], fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
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
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: todoItem.priorityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Prioritas: ${todoItem.priority}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (todoItem.dueDate != null)
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: todoItem.isOverdue ? Colors.red : Colors.blue[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Deadline: ${todoItem.dueDateString}',
                          style: TextStyle(fontSize: 12, color: todoItem.isOverdue ? Colors.red : Colors.blue[600]),
                        ),
                      ],
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
                      'ðŸ“ ${todoItem.notes.length > 30 ? '${todoItem.notes.substring(0, 30)}...' : todoItem.notes}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              trailing: SizedBox(
                width: 120, // Fixed width to prevent overflow
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (todoItem.subtasks.isNotEmpty || todoItem.notes.isNotEmpty)
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            todoItem.isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.blue,
                            size: 20,
                          ),
                          onPressed: () => _toggleExpanded(index),
                        ),
                      ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                        onPressed: () => _showDetailDialog(todoItem, index),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Hapus Tugas'),
                              content: Text('Yakin ingin menghapus tugas "${todoItem.task}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            _removeTodoItem(index);
                          }
                        },
                      ),
                    ),
                  ],
                ),
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
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: subtask.isOverdue 
                                ? Colors.red[50]
                                : subtask.isActive
                                    ? Colors.green[50]
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: subtask.isOverdue 
                                  ? Colors.red[300]!
                                  : subtask.isActive
                                      ? Colors.green[300]!
                                      : Colors.grey[300]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                            : subtask.isOverdue
                                                ? Colors.red[700]
                                                : Colors.black87,
                                        fontSize: 14,
                                        fontWeight: subtask.isOverdue || subtask.isActive
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (subtask.isActive)
                                    Icon(Icons.play_circle, size: 16, color: Colors.green[600]),
                                  if (subtask.isOverdue)
                                    Icon(Icons.warning, size: 16, color: Colors.red[600]),
                                ],
                              ),
                              if (subtask.isScheduled || subtask.hasEndTime)
                                Padding(
                                  padding: const EdgeInsets.only(left: 40, top: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (subtask.isScheduled)
                                        Text(
                                          'Mulai: ${_formatDateTime(subtask.scheduledTime!)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: subtask.isActive ? Colors.green[600] : Colors.blue[600],
                                          ),
                                        ),
                                      if (subtask.hasEndTime)
                                        Text(
                                          subtask.isOverdue 
                                              ? 'TERLAMBAT!'
                                              : subtask.remainingTime != null
                                                  ? 'Sisa: ${_formatDuration(subtask.remainingTime!)}'
                                                  : 'Berakhir: ${_formatDateTime(subtask.endTime!)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: subtask.isOverdue 
                                                ? Colors.red[600] 
                                                : Colors.orange[600],
                                            fontWeight: subtask.isOverdue 
                                                ? FontWeight.bold 
                                                : FontWeight.normal,
                                          ),
                                        ),
                                    ],
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}h ${duration.inHours.remainder(24)}j';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}j ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  int get _completedCount => _todoItems.where((item) => item.isCompleted).length;
  int get _totalCount => _todoItems.length;
  int get _activeSubtasksCount => _todoItems.expand((item) => item.subtasks).where((subtask) => subtask.isActive).length;
  int get _overdueSubtasksCount => _todoItems.expand((item) => item.subtasks).where((subtask) => subtask.isOverdue).length;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      body: _tabIndex == 0
          ? Column(
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
                        if (_activeSubtasksCount > 0 || _overdueSubtasksCount > 0)
                          Text(
                            'Subtask: ${_activeSubtasksCount > 0 ? '$_activeSubtasksCount aktif' : ''}${_activeSubtasksCount > 0 && _overdueSubtasksCount > 0 ? ' â€¢ ' : ''}${_overdueSubtasksCount > 0 ? '$_overdueSubtasksCount terlambat' : ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
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
            )
          : TodoFilterView<TodoItem>(
              items: _todoItems,
              getPriority: (t) => t.priority,
              itemBuilder: (origIndex, item) => _buildTodoItem(item, origIndex),
            ),
      floatingActionButton: _tabIndex == 0
          ? ScaleTransition(
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
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Daftar'),
          BottomNavigationBarItem(icon: Icon(Icons.filter_alt), label: 'Filter'),
        ],
      ),
    );
  }
}