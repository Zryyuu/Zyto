import 'dart:io';
import 'lib/services/local_storage_service.dart';
import 'lib/services/data_service.dart';
import 'lib/page/budgeting.dart';

void main() async {
  // Testing local storage functionality
  
  // Initialize local storage
  await LocalStorageService.instance.init();
  
  // Set guest mode
  await LocalStorageService.instance.setGuestMode(true);
  await LocalStorageService.instance.isGuestMode();
  
  // Test saving a transaction
  final dataService = DataService.instance;
  final transaction = Transaction(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    title: 'Test Transaction',
    amount: 50000.0,
    category: 'Test',
    date: DateTime.now(),
    isIncome: false,
    notes: 'Test transaction for debugging',
  );
  
  // Save and load test transaction
  await dataService.saveBudgetTransactions([transaction]);
  
  final loadedTransactions = await dataService.loadBudgetTransactions();
  
  if (loadedTransactions.isNotEmpty) {
    // SUCCESS: Data persistence is working
    loadedTransactions.first.title;
  } else {
    // ERROR: No transactions found after saving
  }
  
  exit(0);
}
