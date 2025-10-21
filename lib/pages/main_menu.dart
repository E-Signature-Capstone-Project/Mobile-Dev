import 'package:flutter/material.dart';
import '../login_register.dart';
import 'dashboard_page.dart';
import 'verif_log_page.dart';
import 'request_page.dart';
import 'notification_page.dart';
import 'profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Dashboard',
    'Verif Log',
    'Request',
    'Notification',
  ];

  final List<Widget> _pages = const [
    DashboardPage(),
    VerifLogPage(),
    RequestPage(),
    NotificationPage(),
  ];

  void _goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leadingWidth: 60,
        leading: const SizedBox(),
        backgroundColor: Colors.black,
        elevation: 1,
        centerTitle: true,
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            iconSize: 35,
            onPressed: _goToProfile,
          ),
        ],
      ),

      // Konten utama
      body: IndexedStack(index: _selectedIndex, children: _pages),

      // Desain navbar modern & minimalis
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.dashboard_outlined, 'Dashboard', 0),
            _buildNavItem(Icons.verified_user_outlined, 'Verif Log', 1),
            _buildNavItem(Icons.assignment_outlined, 'Request', 2),
            _buildNavItem(Icons.notifications_outlined, 'Notification', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
