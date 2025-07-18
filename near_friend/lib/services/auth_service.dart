import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanıcı giriş durumunu dinle
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Kullanıcının quiz'i geçip geçmediğini kontrol et
  Future<bool> hasUserPassedQuiz(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['hasPassedQuiz'] ?? false;
      }
      return false;
    } catch (e) {
      print('Quiz durumu kontrol edilirken hata: $e');
      return false;
    }
  }

  // Kullanıcının profilini oluşturup oluşturmadığını kontrol et
  Future<bool> hasUserCreatedProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['hasCreatedProfile'] ?? false;
      }
      return false;
    } catch (e) {
      print('Profil durumu kontrol edilirken hata: $e');
      return false;
    }
  }

  // Quiz'i geçti olarak işaretle
  Future<void> markQuizAsPassed(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'hasPassedQuiz': true,
        'quizPassedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Quiz geçildi işaretlenirken hata: $e');
    }
  }

  // Yeni kullanıcı kaydı oluştur
  Future<void> createUserRecord(User firebaseUser) async {
    try {
      print('Firestore\'da kullanıcı kaydı oluşturuluyor...');
      print('User ID: ${firebaseUser.uid}');
      print('User Email: ${firebaseUser.email}');

      // Önce kullanıcının zaten var olup olmadığını kontrol et
      final existingDoc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (existingDoc.exists) {
        print('Kullanıcı zaten mevcut, güncelleme yapılıyor...');
        await _firestore.collection('users').doc(firebaseUser.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'email': firebaseUser.email,
          'displayName': firebaseUser.displayName ?? '',
          'photoURL': firebaseUser.photoURL,
        });
        print('Kullanıcı güncellendi');
      } else {
        print('Yeni kullanıcı oluşturuluyor...');
        final userData = {
          'email': firebaseUser.email,
          'displayName': firebaseUser.displayName ?? '',
          'photoURL': firebaseUser.photoURL,
          'phoneNumber': firebaseUser.phoneNumber ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'hasPassedQuiz': false, // Quiz yapması gerekiyor
          'hasCreatedProfile': false, // Profil oluşturması gerekiyor
          'isVerified': true, // Email doğrulaması yapıldığı için true
          'isBanned': false,
          'verificationScore': 0,
          'blockedUsers': [],
          'blockedBy': [],
          'authMethod': 'email_password', // Giriş yöntemi
          'isEmailVerified': firebaseUser.emailVerified, // Email doğrulandı mı
          'isActive': true,
          'isOnline': true,
        };

        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(userData);
        print('Yeni kullanıcı başarıyla oluşturuldu');
        print('Email: ${firebaseUser.email}');
        print('Email Verified: ${firebaseUser.emailVerified}');
      }
    } catch (e) {
      print('Kullanıcı kaydı oluşturulurken hata: $e');
      print('Hata detayı: ${e.toString()}');
      // Hatayı yukarı fırlatma, sadece log'la
      print('Kullanıcı kaydı oluşturulamadı, devam ediliyor...');
    }
  }

  // Kullanıcı verilerini güncelle
  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      print('AuthService: Profil güncelleniyor...');
      print('Kullanıcı UID: $userId');
      print('Güncellenecek veri: $data');

      await _firestore.collection('users').doc(userId).update({
        ...data,
        'hasCreatedProfile': true,
        'profileUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('AuthService: Profil başarıyla güncellendi!');
    } catch (e) {
      print('Kullanıcı profili güncellenirken hata: $e');
      throw e; // Hatayı yukarı fırlat
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
