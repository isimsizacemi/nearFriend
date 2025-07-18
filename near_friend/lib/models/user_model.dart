import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String displayName;
  final String? photoURL;
  final String email;
  final String university;
  final String department;
  final int age;
  final String gender;
  final List<String> interests;
  final String? bio;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isOnline;
  final GeoPoint? currentLocation;
  final List<String> blockedUsers;
  final List<String> matchedUsers;
  final List<String> pendingMatches;
  final List<String> receivedMatches;

  UserModel({
    required this.id,
    required this.displayName,
    this.photoURL,
    required this.email,
    required this.university,
    required this.department,
    required this.age,
    required this.gender,
    required this.interests,
    this.bio,
    required this.createdAt,
    required this.lastActiveAt,
    required this.isOnline,
    this.currentLocation,
    required this.blockedUsers,
    required this.matchedUsers,
    required this.pendingMatches,
    required this.receivedMatches,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      displayName: data['displayName'] ?? '',
      photoURL: data['photoURL'],
      email: data['email'] ?? '',
      university: data['university'] ?? '',
      department: data['department'] ?? '',
      age: data['age'] ?? 18,
      gender: data['gender'] ?? '',
      interests: List<String>.from(data['interests'] ?? []),
      bio: data['bio'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp).toDate(),
      isOnline: data['isOnline'] ?? false,
      currentLocation: data['currentLocation'],
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      matchedUsers: List<String>.from(data['matchedUsers'] ?? []),
      pendingMatches: List<String>.from(data['pendingMatches'] ?? []),
      receivedMatches: List<String>.from(data['receivedMatches'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'photoURL': photoURL,
      'email': email,
      'university': university,
      'department': department,
      'age': age,
      'gender': gender,
      'interests': interests,
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      'isOnline': isOnline,
      'currentLocation': currentLocation,
      'blockedUsers': blockedUsers,
      'matchedUsers': matchedUsers,
      'pendingMatches': pendingMatches,
      'receivedMatches': receivedMatches,
    };
  }

  UserModel copyWith({
    String? id,
    String? displayName,
    String? photoURL,
    String? email,
    String? university,
    String? department,
    int? age,
    String? gender,
    List<String>? interests,
    String? bio,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? isOnline,
    GeoPoint? currentLocation,
    List<String>? blockedUsers,
    List<String>? matchedUsers,
    List<String>? pendingMatches,
    List<String>? receivedMatches,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      email: email ?? this.email,
      university: university ?? this.university,
      department: department ?? this.department,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isOnline: isOnline ?? this.isOnline,
      currentLocation: currentLocation ?? this.currentLocation,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      matchedUsers: matchedUsers ?? this.matchedUsers,
      pendingMatches: pendingMatches ?? this.pendingMatches,
      receivedMatches: receivedMatches ?? this.receivedMatches,
    );
  }
}
