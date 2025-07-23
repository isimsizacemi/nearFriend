import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'main_app.dart'; // Correct import for MainApp

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

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_disposed) return;

    try {
      // Konum izni kontrol et
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!_disposed && mounted) {
            setState(() => _isLocationLoading = false);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!_disposed && mounted) {
          setState(() => _isLocationLoading = false);
        }
        return;
      }

      // Mevcut konumu al
      _currentPosition = await Geolocator.getCurrentPosition();

      // Konum adını al
      if (_currentPosition != null && !_disposed && mounted) {
        try {
          final placemarks = await placemarkFromCoordinates(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );

          if (placemarks.isNotEmpty && !_disposed && mounted) {
            final placemark = placemarks.first;
            setState(() {
              _locationName =
                  '${placemark.street ?? ''}, ${placemark.locality ?? ''}';
            });
          } else if (!_disposed && mounted) {
            setState(() {
              _locationName = 'Konum bilgisi alınamadı';
            });
          }
        } catch (e) {
          print('Konum adı alınırken hata: $e');
          if (!_disposed && mounted) {
            setState(() {
              _locationName = 'Konum bilgisi alınamadı';
            });
          }
        }
      }
    } catch (e) {
      print('Konum alınırken hata: $e');
    } finally {
      if (!_disposed && mounted) {
        setState(() => _isLocationLoading = false);
      }
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

        // Kısa bir bekleme sonrası ana ekrana git
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          // Ana akışa yönlendir
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainApp()),
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
                      color: AppTheme.iosGreen,
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
                          'Check-in',
                          style: AppTheme.iosFontSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          'Yeni paylaşım oluştur',
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
                    onPressed: () => Navigator.pop(context),
                    child: Icon(
                      CupertinoIcons.xmark,
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Konum Bilgisi - Kompakt
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.iosDarkTertiaryBackground
                            : AppTheme.iosTertiaryBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.iosBlue.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.iosBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              CupertinoIcons.location_solid,
                              color: AppTheme.iosBlue,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '📍 Konum',
                                  style: AppTheme.iosFontCaption.copyWith(
                                    color: AppTheme.iosBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isLocationLoading
                                      ? 'Konum alınıyor...'
                                      : _locationName.isNotEmpty
                                          ? _locationName
                                          : 'Konum alınamadı',
                                  style: AppTheme.iosFontSmall.copyWith(
                                    color: isDark
                                        ? AppTheme.iosDarkPrimaryText
                                        : AppTheme.iosPrimaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Mesaj Alanı - Kompakt
                    Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.iosGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  CupertinoIcons.pencil,
                                  color: AppTheme.iosGreen,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '✍️ Mesajınız',
                                style: AppTheme.iosFontSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _messageController,
                            maxLines: 4,
                            maxLength: 300,
                            decoration: InputDecoration(
                              hintText: 'Ne düşünüyorsunuz?',
                              hintStyle: AppTheme.iosFontSmall.copyWith(
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: AppTheme.iosGreen,
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? AppTheme.iosDarkTertiaryBackground
                                  : AppTheme.iosTertiaryBackground,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            style: AppTheme.iosFontSmall.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkPrimaryText
                                  : AppTheme.iosPrimaryText,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Görünürlük Ayarları - Kompakt
                    Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.iosPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  CupertinoIcons.eye,
                                  color: AppTheme.iosPurple,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '👁️ Görünürlük',
                                style: AppTheme.iosFontSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  color: _isPublic
                                      ? AppTheme.iosGreen
                                      : (isDark
                                          ? AppTheme.iosDarkTertiaryBackground
                                          : AppTheme.iosTertiaryBackground),
                                  borderRadius: BorderRadius.circular(16),
                                  onPressed: () =>
                                      setState(() => _isPublic = true),
                                  child: Text(
                                    '🌍 Herkese Açık',
                                    style: AppTheme.iosFontSmall.copyWith(
                                      color: _isPublic
                                          ? Colors.white
                                          : (isDark
                                              ? AppTheme.iosDarkSecondaryText
                                              : AppTheme.iosSecondaryText),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  color: !_isPublic
                                      ? AppTheme.iosPurple
                                      : (isDark
                                          ? AppTheme.iosDarkTertiaryBackground
                                          : AppTheme.iosTertiaryBackground),
                                  borderRadius: BorderRadius.circular(16),
                                  onPressed: () =>
                                      setState(() => _isPublic = false),
                                  child: Text(
                                    '🔒 Özel',
                                    style: AppTheme.iosFontSmall.copyWith(
                                      color: !_isPublic
                                          ? Colors.white
                                          : (isDark
                                              ? AppTheme.iosDarkSecondaryText
                                              : AppTheme.iosSecondaryText),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Paylaş Butonu - Kompakt
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: CupertinoButton.filled(
                        onPressed: _isLoading ? null : _createCheckin,
                        borderRadius: BorderRadius.circular(20),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CupertinoActivityIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Paylaşılıyor...',
                                    style: AppTheme.iosFontSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.paperplane_fill,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Paylaş',
                                    style: AppTheme.iosFontSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
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
