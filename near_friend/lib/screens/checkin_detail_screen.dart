import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/checkin_model.dart';
import '../utils/app_theme.dart';
import '../widgets/smart_avatar.dart';
import 'dart:math' as math;

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
  LocationData? _currentPosition;

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
      print('🔄 CheckinDetail: Konum alma işlemi başlatılıyor...');

      Location location = Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          print('❌ CheckinDetail: Konum servisi açılamadı');
          return;
        }
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          print('❌ CheckinDetail: Konum izni alınamadı');
          return;
        }
      }

      _currentPosition = await location.getLocation();
      print(
          '✅ CheckinDetail: Konum alındı: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      setState(() {});
    } catch (e) {
      print('❌ CheckinDetail: Konum alınırken hata: $e');
    }
  }

  Future<void> _loadCheckin() async {
    try {
      print('🔄 CheckinDetail: Check-in yükleniyor...');
      print('Check-in ID: ${widget.checkinId}');

      final doc = await FirebaseFirestore.instance
          .collection('checkins')
          .doc(widget.checkinId)
          .get();

      print('Doküman var mı: ${doc.exists}');

      if (doc.exists && mounted) {
        setState(() {
          _checkin = CheckinModel.fromFirestore(doc);
          _isLoading = false;
        });
        print('✅ CheckinDetail: Check-in yüklendi: ${_checkin?.message}');
      } else {
        print('❌ CheckinDetail: Check-in bulunamadı');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ CheckinDetail: Check-in yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Dünya'nın yarıçapı (km)

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    double distance = earthRadius * c;

    return distance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    } else {
      return '${distanceKm.toStringAsFixed(1)}km';
    }
  }

  Future<void> _openInMaps() async {
    if (_checkin?.location['geopoint'] == null) return;

    final geoPointData = _checkin!.location['geopoint'];
    double? latitude, longitude;
    
    if (geoPointData is GeoPoint) {
      latitude = geoPointData.latitude;
      longitude = geoPointData.longitude;
    } else if (geoPointData is Map<String, dynamic>) {
      latitude = geoPointData['latitude']?.toDouble();
      longitude = geoPointData['longitude']?.toDouble();
    }
    
    if (latitude == null || longitude == null) return;
    
    final url = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      print('Harita açılamadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
        appBar: AppBar(
          title: const Text('Check-in Detayı'),
          backgroundColor: isDark
              ? AppTheme.iosDarkSecondaryBackground
              : AppTheme.iosSecondaryBackground,
          foregroundColor:
              isDark ? AppTheme.iosDarkPrimaryText : AppTheme.iosPrimaryText,
        ),
        body: const Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (_checkin == null) {
      return Scaffold(
        backgroundColor:
            isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
        appBar: AppBar(
          title: const Text('Check-in Detayı'),
          backgroundColor: isDark
              ? AppTheme.iosDarkSecondaryBackground
              : AppTheme.iosSecondaryBackground,
          foregroundColor:
              isDark ? AppTheme.iosDarkPrimaryText : AppTheme.iosPrimaryText,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 64,
                color: AppTheme.iosRed,
              ),
              const SizedBox(height: 16),
              Text(
                'Check-in bulunamadı',
                style: AppTheme.iosFont.copyWith(
                  color: isDark
                      ? AppTheme.iosDarkPrimaryText
                      : AppTheme.iosPrimaryText,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: () => Navigator.pop(context),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    final geoPointData = _checkin!.location['geopoint'];
    double? latitude, longitude;
    double? distance;
    
    if (geoPointData is GeoPoint) {
      latitude = geoPointData.latitude;
      longitude = geoPointData.longitude;
    } else if (geoPointData is Map<String, dynamic>) {
      latitude = geoPointData['latitude']?.toDouble();
      longitude = geoPointData['longitude']?.toDouble();
    }
    
    if (_currentPosition != null && latitude != null && longitude != null) {
      distance = _calculateDistance(
        _currentPosition!.latitude!,
        _currentPosition!.longitude!,
        latitude,
        longitude,
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
      appBar: AppBar(
        title: const Text('Check-in Detayı'),
        backgroundColor: isDark
            ? AppTheme.iosDarkSecondaryBackground
            : AppTheme.iosSecondaryBackground,
        foregroundColor:
            isDark ? AppTheme.iosDarkPrimaryText : AppTheme.iosPrimaryText,
        actions: [
          if (latitude != null && longitude != null)
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: _openInMaps,
              child: Icon(
                CupertinoIcons.map,
                color: AppTheme.iosBlue,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SmartAvatar(
                    photoURL: _checkin!.userPhotoURL,
                    size: 50,
                    fallbackColor: AppTheme.iosBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _checkin!.userDisplayName,
                          style: AppTheme.iosFont.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          _formatDate(_checkin!.createdAt),
                          style: AppTheme.iosFontCaption.copyWith(
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

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mesaj',
                    style: AppTheme.iosFontSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.iosDarkPrimaryText
                          : AppTheme.iosPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _checkin!.message,
                    style: AppTheme.iosFont.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkPrimaryText
                          : AppTheme.iosPrimaryText,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.location_solid,
                        color: AppTheme.iosBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Konum',
                        style: AppTheme.iosFontSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.iosDarkPrimaryText
                              : AppTheme.iosPrimaryText,
                        ),
                      ),
                      if (distance != null) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.iosGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatDistance(distance),
                            style: AppTheme.iosFontCaption.copyWith(
                              color: AppTheme.iosGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _checkin!.locationName.isNotEmpty
                        ? _checkin!.locationName
                        : latitude != null && longitude != null
                            ? 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}'
                            : 'Konum bilgisi yok',
                    style: AppTheme.iosFont.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkPrimaryText
                          : AppTheme.iosPrimaryText,
                    ),
                  ),
                  if (latitude != null && longitude != null) ...[
                    const SizedBox(height: 12),
                    CupertinoButton.filled(
                      onPressed: _openInMaps,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.map, size: 16),
                          const SizedBox(width: 8),
                          const Text('Haritada Aç'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İstatistikler',
                    style: AppTheme.iosFontSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.iosDarkPrimaryText
                          : AppTheme.iosPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: CupertinoIcons.heart,
                          label: 'Beğeni',
                          value: '${_checkin!.likes.length}',
                          color: AppTheme.iosRed,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem(
                          icon: CupertinoIcons.chat_bubble,
                          label: 'Yorum',
                          value: '${_checkin!.comments.length}',
                          color: AppTheme.iosBlue,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.iosFont.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTheme.iosFontCaption.copyWith(
              color: isDark
                  ? AppTheme.iosDarkSecondaryText
                  : AppTheme.iosSecondaryText,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Şimdi';
    }
  }
}
