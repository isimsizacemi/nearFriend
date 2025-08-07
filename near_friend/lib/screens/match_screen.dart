import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:location/location.dart';
import '../utils/location_debug.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../models/user_model.dart';
import '../services/match_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:swipe_cards/swipe_cards.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with TickerProviderStateMixin {
  final List<UserModel> _users = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreUsers = true;
  LocationData? _currentPosition;
  DocumentSnapshot? _lastDocument;

  int _minAge = 18;
  int _maxAge = 100;
  String _selectedGender = 'Hepsi';
  double _maxDistance = 30.0;

  MatchEngine? _matchEngine;
  List<SwipeItem> _swipeItems = [];
  final int _pageSize = 10; // Sayfa boyutunu artırdım

  static const String _locationCacheKey = 'match_screen_location';
  static const String _usersCacheKey = 'match_screen_users';
  static const Duration _cacheDuration = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    print('🚀 MatchScreen: Başlatılıyor...');

    await Future.wait([
      _getCurrentLocationWithCache(),
      _loadUsersWithCache(),
    ]);

    print('✅ MatchScreen: Başlatma tamamlandı');
  }

  Future<void> _getCurrentLocationWithCache() async {
    print('🔄 Konum alınıyor (cache ile)...');

    try {
      final cachedLocation = await _getCachedLocation();
      if (cachedLocation != null) {
        setState(() {
          _currentPosition = cachedLocation;
        });
        print('✅ Cache\'den konum alındı');
        return;
      }

      Location location = Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          print('❌ Konum servisi açılamadı');
          return;
        }
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          print('❌ Konum izni alınamadı');
          return;
        }
      }

      await location.changeSettings(
        accuracy: LocationAccuracy.balanced, // Daha hızlı
        interval: 5000, // 5 saniye
        distanceFilter: 10, // 10 metre
      );

      _currentPosition = await location.getLocation();

      await _cacheLocation(_currentPosition!);

      print(
          '✅ Yeni konum alındı ve cache\'lendi: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
    } catch (e) {
      print('❌ Konum alınamadı: $e');
    }
  }

  Future<LocationData?> _getCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationData = prefs.getString(_locationCacheKey);
      final timestamp = prefs.getInt('${_locationCacheKey}_timestamp');

      if (locationData != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();

        if (now.difference(cacheTime) < _cacheDuration) {
          final data = json.decode(locationData);
          return LocationData.fromMap(data);
        }
      }
    } catch (e) {
      print('❌ Cache\'den konum alınamadı: $e');
    }
    return null;
  }

  Future<void> _cacheLocation(LocationData location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationData = json.encode({
        'latitude': location.latitude,
        'longitude': location.longitude,
        'accuracy': location.accuracy,
        'altitude': location.altitude,
        'heading': location.heading,
        'speed': location.speed,
        'speedAccuracy': location.speedAccuracy,
        'time': location.time,
      });

      await prefs.setString(_locationCacheKey, locationData);
      await prefs.setInt('${_locationCacheKey}_timestamp',
          DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ Konum cache\'lenemedi: $e');
    }
  }

  Future<void> _loadUsersWithCache() async {
    print('🔄 Kullanıcılar yükleniyor (cache ile)...');

    setState(() {
      _isLoading = true;
    });

    try {
      final cachedUsers = await _getCachedUsers();
      if (cachedUsers.isNotEmpty) {
        setState(() {
          _users.clear();
          _users.addAll(cachedUsers);
          _isLoading = false;
        });

        print('✅ Cache\'den ${cachedUsers.length} kullanıcı yüklendi');

        _refreshUsersInBackground();
        return;
      }

      await _loadUsersFromFirestore();
    } catch (e) {
      print('❌ Kullanıcılar yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<UserModel>> _getCachedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersData = prefs.getString(_usersCacheKey);
      final timestamp = prefs.getInt('${_usersCacheKey}_timestamp');

      if (usersData != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();

        if (now.difference(cacheTime) < _cacheDuration) {
          final List<dynamic> usersList = json.decode(usersData);
          return usersList
              .map((userData) => UserModel.fromJson(userData))
              .toList();
        }
      }
    } catch (e) {
      print('❌ Cache\'den kullanıcılar alınamadı: $e');
    }
    return [];
  }

  Future<void> _cacheUsers(List<UserModel> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersData =
          json.encode(users.map((user) => user.toJson()).toList());

      await prefs.setString(_usersCacheKey, usersData);
      await prefs.setInt(
          '${_usersCacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ Kullanıcılar cache\'lenemedi: $e');
    }
  }

  Future<void> _loadUsersFromFirestore() async {
    try {
      print('🔥 Firestore\'dan kullanıcılar yükleniyor...');

      final matchService = MatchService();
      final users = await matchService
          .getNearbyUsers(
            limit: _pageSize,
            lastDocument: null,
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => <UserModel>[],
          );

      print('📊 Firestore\'dan ${users.length} kullanıcı alındı');

      final filteredUsers = _applyFilters(users);
      print('🔍 Filtreleme sonrası ${filteredUsers.length} kullanıcı kaldı');

      if (users.isNotEmpty) {
        final lastUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(users.last.id)
            .get();
        _lastDocument = lastUserDoc;
      }

      _hasMoreUsers = users.length >= _pageSize;

      setState(() {
        _users.clear();
        _users.addAll(filteredUsers);
        _isLoading = false;
      });

      if (filteredUsers.isNotEmpty) {
        await _cacheUsers(filteredUsers);
        print('💾 ${filteredUsers.length} kullanıcı cache\'lendi');
      }

      print(
          '📱 ${filteredUsers.length} kullanıcı yüklendi (Toplam: ${_users.length})');

      for (var user in filteredUsers.take(3)) {
        print('👤 ${user.displayName} (${user.age} yaş, ${user.gender})');
      }
    } catch (e) {
      print('❌ Firestore\'dan kullanıcılar yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshUsersInBackground() async {
    try {
      final matchService = MatchService();
      final users = await matchService
          .getNearbyUsers(
            limit: _pageSize,
            lastDocument: null,
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => <UserModel>[],
          );

      final filteredUsers = _applyFilters(users);

      if (filteredUsers.isNotEmpty && mounted) {
        setState(() {
          _users.clear();
          _users.addAll(filteredUsers);
        });

        await _cacheUsers(filteredUsers);
        _updateSwipeEngine();

        print('🔄 Arka planda ${filteredUsers.length} kullanıcı güncellendi');
      }
    } catch (e) {
      print('❌ Arka plan güncelleme hatası: $e');
    }
  }

  Future<void> _loadUsers({bool isRefresh = false}) async {
    if (isRefresh) {
      await _loadUsersFromFirestore();
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMoreUsers) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final matchService = MatchService();
      final users = await matchService
          .getNearbyUsers(
            limit: _pageSize,
            lastDocument: _lastDocument,
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => <UserModel>[],
          );

      if (users.isNotEmpty) {
        final lastUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(users.last.id)
            .get();
        _lastDocument = lastUserDoc;
      }

      if (users.length < _pageSize) {
        _hasMoreUsers = false;
      }

      final filteredUsers = _applyFilters(users);

      setState(() {
        _users.addAll(filteredUsers);
        _isLoadingMore = false;
      });

      if (filteredUsers.isNotEmpty) {
        _updateSwipeEngine();
      }
    } catch (e) {
      print('❌ Daha fazla kullanıcı yüklenirken hata: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  List<UserModel> _applyFilters(List<UserModel> users) {
    return users.where((user) {
      if (user.age != null) {
        if (user.age! < _minAge || user.age! > _maxAge) return false;
      }

      if (_selectedGender != 'Hepsi' && user.gender != null) {
        if (user.gender != _selectedGender) return false;
      }

      if (_currentPosition != null && user.currentLocation != null) {
        final distance = _calculateDistance(
          _currentPosition!.latitude!,
          _currentPosition!.longitude!,
          user.currentLocation!.latitude,
          user.currentLocation!.longitude,
        );
        if (distance > _maxDistance * 1000) return false;
      }

      return true;
    }).toList();
  }

  void _setupSwipeEngine() {
    if (_users.isEmpty) return;

    _swipeItems = _users.map((user) {
      return SwipeItem(
        content: user,
        likeAction: () => _likeUser(user),
        nopeAction: () => _dislikeUser(user),
      );
    }).toList();
    _matchEngine = MatchEngine(swipeItems: _swipeItems);

    print('✅ Swipe engine kuruldu: ${_swipeItems.length} kullanıcı');

    if (mounted) {
      setState(() {});
    }
  }

  void _updateSwipeEngine() {
    if (_users.isEmpty) return;

    final newSwipeItems = _users.map((user) {
      return SwipeItem(
        content: user,
        likeAction: () => _likeUser(user),
        nopeAction: () => _dislikeUser(user),
      );
    }).toList();

    _swipeItems = newSwipeItems;
    _matchEngine = MatchEngine(swipeItems: _swipeItems);

    print('🔄 Swipe engine güncellendi: ${_swipeItems.length} kullanıcı');
  }

  Future<void> _likeUser(UserModel user) async {
    try {
      final matchService = MatchService();
      await matchService.likeUser(user.id);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null) {
          final otherUserPending =
              List<String>.from(userData['pendingMatches'] ?? []);

          if (otherUserPending.contains(currentUser.uid)) {
            _showMatchDialog(user);
          } else {
            _showLikeSnackbar(user);
          }
        }
      }

      setState(() {
        _users.remove(user);
      });

      if (_users.isEmpty && _hasMoreUsers && !_isLoadingMore) {
        _loadMoreUsers();
      }
    } catch (e) {
      print('❌ Beğeni işlemi hatası: $e');
      _showErrorSnackbar('Beğeni işlemi başarısız');
    }
  }

  Future<void> _dislikeUser(UserModel user) async {
    try {
      final matchService = MatchService();
      await matchService.dislikeUser(user.id);

      setState(() {
        _users.remove(user);
      });

      if (_users.isEmpty && _hasMoreUsers && !_isLoadingMore) {
        _loadMoreUsers();
      }
    } catch (e) {
      print('❌ Beğenmeme işlemi hatası: $e');
    }
  }

  void _showMatchDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.favorite, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Eşleşme!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('🎉 ${user.displayName} ile eşleştin!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Devam Et'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'otherUserId': user.id,
                  'otherUserName': user.displayName ?? 'İsimsiz Kullanıcı',
                },
              );
            },
            child: Text('Mesaj Gönder'),
          ),
        ],
      ),
    );
  }

  void _showLikeSnackbar(UserModel user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.favorite, color: Colors.white),
            SizedBox(width: 8),
            Text('${user.displayName} beğenildi'),
          ],
        ),
        backgroundColor: Colors.pink,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);
    double a = 0.5 -
        cos(dLat) / 2 +
        cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) * (1 - cos(dLon)) / 2;
    return earthRadius * 2 * asin(sqrt(a));
  }

  bool _hasActiveFilters() {
    return _maxDistance != 30.0 ||
        _minAge != 18 ||
        _maxAge != 100 ||
        _selectedGender != 'Hepsi';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _matchEngine == null && _users.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupSwipeEngine();
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: Text(
        _hasActiveFilters() ? 'Eşleşmeler (Filtreli)' : 'Eşleşmeler',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
      actions: [
        IconButton(
          icon:
              Icon(Icons.filter_list, color: Theme.of(context).iconTheme.color),
          onPressed: _showFilterDialog,
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: Theme.of(context).iconTheme.color),
          onPressed: () => _loadUsersWithCache(),
        ),
        IconButton(
          icon:
              Icon(Icons.bug_report, color: Theme.of(context).iconTheme.color),
          onPressed: _debugInfo,
        ),
      ],
    );
  }

  void _debugInfo() {
    print('=== DEBUG BİLGİLERİ ===');
    print('📊 Toplam kullanıcı: ${_users.length}');
    print('🔄 Yükleniyor: $_isLoading');
    print('📍 Konum: ${_currentPosition != null ? "Mevcut" : "Yok"}');
    print('🎯 Swipe items: ${_swipeItems.length}');
    print('📄 Son doküman: ${_lastDocument != null ? "Mevcut" : "Yok"}');
    print('➕ Daha fazla kullanıcı: $_hasMoreUsers');
    print('🔍 Filtreler:');
    print('   - Yaş: $_minAge - $_maxAge');
    print('   - Cinsiyet: $_selectedGender');
    print('   - Mesafe: ${_maxDistance.round()} km');

    _getCacheStatus();
  }

  Future<void> _getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationCache = prefs.getString(_locationCacheKey);
      final usersCache = prefs.getString(_usersCacheKey);

      print('💾 Cache Durumu:');
      print('   - Konum cache: ${locationCache != null ? "Mevcut" : "Yok"}');
      print('   - Kullanıcı cache: ${usersCache != null ? "Mevcut" : "Yok"}');
    } catch (e) {
      print('❌ Cache durumu alınamadı: $e');
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Kullanıcılar yükleniyor...'),
            if (_currentPosition == null) ...[
              SizedBox(height: 8),
              Text(
                'Konum alınıyor...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Eşleşme bulunamadı',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Filtrelerinizi değiştirmeyi deneyin',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadUsersWithCache(),
              child: Text('Yenile'),
            ),
          ],
        ),
      );
    }

    if (_matchEngine == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Swipe engine hazırlanıyor...'),
          ],
        ),
      );
    }

    return SwipeCards(
      matchEngine: _matchEngine!,
      itemBuilder: (context, index) {
        final user = _swipeItems[index].content as UserModel;
        return _buildUserCard(user);
      },
      onStackFinished: () {
        if (_hasMoreUsers && !_isLoadingMore) {
          _loadMoreUsers();
        }
        setState(() {});
      },
      upSwipeAllowed: false,
      fillSpace: true,
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                child: user.getProfileImageProvider() != null
                    ? CachedNetworkImage(
                        imageUrl: user.getProfileImageProvider()!.toString(),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child:
                              Icon(Icons.person, size: 64, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.person, size: 64, color: Colors.grey),
                      ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.all(16),
                color: Theme.of(context).cardColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName ?? 'İsimsiz Kullanıcı',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.age != null)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${user.age}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (user.university != null) ...[
                      SizedBox(height: 4),
                      Text(
                        user.university!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        user.bio!,
                        style: TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (user.interests.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: user.interests.take(3).map((interest) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              interest,
                              style: TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildBottomBar() {
    if (_users.isEmpty || _matchEngine == null) return null;

    return Container(
      padding: EdgeInsets.only(bottom: 24, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: CupertinoIcons.xmark,
            color: Colors.red,
            onPressed: () => _matchEngine!.currentItem?.nope(),
          ),
          _buildActionButton(
            icon: CupertinoIcons.heart_fill,
            color: Colors.pink,
            onPressed: () => _matchEngine!.currentItem?.like(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }

  void _showFilterDialog() {
    int tempMinAge = _minAge;
    int tempMaxAge = _maxAge;
    String tempSelectedGender = _selectedGender;
    double tempMaxDistance = _maxDistance;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title:
              Text('Filtrele', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Yaş Aralığı: $tempMinAge - $tempMaxAge'),
                RangeSlider(
                  values:
                      RangeValues(tempMinAge.toDouble(), tempMaxAge.toDouble()),
                  min: 18,
                  max: 100,
                  divisions: 82,
                  labels:
                      RangeLabels(tempMinAge.toString(), tempMaxAge.toString()),
                  onChanged: (RangeValues values) {
                    setDialogState(() {
                      tempMinAge = values.start.round();
                      tempMaxAge = values.end.round();
                    });
                  },
                ),
                SizedBox(height: 16),
                Text('Cinsiyet'),
                DropdownButton<String>(
                  value: tempSelectedGender,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: 'Hepsi', child: Text('Hepsi')),
                    DropdownMenuItem(value: 'Erkek', child: Text('Erkek')),
                    DropdownMenuItem(value: 'Kadın', child: Text('Kadın')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      tempSelectedGender = value ?? 'Hepsi';
                    });
                  },
                ),
                SizedBox(height: 16),
                Text('Maksimum Mesafe: ${tempMaxDistance.round()} km'),
                Slider(
                  value: tempMaxDistance,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: tempMaxDistance.round().toString(),
                  onChanged: (value) {
                    setDialogState(() {
                      tempMaxDistance = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _minAge = tempMinAge;
                  _maxAge = tempMaxAge;
                  _selectedGender = tempSelectedGender;
                  _maxDistance = tempMaxDistance;
                });

                Navigator.pop(context);

                _applyRealtimeFilters();
              },
              child: Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyRealtimeFilters() {
    print('🔄 Realtime filtreleme uygulanıyor...');

    final filteredUsers = _users.where((user) {
      if (user.age != null) {
        if (user.age! < _minAge || user.age! > _maxAge) return false;
      }

      if (_selectedGender != 'Hepsi' && user.gender != null) {
        if (user.gender != _selectedGender) return false;
      }

      if (_currentPosition != null && user.currentLocation != null) {
        final distance = _calculateDistance(
          _currentPosition!.latitude!,
          _currentPosition!.longitude!,
          user.currentLocation!.latitude,
          user.currentLocation!.longitude,
        );
        if (distance > _maxDistance * 1000) return false;
      }

      return true;
    }).toList();

    setState(() {
      _users.clear();
      _users.addAll(filteredUsers);
    });

    if (_users.isNotEmpty) {
      _updateSwipeEngine();
    } else {
      _loadUsersFromFirestore();
    }

    print(
        '✅ Realtime filtreleme tamamlandı: ${filteredUsers.length} kullanıcı');
  }
}
