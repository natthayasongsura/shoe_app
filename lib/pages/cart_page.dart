import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'confirm_order_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('กรุณาเข้าสู่ระบบก่อนดูตะกร้า'),
        ),
      );
    }

    // ✅ อ้างอิง path carts/userId/items
    final cartRef = FirebaseFirestore.instance
        .collection('carts')
        .doc(user.uid)
        .collection('items');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('🛒 ตะกร้าสินค้า'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ แก้ให้ไม่ crash ถ้าไม่มี addedAt
        stream: cartRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'เกิดข้อผิดพลาด: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data?.docs ?? [];

          // ✅ Debug log (คุณจะเห็นใน console)
          print('🛍 จำนวนสินค้าในตะกร้า: ${items.length}');

          if (items.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีสินค้าในตะกร้า',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          double totalPrice = 0;
          for (var doc in items) {
            final data = doc.data() as Map<String, dynamic>;
            totalPrice += (data['price'] ?? 0).toDouble();
          }

          return Column(
            children: [
              // ✅ แสดงรายการสินค้า
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index].data() as Map<String, dynamic>;
                    final imageUrl = item['image'] ?? '';
                    final name = item['name'] ?? 'ไม่ระบุชื่อสินค้า';
                    final price = item['price'] ?? 0;
                    final size = item['size'] ?? 'ไม่ระบุ';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_not_supported,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.image_not_supported,
                                size: 40,
                                color: Colors.grey,
                              ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ไซส์: $size',
                                style: const TextStyle(fontSize: 14)),
                            Text('฿$price',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.orange)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('ลบสินค้า'),
                                content: const Text(
                                    'คุณต้องการลบสินค้านี้ออกจากตะกร้าหรือไม่?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('ยกเลิก'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      items[index].reference.delete();
                                      Navigator.pop(context);
                                    },
                                    child: const Text('ลบ',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ✅ แถบรวมราคาด้านล่าง
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(top: BorderSide(color: Colors.black12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'รวมทั้งหมด: ฿${totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final itemList = items
                            .map((doc) => doc.data() as Map<String, dynamic>)
                            .toList();
                        final totalPrice = itemList.fold(
                            0.0,
                            (sum, item) =>
                                sum + (item['price'] ?? 0).toDouble());

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConfirmOrderPage(
                                items: itemList, total: totalPrice),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text('ไปชำระเงิน'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
