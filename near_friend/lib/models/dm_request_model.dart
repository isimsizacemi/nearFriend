import 'package:cloud_firestore/cloud_firestore.dart';

class DMRequestModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String checkinId;
  final String message;
  final String status; // pending, accepted, rejected
  final String? type; // like, checkin, etc.
  final DateTime createdAt;

  DMRequestModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.checkinId,
    required this.message,
    required this.status,
    this.type,
    required this.createdAt,
  });

  factory DMRequestModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DMRequestModel(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      checkinId: data['checkinId'] ?? '',
      message: data['message'] ?? '',
      status: data['status'] ?? 'pending',
      type: data['type'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'checkinId': checkinId,
      'message': message,
      'status': status,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  DMRequestModel copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? checkinId,
    String? message,
    String? status,
    String? type,
    DateTime? createdAt,
  }) {
    return DMRequestModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      checkinId: checkinId ?? this.checkinId,
      message: message ?? this.message,
      status: status ?? this.status,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
