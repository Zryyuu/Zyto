import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _todoKey = 'local_todos';
  static const String _budgetKey = 'local_budget_items';
  static const String _hasShownWelcomeKey = 'has_shown_welcome';
  static const String _isGuestModeKey = 'is_guest_mode';

  // Singleton pattern
  static LocalStorageService? _instance;
  static LocalStorageService get instance => _instance ??= LocalStorageService._();
  LocalStorageService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Welcome dialog tracking
  Future<bool> hasShownWelcome() async {
    await init();
    return _prefs!.getBool(_hasShownWelcomeKey) ?? false;
  }

  Future<void> setWelcomeShown() async {
    await init();
    await _prefs!.setBool(_hasShownWelcomeKey, true);
  }

  // Guest mode tracking
  Future<bool> isGuestMode() async {
    await init();
    return _prefs!.getBool(_isGuestModeKey) ?? false;
  }

  Future<void> setGuestMode(bool isGuest) async {
    await init();
    await _prefs!.setBool(_isGuestModeKey, isGuest);
  }

  // Todo operations
  Future<List<Map<String, dynamic>>> getTodos() async {
    await init();
    final String? todosJson = _prefs!.getString(_todoKey);
    if (todosJson == null) return [];
    
    try {
      final List<dynamic> todosList = json.decode(todosJson);
      return todosList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveTodos(List<Map<String, dynamic>> todos) async {
    await init();
    final String todosJson = json.encode(todos);
    await _prefs!.setString(_todoKey, todosJson);
  }

  Future<void> addTodo(Map<String, dynamic> todo) async {
    final todos = await getTodos();
    todos.add(todo);
    await saveTodos(todos);
  }

  Future<void> updateTodo(String id, Map<String, dynamic> updatedTodo) async {
    final todos = await getTodos();
    final index = todos.indexWhere((todo) => todo['id'] == id);
    if (index != -1) {
      todos[index] = updatedTodo;
      await saveTodos(todos);
    }
  }

  Future<void> deleteTodo(String id) async {
    final todos = await getTodos();
    todos.removeWhere((todo) => todo['id'] == id);
    await saveTodos(todos);
  }

  // Budget operations
  Future<List<Map<String, dynamic>>> getBudgetItems() async {
    await init();
    final String? budgetJson = _prefs!.getString(_budgetKey);
    if (budgetJson == null) return [];
    
    try {
      final List<dynamic> budgetList = json.decode(budgetJson);
      return budgetList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveBudgetItems(List<Map<String, dynamic>> budgetItems) async {
    await init();
    final String budgetJson = json.encode(budgetItems);
    await _prefs!.setString(_budgetKey, budgetJson);
  }

  Future<void> addBudgetItem(Map<String, dynamic> budgetItem) async {
    final budgetItems = await getBudgetItems();
    budgetItems.add(budgetItem);
    await saveBudgetItems(budgetItems);
  }

  Future<void> updateBudgetItem(String id, Map<String, dynamic> updatedItem) async {
    final budgetItems = await getBudgetItems();
    final index = budgetItems.indexWhere((item) => item['id'] == id);
    if (index != -1) {
      budgetItems[index] = updatedItem;
      await saveBudgetItems(budgetItems);
    }
  }

  Future<void> deleteBudgetItem(String id) async {
    final budgetItems = await getBudgetItems();
    budgetItems.removeWhere((item) => item['id'] == id);
    await saveBudgetItems(budgetItems);
  }

  // Clear all local data (when user logs in or uninstalls)
  Future<void> clearAllData() async {
    await init();
    await _prefs!.remove(_todoKey);
    await _prefs!.remove(_budgetKey);
    // Keep welcome and guest mode flags
  }

  // Reset all preferences (for testing or complete reset)
  Future<void> resetAll() async {
    await init();
    await _prefs!.clear();
  }
}
