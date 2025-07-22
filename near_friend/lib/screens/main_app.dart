import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'feed_screen.dart';
import 'match_screen.dart';
import 'checkin_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  final GlobalKey<FeedScreenState> _feedScreenKey =
      GlobalKey<FeedScreenState>();
  final GlobalKey<ProfileScreenState> _profileScreenKey =
      GlobalKey<ProfileScreenState>();

  List<Widget> get _screens => [
        FeedScreen(key: _feedScreenKey, useScaffold: false),
        const MatchScreen(),
        const CheckinScreen(),
        const ChatScreen(),
        ProfileScreen(key: _profileScreenKey),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Profil ekranına geçiş yapıldığında yenileme yap
    if (index == 4) {
      // Profil ekranını yenile
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _profileScreenKey.currentState?.refreshProfile();
      });
    }
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
                  label: 'Eşleşmeler',
                  index: 1,
                  isSelected: _selectedIndex == 1,
                ),
                _buildNavItem(
                  icon: Icons.location_on_outlined,
                  selectedIcon: Icons.location_on,
                  label: 'Check-in',
                  index: 2,
                  isSelected: _selectedIndex == 2,
                ),
                _buildNavItem(
                  icon: Icons.chat_outlined,
                  selectedIcon: Icons.chat,
                  label: 'Mesajlar',
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.iosBlue.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected
                  ? AppTheme.iosBlue
                  : (isDark
                      ? AppTheme.iosDarkSecondaryText
                      : AppTheme.iosSecondaryText),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.iosFontSmall.copyWith(
              color: isSelected
                  ? AppTheme.iosBlue
                  : (isDark
                      ? AppTheme.iosDarkSecondaryText
                      : AppTheme.iosSecondaryText),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
