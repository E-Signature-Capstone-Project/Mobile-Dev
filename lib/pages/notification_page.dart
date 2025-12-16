import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/api_config.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  // Config
  String get requestsUrl => ApiConfig.requestsUrl;
  final Color primaryColorUI = const Color(0xFF003E9C);
  final Color colorBG = const Color(0xFFF4FAFE);

  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];
  final Set<String> _readKeys = {};

  @override
  void initState() {
    super.initState();
    _loadReadKeys();
    _fetchNotifications();
  }

  // Helper Key Unik Notif
  String _buildNotifKey(Map<String, dynamic> raw) {
    final id = (raw['request_id'] ?? '').toString();
    final status = (raw['status'] ?? '').toString();
    return '${id}_$status';
  }

  Future<void> _loadReadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('read_notification_keys') ?? [];
    _readKeys
      ..clear()
      ..addAll(saved);
  }

  // --- FETCH DATA ---
  Future<void> _fetchNotifications() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Ambil User ID Login untuk filter
      final currentUserId = prefs.getInt('user_id');

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
        outgoing = (d['data'] ?? []) as List;
      }

      final List<Map<String, dynamic>> items = [];

      // 1. INCOMING (Permintaan Masuk dari orang lain)
      for (final r in incoming) {
        final item = r as Map<String, dynamic>;

        // Filter Self Sign (Jaga-jaga)
        final reqId = item['requester_id'];
        final sigId = item['signer_id'];
        if (reqId == sigId) continue; // Skip jika requester == signer

        items.add({
          'type': 'incoming',
          'raw': item,
          'created_at': item['created_at'],
        });
      }

      // 2. OUTGOING (Status update permintaan kita ke orang lain)
      for (final r in outgoing) {
        final item = r as Map<String, dynamic>;

        // --- FILTER PENTING: Hapus Self Sign ---
        final reqId = item['requester_id'];
        final sigId = item['signer_id'];
        final note = (item['note'] ?? '').toString();

        // Jika requester sama dengan signer, berarti itu Self Sign -> SKIP
        if (reqId == sigId) continue;
        // Filter tambahan berdasarkan note dari BE
        if (note == "Self signed document") continue;

        final status = (item['status'] ?? 'pending').toString().toLowerCase();
        if (status == 'pending')
          continue; // Pending gak perlu notif (kan kita yg minta)

        String type = '';
        if (status == 'approved')
          type = 'outgoing_approved';
        else if (status == 'rejected')
          type = 'outgoing_rejected';
        else if (status == 'completed')
          type = 'outgoing_completed';
        else
          continue;

        items.add({
          'type': type,
          'raw': item,
          'created_at':
              item['updated_at'] ??
              item['created_at'], // Pakai updated_at agar notif muncul saat status berubah
        });
      }

      // Sort by Date Descending (Terbaru diatas)
      items.sort((a, b) {
        final da = DateTime.tryParse(a['created_at'].toString()) ?? DateTime(0);
        final db = DateTime.tryParse(b['created_at'].toString()) ?? DateTime(0);
        return db.compareTo(da);
      });

      if (mounted) {
        setState(() => _notifications = items);
      }
    } catch (e) {
      debugPrint('Error fetch notifications: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- MARK AS READ ---
  Future<void> _markAsRead(String key) async {
    if (_readKeys.contains(key)) return;
    setState(() => _readKeys.add(key));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('read_notification_keys', _readKeys.toList());
  }

  // --- HELPERS DATE ---
  String _formatDate(dynamic v) {
    if (v == null) return '-';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
  }

  // --- UI ---
  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final String type = notif['type'];
    final Map<String, dynamic> raw = notif['raw'];
    final createdAt = notif['created_at'];
    final key = _buildNotifKey(raw);
    final bool isUnread = !_readKeys.contains(key);

    IconData icon;
    Color iconColor;
    String title;
    String messageLine;

    final docTitle = (raw['Document']?['title'] ?? 'Dokumen').toString();

    if (type == 'incoming') {
      final requesterName = (raw['requester']?['name'] ?? 'Seseorang')
          .toString();
      icon = Icons.mark_email_unread_rounded;
      iconColor = primaryColorUI;
      title = "Permintaan Masuk";
      messageLine = "$requesterName meminta tanda tangan pada '$docTitle'";
    } else if (type == 'outgoing_approved') {
      final signerName =
          (raw['signer']?['name'] ?? raw['recipient_email'] ?? 'Penerima')
              .toString();
      icon = Icons.check_circle_rounded;
      iconColor = Colors.green;
      title = "Permintaan Disetujui";
      messageLine = "$signerName telah menyetujui permintaan pada '$docTitle'";
    } else if (type == 'outgoing_rejected') {
      final signerName =
          (raw['signer']?['name'] ?? raw['recipient_email'] ?? 'Penerima')
              .toString();
      icon = Icons.cancel_rounded;
      iconColor = Colors.redAccent;
      title = "Permintaan Ditolak";
      messageLine = "$signerName menolak permintaan pada '$docTitle'";
    } else {
      // Completed
      final signerName = (raw['signer']?['name'] ?? 'Penerima').toString();
      icon = Icons.done_all_rounded;
      iconColor = Colors.blue;
      title = "Tanda Tangan Selesai";
      messageLine =
          "Dokumen '$docTitle' telah selesai ditandatangani oleh $signerName";
    }

    return GestureDetector(
      onTap: () {
        _markAsRead(key);
        // Bisa tambahkan navigasi ke detail jika perlu
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnread ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread
                ? primaryColorUI.withOpacity(0.3)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isUnread
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    messageLine,
                    style: TextStyle(
                      fontSize: 13,
                      color: isUnread ? Colors.black87 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorBG,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: _notifications.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        const Center(
                          child: Text(
                            "Belum ada notifikasi",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      itemBuilder: (ctx, i) =>
                          _buildNotificationCard(_notifications[i]),
                    ),
            ),
    );
  }
}
