import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/checkin_model.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'checkin_detail_screen.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FakeDoc implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  FakeDoc(this._data);
  @override
  Map<String, dynamic>? data([options]) => _data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FeedScreen extends StatefulWidget {
  final bool useScaffold;

  const FeedScreen({
    super.key,
    this.useScaffold = true,
  });

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  final AuthService _authService = AuthService();
  Position? _currentPosition;
  bool _isLoading = true;
  List<CheckinModel> _checkins = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isPaginating = false;
  static const _pageSize = 20;

  // Önbellek için sabitler
  static const String _cacheKey = 'feed_checkins_cache';
  static const String _cacheTimeKey = 'feed_checkins_cache_time';
  static const Duration _cacheDuration = Duration(minutes: 5);

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNearbyCheckins(initial: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isPaginating &&
        _hasMore &&
        !_isLoading) {
      _loadNearbyCheckins();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Mevcut konumu al
      _currentPosition = await Geolocator.getCurrentPosition();
      await _loadNearbyCheckins();
    } catch (e) {
      print('Konum alınırken hata: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNearbyCheckins({bool initial = false}) async {
    if (_currentPosition == null) return;
    if (initial) {
      setState(() {
        _isLoading = true;
        _checkins = [];
        _lastDoc = null;
        _hasMore = true;
      });
    } else {
      setState(() {
        _isPaginating = true;
      });
    }

    try {
      print('=== FEED SCREEN DEBUG ===');
      print(
          'Konum: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

      final collectionRef = FirebaseFirestore.instance.collection('checkins');

      // Önce önbellekten yükle
      if (initial) {
        await _loadFromCache();
      }

      // Firestore sorgusu
      Query query = collectionRef
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      query = query.limit(_pageSize);

      // Sorguyu çalıştır
      final QuerySnapshot snapshot = await query.get(
        const GetOptions(source: Source.serverAndCache),
      );

      final docs = snapshot.docs;
      print('Bulunan toplam gönderi: ${docs.length}');

      if (docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
          _isPaginating = false;
        });
        return;
      }

      // Gönderileri dönüştür
      final newCheckins = docs
          .map((doc) {
            try {
              return CheckinModel.fromFirestore(doc);
            } catch (e) {
              print('Gönderi dönüştürme hatası: $e');
              print('Hatalı doküman: ${doc.id}');
              print('Doküman verisi: ${doc.data()}');
              return null;
            }
          })
          .where((checkin) => checkin != null)
          .cast<CheckinModel>()
          .toList();

      // Mesafe hesapla ve filtreleme
      newCheckins.removeWhere((checkin) {
        if (checkin.location['geopoint'] == null) return true;
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          checkin.geoPoint.latitude,
          checkin.geoPoint.longitude,
        );
        return distance > 30000; // 30km'den uzak olanları filtrele
      });

      print('Dönüştürülen gönderi sayısı: ${newCheckins.length}');
      for (var checkin in newCheckins) {
        print(
            '- ${checkin.userDisplayName}: ${checkin.message} (${checkin.createdAt})');
      }

      // Durumu güncelle
      setState(() {
        if (initial) {
          _checkins = newCheckins;
          // Önbelleğe kaydet
          _saveToCache(_checkins);
        } else {
          _checkins.addAll(newCheckins);
        }
        if (docs.isNotEmpty) {
          _lastDoc = docs.last;
        }
        _isLoading = false;
        _isPaginating = false;
      });
    } catch (e) {
      print('Gönderiler yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
        _isPaginating = false;
      });
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_cacheTimeKey);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (cacheTime != null &&
          now - cacheTime < _cacheDuration.inMilliseconds) {
        final cacheData = prefs.getString(_cacheKey);
        if (cacheData != null) {
          final List<dynamic> jsonList = json.decode(cacheData);
          final cachedCheckins = jsonList
              .map((e) {
                try {
                  // GeoPoint dönüşümü
                  if (e['location'] != null &&
                      e['location']['geopoint'] != null) {
                    final geoPoint = e['location']['geopoint'];
                    if (geoPoint is Map) {
                      e['location']['geopoint'] = {
                        'latitude': geoPoint['latitude'],
                        'longitude': geoPoint['longitude'],
                      };
                    }
                  }
                  // Timestamp dönüşümü
                  if (e['createdAt'] != null) {
                    final timestamp = e['createdAt'];
                    if (timestamp is Map) {
                      e['createdAt'] = {
                        'seconds': timestamp['seconds'],
                        'nanoseconds': timestamp['nanoseconds'],
                      };
                    }
                  }
                  return CheckinModel.fromFirestore(FakeDoc(e));
                } catch (e) {
                  print('Önbellekten dönüştürme hatası: $e');
                  return null;
                }
              })
              .where((checkin) => checkin != null)
              .cast<CheckinModel>()
              .toList();

          setState(() {
            _checkins = cachedCheckins;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Önbellekten yükleme hatası: $e');
    }
  }

  Future<void> _saveToCache(List<CheckinModel> checkins) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = checkins.map((c) {
        final data = c.toFirestore();
        // GeoPoint'i JSON'a çevrilebilir hale getir
        if (data['location'] != null &&
            data['location']['geopoint'] is GeoPoint) {
          final geoPoint = data['location']['geopoint'] as GeoPoint;
          data['location']['geopoint'] = {
            'latitude': geoPoint.latitude,
            'longitude': geoPoint.longitude,
          };
        }
        // Timestamp'i JSON'a çevrilebilir hale getir
        if (data['createdAt'] is Timestamp) {
          final timestamp = data['createdAt'] as Timestamp;
          data['createdAt'] = {
            'seconds': timestamp.seconds,
            'nanoseconds': timestamp.nanoseconds,
          };
        }
        return data;
      }).toList();

      await prefs.setString(_cacheKey, json.encode(jsonList));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Önbelleğe kaydetme hatası: $e');
    }
  }

  // Dışarıdan çağrılabilir refresh metodu
  void refreshFeed() {
    _loadNearbyCheckins(initial: true);
  }

  double _getDistance(CheckinModel checkin) {
    if (_currentPosition == null) return 0;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      checkin.geoPoint.latitude,
      checkin.geoPoint.longitude,
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

  Future<void> _sendDMRequest(CheckinModel checkin) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Kendi check-in'ine DM isteği gönderemez
      if (checkin.userId == currentUser.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kendi paylaşımına DM isteği gönderemezsin'),
            backgroundColor: AppTheme.iosRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Önce mevcut chat kontrolü yap
      final chatId = [currentUser.uid, checkin.userId]..sort();
      final chatIdString = chatId.join('_');

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatIdString)
          .get();

      if (chatDoc.exists) {
        // Chat zaten var, otomatik mesaj gönder
        await FirebaseFirestore.instance.collection('messages').add({
          'senderId': currentUser.uid,
          'receiverId': checkin.userId,
          'content': 'Şu check-in\'i gördüm, selam',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'messageType': 'text',
          'checkinId': checkin.id, // Check-in ID'sini ekle
          'checkinData': {
            // Check-in verilerini de ekle
            'id': checkin.id,
            'message': checkin.message,
            'locationName': checkin.locationName,
            'userId': checkin.userId,
            'userDisplayName': checkin.userDisplayName,
          },
        });

        // Chat'i güncelle
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatIdString)
            .update({
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessage': 'Şu check-in\'i gördüm, selam',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mesaj gönderildi!'),
            backgroundColor: AppTheme.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        // Chat yok, DM isteği gönder
        await FirebaseFirestore.instance.collection('dm_requests').add({
          'fromUserId': currentUser.uid,
          'toUserId': checkin.userId,
          'checkinId': checkin.id,
          'message': 'Check-in\'inizle ilgili DM isteği',
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending', // pending, accepted, rejected
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('DM isteği gönderildi!'),
            backgroundColor: AppTheme.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print('DM isteği gönderilirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('DM isteği gönderilirken hata: $e'),
          backgroundColor: AppTheme.iosRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildCheckinCard(CheckinModel checkin) {
    final distance = _getDistance(checkin);
    final isLiked =
        checkin.likes.contains(FirebaseAuth.instance.currentUser?.uid);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckinDetailScreen(
              checkinId: checkin.id,
              checkin: checkin,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.iosDarkSecondaryBackground
              : AppTheme.iosSecondaryBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kullanıcı bilgileri - Kompakt
              Row(
                children: [
                  // Profil fotoğrafı - Daha küçük
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.iosBlue.withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: checkin.userPhotoURL != null
                          ? Image.network(
                              checkin.userPhotoURL!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: isDark
                                      ? AppTheme.iosDarkTertiaryBackground
                                      : AppTheme.iosTertiaryBackground,
                                  child: Icon(
                                    CupertinoIcons.person_fill,
                                    size: 18,
                                    color: isDark
                                        ? AppTheme.iosDarkSecondaryText
                                        : AppTheme.iosSecondaryText,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: isDark
                                  ? AppTheme.iosDarkTertiaryBackground
                                  : AppTheme.iosTertiaryBackground,
                              child: Icon(
                                CupertinoIcons.person_fill,
                                size: 18,
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kullanıcı adı - Daha küçük font
                        Text(
                          checkin.userDisplayName,
                          style: AppTheme.iosFontSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Konum ve mesafe - Tek satırda
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.location_solid,
                              size: 12,
                              color: AppTheme.iosBlue,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                checkin.locationName,
                                style: AppTheme.iosFontCaption.copyWith(
                                  color: AppTheme.iosBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.iosGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _formatDistance(distance),
                                style: AppTheme.iosFontCaption.copyWith(
                                  color: AppTheme.iosGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Zaman - Daha küçük
                  Text(
                    _formatTimeAgo(checkin.createdAt),
                    style: AppTheme.iosFontCaption.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mesaj - Daha kompakt
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.iosDarkTertiaryBackground
                      : AppTheme.iosTertiaryBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  checkin.message,
                  style: AppTheme.iosFontSmall.copyWith(
                    color: isDark
                        ? AppTheme.iosDarkPrimaryText
                        : AppTheme.iosPrimaryText,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Etkileşim butonları - Daha kompakt
              Row(
                children: [
                  _buildActionButton(
                    icon: isLiked
                        ? CupertinoIcons.heart_fill
                        : CupertinoIcons.heart,
                    label: '${checkin.likes.length}',
                    color: isLiked ? AppTheme.iosRed : null,
                    onPressed: () => _likeCheckin(checkin),
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: CupertinoIcons.chat_bubble,
                    label: '${checkin.comments.length}',
                    onPressed: () {
                      // Yorum ekranına git
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: CupertinoIcons.mail,
                    label: 'DM',
                    onPressed: () => _sendDMRequest(checkin),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: AppTheme.iosBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    onPressed: () {
                      // Paylaş işlevi
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.share,
                          size: 14,
                          color: AppTheme.iosBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Paylaş',
                          style: AppTheme.iosFontCaption.copyWith(
                            color: AppTheme.iosBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color ??
                (isDark
                    ? AppTheme.iosDarkSecondaryText
                    : AppTheme.iosSecondaryText),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.iosFontCaption.copyWith(
              color: color ??
                  (isDark
                      ? AppTheme.iosDarkSecondaryText
                      : AppTheme.iosSecondaryText),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Skeleton loading widget
  Widget _buildSkeletonCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.iosDarkSecondaryBackground
            : AppTheme.iosSecondaryBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.iosDarkTertiaryBackground
                  : AppTheme.iosTertiaryBackground,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  color: isDark
                      ? AppTheme.iosDarkTertiaryBackground
                      : AppTheme.iosTertiaryBackground,
                  margin: const EdgeInsets.only(bottom: 8),
                ),
                Container(
                  width: double.infinity,
                  height: 12,
                  color: isDark
                      ? AppTheme.iosDarkTertiaryBackground
                      : AppTheme.iosTertiaryBackground,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = SafeArea(
      child: Column(
        children: [
          // iOS Style Header - Kompakt
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.iosDarkSecondaryBackground
                  : AppTheme.iosSecondaryBackground,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.iosBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    CupertinoIcons.location_solid,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yakındaki Paylaşımlar',
                        style: AppTheme.iosFontSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.iosDarkPrimaryText
                              : AppTheme.iosPrimaryText,
                        ),
                      ),
                      Text(
                        '${_checkins.length} paylaşım bulundu',
                        style: AppTheme.iosFontCaption.copyWith(
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  onPressed: refreshFeed,
                  child: Icon(
                    CupertinoIcons.refresh,
                    color: AppTheme.iosBlue,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 6,
                    itemBuilder: (context, index) => _buildSkeletonCard(),
                  )
                : _checkins.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.iosDarkSecondaryBackground
                                : AppTheme.iosSecondaryBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.doc_text,
                                size: 48,
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Yakında paylaşım yok',
                                style: AppTheme.iosFontSmall.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkSecondaryText
                                      : AppTheme.iosSecondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            _loadNearbyCheckins(initial: true),
                        color: AppTheme.iosBlue,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _checkins.length + (_isPaginating ? 2 : 0),
                          itemBuilder: (context, index) {
                            if (index < _checkins.length) {
                              return _buildCheckinCard(_checkins[index]);
                            } else {
                              return _buildSkeletonCard();
                            }
                          },
                        ),
                      ),
          ),
        ],
      ),
    );

    if (widget.useScaffold) {
      return Scaffold(
        backgroundColor:
            isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
        body: content,
      );
    } else {
      return content;
    }
  }
}
