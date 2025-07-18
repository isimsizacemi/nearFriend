import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/checkin_model.dart';
import '../utils/app_theme.dart';

class CheckinDetailScreen extends StatefulWidget {
  final String checkinId;
  final CheckinModel? checkin;

  const CheckinDetailScreen({
    super.key,
    required this.checkinId,
    this.checkin,
  });

  @override
  State<CheckinDetailScreen> createState() => _CheckinDetailScreenState();
}

class _CheckinDetailScreenState extends State<CheckinDetailScreen> {
  CheckinModel? _checkin;
  bool _isLoading = true;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    if (widget.checkin != null) {
      _checkin = widget.checkin;
      _isLoading = false;
    } else {
      _loadCheckin();
    }
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      setState(() {});
    } catch (e) {
      print('Konum alınırken hata: $e');
    }
  }

  Future<void> _loadCheckin() async {
    try {
      print('Check-in yükleniyor...');
      print('Check-in ID: ${widget.checkinId}');

      final doc = await FirebaseFirestore.instance
          .collection('checkins')
          .doc(widget.checkinId)
          .get();

      print('Doküman var mı: ${doc.exists}');
      if (doc.exists) {
        print('Doküman verisi: ${doc.data()}');
        setState(() {
          _checkin = CheckinModel.fromFirestore(doc);
          _isLoading = false;
        });
      } else {
        print('Check-in bulunamadı!');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Check-in yüklenirken hata: $e');
      setState(() => _isLoading = false);
    }
  }

  double _getDistance() {
    if (_currentPosition == null || _checkin?.location == null) return 0;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _checkin!.location!.latitude,
      _checkin!.location!.longitude,
    );
  }

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()}m uzaklıkta';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km uzaklıkta';
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

  Future<void> _openInGoogleMaps() async {
    if (_checkin?.location == null) return;

    try {
      final latitude = _checkin!.location!.latitude;
      final longitude = _checkin!.location!.longitude;
      final locationName = _checkin!.locationName;

      // Google Maps URL'si oluştur
      final url =
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

      // URL'yi aç
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        // Eğer Google Maps açılamazsa, hata mesajı göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Google Maps açılamadı'),
              backgroundColor: AppTheme.iosRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      print('Google Maps açılırken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konum açılırken hata: $e'),
            backgroundColor: AppTheme.iosRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
        body: SafeArea(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppTheme.iosBlue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Check-in yükleniyor...',
                    style: AppTheme.iosFont.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_checkin == null) {
      return Scaffold(
        backgroundColor:
            isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
        body: SafeArea(
          child: Center(
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
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.iosRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Check-in bulunamadı',
                    style: AppTheme.iosFontMedium.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkPrimaryText
                          : AppTheme.iosPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu check-in silinmiş olabilir',
                    style: AppTheme.iosFontSmall.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
      body: SafeArea(
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
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: isDark
                          ? AppTheme.iosDarkPrimaryText
                          : AppTheme.iosPrimaryText,
                    ),
                  ),
                  const SizedBox(width: 16),
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
                          'Check-in Detayı',
                          style: AppTheme.iosFontMedium.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(_checkin!.createdAt),
                          style: AppTheme.iosFontSmall.copyWith(
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
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kullanıcı bilgileri
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.iosDarkSecondaryBackground
                            : AppTheme.iosSecondaryBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: AppTheme.iosBlue.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: _checkin!.userPhotoURL != null
                                  ? Image.network(
                                      _checkin!.userPhotoURL!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: isDark
                                              ? AppTheme
                                                  .iosDarkTertiaryBackground
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
                                  _checkin!.userDisplayName,
                                  style: AppTheme.iosFontBold.copyWith(
                                    color: isDark
                                        ? AppTheme.iosDarkPrimaryText
                                        : AppTheme.iosPrimaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimeAgo(_checkin!.createdAt),
                                  style: AppTheme.iosFontSmall.copyWith(
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
                    ),
                    const SizedBox(height: 20),

                    // Mesaj
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.iosDarkSecondaryBackground
                            : AppTheme.iosSecondaryBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mesaj',
                            style: AppTheme.iosFontBold.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkPrimaryText
                                  : AppTheme.iosPrimaryText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _checkin!.message,
                            style: AppTheme.iosFont.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkPrimaryText
                                  : AppTheme.iosPrimaryText,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Konum bilgileri
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.iosDarkSecondaryBackground
                            : AppTheme.iosSecondaryBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konum',
                            style: AppTheme.iosFontBold.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkPrimaryText
                                  : AppTheme.iosPrimaryText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _openInGoogleMaps,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.iosBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.iosBlue.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: AppTheme.iosBlue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _checkin!.locationName,
                                      style: AppTheme.iosFont.copyWith(
                                        color: AppTheme.iosBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.open_in_new,
                                    color: AppTheme.iosBlue,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_currentPosition != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_walk,
                                  color: AppTheme.iosGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDistance(_getDistance()),
                                  style: AppTheme.iosFontSmall.copyWith(
                                    color: AppTheme.iosGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Etkileşim istatistikleri
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.iosDarkSecondaryBackground
                            : AppTheme.iosSecondaryBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Etkileşimler',
                            style: AppTheme.iosFontBold.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkPrimaryText
                                  : AppTheme.iosPrimaryText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatItem(
                                icon: Icons.favorite,
                                count: _checkin!.likes.length,
                                label: 'Beğeni',
                                color: AppTheme.iosRed,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 20),
                              _buildStatItem(
                                icon: Icons.comment,
                                count: _checkin!.comments.length,
                                label: 'Yorum',
                                color: AppTheme.iosBlue,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.iosDarkTertiaryBackground
              : AppTheme.iosTertiaryBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: AppTheme.iosFontBold.copyWith(
                color: isDark
                    ? AppTheme.iosDarkPrimaryText
                    : AppTheme.iosPrimaryText,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: AppTheme.iosFontSmall.copyWith(
                color: isDark
                    ? AppTheme.iosDarkSecondaryText
                    : AppTheme.iosSecondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
