import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/checkin_model.dart';
import '../services/auth_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final AuthService _authService = AuthService();
  Position? _currentPosition;
  bool _isLoading = true;
  List<CheckinModel> _checkins = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Konum izni kontrol et
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }

      // Mevcut konumu al
      _currentPosition = await Geolocator.getCurrentPosition();
      await _loadNearbyCheckins();
    } catch (e) {
      print('Konum alınırken hata: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNearbyCheckins() async {
    if (_currentPosition == null) return;

    try {
      // 30km yarıçaptaki check-in'leri al
      final query = FirebaseFirestore.instance
          .collection('checkins')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(50);

      final snapshot = await query.get();
      final checkins =
          snapshot.docs.map((doc) => CheckinModel.fromFirestore(doc)).toList();

      // Konum bazlı filtreleme ve sıralama
      checkins.removeWhere((checkin) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          checkin.location.latitude,
          checkin.location.longitude,
        );
        return distance > 30000; // 30km'den uzak olanları çıkar
      });

      // Yakından uzağa sırala
      checkins.sort((a, b) {
        final distanceA = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a.location.latitude,
          a.location.longitude,
        );
        final distanceB = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b.location.latitude,
          b.location.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

      setState(() {
        _checkins = checkins;
      });
    } catch (e) {
      print('Check-in\'ler yüklenirken hata: $e');
    }
  }

  double _getDistance(CheckinModel checkin) {
    if (_currentPosition == null) return 0;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      checkin.location.latitude,
      checkin.location.longitude,
    );
  }

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else {
      return '${difference.inDays} gün önce';
    }
  }

  Future<void> _likeCheckin(CheckinModel checkin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final isLiked = checkin.likes.contains(user.uid);
      final newLikes = List<String>.from(checkin.likes);

      if (isLiked) {
        newLikes.remove(user.uid);
      } else {
        newLikes.add(user.uid);
      }

      await FirebaseFirestore.instance
          .collection('checkins')
          .doc(checkin.id)
          .update({'likes': newLikes});

      // UI'ı güncelle
      setState(() {
        final index = _checkins.indexWhere((c) => c.id == checkin.id);
        if (index != -1) {
          _checkins[index] = checkin.copyWith(likes: newLikes);
        }
      });
    } catch (e) {
      print('Beğeni işlemi başarısız: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yakındaki Paylaşımlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNearbyCheckins,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _checkins.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Yakınında henüz paylaşım yok',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'İlk check-in\'ini sen yap!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNearbyCheckins,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _checkins.length,
                    itemBuilder: (context, index) {
                      final checkin = _checkins[index];
                      final distance = _getDistance(checkin);
                      final isLiked = checkin.likes
                          .contains(FirebaseAuth.instance.currentUser?.uid);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kullanıcı bilgileri
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: checkin.userPhotoURL !=
                                            null
                                        ? NetworkImage(checkin.userPhotoURL!)
                                        : null,
                                    child: checkin.userPhotoURL == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          checkin.userDisplayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on,
                                                size: 16,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              checkin.locationName,
                                              style: TextStyle(
                                                  color: Colors.grey[600]),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatDistance(distance),
                                              style: const TextStyle(
                                                color: Colors.deepPurple,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatTimeAgo(checkin.createdAt),
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Mesaj
                              Text(
                                checkin.message,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 12),

                              // Etkileşim butonları
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isLiked ? Colors.red : null,
                                    ),
                                    onPressed: () => _likeCheckin(checkin),
                                  ),
                                  Text('${checkin.likes.length}'),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.comment),
                                    onPressed: () {
                                      // Yorum ekranına git
                                    },
                                  ),
                                  Text('${checkin.comments.length}'),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.message),
                                    onPressed: () {
                                      // DM ekranına git
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
