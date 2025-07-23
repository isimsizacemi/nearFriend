import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../screens/checkin_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    Key? key,
    required this.otherUserId,
    required this.otherUserName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  UserModel? _otherUser;
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupMessagesStream();
    _markChatAsReadAndDelivered();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMoreMessages();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  String _getChatId() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return '';

    final List<String> ids = [currentUser.uid, widget.otherUserId];
    ids.sort();
    return ids.join('_');
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (!userDoc.exists) return;

      final user = UserModel.fromFirestore(userDoc);

      if (mounted) {
        setState(() {
          _otherUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Kullanıcı bilgileri yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupMessagesStream() {
    final chatId = _getChatId();
    final messagesQuery = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    _messagesSubscription = messagesQuery.snapshots().listen((snapshot) async {
      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final messages =
          snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList();

      // Gelen mesajlar için delivered güncellemesi
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['receiverId'] == currentUser.uid &&
              data['delivered'] != true) {
            doc.reference.update({'delivered': true});
          }
        }
      }

      if (mounted) {
        setState(() {
          for (var msg in messages) {
            if (!_messages.any((m) => m.id == msg.id)) {
              _messages.add(msg);
            }
          }
          _lastDocument = snapshot.docs.last;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print('Mesaj stream hatası: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || _lastDocument == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final chatId = _getChatId();
      final messagesQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      if (messagesQuery.docs.isEmpty) {
        setState(() {
          _isLoadingMore = false;
        });
        return;
      }

      final messages = messagesQuery.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

      setState(() {
        _messages.addAll(messages);
        _lastDocument = messagesQuery.docs.last;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Daha fazla mesaj yüklenirken hata: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _markChatAsReadAndDelivered() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final chatId = _getChatId();
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .update({'unreadCount_${currentUser.uid}': 0});

      // Tüm karşı tarafın göndermiş olduğu ve delivered=false olan mesajları iletildi olarak işaretle
      final deliveredQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('delivered', isEqualTo: false)
          .get();
      for (var doc in deliveredQuery.docs) {
        doc.reference.update({'delivered': true});
      }

      // Tüm karşı tarafın göndermiş olduğu ve read=false olan mesajları okundu olarak işaretle
      final readQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .get();
      for (var doc in readQuery.docs) {
        doc.reference.update({'read': true});
      }
    } catch (e) {
      print('Sohbet okundu/iletildi olarak işaretlenirken hata: $e');
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _messageController.clear();

    try {
      final chatId = _getChatId();
      final batch = FirebaseFirestore.instance.batch();
      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      final message = MessageModel(
        id: messageRef.id,
        senderId: currentUser.uid,
        receiverId: widget.otherUserId,
        content: messageText,
        timestamp: DateTime.now(),
        isRead: false,
        delivered: true, // Mesaj gönderildiğinde delivered=true
        read: false,
        messageType: 'text',
      );

      batch.set(messageRef, message.toFirestore());

      // Update chat document
      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);
      batch.set(
          chatRef,
          {
            'lastMessage': messageText,
            'lastMessageAt': FieldValue.serverTimestamp(),
            'participants': [currentUser.uid, widget.otherUserId],
            'isActive': true,
            'unreadCount_${widget.otherUserId}': FieldValue.increment(1),
          },
          SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      print('Mesaj gönderilirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Mesaj gönderilemedi. Lütfen tekrar deneyin.')),
      );
    }
  }

  Widget _buildMessageBubble(MessageModel message) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final isMe = message.senderId == currentUser.uid;

    Widget statusIcon = const SizedBox.shrink();
    if (isMe) {
      if (message.read) {
        statusIcon = const Icon(Icons.done_all, color: Colors.amber, size: 16);
      } else if (message.delivered) {
        statusIcon = const Icon(Icons.done_all, color: Colors.grey, size: 16);
      } else {
        statusIcon = const Icon(Icons.check, color: Colors.grey, size: 16);
      }
    }

    Widget bubble = Container(
      margin: EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: isMe ? 64 : 16,
        right: isMe ? 16 : 64,
      ),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                      fontSize: 16,
                      decoration: message.checkinId != null
                          ? TextDecoration.underline
                          : null,
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  statusIcon,
                ]
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );

    if (message.checkinId != null) {
      bubble = GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CheckinDetailScreen(
                checkinId: message.checkinId!,
                checkin: null,
              ),
            ),
          );
        },
        child: bubble,
      );
    }
    return bubble;
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Dün ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _otherUser != null
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: _otherUser!.getProfileImageProvider(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _otherUser!.displayName ?? 'İsimsiz Kullanıcı',
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (_otherUser!.university != null)
                          Text(
                            _otherUser!.university!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : Text(widget.otherUserName),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('Henüz mesaj yok'))
                    : Builder(
                        builder: (context) {
                          final sortedMessages = List<MessageModel>.from(
                              _messages)
                            ..sort(
                                (a, b) => a.timestamp.compareTo(b.timestamp));
                          return ListView.builder(
                            controller: _scrollController,
                            reverse: false,
                            itemCount: sortedMessages.length +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isLoadingMore &&
                                  index == sortedMessages.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return _buildMessageBubble(sortedMessages[index]);
                            },
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Mesaj yazın...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
