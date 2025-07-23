import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final String? photoURL;
  final String? bio;
  final String? university;
  final int? age;
  final String? gender;
  final bool hasCreatedProfile;
  final bool isActive;
  final List<String> interests;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
  final bool isOnline;
  final GeoPoint? currentLocation;
  final Map<String, dynamic>? location;
  final List<String> blockedUsers;
  final List<String> matchedUsers;
  final List<String> pendingMatches;
  final List<String> receivedMatches;

  UserModel({
    required this.id,
    this.displayName,
    this.email,
    this.phoneNumber,
    this.photoURL,
    this.bio,
    this.university,
    this.age,
    this.gender,
    this.hasCreatedProfile = false,
    this.isActive = true,
    List<String>? interests,
    this.createdAt,
    this.lastActiveAt,
    this.isOnline = false,
    this.currentLocation,
    this.location,
    List<String>? blockedUsers,
    List<String>? matchedUsers,
    List<String>? pendingMatches,
    List<String>? receivedMatches,
  })  : interests = interests ?? [],
        blockedUsers = blockedUsers ?? [],
        matchedUsers = matchedUsers ?? [],
        pendingMatches = pendingMatches ?? [],
        receivedMatches = receivedMatches ?? [];

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return UserModel(
      id: doc.id,
      displayName: data['displayName'],
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      photoURL: data['photoURL'],
      bio: data['bio'],
      university: data['university'],
      age: data['age'],
      gender: data['gender'],
      hasCreatedProfile: data['hasCreatedProfile'] ?? false,
      isActive: data['isActive'] ?? true,
      interests: List<String>.from(data['interests'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
      isOnline: data['isOnline'] ?? false,
      currentLocation: data['currentLocation'] as GeoPoint?,
      location: data['location'] as Map<String, dynamic>?,
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      matchedUsers: List<String>.from(data['matchedUsers'] ?? []),
      pendingMatches: List<String>.from(data['pendingMatches'] ?? []),
      receivedMatches: List<String>.from(data['receivedMatches'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'bio': bio,
      'university': university,
      'age': age,
      'gender': gender,
      'hasCreatedProfile': hasCreatedProfile,
      'isActive': isActive,
      'interests': interests,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'lastActiveAt':
          lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'isOnline': isOnline,
      'currentLocation': currentLocation,
      'location': location,
      'blockedUsers': blockedUsers,
      'matchedUsers': matchedUsers,
      'pendingMatches': pendingMatches,
      'receivedMatches': receivedMatches,
    };
  }

  UserModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? phoneNumber,
    String? photoURL,
    String? bio,
    String? university,
    int? age,
    String? gender,
    bool? hasCreatedProfile,
    bool? isActive,
    List<String>? interests,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? isOnline,
    GeoPoint? currentLocation,
    Map<String, dynamic>? location,
    List<String>? blockedUsers,
    List<String>? matchedUsers,
    List<String>? pendingMatches,
    List<String>? receivedMatches,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      bio: bio ?? this.bio,
      university: university ?? this.university,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      hasCreatedProfile: hasCreatedProfile ?? this.hasCreatedProfile,
      isActive: isActive ?? this.isActive,
      interests: interests ?? this.interests,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isOnline: isOnline ?? this.isOnline,
      currentLocation: currentLocation ?? this.currentLocation,
      location: location ?? this.location,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      matchedUsers: matchedUsers ?? this.matchedUsers,
      pendingMatches: pendingMatches ?? this.pendingMatches,
      receivedMatches: receivedMatches ?? this.receivedMatches,
    );
  }

  String? get displayPhotoAssetOrUrl {
    if (photoURL == null || photoURL!.isEmpty) {
      return 'assets/images/default_avatar.png';
    }
    if (photoURL!.startsWith('assets/')) {
      return photoURL;
    }
    return photoURL;
  }

  ImageProvider getProfileImageProvider() {
    if (photoURL == null || photoURL!.isEmpty) {
      return const AssetImage('assets/images/default_avatar.png');
    }
    if (photoURL!.startsWith('assets/')) {
      return AssetImage(photoURL!);
    }
    if (photoURL!.startsWith('http')) {
      return NetworkImage(photoURL!);
    }
    return const AssetImage('assets/images/default_avatar.png');
  }
}
