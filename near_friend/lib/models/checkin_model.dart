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
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
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
              // GeoPoint map olarak gelmiş, GeoPoint'e çevir
              var geoMap = locationData['geopoint'] as Map;
              locationData['geopoint'] = GeoPoint(
                (geoMap['latitude'] as num).toDouble(),
                (geoMap['longitude'] as num).toDouble(),
              );
            }
          } else if (data['location'] is GeoPoint) {
            final geoPoint = data['location'] as GeoPoint;
            locationData = {
              'geohash': '',
              'geopoint': geoPoint,
            };
          }
        }

        // Varsayılan değer
        if (locationData.isEmpty || locationData['geopoint'] == null) {
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
          // Timestamp map olarak gelmiş olabilir
          var timestampMap = data['createdAt'] as Map;
          createdAtDate = DateTime.fromMillisecondsSinceEpoch(
            ((timestampMap['seconds'] as num) * 1000 +
                    (timestampMap['nanoseconds'] as num) / 1000000)
                .round(),
          );
        } else {
          createdAtDate = DateTime.now();
        }
      } catch (e) {
        print('createdAt dönüştürme hatası: $e');
        createdAtDate = DateTime.now();
      }

      var model = CheckinModel(
        id: doc.id,
        userId: data['userId'] ?? '',
        userDisplayName: data['userDisplayName'] ?? '',
        userPhotoURL: data['userPhotoURL'],
        message: data['message'] ?? '',
        location: locationData,
        locationName: data['locationName'] ?? '',
        createdAt: createdAtDate,
        likes: List<String>.from(data['likes'] ?? []),
        comments: List<String>.from(data['comments'] ?? []),
        privacySettings: data['privacySettings'],
        isActive: data['isActive'] ?? true,
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
