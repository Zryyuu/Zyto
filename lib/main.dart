import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'page/todolist.dart';
import 'page/budgeting.dart';
import 'Login/auth_wrapper.dart';
import 'services/auth_service.dart';
import 'services/local_storage_service.dart';

// Tambahkan ke pubspec.yaml:
// dependencies:
//   flutter_local_notifications: ^17.2.2
//   timezone: ^0.9.4

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCtfgGrheQKz9QxF_G07D4vqrUN3O6XdPk",
        authDomain: "todolist-5c453.firebaseapp.com",
        projectId: "todolist-5c453",
        storageBucket: "todolist-5c453.firebasestorage.app",
        messagingSenderId: "724958697708",
        appId: "1:724958697708:web:038915d1e1437618e92dc9",
        measurementId: "G-X94G90VRC1",
      ),
    );
    
    // Initialize local storage
    await LocalStorageService.instance.init();
    
    // Initialize notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
  } catch (e) {
    // If initialization fails, still run the app but with limited functionality
    // Initialization error: $e
  }
  
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
      home: FutureBuilder(
        future: _initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Memuat aplikasi...'),
                  ],
                ),
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Terjadi kesalahan saat memuat aplikasi'),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Restart the app
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const MyApp()),
                        );
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          return const AuthWrapper();
        },
      ),
    );
  }

  Future<void> _initializeApp() async {
    try {
      // Add timeout to prevent infinite waiting
      await Future.wait([
        Future.delayed(const Duration(milliseconds: 500)),
        LocalStorageService.instance.init(),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () => [], // Continue even if timeout
      );
    } catch (e) {
      // Continue even if initialization fails
      // App initialization error: $e
    }
  }
}

// Main Screen with TabBar
class MainScreen extends StatefulWidget {
  final bool isGuestMode;
  final VoidCallback? onSwitchToLogin;
  
  const MainScreen({
    super.key,
    this.isGuestMode = false,
    this.onSwitchToLogin,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

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

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      // Set guest mode after logout to preserve local data
      await LocalStorageService.instance.setGuestMode(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil logout. Kembali ke mode tamu dengan data lokal.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showLoginPromptDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.cloud_sync, color: Colors.indigo.shade600),
            const SizedBox(width: 8),
            const Text('Sinkronisasi Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Login untuk mendapatkan keuntungan:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildDialogBenefit(Icons.cloud_sync, 'Sinkronisasi otomatis'),
            _buildDialogBenefit(Icons.backup, 'Backup aman ke cloud'),
            _buildDialogBenefit(Icons.devices, 'Akses dari semua perangkat'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade600, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Data mode tamu akan hilang jika aplikasi dihapus',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti Saja'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSwitchToLogin?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text('Login Sekarang'),
          ),
        ],
      ),
    );
  }

  void _showGuestModeInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Text('Mode Tamu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anda sedang menggunakan mode tamu:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildDialogInfo(Icons.phone_android, 'Data tersimpan di perangkat ini'),
            _buildDialogInfo(Icons.offline_bolt, 'Dapat digunakan tanpa internet'),
            _buildDialogInfo(Icons.delete_forever, 'Data hilang jika aplikasi dihapus'),
            _buildDialogInfo(Icons.no_accounts, 'Tidak tersinkronisasi antar perangkat'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Login untuk backup otomatis dan akses dari mana saja',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showLoginPromptDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.green.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'Task & Budget Manager',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              widget.isGuestMode 
                ? 'Mode Tamu'
                : 'Halo, ${_authService.userDisplayName}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (widget.isGuestMode) ...[
            // Guest mode actions - only popup menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'login',
                  child: const ListTile(
                    leading: Icon(Icons.login, color: Colors.indigo),
                    title: Text('Login / Daftar'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'info',
                  child: const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Info Mode Tamu'),
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'login') {
                  _showLoginPromptDialog();
                } else if (value == 'info') {
                  _showGuestModeInfoDialog();
                }
              },
            ),
          ] else ...[
            // Logged in user actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(_authService.userDisplayName),
                    subtitle: Text(_authService.userEmail),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: const ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text('Logout', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'logout') {
                  _showLogoutDialog();
                }
              },
            ),
          ],
        ],
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