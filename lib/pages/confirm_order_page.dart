import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_success_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ConfirmOrderPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final double total;
  const ConfirmOrderPage({super.key, required this.items, required this.total});

  @override
  State<ConfirmOrderPage> createState() => _ConfirmOrderPageState();
}

class _ConfirmOrderPageState extends State<ConfirmOrderPage> {
  String selectedPayment = 'เก็บเงินปลายทาง';
  String selectedAddress = '';
  String selectedCouponId = '';
  double discountPercent = 0;

  List<Map<String, dynamic>> availableCoupons = [];

  // QR Code ของ PromptPay ของคุณ (เปลี่ยนเป็นของจริง)
  final String promptPayQR = 'https://promptpay.io/0123456789?amount=';

  @override
  void initState() {
    super.initState();
    _loadAddress();
    _loadCoupons();
  }

  // --- วางไว้ใน class _ConfirmOrderPageState ---
  QrImageView qrCodeWidget(String data) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: 200.0,
      gapless: false,
    );
  }

  Future<void> _loadAddress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docs = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .orderBy('createdAt', descending: true)
        .get();
    if (docs.docs.isNotEmpty) {
      setState(() {
        selectedAddress = docs.docs.first['address'];
      });
    }
  }

  Future<void> _loadCoupons() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('coupons')
        .where('expiryDate', isGreaterThan: Timestamp.now())
        .get();

    setState(() {
      availableCoupons = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'discountPercent': data['discountPercent']?.toDouble() ?? 0,
          'minAmount': data['minAmount']?.toDouble() ?? 0,
        };
      }).toList();
    });
  }

  double getFinalTotal() {
    if (discountPercent > 0) {
      return widget.total * (1 - discountPercent / 100);
    }
    return widget.total;
  }

  Future<void> _placeOrder() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userName = userDoc.data()?['name'] ?? 'ลูกค้าไม่ทราบ';

    // สร้างคำสั่งซื้อใน Firestore
    final orderRef = await FirebaseFirestore.instance.collection('orders').add({
      'userId': uid,
      'username': userName,
      'items': widget.items,
      'total': getFinalTotal(),
      'discountPercent': discountPercent,
      'couponId': selectedCouponId,
      'paymentMethod': selectedPayment,
      'address': selectedAddress,
      'status': 'Pending', // รออนุมัติจากแอดมิน
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ลบสินค้าทั้งหมดในตะกร้า
    final cartSnapshot = await FirebaseFirestore.instance
        .collection('carts')
        .doc(uid)
        .collection('items')
        .get();

    for (var doc in cartSnapshot.docs) {
      await doc.reference.delete();
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccessPage(orderId: orderRef.id),
        ),
      );
    }
  }

  void _showCouponDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เลือกคูปองส่วนลด'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableCoupons.map((coupon) {
            final isValid = widget.total >= coupon['minAmount'];
            return CheckboxListTile(
              title:
                  Text('${coupon['title']} - ลด ${coupon['discountPercent']}%'),
              subtitle: Text('ขั้นต่ำ ฿${coupon['minAmount']}'),
              value: selectedCouponId == coupon['id'],
              onChanged: isValid
                  ? (val) {
                      setState(() {
                        selectedCouponId = val! ? coupon['id'] : '';
                        discountPercent = val ? coupon['discountPercent'] : 0;
                      });
                      Navigator.pop(context);
                    }
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('ยืนยันการสั่งซื้อ'),
          backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ที่อยู่
            ListTile(
              title: const Text('ที่อยู่จัดส่ง'),
              subtitle: Text(
                  selectedAddress.isEmpty ? 'ไม่มีที่อยู่' : selectedAddress),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                await Navigator.pushNamed(context, '/address_page');
                _loadAddress(); // โหลดที่อยู่ใหม่หลังจากกลับมา
              },
            ),
            const Divider(),

            // วิธีชำระเงิน
            const Text('เลือกวิธีชำระเงิน',
                style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile(
              title: const Text('เก็บเงินปลายทาง'),
              value: 'เก็บเงินปลายทาง',
              groupValue: selectedPayment,
              onChanged: (val) => setState(() => selectedPayment = val!),
            ),
            RadioListTile(
              title: const Text('PromptPay'),
              value: 'PromptPay',
              groupValue: selectedPayment,
              onChanged: (val) => setState(() => selectedPayment = val!),
            ),

// แสดง QR Code ถ้าเลือก PromptPay
            if (selectedPayment == 'PromptPay')
              Column(
                children: [
                  SizedBox(height: 16),
                  Text(
                    'สแกน QR Code เพื่อจ่าย PromptPay',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  qrCodeWidget(
                      '$promptPayQR${getFinalTotal().toStringAsFixed(2)}'),
                  SizedBox(height: 16),
                  Text('หลังจากชำระแล้วกดยืนยันการสั่งซื้อ'),
                ],
              ),

            const Divider(),

            // คูปอง
            ListTile(
              title: const Text('คูปองส่วนลด'),
              subtitle: Text(
                selectedCouponId.isEmpty
                    ? 'ยังไม่ได้เลือก'
                    : 'ใช้คูปองลด ${discountPercent.toStringAsFixed(0)}%',
              ),
              trailing: const Icon(Icons.local_offer),
              onTap: _showCouponDialog,
            ),
            const Divider(),

            // สรุปราคา
            Text('รวมทั้งหมด: ฿${widget.total.toStringAsFixed(2)}'),
            if (discountPercent > 0)
              Text('ส่วนลด: -${discountPercent.toStringAsFixed(0)}%'),
            Text('ราคาสุทธิ: ฿${getFinalTotal().toStringAsFixed(2)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _placeOrder,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('ยืนยันการสั่งซื้อ',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
