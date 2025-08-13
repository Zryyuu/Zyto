import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:async';

// Tambahkan ke pubspec.yaml:
// dependencies:
//   flutter_local_notifications: ^17.2.2
//   timezone: ^0.9.4

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi Task & Budget App',
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
      home: const MainScreen(),
    );
  }
}

// Savings Plan Models
class SavingsPlan {
  String id;
  String name;
  double targetAmount;
  double currentAmount;
  DateTime targetDate;
  String description;
  IconData icon;
  Color color;
  bool isCompleted;

  SavingsPlan({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.targetDate,
    this.description = '',
    this.icon = Icons.savings,
    this.color = Colors.blue,
    this.isCompleted = false,
  });

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
  double get remaining => targetAmount - currentAmount;
  bool get isOverdue => DateTime.now().isAfter(targetDate) && !isCompleted;
  
  int get daysRemaining {
    if (isCompleted) return 0;
    final now = DateTime.now();
    return targetDate.difference(now).inDays;
  }

  double get dailySavingsNeeded {
    if (isCompleted || daysRemaining <= 0) return 0;
    return remaining / daysRemaining;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate.toIso8601String(),
      'description': description,
      'icon': icon.codePoint,
      'color': color.toARGB32(),
      'isCompleted': isCompleted,
    };
  }

  factory SavingsPlan.fromJson(Map<String, dynamic> json) {
    return SavingsPlan(
      id: json['id'],
      name: json['name'],
      targetAmount: json['targetAmount'].toDouble(),
      currentAmount: json['currentAmount'].toDouble(),
      targetDate: DateTime.parse(json['targetDate']),
      description: json['description'] ?? '',
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      color: Color(json['color']),
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

class SavingsTransaction {
  String id;
  String planId;
  double amount;
  DateTime date;
  String notes;

  SavingsTransaction({
    required this.id,
    required this.planId,
    required this.amount,
    required this.date,
    this.notes = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planId': planId,
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory SavingsTransaction.fromJson(Map<String, dynamic> json) {
    return SavingsTransaction(
      id: json['id'],
      planId: json['planId'],
      amount: json['amount'].toDouble(),
      date: DateTime.parse(json['date']),
      notes: json['notes'] ?? '',
    );
  }
}

// Transaction Models (existing)
class Transaction {
  String id;
  String title;
  double amount;
  String category;
  DateTime date;
  bool isIncome;
  String notes;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.isIncome = false,
    this.notes = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'isIncome': isIncome,
      'notes': notes,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      title: json['title'],
      amount: json['amount'].toDouble(),
      category: json['category'],
      date: DateTime.parse(json['date']),
      isIncome: json['isIncome'],
      notes: json['notes'] ?? '',
    );
  }
}

// Todo Models (existing)
class TodoSubtask {
  String task;
  bool isCompleted;
  DateTime? scheduledTime;
  DateTime? endTime;

  TodoSubtask({
    required this.task,
    this.isCompleted = false,
    this.scheduledTime,
    this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'task': task,
      'isCompleted': isCompleted,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  factory TodoSubtask.fromJson(Map<String, dynamic> json) {
    return TodoSubtask(
      task: json['task'],
      isCompleted: json['isCompleted'],
      scheduledTime: json['scheduledTime'] != null 
          ? DateTime.parse(json['scheduledTime']) 
          : null,
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime']) 
          : null,
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
}

class TodoItem {
  String task;
  bool isCompleted;
  DateTime createdAt;
  String notes;
  List<TodoSubtask> subtasks;
  bool isExpanded;
  String priority;
  List<String> days;

  TodoItem({
    required this.task,
    this.isCompleted = false,
    DateTime? createdAt,
    this.notes = '',
    List<TodoSubtask>? subtasks,
    this.isExpanded = false,
    this.priority = 'Sedang',
    List<String>? days,
  }) : createdAt = createdAt ?? DateTime.now(),
       subtasks = subtasks ?? [],
       days = days ?? [];

  Map<String, dynamic> toJson() {
    return {
      'task': task,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
      'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
      'isExpanded': isExpanded,
      'priority': priority,
      'days': days,
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
      days: (json['days'] as List<dynamic>?)?.cast<String>() ?? [],
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
  
  String get daysString {
    if (days.isEmpty) return 'Semua hari';
    return days.join(', ');
  }
}

// Main Screen with TabBar
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Task & Budget Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.task_alt),
              text: 'Tugas',
            ),
            Tab(
              icon: Icon(Icons.account_balance_wallet),
              text: 'Keuangan',
            ),
          ],
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Theme.of(context).primaryColor,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TodoListScreen(),
          BudgetScreen(),
        ],
      ),
    );
  }
}

