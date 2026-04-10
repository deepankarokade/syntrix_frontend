import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static Future<String?> uploadFile(Uint8List bytes, String fileName) async {
    try {
      final String ext = fileName.split('.').last.toLowerCase();
      // Force 'raw' for PDFs to bypass the 401/Security block on Cloudinary
      // Images can still be uploaded as 'image' for better processing
      final String resourceType = (ext == 'pdf') ? 'raw' : 'image';

      // Strip extension from public_id to prevent double extension .pdf.pdf
      String publicId = fileName;
      if (fileName.contains('.')) {
        publicId = fileName.substring(0, fileName.lastIndexOf('.'));
      }

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['public_id'] = publicId
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );

      print('📤 Uploading $fileName as $resourceType...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final String secureUrl = json['secure_url'];
        print('✅ Success: $secureUrl');
        return secureUrl;
      } else {
        final json = jsonDecode(response.body);
        print('❌ Failed (${response.statusCode}): ${json["error"]?["message"]}');
        return null;
      }
    } catch (e) {
      print('❌ Error: $e');
      return null;
    }
  }
}
