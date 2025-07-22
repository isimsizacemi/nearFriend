import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../services/match_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FakeDoc implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  FakeDoc(this._data);
  @override
  Map<String, dynamic>? data([options]) => _data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  static const String _cacheKey = 'match_users_cache';
  static const String _cacheTimeKey = 'match_users_cache_time';
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Filtreler
  double _maxDistance = 100.0; // km - çok daha geniş mesafe
  int _minAge = 18; // minimum yaş
  int _maxAge = 50; // maksimum yaş - daha geniş
  String? _preferredGender;

  @override
  void initState() {
    super.initState();
    _loadFromCache();
    _loadFilterSettings();
    _getCurrentLocation();
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheTime = prefs.getInt(_cacheTimeKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (cacheTime != null && now - cacheTime < _cacheDuration.inMilliseconds) {
      final cacheData = prefs.getString(_cacheKey);
      if (cacheData != null) {
        final List<dynamic> jsonList = json.decode(cacheData);
        final cachedUsers =
            jsonList.map((e) => UserModel.fromFirestore(FakeDoc(e))).toList();
        setState(() {
          _users = cachedUsers;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveToCache(List<UserModel> users) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = users.map((u) => u.toFirestore()).toList();
    await prefs.setString(_cacheKey, json.encode(jsonList));
    await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
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
        final geo = GeoFlutterFire();
        final myLocation = geo.point(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'currentLocation':
              GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
          'location': myLocation.data, // {'geohash': ..., 'geopoint': GeoPoint}
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
      // Firestore index uyarısı: Eğer composite index hatası alırsan, Firestore Console'dan önerilen indexi oluştur.
      final users = await _matchService.getNearbyUsers(
        maxDistance: _maxDistance * 1000, // km'yi metre'ye çevir
        minAge: _minAge,
        maxAge: _maxAge,
        preferredGender: _preferredGender,
        currentPosition: _currentPosition,
        // Son 24 saat aktif kullanıcılar için ek filtreleme MatchService'de yapılmalı
      );

      print('Yüklenen kullanıcı sayısı: ${users.length}');

      if (mounted) {
        setState(() {
          _users = users;
          _currentIndex = 0;
          _isLoading = false;
        });
        await _saveToCache(users);
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

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.person_2_fill,
              size: 48,
              color: isDark
                  ? AppTheme.iosDarkSecondaryText
                  : AppTheme.iosSecondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              'Yakında eşleşme yok',
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

  void _onSwipe(DismissDirection direction, int index) {
    if (direction == DismissDirection.endToStart) {
      _dislikeUser();
    } else if (direction == DismissDirection.startToEnd) {
      _likeUser();
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
                      color: AppTheme.iosPink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      CupertinoIcons.heart_fill,
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
                          'Eşleşme',
                          style: AppTheme.iosFontSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          _hasActiveFilters()
                              ? '${_users.length} kişi bulundu (filtreli)'
                              : '${_users.length} kişi bulundu',
                          style: AppTheme.iosFontSmall.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkSecondaryText
                                : AppTheme.iosSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showFilterDialog,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.iosDarkTertiaryBackground
                            : AppTheme.iosTertiaryBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        CupertinoIcons.slider_horizontal_3,
                        color: isDark
                            ? AppTheme.iosDarkPrimaryText
                            : AppTheme.iosPrimaryText,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Ana içerik
            Expanded(
              child: _isLoading
                  ? Center(child: CupertinoActivityIndicator())
                  : _users.isEmpty
                      ? _buildEmptyState()
                      : Stack(
                          alignment: Alignment.center,
                          children: List.generate(_users.length, (index) {
                            if (index >= _users.length) return const SizedBox();

                            final user = _users[index];
                            final isTop = index == _users.length - 1;

                            return Positioned.fill(
                              child: AnimatedOpacity(
                                opacity: isTop ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: AnimatedScale(
                                  scale: isTop ? 1.0 : 0.9,
                                  duration: const Duration(milliseconds: 200),
                                  child: Dismissible(
                                    key: ValueKey(user.id),
                                    direction: DismissDirection.horizontal,
                                    onDismissed: (direction) {
                                      if (direction ==
                                          DismissDirection.startToEnd) {
                                        _likeUser();
                                      } else {
                                        _dislikeUser();
                                      }
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.all(16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      elevation: 8,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: Container(
                                          color: isDark
                                              ? AppTheme
                                                  .iosDarkSecondaryBackground
                                              : AppTheme.iosSecondaryBackground,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildUserCard(user,
                                                  showDetails: true),
                                              Flexible(
                                                child: SingleChildScrollView(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                                  child:
                                                      _buildUserDetails(user),
                                                ),
                                              ),
                                              _buildActionButtons(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).reversed.toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user, {bool showDetails = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.iosDarkSecondaryBackground
            : AppTheme.iosSecondaryBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profil fotoğrafı ve temel bilgiler
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: user.photoURL != null
                  ? CachedNetworkImage(
                      imageUrl: user.photoURL!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: isDark
                            ? AppTheme.iosDarkTertiaryBackground
                            : AppTheme.iosTertiaryBackground,
                        child:
                            const Center(child: CupertinoActivityIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark
                            ? AppTheme.iosDarkTertiaryBackground
                            : AppTheme.iosTertiaryBackground,
                        child: Icon(
                          CupertinoIcons.person_fill,
                          size: 48,
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                      ),
                    )
                  : Container(
                      color: isDark
                          ? AppTheme.iosDarkTertiaryBackground
                          : AppTheme.iosTertiaryBackground,
                      child: Icon(
                        CupertinoIcons.person_fill,
                        size: 48,
                        color: isDark
                            ? AppTheme.iosDarkSecondaryText
                            : AppTheme.iosSecondaryText,
                      ),
                    ),
            ),
          ),

          // Kullanıcı bilgileri
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: AppTheme.iosFont.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.iosDarkPrimaryText
                              : AppTheme.iosPrimaryText,
                        ),
                      ),
                    ),
                    Text(
                      '${user.age} yaş',
                      style: AppTheme.iosFontSmall.copyWith(
                        color: isDark
                            ? AppTheme.iosDarkSecondaryText
                            : AppTheme.iosSecondaryText,
                      ),
                    ),
                  ],
                ),
                if (user.university != null && user.university!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      user.university!,
                      style: AppTheme.iosFontSmall.copyWith(
                        color: isDark
                            ? AppTheme.iosDarkSecondaryText
                            : AppTheme.iosSecondaryText,
                      ),
                    ),
                  ),
                if (user.bio != null && user.bio!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      user.bio!,
                      style: AppTheme.iosFontSmall.copyWith(
                        color: isDark
                            ? AppTheme.iosDarkSecondaryText
                            : AppTheme.iosSecondaryText,
                      ),
                      maxLines: showDetails ? null : 2,
                      overflow: showDetails ? null : TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetails(UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.interests != null && user.interests!.isNotEmpty) ...[
              Text(
                'İlgi Alanları',
                style: AppTheme.iosFontSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.iosDarkPrimaryText
                      : AppTheme.iosPrimaryText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.interests!
                    .map((interest) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.iosDarkTertiaryBackground
                                : AppTheme.iosTertiaryBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            interest,
                            style: AppTheme.iosFontSmall.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkSecondaryText
                                  : AppTheme.iosSecondaryText,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (user.bio != null && user.bio!.isNotEmpty) ...[
              Text(
                'Hakkında',
                style: AppTheme.iosFontSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.iosDarkPrimaryText
                      : AppTheme.iosPrimaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.bio!,
                style: AppTheme.iosFontSmall.copyWith(
                  color: isDark
                      ? AppTheme.iosDarkSecondaryText
                      : AppTheme.iosSecondaryText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _dislikeUser,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.iosDarkTertiaryBackground
                    : AppTheme.iosTertiaryBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.xmark,
                color: AppTheme.iosRed,
                size: 32,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _likeUser,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.iosDarkTertiaryBackground
                    : AppTheme.iosTertiaryBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.heart_fill,
                color: AppTheme.iosPink,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Geçici değerler için state
    double tempMaxDistance = _maxDistance;
    int tempMinAge = _minAge;
    int tempMaxAge = _maxAge;
    String? tempPreferredGender = _preferredGender;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Material(
            type: MaterialType.transparency,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.iosDarkSecondaryBackground
                          : AppTheme.iosSecondaryBackground,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
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
                            color: AppTheme.iosPink,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            CupertinoIcons.slider_horizontal_3,
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
                                'Filtre Ayarları',
                                style: AppTheme.iosFontSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                ),
                              ),
                              Text(
                                'Eşleşme tercihlerinizi ayarlayın',
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Mesafe Filtresi
                          _buildFilterSection(
                            title: '📍 Maksimum Mesafe',
                            subtitle: tempMaxDistance >= 100
                                ? '🌍 Mesafe sınırı yok (tüm kullanıcılar)'
                                : '📍 Maksimum mesafe: ${tempMaxDistance.round()}km',
                            color: tempMaxDistance >= 100
                                ? AppTheme.iosGreen
                                : AppTheme.iosBlue,
                            child: Column(
                              children: [
                                CupertinoSlider(
                                  value: tempMaxDistance.clamp(1.0, 100.0),
                                  min: 1,
                                  max: 100,
                                  divisions: 99,
                                  activeColor: AppTheme.iosBlue,
                                  onChanged: (value) {
                                    setModalState(() {
                                      tempMaxDistance = value;
                                    });
                                  },
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '1km',
                                      style: AppTheme.iosFontCaption.copyWith(
                                        color: isDark
                                            ? AppTheme.iosDarkSecondaryText
                                            : AppTheme.iosSecondaryText,
                                      ),
                                    ),
                                    Text(
                                      '100km+',
                                      style: AppTheme.iosFontCaption.copyWith(
                                        color: isDark
                                            ? AppTheme.iosDarkSecondaryText
                                            : AppTheme.iosSecondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Yaş Aralığı Filtresi
                          _buildFilterSection(
                            title: '👥 Yaş Aralığı',
                            subtitle:
                                '👥 Yaş aralığı: $tempMinAge - $tempMaxAge',
                            color: AppTheme.iosPink,
                            child: Column(
                              children: [
                                RangeSlider(
                                  values: RangeValues(tempMinAge.toDouble(),
                                      tempMaxAge.toDouble()),
                                  min: 18,
                                  max: 50,
                                  divisions: 32,
                                  activeColor: AppTheme.iosPink,
                                  onChanged: (values) {
                                    setModalState(() {
                                      tempMinAge = values.start.round();
                                      tempMaxAge = values.end.round();
                                    });
                                  },
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '18',
                                      style: AppTheme.iosFontCaption.copyWith(
                                        color: isDark
                                            ? AppTheme.iosDarkSecondaryText
                                            : AppTheme.iosSecondaryText,
                                      ),
                                    ),
                                    Text(
                                      '50',
                                      style: AppTheme.iosFontCaption.copyWith(
                                        color: isDark
                                            ? AppTheme.iosDarkSecondaryText
                                            : AppTheme.iosSecondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Cinsiyet Tercihi Filtresi
                          _buildFilterSection(
                            title: '👤 Cinsiyet Tercihi',
                            subtitle: tempPreferredGender == null
                                ? '🤷 Fark etmez'
                                : tempPreferredGender == 'Erkek'
                                    ? '👨 Erkek'
                                    : '👩 Kadın',
                            color: AppTheme.iosPurple,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.iosDarkTertiaryBackground
                                    : AppTheme.iosTertiaryBackground,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: tempPreferredGender,
                                  isExpanded: true,
                                  icon: Icon(
                                    CupertinoIcons.chevron_down,
                                    color: isDark
                                        ? AppTheme.iosDarkSecondaryText
                                        : AppTheme.iosSecondaryText,
                                  ),
                                  style: AppTheme.iosFontSmall.copyWith(
                                    color: isDark
                                        ? AppTheme.iosDarkPrimaryText
                                        : AppTheme.iosPrimaryText,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Row(
                                        children: [
                                          const Text('🤷 '),
                                          Text(
                                            'Fark etmez',
                                            style: AppTheme.iosFontSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Erkek',
                                      child: Row(
                                        children: [
                                          const Text('👨 '),
                                          Text(
                                            'Erkek',
                                            style: AppTheme.iosFontSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Kadın',
                                      child: Row(
                                        children: [
                                          const Text('👩 '),
                                          Text(
                                            'Kadın',
                                            style: AppTheme.iosFontSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setModalState(() {
                                      tempPreferredGender = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.iosDarkSecondaryBackground
                          : AppTheme.iosSecondaryBackground,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'İptal',
                              style: AppTheme.iosFontSmall.copyWith(
                                color: AppTheme.iosRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoButton.filled(
                            onPressed: () async {
                              // Değerleri güncelle
                              setState(() {
                                _maxDistance = tempMaxDistance;
                                _minAge = tempMinAge;
                                _maxAge = tempMaxAge;
                                _preferredGender = tempPreferredGender;
                              });

                              await _saveFilterSettings();
                              Navigator.pop(context);
                              _loadUsers();
                            },
                            child: const Text('Uygula'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ),
    );
  }

  bool _hasActiveFilters() {
    // Default değerlerden farklı olan filtreler varsa aktif sayılır
    return _maxDistance < 100.0 || // Mesafe sınırı varsa
        _minAge > 18 || // Minimum yaş 18'den büyükse
        _maxAge < 50 || // Maksimum yaş 50'den küçükse
        _preferredGender != null; // Cinsiyet tercihi varsa
  }

  Widget _buildFilterSection({
    required String title,
    required String subtitle,
    required Color color,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.iosDarkTertiaryBackground
            : AppTheme.iosTertiaryBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.iosFontSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.iosDarkPrimaryText
                  : AppTheme.iosPrimaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTheme.iosFontCaption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
