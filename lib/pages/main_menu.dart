import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_page.dart';
import 'verif_log_page.dart';
import 'request_page.dart';
import 'notification_page.dart';
import 'profile_page.dart';
import 'config/api_config.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _selectedIndex = 0;

  final Color primaryColorUI = const Color(0xFF003E9C);
  String get requestsUrl => ApiConfig.requestsUrl;

  bool _hasUnreadNotifications = false;

  final List<String> _titles = [
    'E-Signature',
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

  @override
  void initState() {
    super.initState();
    _checkNotificationsForBadge();
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  String _buildNotifKeyFromRaw(Map<String, dynamic> raw) {
    final id = (raw['request_id'] ?? '').toString();
    final status = (raw['status'] ?? '').toString();
    return '${id}_$status';
  }

  /// Cek apakah ada notif (request) yang belum dibaca berdasarkan read_notification_ids
  // Ganti fungsi ini di main_menu.dart
  Future<void> _checkNotificationsForBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await _token() ?? '';

      final savedKeys = prefs.getStringList('read_notification_keys') ?? [];
      final readKeys = savedKeys.toSet();

      final incomingRes = await http.get(
        Uri.parse('$requestsUrl/incoming'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final outgoingRes = await http.get(
        Uri.parse('$requestsUrl/outgoing'),
        headers: {'Authorization': 'Bearer $token'},
      );

      List incoming = [];
      List outgoing = [];

      if (incomingRes.statusCode == 200) {
        final d = jsonDecode(incomingRes.body);
        incoming = (d['data'] ?? []) as List;
      }

      if (outgoingRes.statusCode == 200) {
        final d = jsonDecode(outgoingRes.body);
        final rawOutgoing = (d['data'] ?? []) as List;

        // ✅ FILTER PENTING: Hapus Self Sign dari perhitungan Badge
        outgoing = rawOutgoing.where((item) {
          final reqId = item['requester_id'].toString();
          final sigId = item['signer_id'].toString();
          final note = (item['note'] ?? '').toString().toLowerCase();

          if (reqId == sigId) return false; // Skip Self Sign
          if (note.contains("self signed")) return false; // Skip Note Self Sign

          return true;
        }).toList();
      }

      bool hasUnread = false;

      // Cek Incoming
      for (final r in incoming) {
        final raw = r as Map<String, dynamic>;
        // Filter incoming self sign juga (jaga-jaga)
        if (raw['requester_id'].toString() == raw['signer_id'].toString())
          continue;

        final key = _buildNotifKeyFromRaw(raw);
        if (!readKeys.contains(key)) {
          hasUnread = true;
          break;
        }
      }

      // Cek Outgoing (Hanya yang statusnya bukan pending)
      if (!hasUnread) {
        for (final r in outgoing) {
          final raw = r as Map<String, dynamic>;
          final status = (raw['status'] ?? 'pending').toString().toLowerCase();

          if (status == 'pending') continue;

          final key = _buildNotifKeyFromRaw(raw);
          if (!readKeys.contains(key)) {
            hasUnread = true;
            break;
          }
        }
      }

      if (mounted) {
        setState(() => _hasUnreadNotifications = hasUnread);
      }
    } catch (e) {
      debugPrint('Error checkNotificationsForBadge: $e');
    }
  }

  void _goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  Future<void> _onTabTap(int index) async {
    setState(() => _selectedIndex = index);

    // setiap pindah tab, refresh status badge
    await _checkNotificationsForBadge();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        centerTitle: true,
        leadingWidth: 50,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Image.asset(
            'assets/logo.png',
            height: 28,
            fit: BoxFit.contain,
          ),
        ),
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle, color: primaryColorUI),
            iconSize: 33,
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
    final isNotificationTab = label == 'Notification';

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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? primaryColorUI : Colors.black54,
                ),
                if (isNotificationTab && _hasUnreadNotifications)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
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
