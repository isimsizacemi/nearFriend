import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String phoneNumber;
  final String displayName;
  final String? photoURL;
  final String university;
  final String department;
  final int age;
  final String gender;
  final List<String> interests;
  final String? bio;
  final GeoPoint? location;
  final DateTime createdAt;
  final bool isVerified;
  final bool isBanned;
  final int verificationScore;
  final Map<String, dynamic>? privacySettings;
  final List<String> blockedUsers;
  final List<String> blockedBy;

  UserModel({
    required this.id,
    required this.email,
    required this.phoneNumber,
    required this.displayName,
    this.photoURL,
    required this.university,
    required this.department,
    required this.age,
    required this.gender,
    required this.interests,
    this.bio,
    this.location,
    required this.createdAt,
    required this.isVerified,
    required this.isBanned,
    required this.verificationScore,
    this.privacySettings,
    required this.blockedUsers,
    required this.blockedBy,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      displayName: data['displayName'] ?? '',
      photoURL: data['photoURL'],
      university: data['university'] ?? '',
      department: data['department'] ?? '',
      age: data['age'] ?? 0,
      gender: data['gender'] ?? '',
      interests: List<String>.from(data['interests'] ?? []),
      bio: data['bio'],
      location: data['location'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isVerified: data['isVerified'] ?? false,
      isBanned: data['isBanned'] ?? false,
      verificationScore: data['verificationScore'] ?? 0,
      privacySettings: data['privacySettings'],
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      blockedBy: List<String>.from(data['blockedBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoURL': photoURL,
      'university': university,
      'department': department,
      'age': age,
      'gender': gender,
      'interests': interests,
      'bio': bio,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'isVerified': isVerified,
      'isBanned': isBanned,
      'verificationScore': verificationScore,
      'privacySettings': privacySettings,
      'blockedUsers': blockedUsers,
      'blockedBy': blockedBy,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? photoURL,
    String? university,
    String? department,
    int? age,
    String? gender,
    List<String>? interests,
    String? bio,
    GeoPoint? location,
    DateTime? createdAt,
    bool? isVerified,
    bool? isBanned,
    int? verificationScore,
    Map<String, dynamic>? privacySettings,
    List<String>? blockedUsers,
    List<String>? blockedBy,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      university: university ?? this.university,
      department: department ?? this.department,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
      isBanned: isBanned ?? this.isBanned,
      verificationScore: verificationScore ?? this.verificationScore,
      privacySettings: privacySettings ?? this.privacySettings,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      blockedBy: blockedBy ?? this.blockedBy,
    );
  }
}
