import 'package:flutter/material.dart';
// Import screen widgets
import 'home_screen.dart'; // Import HomeScreen
import 'manage_screen.dart'; // Import ManageScreen
import 'settings_screen.dart'; // Import SettingsScreen

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1; // Index for the selected tab

  // List of widgets to display for each tab
  // Replace Placeholder widgets with actual screen widgets later
  static const List<Widget> _widgetOptions = <Widget>[
    ManageScreen(), // Use the actual ManageScreen
    HomeScreen(), // Use the actual HomeScreen
    SettingsScreen(), // Use the actual SettingsScreen
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar might be different for each screen, handle within individual screens if needed
      // appBar: AppBar(
      //   title: const Text('ShuangJu'), // Generic title?
      // ),
      // Use IndexedStack to keep the state of the screens
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: '管理',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '主页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
        currentIndex: _selectedIndex,
        // Customize colors and styles as needed
        // selectedItemColor: Theme.of(context).colorScheme.primary,
        // unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        // type: BottomNavigationBarType.fixed, // Or shifting
      ),
    );
  }
}

// Removed the PlaceholderWidget class as it's no longer needed.
