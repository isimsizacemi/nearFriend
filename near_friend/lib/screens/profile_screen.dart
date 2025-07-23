import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/checkin_model.dart';
import '../utils/app_theme.dart';
import 'profile_edit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false; // Her seferinde yeniden oluştur

  void refreshProfile() {
    setState(() {
      _isLoading = true;
      _isLoadingPosts = true;
    });

    _loadUserData();
    _loadUserPosts();
  }

  final _authService = AuthService();

  // Kullanıcı verileri
  Map<String, dynamic>? _userData;
  List<CheckinModel> _userPosts = [];
  bool _isLoading = false;
  bool _isLoadingPosts = false;

  // Cache kullanmıyoruz, direkt Firestore'dan veri çekiyoruz

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserPosts();
  }

  // Cache fonksiyonları kaldırıldı - direkt Firestore'dan veri çekiyoruz

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _userData = userData;
          });
        }
      } catch (e) {
        print('Kullanıcı verileri yüklenirken hata: $e');
      }
    }
  }

  Future<void> _loadUserPosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoadingPosts = true);
    try {
      // Tüm gönderileri getir, sadece son 7 günlük değil
      final query = FirebaseFirestore.instance
          .collection('checkins')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(50); // Performans için limit ekle

      final snapshot = await query.get();
      final posts = snapshot.docs
          .map((doc) => CheckinModel.fromFirestore(doc))
          .where((post) => post.isActive)
          .toList();

      print('=== PROFİL EKRANI DEBUG ===');
      print('Yüklenen gönderi sayısı: ${posts.length}');
      print('Toplam doküman sayısı: ${snapshot.docs.length}');
      print('Kullanıcı ID: ${user.uid}');
      print('Sorgu başarılı!');
      print('Gönderiler:');
      for (var post in posts) {
        print('- ${post.userDisplayName}: ${post.message} (${post.createdAt})');
      }
      print('==========================');

      // Firestore'dan gelen ham veriyi kontrol et
      print('=== HAM VERİ DEBUG ===');
      for (var doc in snapshot.docs) {
        print('Doküman ID: ${doc.id}');
        print('Veri: ${doc.data()}');
        print('---');
      }
      print('=====================');

      setState(() {
        _userPosts = posts;
      });
    } catch (e) {
      print('Kullanıcı gönderileri yüklenirken hata: $e');
      // Hata durumunda daha basit bir sorgu dene
      try {
        final simpleQuery = FirebaseFirestore.instance
            .collection('checkins')
            .where('userId', isEqualTo: user.uid)
            .limit(20);
        final simpleSnapshot = await simpleQuery.get();
        final simplePosts = simpleSnapshot.docs
            .map((doc) => CheckinModel.fromFirestore(doc))
            .where((post) => post.isActive)
            .toList();
        setState(() {
          _userPosts = simplePosts;
        });
        print('=== BASİT SORGU DEBUG ===');
        print('Basit sorgu ile yüklenen gönderi sayısı: ${simplePosts.length}');
        print('Basit sorgu başarılı!');
        print('Basit sorgu gönderileri:');
        for (var post in simplePosts) {
          print(
              '- ${post.userDisplayName}: ${post.message} (${post.createdAt})');
        }
        print('==========================');
      } catch (simpleError) {
        print('Basit sorgu da başarısız: $simpleError');
        setState(() {
          _userPosts = [];
        });
      }
    } finally {
      setState(() => _isLoadingPosts = false);
    }
  }

  void _showLogoutDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text(
            'Hesabınızdan çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            isDestructiveAction: true,
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Tüm cache'i temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        // Önce snackbar göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Başarıyla çıkış yapıldı'),
            backgroundColor: AppTheme.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Kısa bir bekleme sonrası login ekranına yönlendir
        await Future.delayed(const Duration(milliseconds: 500));

        // Tüm stacki temizle ve login ekranına git
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çıkış yapılırken hata: $e'),
            backgroundColor: AppTheme.iosRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _navigateToEditProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      if (!mounted) return;

      final userModel = UserModel.fromFirestore(userDoc);
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileEditScreen(user: userModel),
        ),
      );

      if (result == true) {
        _loadUserData();
        _loadUserPosts();
      }
    } catch (e) {
      print('Profil düzenleme ekranına giderken hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      // Kullanıcı yoksa otomatik olarak login ekranına yönlendir
      Future.microtask(() {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      });
      return Scaffold(
        backgroundColor:
            isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
        body: Center(
          child: Text(
            'Kullanıcı bulunamadı',
            style: AppTheme.iosFont.copyWith(
              color: isDark
                  ? AppTheme.iosDarkPrimaryText
                  : AppTheme.iosPrimaryText,
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
            // iOS Style Header - Daha kompakt ve modern
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.iosOrange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      CupertinoIcons.person_fill,
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
                          'Profilim',
                          style: AppTheme.iosFontSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          '${_userPosts.length} paylaşım',
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
                    onPressed: () async {
                      setState(() {
                        _isLoading = true;
                        _isLoadingPosts = true;
                      });

                      try {
                        await _loadUserData();
                        await _loadUserPosts();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Profil güncellendi!'),
                              backgroundColor: AppTheme.iosGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      } catch (e) {
                        print('Profil güncelleme hatası: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Güncelleme sırasında hata: $e'),
                              backgroundColor: AppTheme.iosRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                            _isLoadingPosts = false;
                          });
                        }
                      }
                    },
                    child: Icon(
                      CupertinoIcons.refresh,
                      color: AppTheme.iosOrange,
                      size: 20,
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () {
                      _navigateToEditProfile();
                    },
                    child: Icon(
                      CupertinoIcons.pencil,
                      color: AppTheme.iosOrange,
                      size: 20,
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () {
                      _showLogoutDialog();
                    },
                    child: Icon(
                      CupertinoIcons.ellipsis,
                      color: AppTheme.iosOrange,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Profil Bilgileri
                    _buildProfileContent(),

                    // Gönderiler
                    _isLoadingPosts
                        ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: 6,
                            itemBuilder: (context, index) =>
                                _buildSkeletonCard(),
                          )
                        : _userPosts.isEmpty
                            ? Center(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  margin: const EdgeInsets.all(16),
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
                                        'Gönderi yok',
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
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: _userPosts.length,
                                itemBuilder: (context, index) {
                                  return _buildPostCard(
                                      _userPosts[index], isDark);
                                },
                              ),
                  ],
                ),
              ),
            ),
            if (_isLoadingPosts)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Gönderiler yükleniyor...',
                  style: AppTheme.iosFont.copyWith(
                    color: isDark
                        ? AppTheme.iosDarkSecondaryText
                        : AppTheme.iosSecondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

  Widget _buildProfileContent() {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Profil Bilgileri - Daha kompakt
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.iosDarkSecondaryBackground
                  : AppTheme.iosSecondaryBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppTheme.iosDarkSecondaryText.withOpacity(0.05)
                    : AppTheme.iosSecondaryText.withOpacity(0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Profil Fotoğrafı ve Bilgiler
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: AppTheme.iosOrange.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: _userData?['photoURL'] != null &&
                                (_userData!['photoURL'] as String)
                                    .startsWith('assets/')
                            ? Image.asset(_userData!['photoURL'],
                                fit: BoxFit.cover)
                            : Image.asset('assets/images/default_avatar.png',
                                fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userData?['displayName'] ?? 'İsimsiz Kullanıcı',
                            style: AppTheme.iosFontLarge.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkPrimaryText
                                  : AppTheme.iosPrimaryText,
                            ),
                          ),
                          if (_userData?['university'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.school,
                                  size: 16,
                                  color: isDark
                                      ? AppTheme.iosDarkSecondaryText
                                      : AppTheme.iosSecondaryText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _userData!['university'],
                                  style: AppTheme.iosFontSmall.copyWith(
                                    color: isDark
                                        ? AppTheme.iosDarkSecondaryText
                                        : AppTheme.iosSecondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_userData?['bio'] != null &&
                              _userData!['bio'].isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.iosDarkTertiaryBackground
                                    : AppTheme.iosTertiaryBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.iosDarkSecondaryText
                                          .withOpacity(0.1)
                                      : AppTheme.iosSecondaryText
                                          .withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _userData!['bio'],
                                style: AppTheme.iosFontSmall.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // İstatistikler
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(
                        '📝 Gönderi', _userPosts.length.toString(), isDark),
                    _buildStatColumn('❤️ Beğeni', '0',
                        isDark), // TODO: Beğeni sayısını hesapla
                    _buildStatColumn('👥 Takipçi', '0',
                        isDark), // TODO: Takipçi sayısını hesapla
                  ],
                ),
              ],
            ),
          ),

          // Gönderiler - Daha kompakt
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.iosDarkSecondaryBackground
                  : AppTheme.iosSecondaryBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppTheme.iosDarkSecondaryText.withOpacity(0.05)
                    : AppTheme.iosSecondaryText.withOpacity(0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.iosOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          CupertinoIcons.doc_text,
                          color: AppTheme.iosOrange,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Gönderilerim',
                        style: AppTheme.iosFontSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.iosDarkPrimaryText
                              : AppTheme.iosPrimaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                _isLoadingPosts
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: AppTheme.iosOrange,
                          ),
                        ),
                      )
                    : _userPosts.isEmpty
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              child: Column(
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
                                    'Henüz gönderi yok',
                                    style: AppTheme.iosFontMedium.copyWith(
                                      color: isDark
                                          ? AppTheme.iosDarkPrimaryText
                                          : AppTheme.iosPrimaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'İlk check-in\'ini yap!',
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
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _userPosts.length,
                            itemBuilder: (context, index) {
                              return _buildPostCard(_userPosts[index], isDark);
                            },
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.iosDarkTertiaryBackground
            : AppTheme.iosTertiaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppTheme.iosDarkSecondaryText.withOpacity(0.1)
              : AppTheme.iosSecondaryText.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.iosFontMedium.copyWith(
              color: AppTheme.iosOrange,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
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

  Widget _buildPostCard(CheckinModel post, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.iosDarkTertiaryBackground
            : AppTheme.iosTertiaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppTheme.iosDarkSecondaryText.withOpacity(0.05)
              : AppTheme.iosSecondaryText.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.iosOrange.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: post.userPhotoURL != null
                      ? Image.network(
                          post.userPhotoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: isDark
                                  ? AppTheme.iosDarkSecondaryBackground
                                  : AppTheme.iosSecondaryBackground,
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
                              ? AppTheme.iosDarkSecondaryBackground
                              : AppTheme.iosSecondaryBackground,
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
                    Text(
                      post.userDisplayName,
                      style: AppTheme.iosFontMedium.copyWith(
                        color: isDark
                            ? AppTheme.iosDarkPrimaryText
                            : AppTheme.iosPrimaryText,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.location_fill,
                          size: 12,
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          post.locationName,
                          style: AppTheme.iosFontSmall.copyWith(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.iosDarkSecondaryBackground
                      : AppTheme.iosSecondaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatTimeAgo(post.createdAt),
                  style: AppTheme.iosFontCaption.copyWith(
                    color: isDark
                        ? AppTheme.iosDarkSecondaryText
                        : AppTheme.iosSecondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.message,
            style: AppTheme.iosFont.copyWith(
              color: isDark
                  ? AppTheme.iosDarkPrimaryText
                  : AppTheme.iosPrimaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                CupertinoIcons.heart_fill,
                size: 14,
                color: AppTheme.iosRed,
              ),
              const SizedBox(width: 4),
              Text(
                '${post.likes.length}',
                style: AppTheme.iosFontSmall.copyWith(
                  color: isDark
                      ? AppTheme.iosDarkSecondaryText
                      : AppTheme.iosSecondaryText,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                CupertinoIcons.chat_bubble_2,
                size: 14,
                color: isDark
                    ? AppTheme.iosDarkSecondaryText
                    : AppTheme.iosSecondaryText,
              ),
              const SizedBox(width: 4),
              Text(
                '${post.comments.length}',
                style: AppTheme.iosFontSmall.copyWith(
                  color: isDark
                      ? AppTheme.iosDarkSecondaryText
                      : AppTheme.iosSecondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
}
