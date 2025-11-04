import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditProfilePage extends StatefulWidget {
  final String? username;
  final String? photoUrl;

  const EditProfilePage({super.key, this.username, this.photoUrl});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _usernameController = TextEditingController();
  File? selectedImage;
  bool isUpdating = false;
  final ImagePicker _picker = ImagePicker();

  // --- Cloudinary config ---
  final String cloudName = 'dtryzzo7e';
  final String apiKey = '787568827251677';
  final String uploadPreset = 'flutter_upload';

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.username ?? '';
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image =
        await _picker.pickImage(source: source, imageQuality: 80);
    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadToCloudinary(File imageFile) async {
    try {
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        return data['secure_url'];
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _saveProfile() async {
    final newName = _usernameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อผู้ใช้')));
      return;
    }

    setState(() {
      isUpdating = true;
    });

    String? newPhotoUrl = widget.photoUrl;

    if (selectedImage != null) {
      final uploadedUrl = await _uploadToCloudinary(selectedImage!);
      if (uploadedUrl != null) {
        newPhotoUrl = uploadedUrl;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('อัปโหลดรูปภาพล้มเหลว')));
      }
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .update({'username': newName, 'photoUrl': newPhotoUrl});

    setState(() {
      isUpdating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปเดตโปรไฟล์เรียบร้อยแล้ว')));
    Navigator.pop(context);
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากแกลเลอรี่'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูปด้วยกล้อง'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขโปรไฟล์'),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _showImageOptions,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: selectedImage != null
                            ? FileImage(selectedImage!)
                            : (widget.photoUrl != null
                                ? NetworkImage(widget.photoUrl!)
                                : null) as ImageProvider<Object>?,
                        child:
                            (selectedImage == null && widget.photoUrl == null)
                                ? const Icon(Icons.person, size: 50)
                                : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.black,
                          child: const Icon(Icons.edit,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อผู้ใช้',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save),
                label: const Text('บันทึก'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50)),
              ),
            ],
          ),
          if (isUpdating)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
