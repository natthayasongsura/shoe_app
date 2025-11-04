import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart';
import 'login_page.dart';
import 'orders_page.dart';
import 'address_page.dart';
import 'contact_page.dart';
import 'ChatScreen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int unreadCount = 0;
  String? username;
  String? photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUnreadCount();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        username = data['username'];
        photoUrl = data['photoUrl'];
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('chats').doc(uid).get();
    final data = doc.data();
    if (data != null && data['adminUnreadCount'] != null) {
      setState(() {
        unreadCount = data['adminUnreadCount'];
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  Widget _buildMenuItem(
      BuildContext context, IconData icon, String title, Widget page) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey.shade800),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์ของฉัน'),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: user == null
          ? Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LoginPage()));
                },
                icon: const Icon(Icons.login),
                label: const Text('เข้าสู่ระบบ / สมัครสมาชิก'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundImage:
                          photoUrl != null ? NetworkImage(photoUrl!) : null,
                      child: photoUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(username ?? 'กำลังโหลดชื่อ...'),
                    subtitle: Text(user.email ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EditProfilePage(
                                  username: username, photoUrl: photoUrl)),
                        ).then((_) => _loadUserData());
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildMenuItem(context, Icons.shopping_bag, 'คำสั่งซื้อ',
                    const OrdersPage(initialIndex: 0)),
                _buildMenuItem(
                    context, Icons.location_on, 'ที่อยู่', const AddressPage()),
                _buildMenuItem(
                    context, Icons.phone, 'ติดต่อเรา', const ContactPage()),
                Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Stack(
                    children: [
                      ListTile(
                        leading: Icon(Icons.chat, color: Colors.grey.shade800),
                        title: const Text('แชทกับแอดมิน'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ChatScreen()));
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 12,
                          top: 8,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.red,
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('ออกจากระบบ'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50)),
                ),
              ],
            ),
    );
  }
}
