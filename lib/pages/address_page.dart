import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _showAddressDialog(
      {String? docId, String? type, String? address}) async {
    final typeController = TextEditingController(text: type ?? '');
    final addressController = TextEditingController(text: address ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          docId == null ? 'เพิ่มที่อยู่ใหม่' : 'แก้ไขที่อยู่',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: typeController,
              decoration: InputDecoration(
                labelText: 'ประเภทที่อยู่ (บ้าน/ที่ทำงาน)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: InputDecoration(
                labelText: 'ที่อยู่',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newType = typeController.text.trim();
              final newAddress = addressController.text.trim();
              if (newType.isEmpty || newAddress.isEmpty) return;

              final collection = FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('addresses');

              if (docId == null) {
                await collection.add({
                  'type': newType,
                  'address': newAddress,
                  'createdAt': Timestamp.now(),
                });
              } else {
                await collection.doc(docId).update({
                  'type': newType,
                  'address': newAddress,
                  'updatedAt': Timestamp.now(),
                });
              }

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAddress(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('addresses')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบเพื่อจัดการที่อยู่'));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title:
            const Text('ที่อยู่ของฉัน', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('addresses')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('เกิดข้อผิดพลาด'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.black));
          }

          final docs = snapshot.data?.docs ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == docs.length) {
                return ElevatedButton.icon(
                  onPressed: () => _showAddressDialog(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('เพิ่มที่อยู่ใหม่'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }

              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.black,
                    child: Icon(
                      data['type'].toString().toLowerCase() == 'บ้าน'
                          ? Icons.home
                          : Icons.work,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(data['type'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['address'] ?? '',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.black87),
                        onPressed: () => _showAddressDialog(
                          docId: doc.id,
                          type: data['type'],
                          address: data['address'],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteAddress(doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
