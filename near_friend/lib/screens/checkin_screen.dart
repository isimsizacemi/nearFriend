import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final _messageController = TextEditingController();
  final _authService = AuthService();

  Position? _currentPosition;
  String _locationName = '';
  bool _isLoading = false;
  bool _isLocationLoading = true;

  // Görünürlük ayarları
  bool _isPublic = true;
  String _selectedGender = '';
  int _minAge = 18;
  int _maxAge = 30;
  final List<String> _selectedUniversities = [];
  final List<String> _selectedInterests = [];

  // Seçenekler
  final List<String> _universities = [
    'İstanbul Teknik Üniversitesi',
    'Boğaziçi Üniversitesi',
    'Orta Doğu Teknik Üniversitesi',
    'Hacettepe Üniversitesi',
    'Ankara Üniversitesi',
    'İstanbul Üniversitesi',
    'Marmara Üniversitesi',
    'Yıldız Teknik Üniversitesi',
    'Ege Üniversitesi',
    'Dokuz Eylül Üniversitesi',
  ];

  final List<String> _interests = [
    'Müzik',
    'Spor',
    'Kitap',
    'Film',
    'Yemek',
    'Seyahat',
    'Teknoloji',
    'Sanat',
    'Fotoğrafçılık',
    'Dans',
    'Yoga',
    'Fitness',
    'Kahve',
    'Konser',
    'Tiyatro',
    'Müze',
    'Doğa',
    'Oyun',
    'Kodlama',
    'Dil Öğrenme',
  ];

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
          setState(() => _isLocationLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocationLoading = false);
        return;
      }

      // Mevcut konumu al
      _currentPosition = await Geolocator.getCurrentPosition();

      // Konum adını al
      if (_currentPosition != null) {
        try {
          final placemarks = await placemarkFromCoordinates(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );

          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            setState(() {
              _locationName =
                  '${placemark.street ?? ''}, ${placemark.locality ?? ''}';
            });
          } else {
            setState(() {
              _locationName = 'Konum bilgisi alınamadı';
            });
          }
        } catch (e) {
          print('Konum adı alınırken hata: $e');
          setState(() {
            _locationName = 'Konum bilgisi alınamadı';
          });
        }
      }
    } catch (e) {
      print('Konum alınırken hata: $e');
    } finally {
      setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _createCheckin() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen bir mesaj yazın'),
          backgroundColor: AppTheme.iosRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Konum alınamadı. Lütfen konum iznini kontrol edin.'),
          backgroundColor: AppTheme.iosRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Kullanıcı bilgilerini al
      Map<String, dynamic> userData = {};
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          userData = userDoc.data()!;
        }
      } catch (e) {
        print('Kullanıcı verileri alınırken hata: $e');
      }

      // Eğer userData boşsa temel bilgileri kullan
      if (userData.isEmpty) {
        userData = {
          'displayName': user.displayName ?? 'İsimsiz',
          'photoURL': user.photoURL,
          'hasCreatedProfile': true,
        };
      }

      // Görünürlük ayarlarını hazırla
      Map<String, dynamic> privacySettings = {};
      if (!_isPublic) {
        privacySettings = {
          'gender': _selectedGender,
          'minAge': _minAge,
          'maxAge': _maxAge,
          'universities': _selectedUniversities,
          'interests': _selectedInterests,
        };
      }

      // Check-in oluştur
      final checkinData = {
        'userId': user.uid,
        'userDisplayName': userData['displayName'] ?? user.displayName ?? '',
        'userPhotoURL': userData['photoURL'] ?? user.photoURL,
        'message': _messageController.text.trim(),
        'location':
            GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        'locationName': _locationName,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'comments': [],
        'privacySettings': privacySettings,
        'isActive': true,
      };

      // Check-in oluştur
      final checkinDoc = await FirebaseFirestore.instance
          .collection('checkins')
          .add(checkinData);

      // Kullanıcının konumunu güncelle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'currentLocation':
            GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      if (mounted) {
        // Başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Check-in başarıyla paylaşıldı!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );

        // Kısa bir bekleme sonrası feed screen'e git
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          // Feed screen'e git
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/feed',
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('Check-in oluşturulurken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Check-in paylaşılırken bir hata oluştu. Lütfen tekrar deneyin.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.iosRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.iosGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_location,
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
                          'Check-in',
                          style: AppTheme.iosFontMedium.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          'Yeni paylaşım oluştur',
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
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
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
                    // Konum Bilgisi
                    Container(
                      padding: const EdgeInsets.all(16),
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
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.iosBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: AppTheme.iosBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Konum',
                                  style: AppTheme.iosFontSmall.copyWith(
                                    color: isDark
                                        ? AppTheme.iosDarkSecondaryText
                                        : AppTheme.iosSecondaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isLocationLoading
                                      ? 'Konum alınıyor...'
                                      : _locationName.isNotEmpty
                                          ? _locationName
                                          : 'Konum alınamadı',
                                  style: AppTheme.iosFontMedium.copyWith(
                                    color: isDark
                                        ? AppTheme.iosDarkPrimaryText
                                        : AppTheme.iosPrimaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Mesaj Alanı
                    Container(
                      padding: const EdgeInsets.all(16),
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
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.iosGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: AppTheme.iosGreen,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Mesajınız',
                                style: AppTheme.iosFontMedium.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _messageController,
                            maxLines: 5,
                            maxLength: 500,
                            decoration: InputDecoration(
                              hintText: 'Ne düşünüyorsunuz?',
                              hintStyle: AppTheme.iosFont.copyWith(
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppTheme.iosDarkTertiaryBackground
                                      : AppTheme.iosTertiaryBackground,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppTheme.iosDarkTertiaryBackground
                                      : AppTheme.iosTertiaryBackground,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppTheme.iosGreen,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? AppTheme.iosDarkTertiaryBackground
                                  : AppTheme.iosTertiaryBackground,
                            ),
                            style: AppTheme.iosFont.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkPrimaryText
                                  : AppTheme.iosPrimaryText,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Görünürlük Ayarları
                    Container(
                      padding: const EdgeInsets.all(16),
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
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.iosPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.visibility,
                                  color: AppTheme.iosPurple,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Görünürlük',
                                style: AppTheme.iosFontMedium.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isPublic = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _isPublic
                                          ? AppTheme.iosGreen
                                          : isDark
                                              ? AppTheme
                                                  .iosDarkTertiaryBackground
                                              : AppTheme.iosTertiaryBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _isPublic
                                            ? AppTheme.iosGreen
                                            : isDark
                                                ? AppTheme
                                                    .iosDarkTertiaryBackground
                                                : AppTheme
                                                    .iosTertiaryBackground,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Herkese Açık',
                                        style: AppTheme.iosFontMedium.copyWith(
                                          color: _isPublic
                                              ? Colors.white
                                              : isDark
                                                  ? AppTheme
                                                      .iosDarkSecondaryText
                                                  : AppTheme.iosSecondaryText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _isPublic = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !_isPublic
                                          ? AppTheme.iosPurple
                                          : isDark
                                              ? AppTheme
                                                  .iosDarkTertiaryBackground
                                              : AppTheme.iosTertiaryBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: !_isPublic
                                            ? AppTheme.iosPurple
                                            : isDark
                                                ? AppTheme
                                                    .iosDarkTertiaryBackground
                                                : AppTheme
                                                    .iosTertiaryBackground,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Özel',
                                        style: AppTheme.iosFontMedium.copyWith(
                                          color: !_isPublic
                                              ? Colors.white
                                              : isDark
                                                  ? AppTheme
                                                      .iosDarkSecondaryText
                                                  : AppTheme.iosSecondaryText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Paylaş Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createCheckin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.iosGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Paylaşılıyor...',
                                    style: AppTheme.iosFontMedium.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Paylaş',
                                    style: AppTheme.iosFontMedium.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
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
}
