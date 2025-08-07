import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../services/time_service.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    Key? key,
    required this.otherUserId,
    required this.otherUserName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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

    _messagesSubscription = messagesQuery.snapshots().listen(
      (snapshot) async {
        if (snapshot.docs.isEmpty) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }

        final messages = snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList();

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (data['receiverId'] == currentUser.uid) {
              if (data['delivered'] != true) {
                doc.reference.update({'delivered': true});
              }

              if (data['read'] != true) {
                doc.reference.update({'read': true});
              }
            }
          }
        }

        if (mounted) {
          final previousLength = _messages.length;

          setState(() {
            for (var msg in messages) {
              if (!_messages.any((m) => m.id == msg.id)) {
                _messages.add(msg);
              }
            }
            _lastDocument = snapshot.docs.last;
            _isLoading = false;
          });

          if (_messages.length > previousLength) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        }
      },
      onError: (error) {
        print('Mesaj stream hatası: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
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

  Future<void> _markMessagesAsReadInRealTime() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final chatId = _getChatId();

      final unreadMessages = _messages
          .where((msg) => msg.receiverId == currentUser.uid && !msg.read)
          .toList();

      final batch = FirebaseFirestore.instance.batch();

      for (var message in unreadMessages) {
        final messageRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(message.id);
        batch.update(messageRef, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(), // Okundu zamanı
        });
      }

      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'unreadCount_${currentUser.uid}': 0,
      });

      await batch.commit();

      print('✅ ${unreadMessages.length} mesaj anlık olarak okundu işaretlendi');
    } catch (e) {
      print('❌ Anlık okundu işaretleme hatası: $e');
    }
  }

  Future<void> _markChatAsReadAndDelivered() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final chatId = _getChatId();
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'unreadCount_${currentUser.uid}': 0,
      });

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
      final realTimestamp = await TimeService.getCurrentTime();

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
        timestamp: realTimestamp, // İnternetten alınan gerçek saat
        isRead: false,
        delivered: true, // Mesaj gönderildiğinde delivered=true
        read: false,
        messageType: 'text',
      );

      batch.set(messageRef, message.toFirestore());

      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);
      batch.set(
          chatRef,
          {
            'lastMessage': messageText,
            'lastMessageAt':
                Timestamp.fromDate(realTimestamp), // İnternetten alınan saat
            'participants': [currentUser.uid, widget.otherUserId],
            'isActive': true,
            'unreadCount_${widget.otherUserId}': FieldValue.increment(1),
          },
          SetOptions(merge: true));

      await batch.commit();

      print('✅ Mesaj gönderildi - Gerçek saat: $realTimestamp');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('❌ Mesaj gönderilirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesaj gönderilemedi. Lütfen tekrar deneyin.'),
        ),
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
        statusIcon = const Icon(Icons.done_all, color: Colors.blue, size: 16);
      } else if (message.delivered) {
        statusIcon = const Icon(Icons.done_all, color: Colors.grey, size: 16);
      } else {
        statusIcon = const Icon(Icons.check, color: Colors.grey, size: 16);
      }
    }

    Widget bubble = Container(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isMe ? 64 : 16,
        right: isMe ? 16 : 64,
      ),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0084FF) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
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
                if (isMe) ...[const SizedBox(width: 4), statusIcon],
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
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
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Detay Geçici Devre Dışı')),
                body: const Center(
                  child: Text('CheckinDetailScreen geçici olarak devre dışı'),
                ),
              ), // CheckinDetailScreen geçici devre dışı
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
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Dün ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate.isAfter(today.subtract(const Duration(days: 7)))) {
      final weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      final weekday = weekdays[timestamp.weekday - 1];
      return '$weekday ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day.toString().padLeft(2, '0')}.${timestamp.month.toString().padLeft(2, '0')}.${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
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
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                Theme.of(context).textTheme.titleLarge?.color ??
                                    Colors.black,
                          ),
                        ),
                        if (_otherUser!.university != null)
                          Text(
                            _otherUser!.university!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey,
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
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Mesaj yazın...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      onChanged: (_) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0084FF),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
