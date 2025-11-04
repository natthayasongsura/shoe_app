import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OrdersPage extends StatelessWidget {
  final int initialIndex;

  const OrdersPage({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: initialIndex,
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('คำสั่งซื้อของฉัน'),
          backgroundColor: Colors.black,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'ทั้งหมด'),
              Tab(text: 'รอดำเนินการ'),
              Tab(text: 'กำลังจัดส่ง'),
              Tab(text: 'ยกเลิก'),
              Tab(text: 'คำขอยกเลิก'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            OrdersList(statusFilter: null), // ทั้งหมด
            OrdersList(statusFilter: 'Pending'), // รอดำเนินการ
            OrdersList(statusFilter: 'Shipping'), // กำลังจัดส่ง
            OrdersList(statusFilter: 'Cancelled'), // ยกเลิก
            OrdersList(statusFilter: 'cancelRequested'), //คำขอยกเลิก
          ],
        ),
      ),
    );
  }
}

class OrdersList extends StatelessWidget {
  final String? statusFilter;
  const OrdersList({super.key, this.statusFilter});

  Color getStatusColor(String? status) {
    switch (status) {
      case 'Pending':
        return Colors.orangeAccent;
      case 'Shipping':
        return Colors.lightBlueAccent;
      case 'Cancelled':
        return Colors.grey;
      case 'cancelRequested':
        return Colors.redAccent;
      default:
        return Colors.white;
    }
  }

  String getThaiStatus(String status) {
    switch (status) {
      case 'Pending':
        return 'รอดำเนินการ';
      case 'Shipping':
        return 'กำลังจัดส่ง';
      case 'Cancelled':
        return 'ยกเลิกแล้ว';
      case 'cancelRequested':
        return 'รออนุมัติการยกเลิก';
      case 'Completed':
        return 'สำเร็จ';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  void _showCancelReasonDialog(BuildContext context, String orderId) {
    final reasons = [
      'สั่งผิดไซต์',
      'ที่อยู่ผิด',
      'ไม่ต้องการสินค้านี้แล้ว',
      'อื่นๆ',
    ];

    showDialog(
      context: context,
      builder: (context) {
        String? selectedReason;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('เหตุผลในการยกเลิก'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: reasons.map((reason) {
                return RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: selectedReason == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _confirmCancel(context, orderId, selectedReason!);
                      },
                child: const Text('ยืนยัน'),
              ),
            ],
          );
        });
      },
    );
  }

  void _confirmCancel(
      BuildContext context, String orderId, String reason) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'cancelRequested',
      'cancelReason': reason, // ✅ ใช้ตัวแปรที่ถูกส่งเข้ามา
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ส่งคำขอยกเลิกแล้ว: $reason')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(
        child: Text(
          'กรุณาเข้าสู่ระบบ',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    Query ordersQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('createdAt',
            isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(
                0)) // ✅ ป้องกัน document ที่ไม่มี createdAt
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      ordersQuery = ordersQuery.where('status', isEqualTo: statusFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: ordersQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล',
                style: TextStyle(color: Colors.redAccent)),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('ไม่มีคำสั่งซื้อ',
                style: TextStyle(color: Colors.white70)),
          );
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final data = doc.data() as Map<String, dynamic>;
            final items = data['items'] as List<dynamic>? ?? [];
            final timestamp = data['createdAt'] as Timestamp?;
            final orderDate = timestamp?.toDate();
            final total = data['total'] is num ? data['total'].toDouble() : 0.0;

            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'คำสั่งซื้อ: ${doc.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'สถานะ: ${getThaiStatus(data['status'] ?? '')}',
                      style: TextStyle(
                        color: getStatusColor(data['status']),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'วันที่สั่ง: ${orderDate != null ? DateFormat('dd/MM/yyyy HH:mm').format(orderDate) : '-'}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (data['status'] == 'cancelRequested') ...[
                      const SizedBox(height: 4),
                      Text(
                        'เหตุผลที่ขอยกเลิก: ${data['cancelReason'] ?? '-'}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'รวมทั้งหมด: ฿${total.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const Divider(color: Colors.white24),
                    Column(
                      children: items.map((item) {
                        final imagePath =
                            item['image'] is List && item['image'].isNotEmpty
                                ? item['image'][0]
                                : item['image'] is String &&
                                        item['image']
                                            .toString()
                                            .startsWith('assets/')
                                    ? item['image']
                                    : null;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: imagePath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    imagePath,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        color: Colors.white38),
                                  ),
                                )
                              : const Icon(Icons.image_not_supported,
                                  color: Colors.white38),
                          title: Text(
                            item['name'] ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'ราคา: ฿${item['price']} x ${item['quantity'] ?? 1}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        );
                      }).toList(),
                    ),
                    if (data['status'] == 'Pending') ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () {
                          _showCancelReasonDialog(context, doc.id);
                        },
                        child: const Text('ยกเลิกคำสั่งซื้อ'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
