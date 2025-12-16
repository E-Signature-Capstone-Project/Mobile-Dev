// lib/pages/admin_main_menu.dart
import 'package:flutter/material.dart';

import 'admin_verif_log_page.dart';
import 'admin_approve_admin_page.dart';

class AdminMainMenu extends StatefulWidget {
  const AdminMainMenu({super.key});

  @override
  State<AdminMainMenu> createState() => _AdminMainMenuState();
}

class _AdminMainMenuState extends State<AdminMainMenu> {
  int _selectedIndex = 0;

  final Color primaryColorUI = const Color(0xFF003E9C);

  final List<Widget> _pages = const [
    AdminVerifLogPage(),
    AdminApproveAdminPage(),
  ];

  final List<String> _labels = const ['Verif Log', 'Approve Admin'];

  Future<void> _onTabTap(int index) async {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAFE),
      // setiap page ngatur header & profile sendiri
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
            _buildNavItem(Icons.verified_user_outlined, _labels[0], 0),
            _buildNavItem(Icons.admin_panel_settings_outlined, _labels[1], 1),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onTabTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColorUI.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? primaryColorUI : Colors.black54,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? primaryColorUI : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
