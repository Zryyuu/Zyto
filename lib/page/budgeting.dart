import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' as scheduler;
import 'dart:async';
import '../services/data_service.dart';

// Color utilities used in this file
extension ColorX on Color {
  // Darken the color by [amount] (0..1)
  Color darken([double amount = 0.15]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    double lightness = hsl.lightness - amount;
    if (lightness < 0) lightness = 0;
    if (lightness > 1) lightness = 1;
    return hsl.withLightness(lightness).toColor();
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
      icon: Icons.savings,
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

// Transaction Models
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

// Budget Screen - Updated with Savings Plans
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  List<Transaction> _transactions = [];
  List<SavingsPlan> _savingsPlans = [];
  List<SavingsTransaction> _savingsTransactions = [];
  late AnimationController _fabAnimationController;
  bool _isLoading = true;
  int _selectedIndex = 0; // 0: Transaksi, 1: Rencana Menabung, 2: Rekap
  final DataService _dataService = DataService.instance;

  // Rekap state
  DateTime _recapMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // ----- Monthly Recap helpers (moved from model) -----
  void _changeRecapMonth(int diffMonths) {
    setState(() {
      _recapMonth = DateTime(
        _recapMonth.year,
        _recapMonth.month + diffMonths,
      );
    });
  }

  bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  String _formatMonthYear(DateTime d) {
    const months = [
      'Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  // Month-Year Picker dialog for quick jump
  void _showMonthYearPicker() {
    final now = DateTime.now();
    final years = <int>{now.year}
      ..addAll(_transactions.map((t) => t.date.year))
      ..addAll(_savingsTransactions.map((t) => t.date.year))
      ..addAll(_savingsPlans.map((p) => p.targetDate.year));
    final sortedYears = years.toList()..sort();
    if (!sortedYears.contains(now.year)) sortedYears.add(now.year);
    sortedYears.sort();

    int tempYear = _recapMonth.year;
    int tempMonth = _recapMonth.month; // 1..12

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Pilih Bulan & Tahun'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Year selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => setLocal(() => tempYear--),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      DropdownButton<int>(
                        value: tempYear,
                        onChanged: (v) => setLocal(() => tempYear = v ?? tempYear),
                        items: sortedYears
                            .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                            .toList(),
                      ),
                      IconButton(
                        onPressed: () => setLocal(() => tempYear++),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Months grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.6,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      const months = [
                        'Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'
                      ];
                      final m = index + 1;
                      final selected = m == tempMonth;
                      final color = Theme.of(context).primaryColor;
                      return InkWell(
                        onTap: () => setLocal(() => tempMonth = m),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? color.withValues(alpha: 0.15) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: selected ? color : Colors.grey[300]!),
                          ),
                          child: Text(
                            months[index],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: selected ? color : Colors.grey[800],
                            ),
                          ),
                        ),
                      );
                    },
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
                    setState(() {
                      _recapMonth = DateTime(tempYear, tempMonth);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Pilih'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMonthlyRecap() {
    final monthTx = _transactions.where((t) => _isSameMonth(t.date, _recapMonth)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    double income = 0, expense = 0;
    final Map<String, double> byCategory = {};
    for (final t in monthTx) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount * (t.isIncome ? 1 : -1);
    }
    final topCategories = byCategory.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return Column(
      children: [
        // Header with month selector
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _changeRecapMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: _showMonthYearPicker,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMonthYear(_recapMonth),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changeRecapMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),

        // Summary cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 400;
              if (isNarrow) {
                return Column(
                  children: [
                    _summaryTile(
                      title: 'Pemasukan',
                      value: _formatCurrency(income),
                      color: Colors.green,
                      icon: Icons.trending_up,
                    ),
                    const SizedBox(height: 12),
                    _summaryTile(
                      title: 'Pengeluaran',
                      value: _formatCurrency(expense),
                      color: Colors.red,
                      icon: Icons.trending_down,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _summaryTile(
                      title: 'Pemasukan',
                      value: _formatCurrency(income),
                      color: Colors.green,
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryTile(
                      title: 'Pengeluaran',
                      value: _formatCurrency(expense),
                      color: Colors.red,
                      icon: Icons.trending_down,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        const SizedBox(height: 16),
        // Category breakdown and transaction list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const Text('Ringkasan Kategori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (topCategories.isEmpty)
                Text('Belum ada data pada bulan ini', style: TextStyle(color: Colors.grey[600]))
              else
                ...topCategories.take(6).map((e) => ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Icon(
                        e.value >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        color: e.value >= 0 ? Colors.green : Colors.red,
                      ),
                      title: Text(e.key),
                      trailing: Text(
                        _formatCurrency(e.value.abs()),
                        style: TextStyle(
                          color: e.value >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )),
              const SizedBox(height: 16),
              const Text('Transaksi Bulan Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (monthTx.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text('Tidak ada transaksi', style: TextStyle(color: Colors.grey[600])),
                )
              else
                ...monthTx.map((t) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (t.isIncome ? Colors.green : Colors.red).withValues(alpha: 0.15),
                          child: Icon(t.isIncome ? Icons.add : Icons.remove, color: t.isIncome ? Colors.green : Colors.red),
                        ),
                        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_formatDate(t.date)),
                        trailing: Text(
                          '${t.isIncome ? '+' : '-'} ${_formatCurrency(t.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: t.isIncome ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryTile({required String title, required String value, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color.darken())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

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
      final transactions = await _dataService.loadBudgetTransactions();
      final savingsPlans = await _dataService.loadSavingsPlans();
      final savingsTransactions = await _dataService.loadSavingsTransactions();
      
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _savingsPlans = savingsPlans;
          _savingsTransactions = savingsTransactions;
          _isLoading = false; // Set loading to false after data is loaded
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false; // Set loading to false even on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading budget data: $e')),
        );
      }
    }
  }

  Future<void> _saveBudgetData() async {
    try {
      // Save sequentially to avoid race conditions
      await _dataService.saveBudgetTransactions(_transactions);
      await _dataService.saveSavingsPlans(_savingsPlans);
      await _dataService.saveSavingsTransactions(_savingsTransactions);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving budget data: $e')),
        );
      }
    }
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
    bool isIncome = false;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: const Text('Tambah Transaksi'),
              content: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
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
                        amountController.text.trim().isNotEmpty) {
                      final amount = double.tryParse(amountController.text.trim());
                      if (amount != null && amount > 0) {
                        final transaction = Transaction(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text.trim(),
                          amount: amount,
                          category: isIncome ? 'Pemasukan' : 'Pengeluaran',
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


    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: const Text('Tambah Rencana Menabung'),
              content: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Nama Rencana',
                          hintText: 'Masukkan nama rencana',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          isDense: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text('Tambah ke "${plan.name}"'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
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
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress percentage
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: plan.isCompleted ? Colors.green : plan.color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${plan.progress.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Remaining amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Sisa:',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatCurrency(plan.remaining),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: plan.remaining <= 0 ? Colors.green : Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      // Daily savings needed
                      if (!plan.isCompleted && plan.dailySavingsNeeded > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 1,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Per hari:',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
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
                    ],
                  ),
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
                    color: plan.color.withValues(alpha: 0.2),
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
                          leading: const Icon(Icons.add, color: Colors.green, size: 20),
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
      confirmDismiss: (direction) async {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Transaksi'),
            content: Text('Yakin ingin menghapus transaksi "${transaction.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
        return result ?? false;
      },
      onDismissed: (direction) {
        final removed = transaction;
        // Defer state mutation until after current frame to avoid build scope issues
        scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
          _removeTransaction(index);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Transaksi "${removed.title}" dihapus'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Riwayat Transaksi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rencana Menabung',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildTransactions(),
          _buildSavingsPlans(),
          _buildMonthlyRecap(),
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
            icon: Icon(Icons.list_alt),
            label: 'Transaksi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.savings),
            label: 'Rencana',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Rekap',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 2
          ? null
          : ScaleTransition(
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