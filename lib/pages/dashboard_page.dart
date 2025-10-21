import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final String baseUrl = "http://10.0.2.2:4000/auth";
  String? userName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      if (token == null) {
        setState(() => isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse("$baseUrl/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userName = data["name"];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("❌ Error fetching name: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat(
      'EEEE, dd MMMM yyyy',
    ).format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 👋 Greeting
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hi, ${userName ?? 'User'}!",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 📄 Document placeholder
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: const Center(
                        child: Text(
                          "no document selected",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Button
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white24,
                              width: 1.5,
                            ),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            splashColor: Colors.white24,
                            highlightColor: Colors.white10,
                            onTap: () {
                              //sementara
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Belum berfungsi"),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.folder_open,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Choose Document",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    const Center(
                      child: Text(
                        "select the document to sign",
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
