import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import 'login_screen.dart';
import 'welcome_dialog.dart';
import '../main.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _hasCheckedWelcome = false;
  bool _isGuestMode = false;

  @override
  void initState() {
    super.initState();
    _checkWelcomeStatus();
  }

  Future<void> _checkWelcomeStatus() async {
    try {
      // Add timeout to prevent infinite waiting
      final results = await Future.wait([
        LocalStorageService.instance.hasShownWelcome(),
        LocalStorageService.instance.isGuestMode(),
      ]).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [false, false], // Default values if timeout
      );
      
      final hasShownWelcome = results[0];
      final isGuest = results[1];
      
      if (mounted) {
        setState(() {
          _hasCheckedWelcome = true;
          _isGuestMode = isGuest;
        });

        // Show welcome dialog if first time opening app
        if (!hasShownWelcome && mounted) {
          // Add a small delay to ensure the widget is fully built
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            _showWelcomeDialog();
          }
        }
      }
    } catch (e) {
      // If there's an error, default to guest mode to prevent infinite loading
      if (mounted) {
        setState(() {
          _hasCheckedWelcome = true;
          _isGuestMode = true; // Default to guest mode instead of showing dialog
        });
        // Optionally set guest mode in storage
        try {
          await LocalStorageService.instance.setGuestMode(true);
          await LocalStorageService.instance.setWelcomeShown();
        } catch (_) {
          // Ignore storage errors in fallback
        }
      }
    }
  }

  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WelcomeDialog(
        onContinueAsGuest: () async {
          await LocalStorageService.instance.setGuestMode(true);
          setState(() {
            _isGuestMode = true;
          });
        },
      ),
    );
  }

  void _switchToLoginMode() {
    setState(() {
      _isGuestMode = false;
    });
    LocalStorageService.instance.setGuestMode(false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCheckedWelcome) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // If user is logged in, show main app (not guest mode)
        if (snapshot.hasData && snapshot.data != null) {
          // Ensure we're not in guest mode when logged in
          if (_isGuestMode) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _isGuestMode = false;
              });
            });
          }
          return const MainScreen(isGuestMode: false);
        }
        
        // User is not logged in - check guest mode
        if (_isGuestMode) {
          return MainScreen(
            isGuestMode: true,
            onSwitchToLogin: _switchToLoginMode,
          );
        }
        
        // Check if guest mode is enabled in storage
        return FutureBuilder<bool>(
          future: LocalStorageService.instance.isGuestMode(),
          builder: (context, guestSnapshot) {
            if (guestSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            final isGuest = guestSnapshot.data ?? false;
            if (isGuest) {
              // Update local state to match storage
              if (!_isGuestMode) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _isGuestMode = true;
                  });
                });
              }
              return MainScreen(
                isGuestMode: true,
                onSwitchToLogin: _switchToLoginMode,
              );
            }
            
            // Show login screen if not in guest mode
            return const LoginScreen();
          },
        );
      },
    );
  }
}
