import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'screens/login_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/checkin_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/match_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/register_flow_screen.dart';
import 'screens/main_app.dart';
import 'services/auth_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase başarıyla başlatıldı');
  } catch (e) {
    print('Firebase başlatma hatası: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nearFriend',
      theme: _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _nextScreen;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      print('Mevcut kullanıcı: ${user?.uid}');

      if (user != null) {
        try {
          final hasPassedQuiz = await _authService.hasUserPassedQuiz(user.uid);
          final hasCreatedProfile =
              await _authService.hasUserCreatedProfile(user.uid);

          print(
              'Quiz durumu: $hasPassedQuiz, Profil durumu: $hasCreatedProfile');

          if (!hasPassedQuiz) {
            setState(() {
              _nextScreen = 'quiz';
              _isLoading = false;
            });
          } else if (!hasCreatedProfile) {
            setState(() {
              _nextScreen = 'profile';
              _isLoading = false;
            });
          } else {
            setState(() {
              _nextScreen = 'main';
              _isLoading = false;
            });
          }
        } catch (e) {
          print('Kullanıcı durumu kontrol hatası: $e');
          setState(() {
            _nextScreen = 'main';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('AuthWrapper hatası: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Bir hata oluştu', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _checkUserStatus();
                },
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Yükleniyor...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          switch (_nextScreen) {
            case 'quiz':
              return const QuizScreen();
            case 'profile':
              return const ProfileScreen();
            case 'main':
            default:
              return const MainApp();
          }
        }

        return const LoginScreen();
      },
    );
  }
}
