import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/checkin_model.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'checkin_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    // Ekran görünür olduğunda otomatik yenile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNearbyCheckins();
    });
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

  Future<void> _loadNearbyCheckins() async {
    if (_currentPosition == null) return;

    try {
      // Önce tüm check-in'leri al, sonra client-side'da filtrele
      final query = FirebaseFirestore.instance
          .collection('checkins')
          .orderBy('createdAt', descending: true)
          .limit(100); // Daha fazla veri al, sonra filtrele

      final snapshot = await query.get();
      final allCheckins =
          snapshot.docs.map((doc) => CheckinModel.fromFirestore(doc)).toList();

      // Client-side filtering: sadece aktif check-in'leri al
      final activeCheckins =
          allCheckins.where((checkin) => checkin.isActive).toList();

      // Konum bazlı filtreleme ve sıralama
      final nearbyCheckins = activeCheckins.where((checkin) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          checkin.location.latitude,
          checkin.location.longitude,
        );
        return distance <= 30000; // 30km'den yakın olanları al
      }).toList();

      // Yakından uzağa sırala
      nearbyCheckins.sort((a, b) {
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

      if (mounted) {
        setState(() {
          _checkins = nearbyCheckins;
        });
      }
    } catch (e) {
      print('Check-in\'ler yüklenirken hata: $e');
      // Hata durumunda boş liste göster
      if (mounted) {
        setState(() {
          _checkins = [];
        });
      }
    }
  }

  // Dışarıdan çağrılabilir refresh metodu
  void refreshFeed() {
    _loadNearbyCheckins();
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
        // Check-in detay sayfasına git
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
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.iosDarkSecondaryBackground
              : AppTheme.iosSecondaryBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: AppTheme.iosBlue.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kullanıcı bilgileri
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: AppTheme.iosBlue.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
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
                                    Icons.person,
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
                                Icons.person,
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          checkin.userDisplayName,
                          style: AppTheme.iosFontBold.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.iosBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: AppTheme.iosBlue,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      checkin.locationName,
                                      style: AppTheme.iosFontSmall.copyWith(
                                        color: AppTheme.iosBlue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.iosGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatDistance(distance),
                                style: AppTheme.iosFontSmall.copyWith(
                                  color: AppTheme.iosGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.iosDarkTertiaryBackground
                          : AppTheme.iosTertiaryBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatTimeAgo(checkin.createdAt),
                      style: AppTheme.iosFontCaption.copyWith(
                        color: isDark
                            ? AppTheme.iosDarkSecondaryText
                            : AppTheme.iosSecondaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mesaj
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.iosDarkTertiaryBackground
                      : AppTheme.iosTertiaryBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  checkin.message,
                  style: AppTheme.iosFont.copyWith(
                    color: isDark
                        ? AppTheme.iosDarkPrimaryText
                        : AppTheme.iosPrimaryText,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Etkileşim butonları
              Row(
                children: [
                  _buildActionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: '${checkin.likes.length}',
                    color: isLiked ? AppTheme.iosRed : null,
                    onPressed: () => _likeCheckin(checkin),
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: Icons.comment_outlined,
                    label: '${checkin.comments.length}',
                    onPressed: () {
                      // Yorum ekranına git
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: Icons.message_outlined,
                    label: 'DM',
                    onPressed: () => _sendDMRequest(checkin),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.iosBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.share,
                          size: 16,
                          color: AppTheme.iosBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Paylaş',
                          style: AppTheme.iosFontSmall.copyWith(
                            color: AppTheme.iosBlue,
                            fontWeight: FontWeight.w500,
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

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: color ??
                  (isDark
                      ? AppTheme.iosDarkSecondaryText
                      : AppTheme.iosSecondaryText),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTheme.iosFontSmall.copyWith(
                color: color ??
                    (isDark
                        ? AppTheme.iosDarkSecondaryText
                        : AppTheme.iosSecondaryText),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = SafeArea(
      child: Column(
        children: [
          // iOS Style Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.iosDarkSecondaryBackground
                  : AppTheme.iosSecondaryBackground,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.iosBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yakındaki Paylaşımlar',
                        style: AppTheme.iosFontMedium.copyWith(
                          color: isDark
                              ? AppTheme.iosDarkPrimaryText
                              : AppTheme.iosPrimaryText,
                        ),
                      ),
                      Text(
                        '${_checkins.length} paylaşım bulundu',
                        style: AppTheme.iosFontSmall.copyWith(
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: refreshFeed,
                  icon: Icon(
                    Icons.refresh,
                    color: AppTheme.iosBlue,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.iosDarkSecondaryBackground
                                : AppTheme.iosSecondaryBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                color: AppTheme.iosBlue,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Yakındaki paylaşımlar yükleniyor...',
                                style: AppTheme.iosFont.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkSecondaryText
                                      : AppTheme.iosSecondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : _checkins.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          margin: const EdgeInsets.all(20),
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
                                Icons.location_off,
                                size: 64,
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Yakınında paylaşım yok',
                                style: AppTheme.iosFontMedium.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'İlk paylaşımı sen yap!',
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
                        onRefresh: () async => refreshFeed(),
                        color: AppTheme.iosBlue,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _checkins.length,
                          itemBuilder: (context, index) {
                            return _buildCheckinCard(_checkins[index]);
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