// Budget Screen - Updated with Savings Plans
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> with TickerProviderStateMixin {
  final List<Transaction> _transactions = [];
  final List<SavingsPlan> _savingsPlans = [];
  final List<SavingsTransaction> _savingsTransactions = [];
  late AnimationController _fabAnimationController;
  bool _isLoading = true;
  int _selectedIndex = 0; // 0: Transactions, 1: Savings Plans

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadBudgetData();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadBudgetData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Load transactions
      List<String>? transactionStrings = prefs.getStringList('budget_transactions');
      if (transactionStrings != null) {
        _transactions.clear();
        for (String transactionString in transactionStrings) {
          Map<String, dynamic> transactionMap = json.decode(transactionString);
          _transactions.add(Transaction.fromJson(transactionMap));
        }
      }
      
      // Load savings plans
      List<String>? savingsStrings = prefs.getStringList('savings_plans');
      if (savingsStrings != null) {
        _savingsPlans.clear();
        for (String savingsString in savingsStrings) {
          Map<String, dynamic> savingsMap = json.decode(savingsString);
          _savingsPlans.add(SavingsPlan.fromJson(savingsMap));
        }
      }
      
      // Load savings transactions
      List<String>? savingsTransactionStrings = prefs.getStringList('savings_transactions');
      if (savingsTransactionStrings != null) {
        _savingsTransactions.clear();
        for (String savingsTransactionString in savingsTransactionStrings) {
          Map<String, dynamic> savingsTransactionMap = json.decode(savingsTransactionString);
          _savingsTransactions.add(SavingsTransaction.fromJson(savingsTransactionMap));
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveBudgetData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Save transactions
    List<String> transactionStrings = _transactions
        .map((transaction) => json.encode(transaction.toJson()))
        .toList();
    await prefs.setStringList('budget_transactions', transactionStrings);
    
    // Save savings plans
    List<String> savingsStrings = _savingsPlans
        .map((plan) => json.encode(plan.toJson()))
        .toList();
    await prefs.setStringList('savings_plans', savingsStrings);
    
    // Save savings transactions
    List<String> savingsTransactionStrings = _savingsTransactions
        .map((transaction) => json.encode(transaction.toJson()))
        .toList();
    await prefs.setStringList('savings_transactions', savingsTransactionStrings);
  }

  void _addTransaction(Transaction transaction) {
    setState(() {
      _transactions.add(transaction);
    });
    _saveBudgetData();
  }

  void _removeTransaction(int index) {
    setState(() {
      _transactions.removeAt(index);
    });
    _saveBudgetData();
  }

  void _addSavingsPlan(SavingsPlan plan) {
    setState(() {
      _savingsPlans.add(plan);
    });
    _saveBudgetData();
  }

  void _removeSavingsPlan(int index) {
    final planId = _savingsPlans[index].id;
    setState(() {
      _savingsPlans.removeAt(index);
      _savingsTransactions.removeWhere((t) => t.planId == planId);
    });
    _saveBudgetData();
  }

  void _addToSavings(String planId, double amount, String notes) {
    final transaction = SavingsTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      planId: planId,
      amount: amount,
      date: DateTime.now(),
      notes: notes,
    );

    setState(() {
      _savingsTransactions.add(transaction);
      // Update plan current amount
      for (var plan in _savingsPlans) {
        if (plan.id == planId) {
          plan.currentAmount += amount;
          if (plan.currentAmount >= plan.targetAmount) {
            plan.isCompleted = true;
          }
          break;
        }
      }
    });
    _saveBudgetData();
  }

  double get totalIncome => _transactions
      .where((t) => t.isIncome)
      .fold(0, (sum, t) => sum + t.amount);
  double get totalExpense => _transactions
      .where((t) => !t.isIncome)
      .fold(0, (sum, t) => sum + t.amount);
  double get balance => totalIncome - totalExpense;
  double get totalSavings => _savingsPlans.fold(0, (sum, plan) => sum + plan.currentAmount);

  void _showAddTransactionDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    final TextEditingController categoryController = TextEditingController();
    bool isIncome = false;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Tambah Transaksi'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Income/Expense Toggle
                      Row(
                        children: [
                          Expanded(
                            child: FilterChip(
                              label: const Text('Pengeluaran'),
                              selected: !isIncome,
                              onSelected: (selected) {
                                setDialogState(() {
                                  isIncome = !selected;
                                });
                              },
                              selectedColor: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilterChip(
                              label: const Text('Pemasukan'),
                              selected: isIncome,
                              onSelected: (selected) {
                                setDialogState(() {
                                  isIncome = selected;
                                });
                              },
                              selectedColor: Colors.green.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Title
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Judul Transaksi',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      
                      // Amount
                      TextField(
                        controller: amountController,
                        decoration: const InputDecoration(
                          labelText: 'Jumlah',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      
                      // Category
                      TextField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Date
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setDialogState(() {
                              selectedDate = date;
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
                              Text(_formatDate(selectedDate)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Notes
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty &&
                        amountController.text.trim().isNotEmpty &&
                        categoryController.text.trim().isNotEmpty) {
                      final amount = double.tryParse(amountController.text.trim());
                      if (amount != null && amount > 0) {
                        final transaction = Transaction(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text.trim(),
                          amount: amount,
                          category: categoryController.text.trim(),
                          date: selectedDate,
                          isIncome: isIncome,
                          notes: notesController.text.trim(),
                        );
                        
                        _addTransaction(transaction);
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Transaksi "${transaction.title}" berhasil ditambahkan'),
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
    );
  }

  void _showAddSavingsPlanDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController targetController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    IconData selectedIcon = Icons.savings;
    Color selectedColor = Colors.blue;

    final List<IconData> icons = [
      Icons.savings, Icons.home, Icons.directions_car, Icons.flight,
      Icons.phone_android, Icons.laptop, Icons.school, Icons.medical_services,
    ];

    final List<Color> colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.red, Colors.teal, Colors.indigo, Colors.pink,
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Tambah Rencana Menabung'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Rencana',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: targetController,
                      decoration: const InputDecoration(
                        labelText: 'Target Jumlah',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    
                    // Target Date
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            selectedDate = date;
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
                            Text('Target: ${_formatDate(selectedDate)}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi (opsional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    
                    // Icon selection
                    const Text('Pilih Icon:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: icons.map((icon) {
                        final isSelected = icon == selectedIcon;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = icon;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? selectedColor.withValues(alpha: 0.3) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? selectedColor : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Icon(icon, color: isSelected ? selectedColor : Colors.grey[600]),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Color selection
                    const Text('Pilih Warna:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colors.map((color) {
                        final isSelected = color == selectedColor;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty &&
                        targetController.text.trim().isNotEmpty) {
                      final target = double.tryParse(targetController.text.trim());
                      if (target != null && target > 0) {
                        final plan = SavingsPlan(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameController.text.trim(),
                          targetAmount: target,
                          targetDate: selectedDate,
                          description: descController.text.trim(),
                          icon: selectedIcon,
                          color: selectedColor,
                        );
                        
                        _addSavingsPlan(plan);
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Rencana "${plan.name}" berhasil ditambahkan'),
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
    );
  }

  void _showAddToSavingsDialog(SavingsPlan plan) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Tambah ke "${plan.name}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Menabung',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (amountController.text.trim().isNotEmpty) {
                  final amount = double.tryParse(amountController.text.trim());
                  if (amount != null && amount > 0) {
                    _addToSavings(plan.id, amount, notesController.text.trim());
                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Berhasil menabung ${_formatCurrency(amount)} ke "${plan.name}"'),
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
  }

  Widget _buildTransactions() {
    final sortedTransactions = List<Transaction>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    
    return Column(
      children: [
        // Balance Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text(
                'Saldo Saat Ini',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.arrow_upward, color: Colors.green, size: 24),
                      Text(
                        _formatCurrency(totalIncome),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Text(
                        'Pemasukan',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.arrow_downward, color: Colors.red, size: 24),
                      Text(
                        _formatCurrency(totalExpense),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Text(
                        'Pengeluaran',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.savings, color: Colors.amber, size: 24),
                      Text(
                        _formatCurrency(totalSavings),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Text(
                        'Total Tabungan',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Transactions Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Riwayat Transaksi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _showAddTransactionDialog,
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: sortedTransactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada transaksi',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap tombol + untuk menambah transaksi baru',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = sortedTransactions[index];
                    final originalIndex = _transactions.indexOf(transaction);
                    return _buildTransactionCard(transaction, originalIndex);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSavingsPlans() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rencana Menabung',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _showAddSavingsPlanDialog,
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
              ),
            ],
          ),
        ),
        
        if (_savingsPlans.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada rencana menabung',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap tombol + untuk membuat rencana baru',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _savingsPlans.length,
              itemBuilder: (context, index) {
                return _buildSavingsPlanCard(_savingsPlans[index], index);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSavingsPlanCard(SavingsPlan plan, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: plan.isOverdue && !plan.isCompleted
            ? const BorderSide(color: Colors.red, width: 2)
            : plan.isCompleted
                ? const BorderSide(color: Colors.green, width: 2)
                : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: plan.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(plan.icon, color: plan.color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (plan.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'SELESAI',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (plan.isOverdue && !plan.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'TERLAMBAT',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${_formatCurrency(plan.currentAmount)} / ${_formatCurrency(plan.targetAmount)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (plan.description.isNotEmpty)
                        Text(
                          plan.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${plan.progress.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: plan.isCompleted ? Colors.green : plan.color,
                      ),
                    ),
                    Text(
                      _formatCurrency(plan.remaining),
                      style: TextStyle(
                        fontSize: 12,
                        color: plan.remaining <= 0 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Progress Bar
            LinearProgressIndicator(
              value: plan.progress / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                plan.isCompleted ? Colors.green : plan.color,
              ),
            ),
            const SizedBox(height: 12),
            
            // Date and daily savings info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Target: ${_formatDate(plan.targetDate)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    if (!plan.isCompleted && plan.daysRemaining > 0)
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${plan.daysRemaining} hari lagi',
                            style: TextStyle(
                              fontSize: 12, 
                              color: plan.isOverdue ? Colors.red : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (!plan.isCompleted && plan.dailySavingsNeeded > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Per hari:',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      Text(
                        _formatCurrency(plan.dailySavingsNeeded),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: plan.color,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                if (!plan.isCompleted)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddToSavingsDialog(plan),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: plan.color,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showSavingsPlanDetail(plan),
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Detail',
                ),
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Hapus Rencana'),
                        content: Text('Yakin ingin menghapus rencana "${plan.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _removeSavingsPlan(index);
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
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Hapus',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSavingsPlanDetail(SavingsPlan plan) {
    final planTransactions = _savingsTransactions
        .where((t) => t.planId == plan.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(plan.icon, color: plan.color),
              const SizedBox(width: 8),
              Expanded(child: Text(plan.name)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: plan.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Target: ${_formatCurrency(plan.targetAmount)}'),
                          Text('${plan.progress.toStringAsFixed(1)}%'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Terkumpul: ${_formatCurrency(plan.currentAmount)}'),
                      Text('Sisa: ${_formatCurrency(plan.remaining)}'),
                      if (!plan.isCompleted && plan.daysRemaining > 0)
                        Text('Per hari: ${_formatCurrency(plan.dailySavingsNeeded)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Transaction History
                const Text('Riwayat Menabung:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                if (planTransactions.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('Belum ada riwayat menabung'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: planTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = planTransactions[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.add, color: Colors.green, size: 20),
                          title: Text(_formatCurrency(transaction.amount)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_formatDate(transaction.date)),
                              if (transaction.notes.isNotEmpty)
                                Text(
                                  transaction.notes,
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionCard(Transaction transaction, int index) {
    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 24),
      ),
      onDismissed: (direction) {
        _removeTransaction(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaksi "${transaction.title}" dihapus'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: transaction.isIncome 
                  ? Colors.green.withValues(alpha: 0.2) 
                  : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              transaction.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: transaction.isIncome ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          title: Text(
            transaction.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.category,
                style: TextStyle(color: Colors.grey[600]),
              ),
              Text(
                _formatDate(transaction.date),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              if (transaction.notes.isNotEmpty)
                Text(
                  transaction.notes,
                  style: TextStyle(fontSize: 12, color: Colors.blue[600], fontStyle: FontStyle.italic),
                ),
            ],
          ),
          trailing: Text(
            '${transaction.isIncome ? '+' : '-'} ${_formatCurrency(transaction.amount)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: transaction.isIncome ? Colors.green : Colors.red,
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}K';
    } else {
      return 'Rp ${amount.toStringAsFixed(0)}';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildTransactions(),
          _buildSavingsPlans(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Transaksi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.savings),
            label: 'Rencana Menabung',
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
          onPressed: _selectedIndex == 0 ? _showAddTransactionDialog : _showAddSavingsPlanDialog,
          icon: const Icon(Icons.add),
          label: Text(_selectedIndex == 0 ? 'Tambah Transaksi' : 'Tambah Rencana'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

// Todo List Screen (existing functionality)
class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen>
    with TickerProviderStateMixin {
  final List<TodoItem> _todoItems = [];
  late AnimationController _fabAnimationController;
  bool _isLoading = true;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadTodoItems();
    _startNotificationTimer();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndSendNotifications();
    });
  }

  void _checkAndSendNotifications() {
    final now = DateTime.now();
    
    for (var todoItem in _todoItems) {
      for (var subtask in todoItem.subtasks) {
        if (subtask.scheduledTime != null && !subtask.isCompleted) {
          final startDiff = subtask.scheduledTime!.difference(now).inMinutes;
          if (startDiff == 10 || startDiff == 5) {
            _showNotification(
              'Subtask akan dimulai',
              'Subtask "${subtask.task}" akan dimulai dalam $startDiff menit',
              subtask.hashCode,
            );
          }
        }
        
        if (subtask.endTime != null && !subtask.isCompleted) {
          final endDiff = subtask.endTime!.difference(now).inMinutes;
          if (endDiff == 10 || endDiff == 5) {
            _showNotification(
              'Subtask akan berakhir',
              'Subtask "${subtask.task}" akan berakhir dalam $endDiff menit',
              subtask.hashCode + 1000,
            );
          }
        }
      }
    }
  }

  Future<void> _showNotification(String title, String body, int id) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'todo_timer_channel',
      'Todo Timer Notifications',
      channelDescription: 'Notifications for todo timer reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> _loadTodoItems() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String>? todoStrings = prefs.getStringList('todo_items');
      setState(() {
        _todoItems.clear();
        for (String todoString in todoStrings ?? []) {
          Map<String, dynamic> todoMap = json.decode(todoString);
          _todoItems.add(TodoItem.fromJson(todoMap));
        }
        _isLoading = false;
      });
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

  void _addSubtask(int todoIndex, String subtaskText, {DateTime? scheduledTime, DateTime? endTime}) {
    if (subtaskText.trim().isNotEmpty) {
      setState(() {
        _todoItems[todoIndex].subtasks.add(
          TodoSubtask(
            task: subtaskText.trim(),
            scheduledTime: scheduledTime,
            endTime: endTime,
          )
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

  void _showAddDialog() {
    final TextEditingController taskController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    final TextEditingController subtaskController = TextEditingController();
    final List<TodoSubtask> tempSubtasks = [];
    String selectedPriority = 'Sedang';
    List<String> selectedDays = [];
    
    final List<String> weekDays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
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
                        value: selectedPriority,
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
                      
                      // Days Section
                      const Text('Hari (opsional):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: weekDays.map((day) {
                          final isSelected = selectedDays.contains(day);
                          return FilterChip(
                            label: Text(day),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedDays.add(day);
                                } else {
                                  selectedDays.remove(day);
                                }
                              });
                            },
                            selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          );
                        }).toList(),
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
                                  onPressed: () {
                                    setDialogState(() {
                                      tempSubtasks.removeAt(subtaskIndex);
                                    });
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
                    taskController.dispose();
                    notesController.dispose();
                    subtaskController.dispose();
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
                        days: List.from(selectedDays),
                      );
                      
                      setState(() {
                        _todoItems.add(newTodo);
                      });
                      _saveTodoItems();
                      
                      _fabAnimationController.forward().then((_) {
                        _fabAnimationController.reverse();
                      });
                      
                      taskController.dispose();
                      notesController.dispose();
                      subtaskController.dispose();
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
    );
  }

  Future<void> _showSubtaskTimerDialog(BuildContext context, String taskText, Function(TodoSubtask) onAdd) async {
    DateTime? scheduledTime;
    DateTime? endTime;
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set Timer untuk Subtask'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subtask: $taskText', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final dateTime = await _selectDateTime(context, initialDate: scheduledTime);
                      if (dateTime != null) {
                        setDialogState(() {
                          scheduledTime = dateTime;
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      scheduledTime != null 
                          ? 'Mulai: ${_formatDateTime(scheduledTime!)}'
                          : 'Set Waktu Mulai (Opsional)',
                    ),
                  ),
                  if (scheduledTime != null) ...[
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final dateTime = await _selectDateTime(
                          context, 
                          initialDate: endTime ?? scheduledTime!.add(const Duration(hours: 1))
                        );
                        if (dateTime != null && dateTime.isAfter(scheduledTime!)) {
                          setDialogState(() {
                            endTime = dateTime;
                          });
                        }
                      },
                      icon: const Icon(Icons.timer_off),
                      label: Text(
                        endTime != null 
                            ? 'Berakhir: ${_formatDateTime(endTime!)}'
                            : 'Set Waktu Berakhir (Opsional)',
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onAdd(TodoSubtask(
                      task: taskText,
                      scheduledTime: scheduledTime,
                      endTime: endTime,
                    ));
                    Navigator.pop(context);
                  },
                  child: const Text('Tambah'),
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
                height: 500,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Priority and Days info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                const SizedBox(width: 8),
                                Text('Prioritas: ${todoItem.priority}'),
                              ],
                            ),
                            if (todoItem.days.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text('Hari: ${todoItem.daysString}'),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
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
                              onSubmitted: (value) async {
                                if (value.trim().isNotEmpty) {
                                  await _showSubtaskTimerDialog(context, value.trim(), (subtask) {
                                    _addSubtask(index, subtask.task, 
                                        scheduledTime: subtask.scheduledTime, 
                                        endTime: subtask.endTime);
                                    subtaskController.clear();
                                    setDialogState(() {});
                                  });
                                }
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              if (subtaskController.text.trim().isNotEmpty) {
                                await _showSubtaskTimerDialog(context, subtaskController.text.trim(), (subtask) {
                                  _addSubtask(index, subtask.task, 
                                      scheduledTime: subtask.scheduledTime, 
                                      endTime: subtask.endTime);
                                  subtaskController.clear();
                                  setDialogState(() {});
                                });
                              }
                            },
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Subtasks list
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: todoItem.subtasks.length,
                          itemBuilder: (context, subtaskIndex) {
                            final subtask = todoItem.subtasks[subtaskIndex];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                dense: true,
                                leading: Checkbox(
                                  value: subtask.isCompleted,
                                  onChanged: (value) {
                                    _toggleSubtask(index, subtaskIndex);
                                    setDialogState(() {});
                                  },
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
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
                                    if (subtask.isScheduled)
                                      Row(
                                        children: [
                                          Icon(
                                            subtask.isActive ? Icons.play_circle : Icons.schedule,
                                            size: 12,
                                            color: subtask.isActive ? Colors.green : Colors.blue,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Mulai: ${_formatDateTime(subtask.scheduledTime!)}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: subtask.isActive ? Colors.green : Colors.blue[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (subtask.hasEndTime)
                                      Row(
                                        children: [
                                          Icon(
                                            subtask.isOverdue ? Icons.warning : Icons.timer_off,
                                            size: 12,
                                            color: subtask.isOverdue ? Colors.red : Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            subtask.isOverdue 
                                                ? 'TERLAMBAT!'
                                                : subtask.remainingTime != null
                                                    ? 'Sisa: ${_formatDuration(subtask.remainingTime!)}'
                                                    : 'Berakhir: ${_formatDateTime(subtask.endTime!)}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: subtask.isOverdue 
                                                  ? Colors.red 
                                                  : Colors.orange[600],
                                              fontWeight: subtask.isOverdue 
                                                  ? FontWeight.bold 
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () {
                                    _removeSubtask(index, subtaskIndex);
                                    setDialogState(() {});
                                  },
                                ),
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
      onDismissed: (direction) {
        final removedItem = todoItem;
        _removeTodoItem(index);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tugas "${removedItem.task}" dihapus'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
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
              title: Row(
                children: [
                  Expanded(
                    child: Text(
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
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: todoItem.priorityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (hasActiveSubtasks)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle, size: 12, color: Colors.green[700]),
                          const SizedBox(width: 2),
                          Text('AKTIF', style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  if (hasOverdueSubtasks)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning, size: 12, color: Colors.red[700]),
                          const SizedBox(width: 2),
                          Text('TERLAMBAT', style: TextStyle(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.bold)),
                        ],
                      ),
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
                  if (todoItem.days.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.blue[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Hari: ${todoItem.daysString}',
                          style: TextStyle(fontSize: 12, color: Colors.blue[600]),
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
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
                  if (_activeSubtasksCount > 0 || _overdueSubtasksCount > 0)
                    Text(
                      'Subtask: ${_activeSubtasksCount > 0 ? '$_activeSubtasksCount aktif' : ''}${_activeSubtasksCount > 0 && _overdueSubtasksCount > 0 ? ' • ' : ''}${_overdueSubtasksCount > 0 ? '$_overdueSubtasksCount terlambat' : ''}',
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