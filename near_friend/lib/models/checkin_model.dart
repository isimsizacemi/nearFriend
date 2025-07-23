import 'package:cloud_firestore/cloud_firestore.dart';

class CheckinModel {
  final String id;
  final String userId;
  final String userDisplayName;
  final String? userPhotoURL;
  final String message;
  final Map<String, dynamic> location;
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
    try {
      Map<String, dynamic> data;
      try {
        data = doc.data() as Map<String, dynamic>;
      } catch (e) {
        print('CheckinModel.fromFirestore: doc.data() parse hatası: $e');
        data = {};
      }
      print('=== CHECKIN MODEL DEBUG ===');
      print('Doküman ID: ${doc.id}');
      print('Ham veri: $data');

      // Location verisini güvenli şekilde işle
      Map<String, dynamic> locationData = {};
      try {
        if (data['location'] != null) {
          if (data['location'] is Map<String, dynamic>) {
            locationData = Map<String, dynamic>.from(data['location']);
            // GeoPoint kontrolü
            if (locationData['geopoint'] is GeoPoint) {
              // Zaten GeoPoint, bir şey yapmaya gerek yok
            } else if (locationData['geopoint'] is Map) {
              var geoMap = locationData['geopoint'] as Map;
              locationData['geopoint'] = GeoPoint(
                (geoMap['latitude'] as num? ?? 0).toDouble(),
                (geoMap['longitude'] as num? ?? 0).toDouble(),
              );
            } else {
              locationData['geopoint'] = const GeoPoint(0, 0);
            }
          } else if (data['location'] is GeoPoint) {
            final geoPoint = data['location'] as GeoPoint;
            locationData = {
              'geohash': '',
              'geopoint': geoPoint,
            };
          } else {
            locationData = {
              'geohash': '',
              'geopoint': const GeoPoint(0, 0),
            };
          }
        } else {
          locationData = {
            'geohash': '',
            'geopoint': const GeoPoint(0, 0),
          };
        }
      } catch (e) {
        print('Location verisi işlenirken hata: $e');
        print('Problemli location verisi: ${data['location']}');
        locationData = {
          'geohash': '',
          'geopoint': const GeoPoint(0, 0),
        };
      }

      // createdAt kontrolü
      DateTime createdAtDate;
      try {
        if (data['createdAt'] is Timestamp) {
          createdAtDate = (data['createdAt'] as Timestamp).toDate();
        } else if (data['createdAt'] is Map) {
          var timestampMap = data['createdAt'] as Map;
          final seconds = (timestampMap['seconds'] as num?) ?? 0;
          final nanoseconds = (timestampMap['nanoseconds'] as num?) ?? 0;
          createdAtDate = DateTime.fromMillisecondsSinceEpoch(
            (seconds * 1000 + nanoseconds / 1000000).round(),
          );
        } else if (data['createdAt'] is int) {
          createdAtDate =
              DateTime.fromMillisecondsSinceEpoch(data['createdAt']);
        } else {
          createdAtDate = DateTime.now();
        }
      } catch (e) {
        print('createdAt dönüştürme hatası: $e');
        createdAtDate = DateTime.now();
      }

      List<String> likes = [];
      try {
        likes = List<String>.from(data['likes'] ?? []);
      } catch (e) {
        print('likes alanı hatalı: $e');
        likes = [];
      }
      List<String> comments = [];
      try {
        comments = List<String>.from(data['comments'] ?? []);
      } catch (e) {
        print('comments alanı hatalı: $e');
        comments = [];
      }

      var model = CheckinModel(
        id: doc.id,
        userId: data['userId']?.toString() ?? '',
        userDisplayName: data['userDisplayName']?.toString() ?? '',
        userPhotoURL: data['userPhotoURL']?.toString(),
        message: data['message']?.toString() ?? '',
        location: locationData,
        locationName: data['locationName']?.toString() ?? '',
        createdAt: createdAtDate,
        likes: likes,
        comments: comments,
        privacySettings: data['privacySettings'] is Map<String, dynamic>
            ? data['privacySettings']
            : null,
        isActive: data['isActive'] is bool ? data['isActive'] : true,
      );

      print('Dönüştürülen model:');
      print('- ID: ${model.id}');
      print('- Kullanıcı: ${model.userDisplayName}');
      print('- Mesaj: ${model.message}');
      print('- Konum: ${model.locationName}');
      print('- Tarih: ${model.createdAt}');
      print('========================');

      return model;
    } catch (e) {
      print('CheckinModel.fromFirestore hatası: $e');
      print('Hatalı doküman ID: ${doc.id}');
      print('Ham veri: ${doc.data()}');
      // Hata durumunda varsayılan değerlerle döndür
      return CheckinModel(
        id: doc.id,
        userId: '',
        userDisplayName: '',
        userPhotoURL: null,
        message: '',
        location: {'geohash': '', 'geopoint': const GeoPoint(0, 0)},
        locationName: '',
        createdAt: DateTime.now(),
        likes: [],
        comments: [],
        privacySettings: null,
        isActive: true,
      );
    }
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

  GeoPoint get geoPoint {
    if (location['geopoint'] is GeoPoint) {
      return location['geopoint'] as GeoPoint;
    }
    // Varsayılan değer
    return const GeoPoint(0, 0);
  }

  CheckinModel copyWith({
    String? id,
    String? userId,
    String? userDisplayName,
    String? userPhotoURL,
    String? message,
    Map<String, dynamic>? location,
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
