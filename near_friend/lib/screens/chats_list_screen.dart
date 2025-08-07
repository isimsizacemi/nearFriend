import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../models/dm_request_model.dart';
import 'chat_screen.dart';
import '../services/time_service.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({Key? key}) : super(key: key);

  @override
  _ChatsListScreenState createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _chats = [];
  final List<Map<String, dynamic>> _dmRequests = [];
  bool _isLoading = true;
  late TabController _tabController;
  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupStreams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatsSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  void _setupStreams() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _chatsSubscription = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _handleChatsUpdate(snapshot);
    });

    _requestsSubscription = FirebaseFirestore.instance
        .collection('dm_requests')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _handleRequestsUpdate(snapshot);
    });
  }

  Future<void> _handleChatsUpdate(QuerySnapshot snapshot) async {
    try {
      final List<Map<String, dynamic>> chats = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) continue;

        final otherUserId = (data['participants'] as List)
            .firstWhere((id) => id != currentUser.uid);

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();

        if (!userDoc.exists) continue;

        final otherUser = UserModel.fromFirestore(userDoc);
        chats.add({
          'id': doc.id,
          'lastMessage': data['lastMessage'] ?? '',
          'lastMessageAt': data['lastMessageAt'] as Timestamp?,
          'otherUser': otherUser,
          'unreadCount': data['unreadCount_${currentUser.uid}'] ?? 0,
        });
      }

      if (mounted) {
        setState(() {
          _chats.clear();
          _chats.addAll(chats);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Sohbetler yüklenirken hata: $e');
    }
  }

  Future<void> _handleRequestsUpdate(QuerySnapshot snapshot) async {
    try {
      final List<Map<String, dynamic>> requests = [];
      for (var doc in snapshot.docs) {
        final request = DMRequestModel.fromFirestore(doc);

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(request.fromUserId)
            .get();

        if (!userDoc.exists) continue;

        final fromUser = UserModel.fromFirestore(userDoc);
        requests.add({
          'request': request,
          'fromUser': fromUser,
        });
      }

      if (mounted) {
        setState(() {
          _dmRequests.clear();
          _dmRequests.addAll(requests);
        });
      }
    } catch (e) {
      print('DM istekleri yüklenirken hata: $e');
    }
  }

  Future<void> _handleDMRequest(DMRequestModel request, bool accept) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final chatId = [request.fromUserId, currentUser.uid]..sort();
      final chatIdString = chatId.join('_');

      if (accept) {
        final chatDoc = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatIdString)
            .get();

        if (!chatDoc.exists) {
          final realTimestamp = await TimeService.getCurrentTime();
          
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatIdString)
              .set({
            'participants': [request.fromUserId, currentUser.uid],
            'lastMessageAt': Timestamp.fromDate(realTimestamp), // İnternetten alınan saat
            'lastMessage': request.message,
            'isActive': true,
            'createdAt': Timestamp.fromDate(realTimestamp), // İnternetten alınan saat
          });
        }

        await FirebaseFirestore.instance
            .collection('dm_requests')
            .doc(request.id)
            .update({'status': 'accepted'});

        if (mounted) {
          final fromUser = (_dmRequests.firstWhere(
              (r) => r['request'].id == request.id)['fromUser'] as UserModel);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                otherUserId: request.fromUserId,
                otherUserName: fromUser.displayName ?? 'İsimsiz Kullanıcı',
              ),
            ),
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('dm_requests')
            .doc(request.id)
            .update({'status': 'rejected'});
      }
    } catch (e) {
      print('DM isteği işlenirken hata: $e');
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inMinutes < 1) {
      return 'Şimdi';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}d';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}s';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}g';
    } else {
      return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
    }
  }

  Widget _buildDMRequestItem(Map<String, dynamic> requestData) {
    final request = requestData['request'] as DMRequestModel;
    final fromUser = requestData['fromUser'] as UserModel;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: fromUser.photoURL != null
            ? CachedNetworkImageProvider(fromUser.photoURL!)
            : const AssetImage('assets/images/avatars/male1.png')
                as ImageProvider,
      ),
      title: Text(fromUser.displayName ?? 'İsimsiz Kullanıcı'),
      subtitle: Text(
        request.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () => _handleDMRequest(request, true),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => _handleDMRequest(request, false),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final otherUser = chat['otherUser'] as UserModel;
    final unreadCount = chat['unreadCount'] as int;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: otherUser.getProfileImageProvider(),
      ),
      title: Text(otherUser.displayName ?? 'İsimsiz Kullanıcı'),
      subtitle: Text(
        chat['lastMessage'] as String? ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_formatTime(chat['lastMessageAt'])),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              otherUserId: otherUser.id,
              otherUserName: otherUser.displayName ?? 'İsimsiz Kullanıcı',
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalUnread = 0;
    for (final chat in _chats) {
      totalUnread += (chat['unreadCount'] as int? ?? 0);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesajlar'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sohbetler'),
                  const SizedBox(width: 4),
                  if (totalUnread > 0)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColorLight,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        totalUnread.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('İstekler'),
                  const SizedBox(width: 4),
                  if (_dmRequests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColorLight,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _dmRequests.length.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _chats.isEmpty
                    ? const Center(child: Text('Henüz aktif sohbet yok'))
                    : ListView.builder(
                        itemCount: _chats.length,
                        itemBuilder: (context, index) =>
                            _buildChatItem(_chats[index]),
                      ),

                _dmRequests.isEmpty
                    ? const Center(child: Text('Henüz mesaj isteği yok'))
                    : ListView.builder(
                        itemCount: _dmRequests.length,
                        itemBuilder: (context, index) =>
                            _buildDMRequestItem(_dmRequests[index]),
                      ),
              ],
            ),
    );
  }
}
