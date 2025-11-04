import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import 'login_page.dart';
import 'ChatScreen.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  final CollectionReference productsRef =
      FirebaseFirestore.instance.collection('products');
  final CollectionReference ordersRef =
      FirebaseFirestore.instance.collection('orders');

  late TabController _tabController;
  List<String> productImages = [];
  final ImagePicker _picker = ImagePicker();

  String? selectedChatId;
  String? selectedUserEmail;
  String? selectedUserPhoto;
  final TextEditingController _messageController = TextEditingController();
  String? selectedBrand;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

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

  // =================== Multi-image picker ===================
  Future<void> pickMultipleImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images == null) return;

    List<String> urls = [];
    for (var img in images) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('products')
          .child(DateTime.now().millisecondsSinceEpoch.toString());
      await ref.putFile(File(img.path));
      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    setState(() {
      productImages = urls;
    });
  }

  // =================== Chat functions ===================
  Future<void> _sendTextToChat() async {
    if (_messageController.text.trim().isEmpty || selectedChatId == null)
      return;
    final message = _messageController.text.trim();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(selectedChatId)
        .collection('messages')
        .add({
      'text': message,
      'senderId': 'admin',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(selectedChatId)
        .update({
      'lastMessage': message,
      'adminUnreadCount': FieldValue.increment(1)
    });

    _messageController.clear();
  }

  Future<void> _sendImageToChat() async {
    if (selectedChatId == null) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final ref = FirebaseStorage.instance
        .ref()
        .child('chat_images')
        .child(DateTime.now().millisecondsSinceEpoch.toString());
    await ref.putFile(File(image.path));
    final imageUrl = await ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(selectedChatId)
        .collection('messages')
        .add({
      'imageUrl': imageUrl,
      'senderId': 'admin',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(selectedChatId)
        .update({'adminUnreadCount': FieldValue.increment(1)});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // =================== Main UI ===================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('แดชบอร์ดผู้ดูแลระบบ',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag), text: 'สินค้า'),
            Tab(icon: Icon(Icons.receipt_long), text: 'คำสั่งซื้อ'),
            Tab(icon: Icon(Icons.chat), text: 'แชท'),
            Tab(icon: Icon(Icons.card_giftcard), text: 'คูปอง'),
          ],
        ),
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

  // =================== Tab Products ===================
  Widget _productTab() {
    return Stack(
      children: [
        Positioned.fill(
          child: StreamBuilder<QuerySnapshot>(
            stream: (() {
              final productsQuery =
                  FirebaseFirestore.instance.collection('products');
              final query = selectedBrand == null
                  ? productsQuery.orderBy('createdAt', descending: true)
                  : productsQuery
                      .where('brand', isEqualTo: selectedBrand)
                      .orderBy('createdAt', descending: true);
              return query.snapshots();
            })(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('ยังไม่มีสินค้า'));
              }

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
                    image: data['image'] ?? '',
                    brand: data['brand'] ?? '',
                  );

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
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: product.image.startsWith('http')
                                ? Image.network(
                                    product.image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.image_not_supported,
                                        size: 50,
                                        color: Colors.grey),
                                  )
                                : Image.asset(
                                    product.image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.image_not_supported,
                                        size: 50,
                                        color: Colors.grey),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(data['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(data['brand'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              Text(
                                '฿${data['price']?.toStringAsFixed(0) ?? 0}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text('สต๊อก: ${data['stock'] ?? 0} ชิ้น',
                                  style: const TextStyle(fontSize: 12)),
                              if ((data['stock'] ?? 0) <= 0)
                                const Text(
                                  '⚠️ สินค้าหมดแล้ว',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.blueAccent),
                              onPressed: () {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _editProductDialog(doc.id, data);
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _deleteProduct(doc.id);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
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
            onPressed: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _addProductDialog();
              });
            },
          ),
        ),
      ],
    );
  }

  // =================== Order Tab ===================
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
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', whereIn: statuses)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('ยังไม่มีคำสั่งซื้อ'));
        }

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
                    Text('สินค้า: ${data['items']?.length ?? 0} ชิ้น'),
                    Text('รวม: ฿${data['total'] ?? 0}'),
                    Text(
                      'สถานะ: ${data['status']}',
                      style: TextStyle(
                        color: _getStatusColor(data['status']),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              final chatDocs = snapshot.data!.docs;
              final filteredChats = chatDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final email = data['userEmail'] ?? data['email'] ?? '';
                final lastMessage = data['lastMessage'] ?? '';
                return email.isNotEmpty && lastMessage.isNotEmpty;
              }).toList();

              return ListView(
                children: filteredChats.map((doc) {
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
                    title: Text(
                      userEmail,
                      style: TextStyle(
                          fontWeight:
                              hasUnread ? FontWeight.bold : FontWeight.normal),
                    ),
                    subtitle: Text(
                      lastMessage,
                      style: TextStyle(
                          fontWeight:
                              hasUnread ? FontWeight.bold : FontWeight.normal),
                    ),
                    trailing: hasUnread
                        ? const Icon(Icons.circle, color: Colors.blue, size: 10)
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: chatId,
                            userEmail: userEmail,
                            userPhoto: userPhoto,
                            isAdmin: true, // ใส่ true เพราะคุณเป็นแอดมิน
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  // =================== Coupon Tab ===================
  Widget _couponTab() {
    final couponRef = FirebaseFirestore.instance.collection('coupons');
    return StreamBuilder<QuerySnapshot>(
      stream: couponRef.orderBy('expiryDate').snapshots(),
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
                    onPressed: () => couponRef.doc(doc.id).delete(),
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

  // =================== Product Dialog ===================
  void _addProductDialog() {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final imageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return _buildProductDialog(
          title: 'เพิ่มสินค้าใหม่',
          nameCtrl: nameCtrl,
          brandCtrl: brandCtrl,
          priceCtrl: priceCtrl,
          stockCtrl: stockCtrl,
          imageCtrl: imageCtrl,
          onSave: () async {
            await productsRef.add({
              'name': nameCtrl.text,
              'brand': brandCtrl.text,
              'price': double.tryParse(priceCtrl.text) ?? 0,
              'stock': int.tryParse(stockCtrl.text) ?? 0,
              'image': imageCtrl.text,
              'createdAt': FieldValue.serverTimestamp(),
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _editProductDialog(String docId, Map<String, dynamic> data) {
    final nameCtrl = TextEditingController(text: data['name']);
    final brandCtrl = TextEditingController(text: data['brand']);
    final priceCtrl =
        TextEditingController(text: data['price']?.toString() ?? '');
    final stockCtrl =
        TextEditingController(text: data['stock']?.toString() ?? '');
    final imageCtrl = TextEditingController(text: data['image'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return _buildProductDialog(
          title: 'แก้ไขสินค้า',
          nameCtrl: nameCtrl,
          brandCtrl: brandCtrl,
          priceCtrl: priceCtrl,
          stockCtrl: stockCtrl,
          imageCtrl: imageCtrl,
          onSave: () async {
            await productsRef.doc(docId).update({
              'name': nameCtrl.text,
              'brand': brandCtrl.text,
              'price': double.tryParse(priceCtrl.text) ?? 0,
              'stock': int.tryParse(stockCtrl.text) ?? 0,
              'image': imageCtrl.text,
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Future<void> _deleteProduct(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณต้องการลบสินค้านี้หรือไม่?'),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await productsRef.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบสินค้าสำเร็จ')),
      );
    }
  }

  Widget _buildProductDialog({
    required String title,
    required TextEditingController nameCtrl,
    required TextEditingController brandCtrl,
    required TextEditingController priceCtrl,
    required TextEditingController stockCtrl,
    required TextEditingController imageCtrl,
    required VoidCallback onSave,
  }) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          children: [
            _buildTextField(nameCtrl, 'ชื่อสินค้า'),
            _buildTextField(brandCtrl, 'แบรนด์'),
            _buildTextField(priceCtrl, 'ราคา', type: TextInputType.number),
            _buildTextField(stockCtrl, 'สต๊อก', type: TextInputType.number),
            _buildTextField(imageCtrl,
                'ชื่อไฟล์รูปภาพ (เช่น assets/images/nike.png หรือ URL)'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onSave,
          child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

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

  Future<void> _showCouponDialog(
      {String? docId, Map<String, dynamic>? data}) async {
    final titleCtrl = TextEditingController(text: data?['title'] ?? '');
    final discountCtrl =
        TextEditingController(text: data?['discountPercent']?.toString() ?? '');
    final minCtrl =
        TextEditingController(text: data?['minAmount']?.toString() ?? '');
    DateTime expiry = data?['expiryDate']?.toDate() ??
        DateTime.now().add(const Duration(days: 7));

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(docId == null ? 'เพิ่มคูปอง' : 'แก้ไขคูปอง'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(titleCtrl, 'ชื่อคูปอง'),
            _buildTextField(discountCtrl, 'ส่วนลด (%)',
                type: TextInputType.number),
            _buildTextField(minCtrl, 'ขั้นต่ำ (บาท)',
                type: TextInputType.number),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: expiry,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) expiry = picked;
              },
              child: const Text('เลือกวันหมดอายุ'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () async {
              final couponData = {
                'title': titleCtrl.text,
                'discountPercent': double.tryParse(discountCtrl.text) ?? 0,
                'minAmount': double.tryParse(minCtrl.text) ?? 0,
                'expiryDate': Timestamp.fromDate(expiry),
              };
              final ref = FirebaseFirestore.instance.collection('coupons');
              if (docId == null) {
                await ref.add(couponData);
              } else {
                await ref.doc(docId).update(couponData);
              }
              Navigator.pop(context);
            },
            child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
