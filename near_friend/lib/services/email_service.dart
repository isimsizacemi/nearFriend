import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 6 haneli rastgele kod oluştur
  String _generateVerificationCode() {
    Random random = Random();
    return List.generate(6, (index) => random.nextInt(10)).join();
  }

  // Doğrulama kodu gönder ve kaydet
  Future<String> sendVerificationCode(String email) async {
    try {
      // 6 haneli kod oluştur
      String verificationCode = _generateVerificationCode();

      // Firestore'a kaydet (5 dakika geçerli)
      await _firestore.collection('verification_codes').doc(email).set({
        'code': verificationCode,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': FieldValue.serverTimestamp(), // 5 dakika sonra
      });

      // TODO: Gerçek email gönderme
      // Şimdilik sadece konsola yazdır
      print('📧 Doğrulama kodu gönderildi: $verificationCode');
      print('📧 Email: $email');

      // Firebase Functions ile gerçek email gönderme (gelecekte)
      // await _sendEmailViaFirebaseFunctions(email, verificationCode);

      return verificationCode;
    } catch (e) {
      print('Doğrulama kodu gönderilirken hata: $e');
      rethrow;
    }
  }

  // Firebase Functions ile email gönderme (gelecekte)
  Future<void> _sendEmailViaFirebaseFunctions(String email, String code) async {
    try {
      // Firebase Functions URL'i (gelecekte oluşturulacak)
      const String functionUrl =
          'https://your-project.cloudfunctions.net/sendEmail';

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'code': code,
          'subject': 'nearFriend - Doğrulama Kodu',
          'message': 'Doğrulama kodunuz: $code\n\nBu kod 5 dakika geçerlidir.',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Email gönderilemedi: ${response.body}');
      }
    } catch (e) {
      print('Firebase Functions ile email gönderme hatası: $e');
      rethrow;
    }
  }

  // Doğrulama kodunu kontrol et
  Future<bool> verifyCode(String email, String code) async {
    try {
      final doc =
          await _firestore.collection('verification_codes').doc(email).get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data()!;
      final storedCode = data['code'] as String;
      final createdAt = data['createdAt'] as Timestamp;

      // 5 dakika geçerlilik kontrolü
      final now = DateTime.now();
      final codeTime = createdAt.toDate();
      final difference = now.difference(codeTime).inMinutes;

      if (difference > 5) {
        // Süresi dolmuş, sil
        await _firestore.collection('verification_codes').doc(email).delete();
        return false;
      }

      // Kod kontrolü
      if (storedCode == code) {
        // Başarılı, kodu sil
        await _firestore.collection('verification_codes').doc(email).delete();
        return true;
      }

      return false;
    } catch (e) {
      print('Doğrulama kodu kontrol edilirken hata: $e');
      return false;
    }
  }
}
