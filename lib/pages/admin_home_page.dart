import 'dart:io';

import 'package:app/pages/ChatScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import 'login_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class CloudinaryService {
  final String cloudName = 'dtryzzo7e';
  final String apiKey = '787568827251677';
  final String uploadPreset = 'flutter_upload';

  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndUploadImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return null;

    return await uploadImage(File(pickedFile.path));
  }

  Future<String?> uploadImage(File imageFile) async {
    try {
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final res = await http.Response.fromStream(response);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        print('อัปโหลดสำเร็จ: ${data['secure_url']}');
        return data['secure_url'];
      } else {
        print('Cloudinary upload failed: ${res.body}');
        return null;
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  // Firebase references
  final CollectionReference productsRef =
      FirebaseFirestore.instance.collection('products');
  final CollectionReference ordersRef =
      FirebaseFirestore.instance.collection('orders');
  final CollectionReference couponsRef =
      FirebaseFirestore.instance.collection('coupons');
  List<String> imageUrls = []; // ✅ เก็บ URL ของรูปทั้งหมด

  // Controllers
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  final cloudinary = CloudinaryService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =================== Logout ===================
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // =================== UI ===================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'สินค้า'),
            Tab(text: 'คำสั่งซื้อ'),
            Tab(text: 'แชท'),
            Tab(text: 'คูปอง'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _productTab(),
          _orderTab(),
          _chatTab(),
          _couponTab(),
        ],
      ),
    );
  }

  // =================== Product Tab ===================
  Widget _productTab() {
    return Stack(
      children: [
        Positioned.fill(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                productsRef.orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty)
                return const Center(child: Text('ยังไม่มีสินค้า'));

              final docs = snapshot.data!.docs;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final product = Product(
                    name: data['name'] ?? '',
                    price: (data['price'] ?? 0).toDouble(),
                    image: data['image'] ??
                        '', // ✅ ต้องเป็น asset path เช่น 'assets/images/shoe1.png'
                    brand: data['brand'] ?? '',
                  );

                  return _productCard(doc.id, product, data);
                },
              );
            },
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: Colors.black,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: _addProductDialog,
          ),
        ),
      ],
    );
  }

  Widget _productCard(
      String docId, Product product, Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade400.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(2, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: product.image.isNotEmpty
                  ? Image.asset(
                      product.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 50),
                    )
                  : const Icon(Icons.image_not_supported,
                      size: 50, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(product.brand,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text('฿${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('สต๊อก: ${data['stock'] ?? 0} ชิ้น',
                    style: const TextStyle(fontSize: 12)),
                if ((data['stock'] ?? 0) <= 0)
                  const Text('⚠️ สินค้าหมดแล้ว',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: () => _editProductDialog(docId, data)),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  await productsRef.doc(docId).delete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ลบสินค้าสำเร็จ')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =================== Orders Tab ===================
  Widget _orderTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'ทั้งหมด'),
              Tab(text: 'ขอยกเลิก'),
              Tab(text: 'รอดำเนินการ'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOrderList([
                  'Pending',
                  'cancelRequested',
                  'Cancelled',
                  'Shipping',
                  'Completed'
                ]),
                _buildOrderList(['cancelRequested']),
                _buildOrderList(['Pending']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<String> statuses) {
    return StreamBuilder<QuerySnapshot>(
      stream: ordersRef
          .where('status', whereIn: statuses)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text('ยังไม่มีคำสั่งซื้อ'));

        final orders = snapshot.data!.docs;
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final data = doc.data() as Map<String, dynamic>;
            final orderId = doc.id;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: ListTile(
                title: Text('ลูกค้า: ${data['username'] ?? 'ไม่ทราบชื่อ'}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('รวม: ฿${data['totalPrice'] ?? 0}'),
                    Text('สถานะ: ${data['status']}',
                        style: TextStyle(
                            color: _getStatusColor(data['status']),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (data['items'] != null)
                      ...List<Widget>.from(
                          (data['items'] as List).map((item) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 8.0, top: 2),
                                child: Text(
                                    '- ${item['name']} ${item['size'] ?? ''} x${item['quantity'] ?? 1}',
                                    style: const TextStyle(fontSize: 14)),
                              ))),
                    const SizedBox(height: 4),
                    if (data['slipUrl'] != null)
                      Image.network(data['slipUrl'],
                          height: 150,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported)),
                    const SizedBox(height: 4),
                    if (data['status'] == 'cancelRequested')
                      _buildCancelButtons(orderId, data),
                    if (data['status'] == 'Pending')
                      _buildShippingButton(orderId),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCancelButtons(String orderId, Map<String, dynamic> data) {
    return Row(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () async {
            await ordersRef.doc(orderId).update({'status': 'Cancelled'});
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('อนุมัติการยกเลิกแล้ว')));
          },
          child: const Text('อนุมัติ'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: () async {
            await ordersRef.doc(orderId).update({'status': 'Pending'});
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ปฏิเสธการยกเลิกแล้ว')));
          },
          child: const Text('ปฏิเสธ'),
        ),
      ],
    );
  }

  Widget _buildShippingButton(String orderId) {
    return ElevatedButton(
      onPressed: () async {
        await ordersRef.doc(orderId).update({'status': 'Shipping'});
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เปลี่ยนสถานะเป็นจัดส่งแล้ว')));
      },
      child: const Text('ดำเนินการสำเร็จ'),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Shipping':
        return Colors.blue;
      case 'Cancelled':
        return Colors.red;
      case 'cancelRequested':
        return Colors.purple;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // =================== Chat Tab ===================
  Widget _chatTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final chatDocs = snapshot.data!.docs;
        return ListView(
          children: chatDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final userEmail = data['userEmail'] ?? data['email'] ?? '';
            final userPhoto =
                data['userPhoto'] ?? 'assets/images/default_avatar.png';
            final chatId = doc.id;
            final hasUnread = data['hasUnread'] == true;
            final lastMessage = data['lastMessage'] ?? '';

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: userPhoto.startsWith('http')
                    ? NetworkImage(userPhoto)
                    : AssetImage(userPhoto) as ImageProvider,
              ),
              title: Text(userEmail,
                  style: TextStyle(
                      fontWeight:
                          hasUnread ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text(lastMessage,
                  style: TextStyle(
                      fontWeight:
                          hasUnread ? FontWeight.bold : FontWeight.normal)),
              trailing: hasUnread
                  ? const Icon(Icons.circle, color: Colors.blue, size: 10)
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                      chatId: chatId,
                      userEmail: userEmail,
                      userPhoto: userPhoto,
                      isAdmin: true),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // =================== Coupon Tab ===================
  Widget _couponTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: couponsRef.orderBy('expiryDate').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มคูปองใหม่'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () => _showCouponDialog(),
            ),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text(data['title'] ?? 'ไม่มีชื่อ'),
                  subtitle: Text(
                      'ลด ${data['discountPercent']}% ขั้นต่ำ ฿${data['minAmount']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => couponsRef.doc(doc.id).delete(),
                  ),
                  onTap: () => _showCouponDialog(docId: doc.id, data: data),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // =================== Product & Coupon Dialogs ===================
  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  // =================== Add/Edit Product Dialog ===================
  void _addProductDialog() {
    final nameController = TextEditingController();
    final brandController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final imagePathController =
        TextEditingController(); // ✅ ช่องพิมพ์ asset path

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('เพิ่มสินค้าใหม่',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildTextField(nameController, 'ชื่อสินค้า'),
                _buildTextField(brandController, 'แบรนด์'),
                _buildTextField(priceController, 'ราคา',
                    type: TextInputType.number),
                _buildTextField(stockController, 'สต๊อก',
                    type: TextInputType.number),
                _buildTextField(imagePathController,
                    'Asset path เช่น assets/images/shoe1.png'),
                const SizedBox(height: 8),
                if (imagePathController.text.isNotEmpty)
                  Image.asset(
                    imagePathController.text,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 50),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    imagePathController.text.isEmpty) return;

                await productsRef.add({
                  'name': nameController.text,
                  'brand': brandController.text,
                  'price': double.tryParse(priceController.text) ?? 0,
                  'stock': int.tryParse(stockController.text) ?? 0,
                  'images': [imagePathController.text], // ✅ ใช้ asset path
                  'createdAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child:
                  const Text('บันทึก', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _editProductDialog(String docId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final brandController = TextEditingController(text: data['brand']);
    final priceController =
        TextEditingController(text: data['price']?.toString() ?? '');
    final stockController =
        TextEditingController(text: data['stock']?.toString() ?? '');

    // ✅ ช่องพิมพ์ asset path
    final imagePathController = TextEditingController(
      text: data['images'] != null && data['images'].isNotEmpty
          ? data['images'][0]
          : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขสินค้า',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(nameController, 'ชื่อสินค้า'),
              _buildTextField(brandController, 'แบรนด์'),
              _buildTextField(priceController, 'ราคา',
                  type: TextInputType.number),
              _buildTextField(stockController, 'สต๊อก',
                  type: TextInputType.number),
              _buildTextField(imagePathController,
                  'Asset path เช่น assets/images/shoe1.png'),
              const SizedBox(height: 8),
              if (imagePathController.text.isNotEmpty)
                Image.asset(
                  imagePathController.text,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 50),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await productsRef.doc(docId).update({
                  'name': nameController.text,
                  'brand': brandController.text,
                  'price': double.tryParse(priceController.text) ?? 0,
                  'stock': int.tryParse(stockController.text) ?? 0,
                  'images': [imagePathController.text], // ✅ ใช้ asset path
                });
                Navigator.pop(context);
              } catch (e) {
                print('แก้ไขสินค้าไม่สำเร็จ: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('เกิดข้อผิดพลาดในการแก้ไข')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =================== Coupon Dialog ===================
  void _showCouponDialog({String? docId, Map<String, dynamic>? data}) {
    final titleController = TextEditingController(text: data?['title']);
    final discountController =
        TextEditingController(text: data?['discountPercent']?.toString() ?? '');
    final minAmountController =
        TextEditingController(text: data?['minAmount']?.toString() ?? '');
    final expiryController = TextEditingController(
        text: data?['expiryDate']?.toDate().toString().split(' ')[0] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(docId == null ? 'เพิ่มคูปอง' : 'แก้ไขคูปอง',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(titleController, 'ชื่อคูปอง'),
              _buildTextField(discountController, 'เปอร์เซ็นต์ลด',
                  type: TextInputType.number),
              _buildTextField(minAmountController, 'ขั้นต่ำ',
                  type: TextInputType.number),
              _buildTextField(expiryController, 'วันหมดอายุ (YYYY-MM-DD)'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final couponData = {
                'title': titleController.text,
                'discountPercent':
                    double.tryParse(discountController.text) ?? 0,
                'minAmount': double.tryParse(minAmountController.text) ?? 0,
                'expiryDate': Timestamp.fromDate(
                    DateTime.tryParse(expiryController.text) ?? DateTime.now()),
              };
              if (docId == null) {
                await couponsRef.add(couponData);
              } else {
                await couponsRef.doc(docId).update(couponData);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
