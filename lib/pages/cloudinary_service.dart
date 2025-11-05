import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  final String cloudName = 'dtryzzo7e';
  final String apiKey = '787568827251677';
  final String uploadPreset = 'flutter_upload';

  final ImagePicker _picker = ImagePicker();

  Future<File?> pickImage({bool fromCamera = false}) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile == null) return null;
    return File(pickedFile.path);
  }

  Future<String?> uploadImage(File file) async {
    try {
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/dtryzzo7e/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = 'flutter_upload'
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final res = await http.Response.fromStream(response);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['secure_url'];
      } else {
        print('Cloudinary upload failed: ${res.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<String?> pickAndUploadImage({bool fromCamera = false}) async {
    final file = await pickImage(fromCamera: fromCamera);
    if (file == null) return null;
    return await uploadImage(file);
  }
}
