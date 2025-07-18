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
    // Firebase başlatılamazsa da uygulamayı çalıştır
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
        // Kullanıcı giriş yapmış, durumunu kontrol et
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
          // Hata durumunda ana ekrana yönlendir
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
          // Kullanıcı giriş yapmış
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

        // Kullanıcı giriş yapmamış
        return const LoginScreen();
      },
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  final GlobalKey<FeedScreenState> _feedScreenKey =
      GlobalKey<FeedScreenState>();

  List<Widget> get _screens => [
        FeedScreen(key: _feedScreenKey),
        const MatchScreen(),
        const CheckinScreen(),
        const ChatScreen(),
        const ProfileScreen(),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.iosDarkSecondaryBackground
              : AppTheme.iosSecondaryBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Ana Akış',
                  index: 0,
                  isSelected: _selectedIndex == 0,
                ),
                _buildNavItem(
                  icon: Icons.favorite_outline,
                  selectedIcon: Icons.favorite,
                  label: 'Eşleşme',
                  index: 1,
                  isSelected: _selectedIndex == 1,
                ),
                _buildNavItem(
                  icon: Icons.add_location_outlined,
                  selectedIcon: Icons.add_location,
                  label: 'Check-in',
                  index: 2,
                  isSelected: _selectedIndex == 2,
                ),
                _buildNavItem(
                  icon: Icons.chat_bubble_outline,
                  selectedIcon: Icons.chat_bubble,
                  label: 'Sohbet',
                  index: 3,
                  isSelected: _selectedIndex == 3,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'Profil',
                  index: 4,
                  isSelected: _selectedIndex == 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.iosPurple.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected
                  ? AppTheme.iosPurple
                  : isDark
                      ? AppTheme.iosDarkSecondaryText
                      : AppTheme.iosSecondaryText,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.iosFontCaption.copyWith(
                color: isSelected
                    ? AppTheme.iosPurple
                    : isDark
                        ? AppTheme.iosDarkSecondaryText
                        : AppTheme.iosSecondaryText,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
