import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'cloudinary_service.dart'; // import สำหรับ Cloudinary

class CheckoutPage extends StatefulWidget {
  final List<QueryDocumentSnapshot>? cartItems;
  final Product? product;

  const CheckoutPage({
    super.key,
    this.cartItems,
    this.product,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _couponController = TextEditingController();
  double discountPercent = 0;
  String appliedCoupon = '';
  bool couponValid = true;

  File? _slipImage; // สำหรับเก็บรูปสลิปชั่วคราว
  String? _slipUrl; // สำหรับเก็บ URL หลังอัปโหลด

  final CloudinaryService _cloudinaryService = CloudinaryService();

  Future<void> updateProductStock(List<Map<String, dynamic>> items) async {
    final batch = FirebaseFirestore.instance.batch();

    for (final item in items) {
      final productQuery = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isEqualTo: item['name'])
          .limit(1)
          .get();

      if (productQuery.docs.isNotEmpty) {
        final productDoc = productQuery.docs.first.reference;
        final currentStock = productQuery.docs.first['stock'] ?? 0;
        final newStock = (currentStock - 1).clamp(0, currentStock);

        batch.update(productDoc, {'stock': newStock});
      }
    }

    await batch.commit();
  }

  double getTotal() {
    double total = 0;
    if (widget.product != null) {
      total = widget.product!.price;
    } else if (widget.cartItems != null) {
      for (var doc in widget.cartItems!) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['price'] ?? 0).toDouble();
      }
    }
    if (discountPercent > 0) {
      total = total * (1 - discountPercent / 100);
    }
    return total;
  }

  Future<void> applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    final couponDoc =
        await FirebaseFirestore.instance.collection('coupons').doc(code).get();

    if (couponDoc.exists) {
      final data = couponDoc.data()!;
      final expiry = data['expiryDate']?.toDate() ?? DateTime.now();
      if (DateTime.now().isBefore(expiry)) {
        setState(() {
          discountPercent = data['discountPercent']?.toDouble() ?? 0;
          appliedCoupon = code;
          couponValid = true;
        });
      } else {
        setState(() {
          couponValid = false;
          discountPercent = 0;
        });
      }
    } else {
      setState(() {
        couponValid = false;
        discountPercent = 0;
      });
    }
  }

  // ฟังก์ชันเลือกสลิปจากแกลเลอรี
  Future<void> pickSlipImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _slipImage = File(pickedFile.path);
      });
    }
  }

  // ฟังก์ชันอัปโหลดไป Cloudinary
  Future<void> uploadSlip() async {
    if (_slipImage == null) return;

    final url = await _cloudinaryService.uploadImage(_slipImage!);
    if (url != null) {
      setState(() {
        _slipUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปโหลดสลิปสำเร็จ')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปโหลดสลิปไม่สำเร็จ')),
      );
    }
  }

  Future<void> placeOrder() async {
    if (_slipImage != null && _slipUrl == null) {
      // ยังไม่ได้อัปโหลดสลิป
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาอัปโหลดสลิปก่อนสั่งซื้อ')),
      );
      return;
    }

    final items = <Map<String, dynamic>>[];

    if (widget.product != null) {
      items.add({
        'name': widget.product!.name,
        'price': widget.product!.price,
        'images': [widget.product!.image],
      });
    } else if (widget.cartItems != null) {
      for (var doc in widget.cartItems!) {
        final data = doc.data() as Map<String, dynamic>;
        items.add({
          'name': data['name'],
          'price': data['price'],
          'images': data['image'] is List ? data['image'] : [data['image']],
        });
      }

      await updateProductStock(items);
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userName = userDoc.data()?['name'] ?? 'ลูกค้าไม่ทราบ';

    await FirebaseFirestore.instance.collection('orders').add({
      'userId': uid,
      'username': userName,
      'items': items,
      'totalPrice': getTotal(),
      'couponUsed': appliedCoupon,
      'discountPercent': discountPercent,
      'status': 'รอจัดส่ง',
      'timestamp': FieldValue.serverTimestamp(),
      'slipUrl': _slipUrl, // เก็บ URL สลิปจาก Cloudinary
    });

    // ล้างตะกร้า
    if (widget.cartItems != null) {
      for (var doc in widget.cartItems!) {
        await doc.reference.delete();
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สั่งซื้อสำเร็จ!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = getTotal();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('ชำระเงิน', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const Text('รายการสินค้า',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (widget.product != null)
                    _buildProductItem(widget.product!)
                  else if (widget.cartItems != null)
                    ...widget.cartItems!.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildProductItem(Product(
                        name: data['name'] ?? '',
                        price: (data['price'] ?? 0).toDouble(),
                        image: data['image'] is List
                            ? (data['image'] as List).first
                            : data['image'] ?? '',
                        brand: data['brand'] ?? '',
                      ));
                    }).toList(),
                  const SizedBox(height: 16),
                  // คูปอง
                  TextField(
                    controller: _couponController,
                    decoration: InputDecoration(
                      hintText: 'กรอกโค้ดคูปอง',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: applyCoupon,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, -3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'รวมทั้งหมด: ฿${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('ยืนยันการสั่งซื้อ',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            product.image,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported, size: 40),
          ),
        ),
        title: Text(product.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('฿${product.price.toStringAsFixed(2)}'),
      ),
    );
  }
}
