import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String messageType; // 'text', 'image', 'location'
  final String? imageURL;
  final GeoPoint? location;
  final String? checkinId;
  final Map<String, dynamic>? checkinData;
  final bool delivered;
  final bool read;
  final DateTime? readAt; // Okundu zamanı

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    required this.isRead,
    required this.messageType,
    this.imageURL,
    this.location,
    this.checkinId,
    this.checkinData,
    this.delivered = false,
    this.read = false,
    this.readAt,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      messageType: data['messageType'] ?? 'text',
      imageURL: data['imageURL'],
      location: data['location'],
      checkinId: data['checkinId'],
      checkinData: data['checkinData'],
      delivered: data['delivered'] ?? false,
      read: data['read'] ?? false,
      readAt: data['readAt'] != null ? (data['readAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'messageType': messageType,
      'imageURL': imageURL,
      'location': location,
      'checkinId': checkinId,
      'checkinData': checkinData,
      'delivered': delivered,
      'read': read,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    String? messageType,
    String? imageURL,
    GeoPoint? location,
    String? checkinId,
    Map<String, dynamic>? checkinData,
    bool? delivered,
    bool? read,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      messageType: messageType ?? this.messageType,
      imageURL: imageURL ?? this.imageURL,
      location: location ?? this.location,
      checkinId: checkinId ?? this.checkinId,
      checkinData: checkinData ?? this.checkinData,
      delivered: delivered ?? this.delivered,
      read: read ?? this.read,
    );
  }
}

class ChatModel {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String lastMessage;
  final bool isActive;
  final List<String> participants;

  ChatModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.createdAt,
    required this.lastMessageAt,
    required this.lastMessage,
    required this.isActive,
    required this.participants,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      user1Id: data['user1Id'] ?? '',
      user2Id: data['user2Id'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp).toDate(),
      lastMessage: data['lastMessage'] ?? '',
      isActive: data['isActive'] ?? true,
      participants: List<String>.from(data['participants'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user1Id': user1Id,
      'user2Id': user2Id,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'lastMessage': lastMessage,
      'isActive': isActive,
      'participants': participants,
    };
  }
}
