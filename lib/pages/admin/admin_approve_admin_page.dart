// lib/pages/admin_approve_admin_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../widget/logout_helper.dart';

class AdminApproveAdminPage extends StatefulWidget {
  const AdminApproveAdminPage({super.key});

  @override
  State<AdminApproveAdminPage> createState() => _AdminApproveAdminPageState();
}

class _AdminApproveAdminPageState extends State<AdminApproveAdminPage> {
  final Color primaryColorUI = const Color(0xFF003E9C);
  final Color bgColor = const Color(0xFFF4FAFE);

  bool loading = true;
  List _pendingAdmins = [];
  List _filteredAdmins = [];
  String _searchText = '';

  // profil bottom sheet
  Map<String, dynamic>? _profile;
  bool _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    _fetchPendingAdmins();
  }

  Future<void> _fetchPendingAdmins() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.get(
        Uri.parse(ApiConfig.pendingAdminUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        List data = [];
        if (decoded is Map && decoded['data'] is List) {
          data = decoded['data'];
        } else if (decoded is List) {
          data = decoded;
        }

        if (decoded is Map &&
            decoded['message'] == "Tidak ada request admin.") {
          data = [];
        }

        _pendingAdmins = data;
        _applyFilter();
      } else {
        print("Error Status Code: ${res.statusCode}"); // Debugging
        print("Error Body: ${res.body}"); // Debugging
        _pendingAdmins = [];
        _filteredAdmins = [];
      }
    } catch (e) {
      debugPrint('Error fetch pending admin: $e');
      _pendingAdmins = [];
      _filteredAdmins = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _applyFilter() {
    List admins = List.from(_pendingAdmins);

    final q = _searchText.trim().toLowerCase();
    if (q.isNotEmpty) {
      admins = admins.where((e) {
        final name = (e['name'] ?? '').toString().toLowerCase();
        final email = (e['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    setState(() {
      _filteredAdmins = admins;
    });
  }

  String _formatOnlyDate(String? ts) {
    if (ts == null) return '-';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
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
                hintText: 'Cari nama / email admin...',
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

  Future<void> _confirmApproveAdmin(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: primaryColorUI,
                size: 48,
              ),
              const SizedBox(height: 14),
              const Text(
                "Setujui Admin",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                "Yakin menyetujui ${user['name'] ?? user['email']} sebagai admin?",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Batal"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColorUI,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Setujui",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      await _approveAdmin(user);
    }
  }

  Future<void> _confirmRejectAdmin(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 14),
              const Text(
                "Tolak Admin",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                "Yakin menolak pengajuan admin untuk ${user['name'] ?? user['email']}?",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Batal"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Tolak",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      await _rejectAdmin(user);
    }
  }

  Future<void> _approveAdmin(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final id = user['user_id'];

      final res = await http.put(
        Uri.parse(ApiConfig.approveAdminUrl(id)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin berhasil disetujui')),
        );
        _fetchPendingAdmins();
      } else {
        final body = jsonDecode(res.body);
        final msg = (body['message'] ?? body['error'] ?? 'Gagal menyetujui')
            .toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyetujui admin: $e')));
    }
  }

  Future<void> _rejectAdmin(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final id = user['user_id'];

      final res = await http.put(
        Uri.parse(ApiConfig.rejectAdminUrl(id)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan admin ditolak')),
        );
        _fetchPendingAdmins();
      } else {
        final body = jsonDecode(res.body);
        final msg = (body['message'] ?? body['error'] ?? 'Gagal menolak')
            .toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menolak admin: $e')));
    }
  }

  // =============== PROFILE SHEET (sama kayak di verif log) ===============

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
                    await performLogout(context);
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

  // =============== BUILD ===============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
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
                          Icons.admin_panel_settings_outlined,
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
                            'Persetujuan Admin Baru',
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

            // SEARCH
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSearchField(),
            ),
            const SizedBox(height: 16),

            // LIST + REFRESH
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchPendingAdmins,
                      color: primaryColorUI,
                      backgroundColor: bgColor,
                      child: _filteredAdmins.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(top: 80),
                              children: const [
                                Center(
                                  child: Text(
                                    'Tidak ada request admin.',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              itemCount: _filteredAdmins.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item =
                                    _filteredAdmins[index]
                                        as Map<String, dynamic>;

                                final name = (item['name'] ?? '-').toString();
                                final email = (item['email'] ?? '-').toString();
                                final status =
                                    (item['status_regis'] ?? 'pending')
                                        .toString();
                                final registerDate = item['register_date']
                                    ?.toString();

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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: primaryColorUI
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons
                                                    .admin_panel_settings_outlined,
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
                                                    name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    email,
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.calendar_today,
                                                        size: 13,
                                                        color: Colors.black38,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Daftar: ${_formatOnlyDate(registerDate)}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black45,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                status == 'pending'
                                                    ? 'Menunggu'
                                                    : status,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.amber.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () =>
                                                    _confirmRejectAdmin(item),
                                                style: OutlinedButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  side: const BorderSide(
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                                child: const Text(
                                                  "Tolak",
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () =>
                                                    _confirmApproveAdmin(item),
                                                style: ElevatedButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  backgroundColor:
                                                      primaryColorUI,
                                                ),
                                                child: const Text(
                                                  "Setujui",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
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
