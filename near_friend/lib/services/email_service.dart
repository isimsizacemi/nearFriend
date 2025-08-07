import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> sendVerificationCode(String email) async {
    try {
      if (!email.contains('@')) {
        throw 'Geçersiz email formatı';
      }

      final verificationCode = _generateVerificationCode();

      await _firestore.collection('verification_codes').doc(email).set({
        'code': verificationCode,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': FieldValue.serverTimestamp(), // 10 dakika sonra
        'isUsed': false,
      });

      print('Email: $email');
      print('Doğrulama Kodu: $verificationCode');

      return true;
    } catch (e) {
      print('Email doğrulama kodu gönderilirken hata: $e');
      return false;
    }
  }

  Future<bool> verifyCode(String email, String code) async {
    try {
      final doc =
          await _firestore.collection('verification_codes').doc(email).get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data();
      if (data == null) return false;

      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt != null) {
        final now = Timestamp.now();
        final difference = now.seconds - createdAt.seconds;
        if (difference > 600) {
          await doc.reference.delete(); // Süresi dolmuş kodu sil
          return false;
        }
      }

      if (data['isUsed'] == true) {
        return false;
      }

      if (data['code'] == code) {
        await doc.reference.update({'isUsed': true});
        return true;
      }

      return false;
    } catch (e) {
      print('Doğrulama kodu kontrol edilirken hata: $e');
      return false;
    }
  }

  Future<UserCredential?> signInWithEmail(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);

      if (methods.isEmpty) {
        return await _auth.createUserWithEmailAndPassword(
          email: email,
          password: _generateTemporaryPassword(), // Geçici şifre
        );
      } else {
        final user = _auth.currentUser;
        if (user != null && user.email == email) {
          return null; // Mevcut kullanıcı için null döndür
        }
        return null;
      }
    } catch (e) {
      print('Email ile giriş yapılırken hata: $e');
      return null;
    }
  }

  String _generateVerificationCode() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = (random % 900000 + 100000).toString();
    return code;
  }

  String _generateTemporaryPassword() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'temp_${random}_${_generateVerificationCode()}';
  }

  Future<void> createUserRecord(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'hasPassedQuiz': false,
        'hasCreatedProfile': false,
        'isVerified': true, // Email doğrulaması yapıldığı için true
        'isBanned': false,
        'verificationScore': 0,
        'blockedUsers': [],
        'blockedBy': [],
      }, SetOptions(merge: true));
    } catch (e) {
      print('Kullanıcı kaydı oluşturulurken hata: $e');
    }
  }
}
