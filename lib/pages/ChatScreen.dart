import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'cloudinary_service.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId; // null = user mode, มีค่า = admin mode
  final String? userEmail; // สำหรับ admin ดู user
  final String? userPhoto;
  final bool isAdmin;

  const ChatScreen({
    super.key,
    this.chatId,
    this.userEmail,
    this.userPhoto,
    this.isAdmin = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final cloudinary = CloudinaryService();

  String chatId = '';
  String displayName = '';
  bool isUserOnline = false;

  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    if (widget.isAdmin) {
      // Admin mode
      if (widget.chatId == null || widget.userEmail == null) return;
      chatId = widget.chatId!;
      displayName = widget.userEmail!;
      _listenToUserStatus();
    } else {
      // User mode
      if (currentUser == null) return;
      chatId = currentUser!.uid;
      displayName = currentUser!.displayName ?? currentUser!.email ?? 'ผู้ใช้';

      final docRef = _firestore.collection('chats').doc(chatId);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'userEmail': currentUser!.email ?? 'ลูกค้า',
          'userPhoto': currentUser!.photoURL ?? '',
          'userName': displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'hasUnread': false,
          'adminUnreadCount': 0,
        });
      }
    }
    setState(() {});
  }

  void _listenToUserStatus() {
    if (widget.userEmail == null) return;
    _firestore
        .collection('users')
        .doc(widget.userEmail)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        setState(() {
          isUserOnline = data?['isOnline'] ?? false;
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_chatController.text.trim().isEmpty || chatId.isEmpty) return;

    final text = _chatController.text.trim();

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': currentUser?.uid ?? 'admin',
      'senderName': widget.isAdmin ? 'Admin' : displayName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      if (!widget.isAdmin) 'hasUnread': true,
      if (!widget.isAdmin) 'adminUnreadCount': FieldValue.increment(1),
    });

    _chatController.clear();
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    if (chatId.isEmpty) return;
    final imageUrl = await cloudinary.pickAndUploadImage();
    if (imageUrl == null) return;

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'imageUrl': imageUrl,
      'senderId': currentUser?.uid ?? 'admin',
      'senderName': widget.isAdmin ? 'Admin' : displayName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': '[รูปภาพ]',
      if (!widget.isAdmin) 'hasUnread': true,
      if (!widget.isAdmin) 'adminUnreadCount': FieldValue.increment(1),
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (chatId.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: widget.isAdmin
            ? Row(
                children: [
                  CircleAvatar(
                    backgroundImage: widget.userPhoto != null &&
                            widget.userPhoto!.isNotEmpty
                        ? NetworkImage(widget.userPhoto!)
                        : const AssetImage('assets/images/default_avatar.png')
                            as ImageProvider,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName),
                      if (widget.userEmail != null)
                        Row(
                          children: [
                            Icon(Icons.circle,
                                size: 8,
                                color: isUserOnline
                                    ? Colors.greenAccent
                                    : Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(isUserOnline ? 'ออนไลน์' : 'ออฟไลน์',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                    ],
                  ),
                ],
              )
            : const Text('แชทกับแอดมิน'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!.docs;
                if (messages.isNotEmpty && !widget.isAdmin) {
                  _firestore
                      .collection('chats')
                      .doc(chatId)
                      .update({'hasUnread': false, 'adminUnreadCount': 0});
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUser?.uid ||
                        (widget.isAdmin && data['senderId'] == 'admin');
                    final text = data['text'] ?? '';
                    final imageUrl = data['imageUrl'];
                    final senderName = data['senderName'] ?? 'คุณ';
                    final timestamp =
                        (data['timestamp'] as Timestamp?)?.toDate();

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 3,
                                offset: const Offset(1, 2))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(senderName,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)),
                            if (imageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(imageUrl,
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.cover)),
                              ),
                            if (text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(text,
                                    style: const TextStyle(fontSize: 15)),
                              ),
                            if (timestamp != null)
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                    DateFormat('HH:mm').format(timestamp),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.image, color: Colors.black),
                      onPressed: _sendImage),
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        fillColor: Colors.grey.shade200,
                        filled: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.black,
                    radius: 22,
                    child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
