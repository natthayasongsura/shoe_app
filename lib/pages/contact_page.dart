import 'package:flutter/material.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('ติดต่อเรา', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 2,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.black,
                child: Icon(Icons.phone, color: Colors.white),
              ),
              title: Text('เบอร์โทรศัพท์',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('02-123-4567'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.black,
                child: Icon(Icons.email, color: Colors.white),
              ),
              title:
                  Text('อีเมล', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('support@example.com'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.black,
                child: Icon(Icons.location_on, color: Colors.white),
              ),
              title: Text('ที่อยู่สำนักงาน',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('123 ถนนสุขุมวิท เขตวัฒนา กรุงเทพฯ 10110'),
            ),
          ),
        ],
      ),
    );
  }
}
