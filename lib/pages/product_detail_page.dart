import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;
  const ProductDetailPage({required this.product, Key? key}) : super(key: key);

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  String selectedSize = '8.5';

  void addToCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
      );
      return;
    }

    final cartRef = FirebaseFirestore.instance
        .collection('carts')
        .doc(user.uid)
        .collection('items');

    await cartRef.add({
      'name': widget.product.name,
      'price': widget.product.price,
      'image': widget.product.image,
      'brand': widget.product.brand,
      'size': selectedSize,
      'addedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เพิ่ม ${widget.product.name} ลงตะกร้าแล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // รูปสินค้า
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                image: DecorationImage(
                  image: AssetImage(product.image),
                  fit: BoxFit.cover,
                ),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
            ),

            const SizedBox(height: 16),

            // ข้อมูลสินค้าใน Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 8),
                      Text("฿${product.price}",
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                      const SizedBox(height: 20),

                      // เลือกไซส์
                      const Text("เลือกไซส์ UK",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: ['7.5', '8', '8.5', '9', '9.5']
                            .map((size) => ChoiceChip(
                                  label: Text(size),
                                  selected: selectedSize == size,
                                  onSelected: (_) {
                                    setState(() {
                                      selectedSize = size;
                                    });
                                  },
                                  selectedColor: Colors.black,
                                  backgroundColor: Colors.grey[300],
                                  labelStyle: TextStyle(
                                      color: selectedSize == size
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 24),

                      // ปุ่มเพิ่มลงตะกร้า
                      ElevatedButton.icon(
                        onPressed: addToCart,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text("เพิ่มลงตะกร้า"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ปุ่มซื้อเลย
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: ไปหน้า Checkout
                        },
                        icon: const Icon(Icons.shopping_bag),
                        label: const Text("ซื้อเลย"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: Colors.black, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
