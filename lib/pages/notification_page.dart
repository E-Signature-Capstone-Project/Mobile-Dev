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
  final String apiBase = ApiConfig.baseUrl;
  String get requestsUrl => ApiConfig.requestsUrl;

  final Color primaryColorUI = const Color(0xFF003E9C);
  final Color colorBG = const Color(0xFFF4FAFE);

  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];

  /// request_id yang SUDAH dibaca (detailnya pernah dibuka)
  final Set<int> _readRequestIds = {};

  @override
  void initState() {
    super.initState();
    _loadReadIds();
    _fetchNotifications();
  }

  Future<void> _loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('read_notification_ids') ?? [];
    _readRequestIds
      ..clear()
      ..addAll(
        saved.map((e) => int.tryParse(e)).where((e) => e != null).cast<int>(),
      );
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  DateTime _parseDate(dynamic v) {
    if (v == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    final parsed = DateTime.tryParse(v.toString());
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(dynamic v) {
    final dt = _parseDate(v);
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
  }

  Future<void> _fetchNotifications() async {
    setState(() => _loading = true);
    try {
      final token = await _token() ?? '';

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
        final decoded = jsonDecode(incomingRes.body);
        if (decoded is Map && decoded['success'] == true) {
          incoming = (decoded['data'] ?? []) as List;
        }
      }

      if (outgoingRes.statusCode == 200) {
        final decoded = jsonDecode(outgoingRes.body);
        if (decoded is Map && decoded['success'] == true) {
          outgoing = (decoded['data'] ?? []) as List;
        }
      }

      final List<Map<String, dynamic>> items = [];

      // Notif permintaan masuk
      for (final r in incoming) {
        final item = r as Map<String, dynamic>;
        items.add({
          'type': 'incoming',
          'raw': item,
          'created_at': item['created_at'],
        });
      }

      // Notif status permintaan (approved / rejected)
      for (final r in outgoing) {
        final item = r as Map<String, dynamic>;
        final status = (item['status'] ?? 'pending').toString().toLowerCase();
        if (status == 'pending') continue;

        items.add({
          'type': status == 'approved'
              ? 'outgoing_approved'
              : 'outgoing_rejected',
          'raw': item,
          'created_at': item['created_at'],
        });
      }

      items.sort((a, b) {
        final da = _parseDate(a['created_at']);
        final db = _parseDate(b['created_at']);
        return db.compareTo(da);
      });

      if (mounted) {
        setState(() => _notifications = items);
      }
    } catch (e) {
      debugPrint('Error fetch notifications: $e');
      if (mounted) setState(() => _notifications = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- UI CARD ----------

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final String type = notif['type'] as String;
    final Map<String, dynamic> raw = notif['raw'] as Map<String, dynamic>;
    final createdAt = notif['created_at'];

    final int? requestId = raw['request_id'] is int
        ? raw['request_id'] as int
        : int.tryParse((raw['request_id'] ?? '').toString());

    final bool isUnread =
        requestId != null && !_readRequestIds.contains(requestId);

    IconData icon;
    Color iconColor;
    String title;
    String messageLine;
    String docTitle = '';

    if (type == 'incoming') {
      final requester = raw['requester'] as Map<String, dynamic>?;
      final doc = raw['Document'] as Map<String, dynamic>?;

      final requesterName = (requester?['name'] ?? '-').toString();
      final requesterEmail = (requester?['email'] ?? '-').toString();
      docTitle = (doc?['title'] ?? 'Dokumen').toString();

      icon = Icons.mark_email_unread_rounded;
      iconColor = primaryColorUI;
      title = "Permintaan tanda tangan baru";
      messageLine = "$requesterName ($requesterEmail)\nDokumen: $docTitle";
    } else if (type == 'outgoing_approved') {
      final signer = raw['signer'] as Map<String, dynamic>?;
      final doc = raw['Document'] as Map<String, dynamic>?;
      final email = (signer?['email'] ?? raw['recipient_email'] ?? '-')
          .toString();
      final name = (signer?['name'] ?? '').toString();
      docTitle = (doc?['title'] ?? 'Dokumen').toString();

      icon = Icons.check_circle_rounded;
      iconColor = Colors.green;
      title = "Permintaan disetujui";
      messageLine =
          "Oleh: ${name.isNotEmpty ? name : email}\nDokumen: $docTitle";
    } else {
      // outgoing_rejected
      final signer = raw['signer'] as Map<String, dynamic>?;
      final doc = raw['Document'] as Map<String, dynamic>?;
      final email = (signer?['email'] ?? raw['recipient_email'] ?? '-')
          .toString();
      final name = (signer?['name'] ?? '').toString();
      docTitle = (doc?['title'] ?? 'Dokumen').toString();

      icon = Icons.cancel_rounded;
      iconColor = Colors.redAccent;
      title = "Permintaan ditolak";
      messageLine =
          "Oleh: ${name.isNotEmpty ? name : email}\nDokumen: $docTitle";
    }

    final Color bgColor = isUnread
        ? primaryColorUI.withOpacity(0.04)
        : Colors.white;
    final Color stripColor = isUnread ? primaryColorUI : Colors.grey.shade300;

    return GestureDetector(
      onTap: () => _openNotificationDetail(notif),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? primaryColorUI.withOpacity(0.25)
                : Colors.grey.withOpacity(0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isUnread ? 0.08 : 0.04),
              blurRadius: isUnread ? 10 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // strip kiri
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: stripColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // judul + dot unread
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: iconColor, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            height: 8,
                            width: 8,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // isi dan tanggal
                    Text(
                      messageLine,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNotificationDetail(Map<String, dynamic> notif) async {
    final String type = notif['type'] as String;
    final Map<String, dynamic> raw = notif['raw'] as Map<String, dynamic>;
    final createdAt = notif['created_at'];

    final int? requestId = raw['request_id'] is int
        ? raw['request_id'] as int
        : int.tryParse((raw['request_id'] ?? '').toString());

    String title;
    String docTitle = '';
    String partyName = '';
    String partyEmail = '';
    String note = (raw['note'] ?? '').toString();

    if (type == 'incoming') {
      final requester = raw['requester'] as Map<String, dynamic>?;
      final doc = raw['Document'] as Map<String, dynamic>?;

      partyName = (requester?['name'] ?? '-').toString();
      partyEmail = (requester?['email'] ?? '-').toString();
      docTitle = (doc?['title'] ?? 'Dokumen').toString();
      title = "Permintaan tanda tangan";
    } else {
      final signer = raw['signer'] as Map<String, dynamic>?;
      final doc = raw['Document'] as Map<String, dynamic>?;

      partyName = (signer?['name'] ?? '').toString();
      partyEmail = (signer?['email'] ?? raw['recipient_email'] ?? '-')
          .toString();
      if (partyName.isEmpty) partyName = partyEmail;

      docTitle = (doc?['title'] ?? 'Dokumen').toString();
      title = type == 'outgoing_approved'
          ? "Permintaan disetujui"
          : "Permintaan ditolak";
    }

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                _formatDate(createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),

              const SizedBox(height: 16),

              Text(
                type == 'incoming' ? "Dari" : "Kepada",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                partyName,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                partyEmail,
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              ),

              const SizedBox(height: 12),

              const Text(
                "Dokumen",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(docTitle, style: const TextStyle(fontSize: 13.5)),

              if (note.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  "Catatan",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],

              const SizedBox(height: 18),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Tutup", style: TextStyle(color: primaryColorUI)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (requestId != null) {
      _markAsRead(requestId);
    }
  }

  Future<void> _markAsRead(int requestId) async {
    if (_readRequestIds.contains(requestId)) return;

    setState(() {
      _readRequestIds.add(requestId);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'read_notification_ids',
      _readRequestIds.map((e) => e.toString()).toList(),
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
              color: primaryColorUI,
              backgroundColor: colorBG,
              child: _notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Text(
                            "Belum ada notifikasi",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _notifications.length,
                      itemBuilder: (_, i) =>
                          _buildNotificationCard(_notifications[i]),
                    ),
            ),
    );
  }
}
