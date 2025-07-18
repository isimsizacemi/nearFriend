import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/match_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final MatchService _matchService = MatchService();
  List<UserModel> _users = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  Position? _currentPosition;

  // Filtreler
  double _maxDistance = 100.0; // km - çok daha geniş mesafe
  int _minAge = 18; // minimum yaş
  int _maxAge = 50; // maksimum yaş - daha geniş
  String? _preferredGender;

  @override
  void initState() {
    super.initState();
    _loadFilterSettings();
    _getCurrentLocation();
  }

  Future<void> _loadFilterSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _maxDistance = prefs.getDouble('match_max_distance') ?? 100.0;
        _minAge = prefs.getInt('match_min_age') ?? 18;
        _maxAge = prefs.getInt('match_max_age') ?? 50;
        _preferredGender = prefs.getString('match_preferred_gender');
      });
    } catch (e) {
      print('Filtre ayarları yüklenirken hata: $e');
    }
  }

  Future<void> _saveFilterSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('match_max_distance', _maxDistance);
      await prefs.setInt('match_min_age', _minAge);
      await prefs.setInt('match_max_age', _maxAge);
      if (_preferredGender != null) {
        await prefs.setString('match_preferred_gender', _preferredGender!);
      } else {
        await prefs.remove('match_preferred_gender');
      }
    } catch (e) {
      print('Filtre ayarları kaydedilirken hata: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();

      // Kullanıcının konumunu Firestore'a kaydet
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _currentPosition != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'currentLocation':
              GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
          'lastActiveAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      }

      await _loadUsers();
    } catch (e) {
      print('Konum alınırken hata: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsers() async {
    if (mounted) setState(() => _isLoading = true);

    // Önce güncel konumu al
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Güncel konumu al
      _currentPosition = await Geolocator.getCurrentPosition();

      // Kullanıcının konumunu Firestore'a kaydet
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _currentPosition != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'currentLocation':
              GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
          'lastActiveAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      }

      print(
          'Güncel konum alındı: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
    } catch (e) {
      print('Güncel konum alınırken hata: $e');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    print('Filtreler:');
    if (_maxDistance >= 100) {
      print('- Maksimum mesafe: Sınırsız (tüm kullanıcılar)');
    } else {
      print('- Maksimum mesafe: ${_maxDistance}km');
    }
    print('- Yaş aralığı: $_minAge - $_maxAge');
    print('- Tercih edilen cinsiyet: $_preferredGender');

    try {
      final users = await _matchService.getNearbyUsers(
        maxDistance: _maxDistance * 1000, // km'yi metre'ye çevir
        minAge: _minAge,
        maxAge: _maxAge,
        preferredGender: _preferredGender,
        currentPosition: _currentPosition,
      );

      print('Yüklenen kullanıcı sayısı: ${users.length}');

      if (mounted) {
        setState(() {
          _users = users;
          _currentIndex = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Kullanıcılar yüklenirken hata: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _likeUser() async {
    if (_users.isEmpty || _currentIndex >= _users.length) return;

    final likedUser = _users[_currentIndex];
    await _matchService.likeUser(likedUser.id);

    if (mounted) {
      setState(() {
        _currentIndex++;
      });
    }

    // Eğer tüm kullanıcılar bittiyse yeniden yükle
    if (_currentIndex >= _users.length) {
      await _loadUsers();
    }
  }

  Future<void> _dislikeUser() async {
    if (_users.isEmpty || _currentIndex >= _users.length) return;

    final dislikedUser = _users[_currentIndex];
    await _matchService.dislikeUser(dislikedUser.id);

    if (mounted) {
      setState(() {
        _currentIndex++;
      });
    }

    // Eğer tüm kullanıcılar bittiyse yeniden yükle
    if (_currentIndex >= _users.length) {
      await _loadUsers();
    }
  }

  double _getDistance(UserModel user) {
    if (_currentPosition == null || user.currentLocation == null) return 0;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      user.currentLocation!.latitude,
      user.currentLocation!.longitude,
    );
  }

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
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
                      color: AppTheme.iosPink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.favorite,
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
                          'Eşleşme',
                          style: AppTheme.iosFontMedium.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          '${_users.length} kişi bulundu',
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
                    onPressed: _showFilterDialog,
                    icon: Icon(
                      Icons.tune,
                      color: AppTheme.iosPink,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.iosPink,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Yakındaki kişiler aranıyor...',
                              style: AppTheme.iosFont.copyWith(
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _users.isEmpty
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
                                  Icons.people_outline,
                                  size: 64,
                                  color: isDark
                                      ? AppTheme.iosDarkSecondaryText
                                      : AppTheme.iosSecondaryText,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Yakınında kimse yok',
                                  style: AppTheme.iosFontMedium.copyWith(
                                    color: isDark
                                        ? AppTheme.iosDarkPrimaryText
                                        : AppTheme.iosPrimaryText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Filtreleri değiştirmeyi dene',
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
                      : Column(
                          children: [
                            // Kart alanı
                            Expanded(
                              child: _currentIndex < _users.length
                                  ? _buildUserCard(_users[_currentIndex])
                                  : Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(32),
                                        margin: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppTheme
                                                  .iosDarkSecondaryBackground
                                              : AppTheme.iosSecondaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 64,
                                              color: AppTheme.iosGreen,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Tüm kullanıcıları gördün',
                                              style: AppTheme.iosFontMedium
                                                  .copyWith(
                                                color: isDark
                                                    ? AppTheme
                                                        .iosDarkPrimaryText
                                                    : AppTheme.iosPrimaryText,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Daha fazla kişi için filtreleri değiştir',
                                              style: AppTheme.iosFontSmall
                                                  .copyWith(
                                                color: isDark
                                                    ? AppTheme
                                                        .iosDarkSecondaryText
                                                    : AppTheme.iosSecondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                            // Butonlar
                            _buildActionButtons(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final distance = _getDistance(user);
    final commonInterests = user.interests.take(3).join(', ');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.iosDarkSecondaryBackground
            : AppTheme.iosSecondaryBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profil fotoğrafı alanı
          Container(
            height: 480,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              image: user.photoURL != null
                  ? DecorationImage(
                      image: NetworkImage(user.photoURL!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: user.photoURL == null
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      color: isDark
                          ? AppTheme.iosDarkTertiaryBackground
                          : AppTheme.iosTertiaryBackground,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 120,
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                  )
                : Stack(
                    children: [
                      // Gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.4),
                              ],
                              stops: const [0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Distance badge
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.iosBlue.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.iosBlue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDistance(distance),
                                style: AppTheme.iosFontSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Age badge
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.iosPink.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.iosPink.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${user.age} yaş',
                            style: AppTheme.iosFontSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      // Bottom info overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: AppTheme.iosFontLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      offset: const Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.school,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${user.university} - ${user.department}',
                                      style: AppTheme.iosFontSmall.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          // Kullanıcı detayları
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gender badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.iosPink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.iosPink.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        user.gender,
                        style: AppTheme.iosFontSmall.copyWith(
                          color: AppTheme.iosPink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (user.isOnline)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.iosGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.iosGreen,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Çevrimiçi',
                              style: AppTheme.iosFontSmall.copyWith(
                                color: AppTheme.iosGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.iosDarkTertiaryBackground
                          : AppTheme.iosTertiaryBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.iosDarkTertiaryBackground
                            : AppTheme.iosTertiaryBackground,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 20,
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            user.bio!,
                            style: AppTheme.iosFont.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkPrimaryText
                                  : AppTheme.iosPrimaryText,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (user.interests.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'İlgi Alanları',
                    style: AppTheme.iosFontMedium.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkPrimaryText
                          : AppTheme.iosPrimaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: user.interests.take(6).map((interest) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.iosBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.iosBlue.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          interest,
                          style: AppTheme.iosFontSmall.copyWith(
                            color: AppTheme.iosBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Dislike Button
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.iosDarkSecondaryBackground
                  : AppTheme.iosSecondaryBackground,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _dislikeUser,
              icon: Icon(
                Icons.close,
                size: 32,
                color: AppTheme.iosRed,
              ),
            ),
          ),

          // Like Button
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.iosPink,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.iosPink.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _likeUser,
              icon: const Icon(
                Icons.favorite,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppTheme.iosDarkSecondaryBackground
            : AppTheme.iosSecondaryBackground,
        title: Text(
          'Filtre Ayarları',
          style: AppTheme.iosFontMedium.copyWith(
            color:
                isDark ? AppTheme.iosDarkPrimaryText : AppTheme.iosPrimaryText,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mesafe
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.iosDarkBackground
                      : AppTheme.iosBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maksimum Mesafe',
                      style: AppTheme.iosFontMedium.copyWith(
                        color: isDark
                            ? AppTheme.iosDarkPrimaryText
                            : AppTheme.iosPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _maxDistance.clamp(1.0, 100.0),
                      min: 1,
                      max: 100,
                      divisions: 99,
                      activeColor: AppTheme.iosBlue,
                      onChanged: (value) {
                        setState(() {
                          _maxDistance = value;
                        });
                      },
                    ),
                    Text(
                      _maxDistance >= 100
                          ? '🌍 Mesafe sınırı yok (tüm kullanıcılar)'
                          : '📍 Maksimum mesafe: ${_maxDistance.round()}km',
                      style: AppTheme.iosFontSmall.copyWith(
                        color: _maxDistance >= 100
                            ? AppTheme.iosGreen
                            : AppTheme.iosBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Yaş aralığı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.iosDarkBackground
                      : AppTheme.iosBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yaş Aralığı',
                      style: AppTheme.iosFontMedium.copyWith(
                        color: isDark
                            ? AppTheme.iosDarkPrimaryText
                            : AppTheme.iosPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RangeSlider(
                      values:
                          RangeValues(_minAge.toDouble(), _maxAge.toDouble()),
                      min: 18,
                      max: 50,
                      divisions: 32,
                      activeColor: AppTheme.iosPink,
                      onChanged: (values) {
                        setState(() {
                          _minAge = values.start.round();
                          _maxAge = values.end.round();
                        });
                      },
                    ),
                    Text(
                      '👥 Yaş aralığı: $_minAge - $_maxAge',
                      style: AppTheme.iosFontSmall.copyWith(
                        color: AppTheme.iosPink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cinsiyet tercihi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.iosDarkBackground
                      : AppTheme.iosBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cinsiyet Tercihi',
                      style: AppTheme.iosFontMedium.copyWith(
                        color: isDark
                            ? AppTheme.iosDarkPrimaryText
                            : AppTheme.iosPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _preferredGender,
                      decoration: InputDecoration(
                        hintText: 'Cinsiyet seçin',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.iosDarkSecondaryBackground
                            : AppTheme.iosSecondaryBackground,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('🤷 Fark etmez')),
                        DropdownMenuItem(
                            value: 'Erkek', child: Text('👨 Erkek')),
                        DropdownMenuItem(
                            value: 'Kadın', child: Text('👩 Kadın')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _preferredGender = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: AppTheme.iosFont.copyWith(color: AppTheme.iosRed),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveFilterSettings();
              Navigator.pop(context);
              _loadUsers();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.iosBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
  }
}
