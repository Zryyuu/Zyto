import 'firestore_service.dart';
import 'local_storage_service.dart';
import '../page/todolist.dart';
import '../page/budgeting.dart';

class DataService {
  static DataService? _instance;
  static DataService get instance => _instance ??= DataService._();
  DataService._();

  final FirestoreService _firestoreService = FirestoreService();
  final LocalStorageService _localStorageService = LocalStorageService.instance;

  // Check if user is in guest mode
  Future<bool> get _isGuestMode async {
    // The primary source of truth is the flag in local storage.
    return await _localStorageService.isGuestMode();
  }

  // Todo operations
  Future<List<TodoItem>> loadTodoItems() async {
    if (await _isGuestMode) {
      final localData = await _localStorageService.getTodos();
      return localData.map((json) => TodoItem.fromJson(json)).toList();
    } else {
      return await _firestoreService.loadTodoItems();
    }
  }

  Future<void> saveTodoItems(List<TodoItem> todoItems) async {
    if (await _isGuestMode) {
      final jsonData = todoItems.map((item) => item.toJson()).toList();
      await _localStorageService.saveTodos(jsonData);
    } else {
      await _firestoreService.saveTodoItems(todoItems);
    }
  }

  Future<void> addTodoItem(TodoItem todoItem) async {
    if (await _isGuestMode) {
      await _localStorageService.addTodo(todoItem.toJson());
    } else {
      // For Firestore, we'll need to load all items, add the new one, and save
      final items = await loadTodoItems();
      items.add(todoItem);
      await saveTodoItems(items);
    }
  }

  Future<void> updateTodoItem(String id, TodoItem todoItem) async {
    if (await _isGuestMode) {
      await _localStorageService.updateTodo(id, todoItem.toJson());
    } else {
      // For Firestore, we'll need to load all items, update the specific one, and save
      final items = await loadTodoItems();
      final index = items.indexWhere((item) => item.createdAt.millisecondsSinceEpoch.toString() == id);
      if (index != -1) {
        items[index] = todoItem;
        await saveTodoItems(items);
      }
    }
  }

  Future<void> deleteTodoItem(String id) async {
    if (await _isGuestMode) {
      await _localStorageService.deleteTodo(id);
    } else {
      // For Firestore, we'll need to load all items, remove the specific one, and save
      final items = await loadTodoItems();
      items.removeWhere((item) => item.createdAt.millisecondsSinceEpoch.toString() == id);
      await saveTodoItems(items);
    }
  }

  // Budget operations
  Future<List<Transaction>> loadBudgetTransactions() async {
    if (await _isGuestMode) {
      final localData = await _localStorageService.getBudgetItems();
      return localData
          .where((json) => json['type'] == 'transaction')
          .map((json) => Transaction.fromJson(json))
          .toList();
    } else {
      return await _firestoreService.loadBudgetTransactions();
    }
  }

  Future<void> saveBudgetTransactions(List<Transaction> transactions) async {
    if (await _isGuestMode) {
      // Create transaction data with type
      final transactionData = transactions.map((transaction) {
        final json = transaction.toJson();
        json['type'] = 'transaction';
        return json;
      }).toList();
      
      // Get existing data and preserve non-transaction items
      final existingData = await _localStorageService.getBudgetItems();
      final nonTransactionData = existingData.where((json) => json['type'] != 'transaction').toList();
      
      // Combine and save
      final allData = [...nonTransactionData, ...transactionData];
      await _localStorageService.saveBudgetItems(allData);
    } else {
      await _firestoreService.saveBudgetTransactions(transactions);
    }
  }

  Future<List<SavingsPlan>> loadSavingsPlans() async {
    if (await _isGuestMode) {
      final localData = await _localStorageService.getBudgetItems();
      return localData
          .where((json) => json['type'] == 'savings_plan')
          .map((json) => SavingsPlan.fromJson(json))
          .toList();
    } else {
      return await _firestoreService.loadSavingsPlans();
    }
  }

  Future<void> saveSavingsPlans(List<SavingsPlan> plans) async {
    if (await _isGuestMode) {
      final planData = plans.map((plan) {
        final json = plan.toJson();
        json['type'] = 'savings_plan';
        return json;
      }).toList();
      
      // Get existing non-plan data
      final existingData = await _localStorageService.getBudgetItems();
      final nonPlanData = existingData.where((json) => json['type'] != 'savings_plan').toList();
      
      // Combine and save
      final allData = [...nonPlanData, ...planData];
      await _localStorageService.saveBudgetItems(allData);
    } else {
      await _firestoreService.saveSavingsPlans(plans);
    }
  }

  Future<List<SavingsTransaction>> loadSavingsTransactions() async {
    if (await _isGuestMode) {
      final localData = await _localStorageService.getBudgetItems();
      return localData
          .where((json) => json['type'] == 'savings_transaction')
          .map((json) => SavingsTransaction.fromJson(json))
          .toList();
    } else {
      return await _firestoreService.loadSavingsTransactions();
    }
  }

  Future<void> saveSavingsTransactions(List<SavingsTransaction> transactions) async {
    if (await _isGuestMode) {
      final transactionData = transactions.map((transaction) {
        final json = transaction.toJson();
        json['type'] = 'savings_transaction';
        return json;
      }).toList();
      
      // Get existing non-savings-transaction data
      final existingData = await _localStorageService.getBudgetItems();
      final nonTransactionData = existingData.where((json) => json['type'] != 'savings_transaction').toList();
      
      // Combine and save
      final allData = [...nonTransactionData, ...transactionData];
      await _localStorageService.saveBudgetItems(allData);
    } else {
      await _firestoreService.saveSavingsTransactions(transactions);
    }
  }

  // Migration helper - when user logs in, optionally sync local data to cloud
  Future<void> migrateLocalDataToCloud() async {
    if (!(await _isGuestMode)) {
      try {
        // Load local data
        final localTodos = await _localStorageService.getTodos();
        final localBudgetItems = await _localStorageService.getBudgetItems();

        if (localTodos.isNotEmpty || localBudgetItems.isNotEmpty) {
          // Convert and save to Firestore
          if (localTodos.isNotEmpty) {
            final todoItems = localTodos.map((json) => TodoItem.fromJson(json)).toList();
            await _firestoreService.saveTodoItems(todoItems);
          }

          if (localBudgetItems.isNotEmpty) {
            final transactions = localBudgetItems
                .where((json) => json['type'] == 'transaction')
                .map((json) => Transaction.fromJson(json))
                .toList();
            
            final savingsPlans = localBudgetItems
                .where((json) => json['type'] == 'savings_plan')
                .map((json) => SavingsPlan.fromJson(json))
                .toList();
            
            final savingsTransactions = localBudgetItems
                .where((json) => json['type'] == 'savings_transaction')
                .map((json) => SavingsTransaction.fromJson(json))
                .toList();

            await Future.wait([
              if (transactions.isNotEmpty) _firestoreService.saveBudgetTransactions(transactions),
              if (savingsPlans.isNotEmpty) _firestoreService.saveSavingsPlans(savingsPlans),
              if (savingsTransactions.isNotEmpty) _firestoreService.saveSavingsTransactions(savingsTransactions),
            ]);
          }

          // Don't clear local data - keep it for guest mode after logout
          // await _localStorageService.clearAllData();
        }
      } catch (e) {
        // Handle migration error - don't clear local data if migration fails
        rethrow;
      }
    }
  }

  // Clear local data (for logout or when switching to guest mode)
  Future<void> clearLocalData() async {
    // Don't clear local data - keep it for guest mode
    // await _localStorageService.clearAllData();
  }
}
