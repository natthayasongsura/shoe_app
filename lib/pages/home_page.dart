import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'checkout_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> brands = [
    'Nike',
    'Adidas',
    'Converse',
    'Puma',
    'New Balance',
  ];

  String? selectedBrand; // ✅ เก็บชื่อแบรนด์ที่เลือกไว้

  void _handleBuy(BuildContext context, Product product) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginAlert();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CheckoutPage(product: product)),
      );
    }
  }

  void _addToCart(BuildContext context, Product product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginAlert();
      return;
    }

    await FirebaseFirestore.instance
        .collection('carts')
        .doc(user.uid)
        .collection('items')
        .add({
      'name': product.name,
      'price': product.price,
      'image': product.image,
      'brand': product.brand,
      'size': '8.5',
      'addedAt': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เพิ่มลงตะกร้าเรียบร้อย')),
    );
  }

  void _showLoginAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("จำเป็นต้องเข้าสู่ระบบ"),
        content: const Text("กรุณาล็อกอินหรือสมัครสมาชิกก่อนดำเนินการต่อ"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ปิด"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text("เข้าสู่ระบบ / สมัครสมาชิก"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsQuery = FirebaseFirestore.instance.collection('products');

    // ✅ ถ้าเลือกแบรนด์ ให้กรองข้อมูลตาม brand
    final query = selectedBrand == null
        ? productsQuery
        : productsQuery.where('brand', isEqualTo: selectedBrand);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'SNEAKER STUDIO',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // ✅ Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.grey],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("STEP INTO ICONIC STYLE",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text("รองเท้าที่ไม่ใช่แค่แฟชั่น แต่คือตัวตน",
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),

          // ✅ หมวดหมู่แบรนด์
          // ✅ หมวดหมู่แบรนด์ + ปุ่ม All
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategory('All'), // เพิ่มปุ่ม All
                ...brands.map((brand) => _buildCategory(brand)).toList(),
              ],
            ),
          ),

          // ✅ แสดงสินค้า (กรองตาม brand)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('เกิดข้อผิดพลาดในการโหลดสินค้า'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('ยังไม่มีสินค้าในหมวดนี้'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final product = Product(
                      name: data['name'] ?? '',
                      price: (data['price'] ?? 0).toDouble(),
                      image: data['image'] ?? '',
                      brand: data['brand'] ?? '',
                    );

                    return Column(
                      children: [
                        Expanded(child: ProductCard(product: product)),
                        const SizedBox(height: 6),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Add to Cart'),
                          onPressed: () => _addToCart(context, product),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black),
                            minimumSize: const Size.fromHeight(40),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ ปุ่มหมวดหมู่แบรนด์
  Widget _buildCategory(String name) {
    final bool isSelected =
        selectedBrand == name || (name == 'All' && selectedBrand == null);

    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            selectedBrand = (name == 'All') ? null : name;
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? Colors.black : Colors.white,
          side: const BorderSide(color: Colors.black),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
