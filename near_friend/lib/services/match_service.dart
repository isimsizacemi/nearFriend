import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Yakındaki kullanıcıları getir
  Future<List<UserModel>> getNearbyUsers({
    required double maxDistance,
    required int minAge,
    required int maxAge,
    String? preferredGender,
    Position? currentPosition,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      // Eğer güncel konum verilmişse onu kullan, yoksa Firestore'dan al
      GeoPoint? currentUserLocation;
      if (currentPosition != null) {
        currentUserLocation =
            GeoPoint(currentPosition.latitude, currentPosition.longitude);
        print(
            'Güncel konum kullanılıyor: ${currentPosition.latitude}, ${currentPosition.longitude}');
      } else {
        // Mevcut kullanıcının verilerini al
        final currentUserDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (!currentUserDoc.exists) return [];

        final currentUserData = currentUserDoc.data()!;
        currentUserLocation = currentUserData['currentLocation'] as GeoPoint?;

        if (currentUserLocation == null) {
          print('Mevcut kullanıcının konumu yok!');
          return [];
        }

        print(
            'Firestore\'dan alınan konum: ${currentUserLocation.latitude}, ${currentUserLocation.longitude}');
      }

      // Mevcut kullanıcının diğer verilerini al
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!currentUserDoc.exists) return [];

      final currentUserData = currentUserDoc.data()!;
      final currentUserInterests =
          List<String>.from(currentUserData['interests'] ?? []);
      final currentUserBlocked =
          List<String>.from(currentUserData['blockedUsers'] ?? []);
      final currentUserMatched =
          List<String>.from(currentUserData['matchedUsers'] ?? []);
      final currentUserPending =
          List<String>.from(currentUserData['pendingMatches'] ?? []);

      // Tüm kullanıcıları al ve filtrele
      final usersQuery = _firestore
          .collection('users')
          .where('hasCreatedProfile', isEqualTo: true)
          .where('isActive', isEqualTo: true);

      final snapshot = await usersQuery.get();
      print('Toplam kullanıcı sayısı: ${snapshot.docs.length}');

      // Adım adım filtreleme
      var allUsers =
          snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
      print('1. Firestore\'dan alınan kullanıcı sayısı: ${allUsers.length}');

      // Kendi kullanıcısını filtrele
      allUsers = allUsers.where((user) => user.id != currentUser.uid).toList();
      print('2. Kendi kullanıcısı filtrelendikten sonra: ${allUsers.length}');

      // Blocked kullanıcıları filtrele
      allUsers = allUsers
          .where((user) => !currentUserBlocked.contains(user.id))
          .toList();
      print(
          '3. Blocked kullanıcılar filtrelendikten sonra: ${allUsers.length}');

      // Matched kullanıcıları filtrele
      allUsers = allUsers
          .where((user) => !currentUserMatched.contains(user.id))
          .toList();
      print(
          '4. Matched kullanıcılar filtrelendikten sonra: ${allUsers.length}');

      // Pending kullanıcıları filtrele
      allUsers = allUsers
          .where((user) => !currentUserPending.contains(user.id))
          .toList();
      print(
          '5. Pending kullanıcılar filtrelendikten sonra: ${allUsers.length}');

      // Yaş filtresi
      allUsers = allUsers
          .where((user) => user.age >= minAge && user.age <= maxAge)
          .toList();
      print('6. Yaş filtresi ($minAge-$maxAge) sonrası: ${allUsers.length}');

      // Cinsiyet filtresi
      if (preferredGender != null) {
        allUsers =
            allUsers.where((user) => user.gender == preferredGender).toList();
        print(
            '7. Cinsiyet filtresi ($preferredGender) sonrası: ${allUsers.length}');
      }

      print('Filtreleme sonrası kullanıcı sayısı: ${allUsers.length}');
      print('Yaş aralığı: $minAge - $maxAge');
      print('Tercih edilen cinsiyet: $preferredGender');

      // Her kullanıcının detaylarını yazdır
      for (final user in allUsers) {
        print(
            'Kullanıcı: ${user.displayName} - Yaş: ${user.age} - Cinsiyet: ${user.gender} - Konum: ${user.currentLocation != null ? "Var" : "Yok"}');
      }

      // Konum bazlı filtreleme
      print('Konum filtresi başlıyor...');
      print(
          'Mevcut kullanıcı konumu: ${currentUserLocation?.latitude}, ${currentUserLocation?.longitude}');

      final nearbyUsers = allUsers.where((user) {
        if (user.currentLocation == null) {
          print('${user.displayName} kullanıcısının konumu yok');
          return false;
        }

        if (currentUserLocation == null) {
          print('Mevcut kullanıcının konumu yok');
          return false;
        }

        final distance = Geolocator.distanceBetween(
          currentUserLocation.latitude,
          currentUserLocation.longitude,
          user.currentLocation!.latitude,
          user.currentLocation!.longitude,
        );

        print(
            '${user.displayName} - Mesafe: ${(distance / 1000).toStringAsFixed(1)}km');
        // Eğer maxDistance çok büyükse (100km+) mesafe sınırı yok
        if (maxDistance >= 100000) {
          return true;
        }
        return distance <= maxDistance;
      }).toList();

      // Yakından uzağa sıralama
      nearbyUsers.sort((a, b) {
        if (currentUserLocation == null) return 0;

        final aDistance = Geolocator.distanceBetween(
          currentUserLocation.latitude,
          currentUserLocation.longitude,
          a.currentLocation!.latitude,
          a.currentLocation!.longitude,
        );
        final bDistance = Geolocator.distanceBetween(
          currentUserLocation.latitude,
          currentUserLocation.longitude,
          b.currentLocation!.latitude,
          b.currentLocation!.longitude,
        );

        // Önce mesafeye göre sırala (yakından uzağa)
        if ((aDistance - bDistance).abs() > 500) {
          // 500m'den fazla fark varsa
          return aDistance.compareTo(bDistance);
        }

        // Mesafe yakınsa ilgi alanlarına göre sırala
        final aCommonInterests = a.interests
            .where((interest) => currentUserInterests.contains(interest))
            .length;
        final bCommonInterests = b.interests
            .where((interest) => currentUserInterests.contains(interest))
            .length;

        return bCommonInterests.compareTo(aCommonInterests);
      });

      print('Yakındaki kullanıcı sayısı: ${nearbyUsers.length}');
      if (maxDistance >= 100000) {
        print('Mesafe sınırı yok (tüm kullanıcılar)');
      } else {
        print('Maksimum mesafe: ${maxDistance / 1000}km');
      }

      return nearbyUsers;
    } catch (e) {
      print('Yakındaki kullanıcılar alınırken hata: $e');
      return [];
    }
  }

  // Sağa kaydır (beğen)
  Future<void> likeUser(String likedUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Önce mevcut chat kontrolü yap
      final chatId = [currentUser.uid, likedUserId]..sort();
      final chatIdString = chatId.join('_');

      final chatDoc =
          await _firestore.collection('chats').doc(chatIdString).get();

      if (chatDoc.exists) {
        // Chat zaten var, otomatik mesaj gönder
        await _firestore.collection('messages').add({
          'senderId': currentUser.uid,
          'receiverId': likedUserId,
          'content': 'Seni beğendim 😊',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'messageType': 'text',
        });

        // Chat'i güncelle
        await _firestore.collection('chats').doc(chatIdString).update({
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessage': 'Seni beğendim 😊',
        });
      } else {
        // Chat yok, DM isteği gönder
        await _firestore.collection('dm_requests').add({
          'fromUserId': currentUser.uid,
          'toUserId': likedUserId,
          'message': 'Seni beğendim 😊',
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'type': 'like', // Like tipi DM isteği
        });

        // Mevcut kullanıcının pending listesine ekle
        await _firestore.collection('users').doc(currentUser.uid).update({
          'pendingMatches': FieldValue.arrayUnion([likedUserId]),
        });

        // Beğenilen kullanıcının received listesine ekle
        await _firestore.collection('users').doc(likedUserId).update({
          'receivedMatches': FieldValue.arrayUnion([currentUser.uid]),
        });

        // Eşleşme kontrolü
        await _checkForMatch(currentUser.uid, likedUserId);
      }
    } catch (e) {
      print('Kullanıcı beğenirken hata: $e');
    }
  }

  // Sola kaydır (reddet)
  Future<void> dislikeUser(String dislikedUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Reddedilen kullanıcıyı blocked listesine ekle (opsiyonel)
      await _firestore.collection('users').doc(currentUser.uid).update({
        'blockedUsers': FieldValue.arrayUnion([dislikedUserId]),
      });
    } catch (e) {
      print('Kullanıcı reddederken hata: $e');
    }
  }

  // Eşleşme kontrolü
  Future<void> _checkForMatch(String user1Id, String user2Id) async {
    try {
      final user1Doc = await _firestore.collection('users').doc(user1Id).get();
      final user2Doc = await _firestore.collection('users').doc(user2Id).get();

      if (!user1Doc.exists || !user2Doc.exists) return;

      final user1Data = user1Doc.data()!;
      final user2Data = user2Doc.data()!;

      final user1Pending = List<String>.from(user1Data['pendingMatches'] ?? []);
      final user2Received =
          List<String>.from(user2Data['receivedMatches'] ?? []);

      // Karşılıklı beğeni kontrolü
      if (user1Pending.contains(user2Id) && user2Received.contains(user1Id)) {
        // Eşleşme oluştur
        await _createMatch(user1Id, user2Id);
      }
    } catch (e) {
      print('Eşleşme kontrolü sırasında hata: $e');
    }
  }

  // Eşleşme oluştur
  Future<void> _createMatch(String user1Id, String user2Id) async {
    try {
      // Her iki kullanıcının listelerini güncelle
      await _firestore.collection('users').doc(user1Id).update({
        'pendingMatches': FieldValue.arrayRemove([user2Id]),
        'matchedUsers': FieldValue.arrayUnion([user2Id]),
      });

      await _firestore.collection('users').doc(user2Id).update({
        'receivedMatches': FieldValue.arrayRemove([user1Id]),
        'matchedUsers': FieldValue.arrayUnion([user1Id]),
      });

      // Chat oluştur
      await _createChat(user1Id, user2Id);

      print('Eşleşme oluşturuldu: $user1Id ve $user2Id');
    } catch (e) {
      print('Eşleşme oluşturulurken hata: $e');
    }
  }

  // Chat oluştur
  Future<void> _createChat(String user1Id, String user2Id) async {
    try {
      final chatId = [user1Id, user2Id]..sort();
      final chatIdString = chatId.join('_');

      await _firestore.collection('chats').doc(chatIdString).set({
        'user1Id': user1Id,
        'user2Id': user2Id,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'isActive': true,
        'participants': [user1Id, user2Id],
      });
    } catch (e) {
      print('Chat oluşturulurken hata: $e');
    }
  }

  // Gelen eşleşme isteklerini getir
  Future<List<UserModel>> getReceivedMatches() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final receivedMatches =
          List<String>.from(userData['receivedMatches'] ?? []);

      if (receivedMatches.isEmpty) return [];

      final usersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: receivedMatches)
          .get();

      return usersSnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Gelen eşleşmeler alınırken hata: $e');
      return [];
    }
  }

  // Eşleşme isteğini kabul et
  Future<void> acceptMatch(String matchedUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _createMatch(currentUser.uid, matchedUserId);
    } catch (e) {
      print('Eşleşme kabul edilirken hata: $e');
    }
  }

  // Eşleşme isteğini reddet
  Future<void> rejectMatch(String rejectedUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Reddedilen kullanıcıyı received listesinden çıkar
      await _firestore.collection('users').doc(currentUser.uid).update({
        'receivedMatches': FieldValue.arrayRemove([rejectedUserId]),
      });

      // Reddeden kullanıcıyı pending listesinden çıkar
      await _firestore.collection('users').doc(rejectedUserId).update({
        'pendingMatches': FieldValue.arrayRemove([currentUser.uid]),
      });
    } catch (e) {
      print('Eşleşme reddedilirken hata: $e');
    }
  }

  // Eşleştiğin kullanıcıları getir
  Future<List<UserModel>> getMatchedUsers() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final matchedUsers = List<String>.from(userData['matchedUsers'] ?? []);

      if (matchedUsers.isEmpty) return [];

      final usersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: matchedUsers)
          .get();

      return usersSnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Eşleşilen kullanıcılar alınırken hata: $e');
      return [];
    }
  }

  // Mesaj gönder
  Future<void> sendMessage(String receiverId, String content) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final messageData = {
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': 'text',
      };

      await _firestore.collection('messages').add(messageData);

      // Chat'i güncelle
      final chatId = [currentUser.uid, receiverId]..sort();
      final chatIdString = chatId.join('_');

      await _firestore.collection('chats').doc(chatIdString).update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': content,
      });
    } catch (e) {
      print('Mesaj gönderilirken hata: $e');
    }
  }

  // Chat mesajlarını getir
  Stream<List<MessageModel>> getChatMessages(String otherUserId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100) // Son 100 mesajı al
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .where((message) =>
                (message.senderId == currentUser.uid &&
                    message.receiverId == otherUserId) ||
                (message.senderId == otherUserId &&
                    message.receiverId == currentUser.uid))
            .toList());
  }

  // Chat listesini getir
  Stream<List<ChatModel>> getChats() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList());
  }
}
