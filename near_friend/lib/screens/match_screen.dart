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
import 'package:swipe_cards/swipe_cards.dart';

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

class _MatchScreenState extends State<MatchScreen>
    with TickerProviderStateMixin {
  final List<UserModel> _users = [];
  bool _isLoading = true;
  Position? _currentPosition;

  // Filtre değişkenleri
  int _minAge = 18;
  int _maxAge = 100;
  String _selectedGender = 'Hepsi';
  double _maxDistance = 30.0;

  late MatchEngine _matchEngine;
  List<SwipeItem> _swipeItems = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
      _loadUsers();
    } catch (e) {
      print('Konum alınamadı: $e');
    }
  }

  Future<void> _loadUsers() async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final users = await FirebaseFirestore.instance
          .collection('users')
          .where('isActive', isEqualTo: true)
          .where('hasCreatedProfile', isEqualTo: true)
          .get();

      final filteredUsers =
          users.docs.map((doc) => UserModel.fromFirestore(doc)).where((user) {
        // Yaş filtresi
        if (user.age == null) return false;
        if (user.age! < _minAge || user.age! > _maxAge) return false;

        // Cinsiyet filtresi
        if (_selectedGender != 'Hepsi' && user.gender != _selectedGender) {
          return false;
        }

        // Mesafe filtresi
        if (user.currentLocation != null) {
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
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
        _isLoading = false;
      });
    } catch (e) {
      print('Kullanıcılar yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupSwipeEngine() {
    _swipeItems = _users.map((user) {
      return SwipeItem(
        content: user,
        likeAction: () => _likeUser(user),
        nopeAction: () => _dislikeUser(user),
      );
    }).toList();
    _matchEngine = MatchEngine(swipeItems: _swipeItems);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading) {
      _setupSwipeEngine();
    }
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_hasActiveFilters() ? 'Eşleşmeler (Filtreli)' : 'Eşleşmeler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Eşleşme bulunamadı'))
              : Center(
                  child: SwipeCards(
                    matchEngine: _matchEngine,
                    itemBuilder: (context, index) {
                      final user = _swipeItems[index].content as UserModel;
                      return _buildUserCard(user);
                    },
                    onStackFinished: () {
                      setState(() {});
                    },
                    upSwipeAllowed: false,
                    fillSpace: true,
                  ),
                ),
      bottomNavigationBar: _users.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _matchEngine.currentItem?.nope(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
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
                    onPressed: () => _matchEngine.currentItem?.like(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
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
            )
          : null,
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrele'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Yaş aralığı
            const Text('Yaş Aralığı'),
            RangeSlider(
              values: RangeValues(
                _minAge.toDouble(),
                _maxAge.toDouble(),
              ),
              min: 18,
              max: 100,
              divisions: 82,
              labels: RangeLabels(
                _minAge.toString(),
                _maxAge.toString(),
              ),
              onChanged: (RangeValues values) {
                setState(() {
                  _minAge = values.start.round();
                  _maxAge = values.end.round();
                });
              },
            ),
            // Cinsiyet
            const Text('Cinsiyet'),
            DropdownButton<String>(
              value: _selectedGender,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'Hepsi', child: Text('Hepsi')),
                DropdownMenuItem(value: 'Erkek', child: Text('Erkek')),
                DropdownMenuItem(value: 'Kadın', child: Text('Kadın')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value ?? 'Hepsi';
                });
              },
            ),
            // Mesafe
            const Text('Maksimum Mesafe (km)'),
            Slider(
              value: _maxDistance,
              min: 1,
              max: 100,
              divisions: 99,
              label: _maxDistance.round().toString(),
              onChanged: (value) {
                setState(() {
                  _maxDistance = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadUsers(); // Filtreleri uygula
            },
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
  }

  void _likeUser(UserModel user) {
    setState(() {
      _users.remove(user);
    });
    // Beğeni işlemleri burada
  }

  void _dislikeUser(UserModel user) {
    setState(() {
      _users.remove(user);
    });
    // Beğenmeme işlemleri burada
  }

  double _calculateDistance(UserModel user) {
    if (_currentPosition == null || user.currentLocation == null) return 0;

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      user.currentLocation!.latitude,
      user.currentLocation!.longitude,
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: user.getProfileImageProvider() != null
                    ? CachedNetworkImage(
                        imageUrl: user.getProfileImageProvider()!.toString(),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      )
                    : Image.asset(
                        'assets/images/default_avatar.png',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName ?? 'İsimsiz Kullanıcı',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.age != null)
                      Text(
                        '${user.age} yaş',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                if (user.university != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.university!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    user.bio!,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (user.interests.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: user.interests.map((interest) {
                      return Chip(
                        label: Text(
                          interest,
                          style: const TextStyle(fontSize: 12),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            onPressed: () => _matchEngine.currentItem?.nope(),
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
            onPressed: () => _matchEngine.currentItem?.like(),
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

  bool _hasActiveFilters() {
    return _maxDistance != 30.0 ||
        _minAge != 18 ||
        _maxAge != 100 ||
        _selectedGender != 'Hepsi';
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
