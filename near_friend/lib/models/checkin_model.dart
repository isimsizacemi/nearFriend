import 'package:cloud_firestore/cloud_firestore.dart';

class CheckinModel {
  final String id;
  final String userId;
  final String userDisplayName;
  final String? userPhotoURL;
  final String message;
  final GeoPoint location;
  final String locationName;
  final DateTime createdAt;
  final List<String> likes;
  final List<String> comments;
  final Map<String, dynamic>? privacySettings;
  final bool isActive;

  CheckinModel({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    this.userPhotoURL,
    required this.message,
    required this.location,
    required this.locationName,
    required this.createdAt,
    required this.likes,
    required this.comments,
    this.privacySettings,
    required this.isActive,
  });

  factory CheckinModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CheckinModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      userPhotoURL: data['userPhotoURL'],
      message: data['message'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      locationName: data['locationName'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      likes: List<String>.from(data['likes'] ?? []),
      comments: List<String>.from(data['comments'] ?? []),
      privacySettings: data['privacySettings'],
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userPhotoURL': userPhotoURL,
      'message': message,
      'location': location,
      'locationName': locationName,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'comments': comments,
      'privacySettings': privacySettings,
      'isActive': isActive,
    };
  }

  CheckinModel copyWith({
    String? id,
    String? userId,
    String? userDisplayName,
    String? userPhotoURL,
    String? message,
    GeoPoint? location,
    String? locationName,
    DateTime? createdAt,
    List<String>? likes,
    List<String>? comments,
    Map<String, dynamic>? privacySettings,
    bool? isActive,
  }) {
    return CheckinModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userPhotoURL: userPhotoURL ?? this.userPhotoURL,
      message: message ?? this.message,
      location: location ?? this.location,
      locationName: locationName ?? this.locationName,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      privacySettings: privacySettings ?? this.privacySettings,
      isActive: isActive ?? this.isActive,
    );
  }
}
