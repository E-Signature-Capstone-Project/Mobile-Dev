// lib/pages/admin_verif_log_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../widget/logout_helper.dart';

class AdminVerifLogPage extends StatefulWidget {
  const AdminVerifLogPage({super.key});

  @override
  State<AdminVerifLogPage> createState() => _AdminVerifLogPageState();
}

class _AdminVerifLogPageState extends State<AdminVerifLogPage> {
  final Color primaryColorUI = const Color(0xFF003E9C);
  final Color bgColor = const Color(0xFFF4FAFE);

  String get logsUrl => ApiConfig.logsUrl;

  bool loading = true;
  List _allLogs = [];
  List _filteredLogs = [];

  String _searchText = '';
  String _statusFilter = 'all'; // all / valid / invalid

  // ===== profile admin (bottom sheet) =====
  Map<String, dynamic>? _profile;
  bool _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    _fetchAdminLogs();
  }

  Future<void> _fetchAdminLogs() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse('$logsUrl/all'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        if (decoded is List) {
          _allLogs = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          _allLogs = decoded['data'];
        } else {
          _allLogs = [];
        }
      } else {
        _allLogs = [];
      }
      _applyFilter();
    } catch (e) {
      debugPrint('Error fetch admin logs: $e');
      _allLogs = [];
      _filteredLogs = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _applyFilter() {
    List logs = List.from(_allLogs);

    if (_statusFilter != 'all') {
      logs = logs
          .where(
            (e) =>
                (e['verification_result'] ?? '').toString().toLowerCase() ==
                _statusFilter,
          )
          .toList();
    }

    final q = _searchText.trim().toLowerCase();
    if (q.isNotEmpty) {
      logs = logs.where((e) {
        final user = e['User'];
        final doc = e['Document'];
        final name = (user?['name'] ?? '').toString().toLowerCase();
        final email = (user?['email'] ?? '').toString().toLowerCase();
        final title = (doc?['title'] ?? '').toString().toLowerCase();

        return name.contains(q) || email.contains(q) || title.contains(q);
      }).toList();
    }

    setState(() {
      _filteredLogs = logs;
    });
  }

  String _formatDate(String? ts) {
    if (ts == null) return '-';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
  }

  Color _statusChipColor(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return Colors.green.shade50;
      case 'invalid':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return Colors.green.shade700;
      case 'invalid':
        return Colors.red.shade700;
      default:
        return Colors.black87;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return 'Valid';
      case 'invalid':
        return 'Tidak Valid';
      default:
        return status;
    }
  }

  Widget _buildSearchField() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Cari user / email / dok...',
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 13.5),
              onChanged: (val) {
                _searchText = val;
                _applyFilter();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip() {
    String label;
    switch (_statusFilter) {
      case 'valid':
        label = 'Valid';
        break;
      case 'invalid':
        label = 'Tidak Valid';
        break;
      default:
        label = 'Semua';
    }

    return PopupMenuButton<String>(
      onSelected: (val) {
        _statusFilter = val;
        _applyFilter();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'all', child: Text('Semua')),
        PopupMenuItem(value: 'valid', child: Text('Valid')),
        PopupMenuItem(value: 'invalid', child: Text('Tidak Valid')),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  // ================= PROFIL ADMIN (BOTTOM SHEET) =================

  Future<void> _fetchProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse('${ApiConfig.authUrl}/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          _profile = decoded;
        }
      }
    } catch (e) {
      debugPrint('Error fetch profile admin: $e');
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _openProfileSheet() async {
    if (_profile == null && !_loadingProfile) {
      await _fetchProfile();
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        final name = _profile?['name']?.toString() ?? '-';
        final email = _profile?['email']?.toString() ?? '-';
        final role = _profile?['role']?.toString() ?? 'admin';

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: primaryColorUI.withOpacity(0.1),
                    child: Icon(
                      Icons.admin_panel_settings_outlined,
                      color: primaryColorUI,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _loadingProfile
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColorUI.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user,
                        size: 14,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context); // tutup sheet
                    await performLogout(context); // helper existing
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: const Text(
                    "Logout",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ===== HEADER =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: primaryColorUI.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          color: primaryColorUI,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Admin Panel',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Log Verifikasi Tanda Tangan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Profil',
                    onPressed: _openProfileSheet,
                    iconSize: 32,
                    icon: Icon(
                      Icons.account_circle_outlined,
                      color: primaryColorUI,
                    ),
                  ),
                ],
              ),
            ),

            // ===== SEARCH + FILTER =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _buildSearchField()),
                  const SizedBox(width: 12),
                  _buildStatusFilterChip(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ===== LIST LOG =====
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredLogs.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada log verifikasi',
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchAdminLogs,
                      color: primaryColorUI,
                      backgroundColor: bgColor,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _filteredLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item =
                              _filteredLogs[index] as Map<String, dynamic>;
                          final user = item['User'] as Map<String, dynamic>?;
                          final doc = item['Document'] as Map<String, dynamic>?;

                          final status =
                              (item['verification_result'] ?? 'unknown')
                                  .toString();
                          final chipColor = _statusChipColor(status);
                          final textColor = _statusTextColor(status);

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: primaryColorUI.withOpacity(
                                            0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.picture_as_pdf_outlined,
                                          size: 18,
                                          color: primaryColorUI,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              doc?['title'] ?? 'Tanpa judul',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'User: ${user?['name'] ?? '-'}',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            Text(
                                              user?['email'] ?? '-',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: chipColor,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatDate(item['timestamp']?.toString()),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
