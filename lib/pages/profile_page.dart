import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../login_register.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final String baseUrl = "http://10.0.2.2:4000/auth";
  bool isLoading = true;

  String? email;
  String? name;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      if (token == null || token.isEmpty) {
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
          email = data["email"];
          name = data["name"];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching profile: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.logout, color: Colors.white70, size: 45),
                const SizedBox(height: 15),
                const Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Apakah kamu yakin ingin logout?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Tombol batal
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.pop(context),
                          splashColor: Colors.white10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2C),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Center(
                              child: Text(
                                "Batal",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Tombol logout
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.pop(context);
                            _logout();
                          },
                          splashColor: Colors.redAccent.withOpacity(0.2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.redAccent, Color(0xFFE63946)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text(
                                "Logout",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              color: Colors.white,
              backgroundColor: Colors.black,
              onRefresh: _fetchProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 25,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFF1E1E1E),
                        child: Icon(
                          Icons.person,
                          size: 70,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    Text(
                      name ?? "Loading...",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    Text(
                      email ?? "-",
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Logout Button
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _showLogoutDialog,
                          splashColor: Colors.white10,
                          highlightColor: Colors.white12,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 25,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.logout, color: Colors.white),
                                SizedBox(width: 10),
                                Text(
                                  "Log out",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Signature Baseline",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Signature grid placeholder
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      height: 200,
                      child: GridView.builder(
                        itemCount: 4,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white24,
                                width: 1,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                "Signature Placeholder",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Upload button
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2C2C2C), Color(0xFF3D3D3D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          splashColor: Colors.white10,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Belum berfungsi"),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 14,
                            ),
                            child: Text(
                              "Upload Signature",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
