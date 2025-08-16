import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import '../page/todolist.dart';
import '../page/budgeting.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Cache for preventing repeated queries
  static final Map<String, dynamic> _cache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  bool get _isCacheValid {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheValidDuration;
  }


  // TodoList Methods
  Future<void> saveTodoItems(List<TodoItem> todoItems) async {
    if (_userId == null) return;

    try {
      final batch = _firestore.batch();
      final userTodosRef = _firestore.collection('users').doc(_userId).collection('todos');

      // Delete all existing todos first
      final existingTodos = await userTodosRef.get();
      for (var doc in existingTodos.docs) {
        batch.delete(doc.reference);
      }

      // Add new todos
      for (var todo in todoItems) {
        final docRef = userTodosRef.doc();
        batch.set(docRef, {
          ...todo.toJson(),
          'id': docRef.id,
          'userId': _userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      
      // Clear cache after saving to ensure fresh data on next load
      _cache.remove('todos_$_userId');
    } catch (e) {
      throw Exception('Error saving todo items: $e');
    }
  }

  Future<List<TodoItem>> loadTodoItems() async {
    if (_userId == null) return [];

    // Check cache first
    final cacheKey = 'todos_$_userId';
    if (_isCacheValid && _cache.containsKey(cacheKey)) {
      return List<TodoItem>.from(_cache[cacheKey]);
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('todos')
          .get();

      final todoItems = snapshot.docs.map((doc) {
        final data = doc.data();
        return TodoItem.fromJson(data);
      }).toList();

      // Sort in memory instead of Firestore to improve performance
      todoItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Cache the results
      _cache[cacheKey] = todoItems;
      _lastCacheUpdate = DateTime.now();

      return todoItems;
    } catch (e) {
      // Error loading todo items: $e
      return [];
    }
  }

  Stream<List<TodoItem>> getTodoItemsStream() {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('todos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TodoItem.fromJson(data);
      }).toList();
    });
  }

  // Budget Methods
  Future<void> saveBudgetTransactions(List<Transaction> transactions) async {
    if (_userId == null) return;

    try {
      final batch = _firestore.batch();
      final userTransactionsRef = _firestore.collection('users').doc(_userId).collection('transactions');

      // Delete all existing transactions first
      final existingTransactions = await userTransactionsRef.get();
      for (var doc in existingTransactions.docs) {
        batch.delete(doc.reference);
      }

      // Add new transactions
      for (var transaction in transactions) {
        final docRef = userTransactionsRef.doc();
        batch.set(docRef, {
          ...transaction.toJson(),
          'id': docRef.id,
          'userId': _userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      
      // Clear cache after saving to ensure fresh data on next load
      _cache.remove('transactions_$_userId');
    } catch (e) {
      throw Exception('Error saving transactions: $e');
    }
  }

  Future<List<Transaction>> loadBudgetTransactions() async {
    if (_userId == null) return [];

    // Check cache first
    final cacheKey = 'transactions_$_userId';
    if (_isCacheValid && _cache.containsKey(cacheKey)) {
      return List<Transaction>.from(_cache[cacheKey]);
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('transactions')
          .get();

      final transactions = snapshot.docs.map((doc) {
        final data = doc.data();
        return Transaction.fromJson(data);
      }).toList();

      // Sort in memory instead of Firestore to improve performance
      transactions.sort((a, b) => b.date.compareTo(a.date));

      // Cache the results
      _cache[cacheKey] = transactions;
      _lastCacheUpdate = DateTime.now();

      return transactions;
    } catch (e) {
      // Error loading transactions: $e
      return [];
    }
  }

  Stream<List<Transaction>> getBudgetTransactionsStream() {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Transaction.fromJson(data);
      }).toList();
    });
  }

  // Savings Plans Methods
  Future<void> saveSavingsPlans(List<SavingsPlan> savingsPlans) async {
    if (_userId == null) return;

    try {
      final batch = _firestore.batch();
      final userSavingsRef = _firestore.collection('users').doc(_userId).collection('savings_plans');

      // Delete all existing savings plans first
      final existingSavings = await userSavingsRef.get();
      for (var doc in existingSavings.docs) {
        batch.delete(doc.reference);
      }

      // Add new savings plans
      for (var plan in savingsPlans) {
        final docRef = userSavingsRef.doc();
        batch.set(docRef, {
          ...plan.toJson(),
          'id': docRef.id,
          'userId': _userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      
      // Clear cache after saving to ensure fresh data on next load
      _cache.remove('savings_plans_$_userId');
    } catch (e) {
      throw Exception('Error saving savings plans: $e');
    }
  }

  Future<List<SavingsPlan>> loadSavingsPlans() async {
    if (_userId == null) return [];

    // Check cache first
    final cacheKey = 'savings_plans_$_userId';
    if (_isCacheValid && _cache.containsKey(cacheKey)) {
      return List<SavingsPlan>.from(_cache[cacheKey]);
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('savings_plans')
          .get();

      final savingsPlans = snapshot.docs.map((doc) {
        final data = doc.data();
        return SavingsPlan.fromJson(data);
      }).toList();

      // Sort in memory instead of Firestore to improve performance
      savingsPlans.sort((a, b) => a.targetDate.compareTo(b.targetDate));

      // Cache the results
      _cache[cacheKey] = savingsPlans;
      _lastCacheUpdate = DateTime.now();

      return savingsPlans;
    } catch (e) {
      // Error loading savings plans: $e
      return [];
    }
  }

  Stream<List<SavingsPlan>> getSavingsPlansStream() {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('savings_plans')
        .orderBy('targetDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return SavingsPlan.fromJson(data);
      }).toList();
    });
  }

  // Savings Transactions Methods
  Future<void> saveSavingsTransactions(List<SavingsTransaction> savingsTransactions) async {
    if (_userId == null) return;

    try {
      final batch = _firestore.batch();
      final userSavingsTransactionsRef = _firestore.collection('users').doc(_userId).collection('savings_transactions');

      // Delete all existing savings transactions first
      final existingSavingsTransactions = await userSavingsTransactionsRef.get();
      for (var doc in existingSavingsTransactions.docs) {
        batch.delete(doc.reference);
      }

      // Add new savings transactions
      for (var transaction in savingsTransactions) {
        final docRef = userSavingsTransactionsRef.doc();
        batch.set(docRef, {
          ...transaction.toJson(),
          'id': docRef.id,
          'userId': _userId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      
      // Clear cache after saving to ensure fresh data on next load
      _cache.remove('savings_transactions_$_userId');
    } catch (e) {
      throw Exception('Error saving savings transactions: $e');
    }
  }

  Future<List<SavingsTransaction>> loadSavingsTransactions() async {
    if (_userId == null) return [];

    // Check cache first
    final cacheKey = 'savings_transactions_$_userId';
    if (_isCacheValid && _cache.containsKey(cacheKey)) {
      return List<SavingsTransaction>.from(_cache[cacheKey]);
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('savings_transactions')
          .get();

      final savingsTransactions = snapshot.docs.map((doc) {
        final data = doc.data();
        return SavingsTransaction.fromJson(data);
      }).toList();

      // Sort in memory instead of Firestore to improve performance
      savingsTransactions.sort((a, b) => b.date.compareTo(a.date));

      // Cache the results
      _cache[cacheKey] = savingsTransactions;
      _lastCacheUpdate = DateTime.now();

      return savingsTransactions;
    } catch (e) {
      // Error loading savings transactions: $e
      return [];
    }
  }

  Stream<List<SavingsTransaction>> getSavingsTransactionsStream() {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('savings_transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return SavingsTransaction.fromJson(data);
      }).toList();
    });
  }

  // Utility Methods
  Future<void> deleteAllUserData() async {
    if (_userId == null) return;

    try {
      final batch = _firestore.batch();
      
      // Delete todos
      final todos = await _firestore.collection('users').doc(_userId).collection('todos').get();
      for (var doc in todos.docs) {
        batch.delete(doc.reference);
      }

      // Delete transactions
      final transactions = await _firestore.collection('users').doc(_userId).collection('transactions').get();
      for (var doc in transactions.docs) {
        batch.delete(doc.reference);
      }

      // Delete savings plans
      final savingsPlans = await _firestore.collection('users').doc(_userId).collection('savings_plans').get();
      for (var doc in savingsPlans.docs) {
        batch.delete(doc.reference);
      }

      // Delete savings transactions
      final savingsTransactions = await _firestore.collection('users').doc(_userId).collection('savings_transactions').get();
      for (var doc in savingsTransactions.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Error deleting user data: $e');
    }
  }
}
