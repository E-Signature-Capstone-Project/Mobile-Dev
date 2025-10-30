import 'package:flutter/material.dart';
import '../login_register.dart';
import 'dashboard_page.dart';
import 'verif_log_page.dart';
import 'request_page.dart';
import 'notification_page.dart';
import 'profile_page.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _selectedIndex = 0;

  final Color primaryRed = const Color(0xFFDA1E28);

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 60,
        leading: const SizedBox(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        centerTitle: true,
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.black87),
            iconSize: 32,
            onPressed: _goToProfile,
          ),
        ],
      ),

      body: IndexedStack(index: _selectedIndex, children: _pages),

      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
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
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryRed.withOpacity(0.12)
              : Colors.transparent, // merah saat dipilih
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? primaryRed : Colors.black54,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? primaryRed : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
