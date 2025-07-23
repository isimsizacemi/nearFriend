import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Yakındaki kullanıcıları getir
  Future<List<UserModel>> getNearbyUsers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isActive', isEqualTo: true)
          .where('hasCreatedProfile', isEqualTo: true)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) =>
              user.id != FirebaseAuth.instance.currentUser?.uid &&
              user.lastActiveAt?.isAfter(yesterday) == true)
          .toList();

      return users;
    } catch (e) {
      print('Yakındaki kullanıcılar yüklenirken hata: $e');
      return [];
    }
  }

  // Sağa kaydır (beğen)
  Future<void> likeUser(String likedUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Önce DM isteği kontrolü yap
      final existingRequest = await _firestore
          .collection('dm_requests')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: likedUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        print('Bu kullanıcıya zaten DM isteği gönderilmiş');
        return;
      }

      // Karşılıklı beğeni kontrolü
      final otherUserDoc =
          await _firestore.collection('users').doc(likedUserId).get();
      if (otherUserDoc.exists) {
        final otherUserData = otherUserDoc.data()!;
        final otherUserPending =
            List<String>.from(otherUserData['pendingMatches'] ?? []);

        // Eğer karşı taraf da beni beğenmişse direkt eşleşme oluştur
        if (otherUserPending.contains(currentUser.uid)) {
          await _createMatch(currentUser.uid, likedUserId);
          return;
        }
      }

      // DM isteği gönder
      await _firestore.collection('dm_requests').add({
        'fromUserId': currentUser.uid,
        'toUserId': likedUserId,
        'checkinId': '', // Like için boş
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

      print('DM isteği gönderildi: ${currentUser.uid} -> $likedUserId');
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

      // DM isteklerini kabul et
      await _firestore
          .collection('dm_requests')
          .where('fromUserId', whereIn: [user1Id, user2Id])
          .where('toUserId', whereIn: [user1Id, user2Id])
          .where('status', isEqualTo: 'pending')
          .get()
          .then((snapshot) {
            for (var doc in snapshot.docs) {
              doc.reference.update({'status': 'accepted'});
            }
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

      // DM isteklerini kabul et
      await _firestore
          .collection('dm_requests')
          .where('fromUserId', isEqualTo: matchedUserId)
          .where('toUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.update({'status': 'accepted'});
        }
      });

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

      // DM isteklerini reddet
      await _firestore
          .collection('dm_requests')
          .where('fromUserId', isEqualTo: rejectedUserId)
          .where('toUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.update({'status': 'rejected'});
        }
      });

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

      // Eşleşme kontrolü
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!currentUserDoc.exists) return;

      final currentUserData = currentUserDoc.data()!;
      final matchedUsers =
          List<String>.from(currentUserData['matchedUsers'] ?? []);

      if (!matchedUsers.contains(receiverId)) {
        print('Bu kullanıcıya mesaj gönderilemez - eşleşme yok');
        return;
      }

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
