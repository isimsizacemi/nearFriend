import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import 'time_service.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<UserModel>> getNearbyUsers(
      {int limit = 10, DocumentSnapshot? lastDocument}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      print('🔍 MatchService: Kullanıcılar yükleniyor... (Limit: $limit)');

      Query query = FirebaseFirestore.instance.collection('users');

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();

      print('📊 MatchService: ${querySnapshot.docs.length} kullanıcı alındı');

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) =>
              user.id != FirebaseAuth.instance.currentUser?.uid &&
              user.displayName != null &&
              user.displayName!.isNotEmpty &&
              user.isActive == true &&
              user.hasCreatedProfile == true)
          .toList();

      print('✅ MatchService: ${users.length} kullanıcı filtrelendi');

      return users;
    } catch (e) {
      print('❌ Yakındaki kullanıcılar yüklenirken hata: $e');
      return [];
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      print('🔍 MatchService: Tüm kullanıcılar yükleniyor...');

      final querySnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      print('📊 MatchService: ${querySnapshot.docs.length} kullanıcı bulundu');

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) =>
              user.id != FirebaseAuth.instance.currentUser?.uid &&
              user.displayName != null &&
              user.displayName!.isNotEmpty)
          .toList();

      print('✅ MatchService: ${users.length} kullanıcı filtrelendi');

      return users;
    } catch (e) {
      print('❌ Tüm kullanıcılar yüklenirken hata: $e');
      return [];
    }
  }

  Future<void> likeUser(String likedUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

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

      final otherUserDoc =
          await _firestore.collection('users').doc(likedUserId).get();
      if (otherUserDoc.exists) {
        final otherUserData = otherUserDoc.data()!;
        final otherUserPending =
            List<String>.from(otherUserData['pendingMatches'] ?? []);

        if (otherUserPending.contains(currentUser.uid)) {
          await _createMatch(currentUser.uid, likedUserId);
          return;
        }
      }

      final realTimestamp = await TimeService.getCurrentTime();

      await _firestore.collection('dm_requests').add({
        'fromUserId': currentUser.uid,
        'toUserId': likedUserId,
        'checkinId': '', // Like için boş
        'message': 'Seni beğendim 😊',
        'createdAt':
            Timestamp.fromDate(realTimestamp), // İnternetten alınan saat
        'status': 'pending',
        'type': 'like', // Like tipi DM isteği
      });

      await _firestore.collection('users').doc(currentUser.uid).update({
        'pendingMatches': FieldValue.arrayUnion([likedUserId]),
      });

      await _firestore.collection('users').doc(likedUserId).update({
        'receivedMatches': FieldValue.arrayUnion([currentUser.uid]),
      });

      print('DM isteği gönderildi: ${currentUser.uid} -> $likedUserId');
    } catch (e) {
      print('Kullanıcı beğenirken hata: $e');
    }
  }

  Future<void> dislikeUser(String dislikedUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('users').doc(currentUser.uid).update({
        'blockedUsers': FieldValue.arrayUnion([dislikedUserId]),
      });
    } catch (e) {
      print('Kullanıcı reddederken hata: $e');
    }
  }

  Future<void> _createMatch(String user1Id, String user2Id) async {
    try {
      await _firestore.collection('users').doc(user1Id).update({
        'pendingMatches': FieldValue.arrayRemove([user2Id]),
        'matchedUsers': FieldValue.arrayUnion([user2Id]),
      });

      await _firestore.collection('users').doc(user2Id).update({
        'receivedMatches': FieldValue.arrayRemove([user1Id]),
        'matchedUsers': FieldValue.arrayUnion([user1Id]),
      });

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

      await _createChat(user1Id, user2Id);

      print('Eşleşme oluşturuldu: $user1Id ve $user2Id');
    } catch (e) {
      print('Eşleşme oluşturulurken hata: $e');
    }
  }

  Future<void> _createChat(String user1Id, String user2Id) async {
    try {
      final chatId = [user1Id, user2Id]..sort();
      final chatIdString = chatId.join('_');

      final realTimestamp = await TimeService.getCurrentTime();

      await _firestore.collection('chats').doc(chatIdString).set({
        'user1Id': user1Id,
        'user2Id': user2Id,
        'createdAt':
            Timestamp.fromDate(realTimestamp), // İnternetten alınan saat
        'lastMessageAt':
            Timestamp.fromDate(realTimestamp), // İnternetten alınan saat
        'lastMessage': '',
        'isActive': true,
        'participants': [user1Id, user2Id],
      });
    } catch (e) {
      print('Chat oluşturulurken hata: $e');
    }
  }

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

  Future<void> acceptMatch(String matchedUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

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

  Future<void> rejectMatch(String rejectedUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

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

      await _firestore.collection('users').doc(currentUser.uid).update({
        'receivedMatches': FieldValue.arrayRemove([rejectedUserId]),
      });

      await _firestore.collection('users').doc(rejectedUserId).update({
        'pendingMatches': FieldValue.arrayRemove([currentUser.uid]),
      });
    } catch (e) {
      print('Eşleşme reddedilirken hata: $e');
    }
  }

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

  Future<void> sendMessage(String receiverId, String content) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

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

      final realTimestamp = await TimeService.getCurrentTime();

      final messageData = {
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'content': content,
        'timestamp':
            Timestamp.fromDate(realTimestamp), // İnternetten alınan saat
        'isRead': false,
        'messageType': 'text',
      };

      await _firestore.collection('messages').add(messageData);

      final chatId = [currentUser.uid, receiverId]..sort();
      final chatIdString = chatId.join('_');

      await _firestore.collection('chats').doc(chatIdString).update({
        'lastMessageAt':
            Timestamp.fromDate(realTimestamp), // İnternetten alınan saat
        'lastMessage': content,
      });
    } catch (e) {
      print('Mesaj gönderilirken hata: $e');
    }
  }

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
