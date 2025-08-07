import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'feed_screen.dart';
import 'match_screen.dart';
import 'checkin_screen.dart';
import 'profile_screen.dart';
import 'chats_list_screen.dart';

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  final GlobalKey<ProfileScreenState> _profileScreenKey = GlobalKey();

  final List<Widget> _screens = [
    const FeedScreen(),
    const CheckinScreen(),
    const MatchScreen(),
    const ChatsListScreen(),
    ProfileScreen(key: GlobalKey<ProfileScreenState>()),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 4) {
        _profileScreenKey.currentState?.refreshProfile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_location),
            label: 'Check-in',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Eşleşme',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Mesajlar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
