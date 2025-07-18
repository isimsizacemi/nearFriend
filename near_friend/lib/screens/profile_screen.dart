import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/checkin_model.dart';
import '../utils/app_theme.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();

  // Kullanıcı verileri
  Map<String, dynamic>? _userData;
  List<CheckinModel> _userPosts = [];
  bool _isLoading = false;
  bool _isLoadingPosts = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserPosts();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Firestore'dan kullanıcı verilerini al
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
      print('Profil ekranında check-in aranıyor...');
      print('Aranan kullanıcı UID: ${user.uid}');

      // Önce sadece userId ile filtrele, sonra client-side'da isActive'yi kontrol et
      final query = FirebaseFirestore.instance
          .collection('checkins')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true);

      final snapshot = await query.get();
      print('Kullanıcı check-in sayısı: ${snapshot.docs.length}');

      final posts = snapshot.docs.map((doc) {
        print('Doküman: ${doc.id} - ${doc.data()}');
        return CheckinModel.fromFirestore(doc);
      }).where((post) {
        print('Check-in: ${post.id} - isActive: ${post.isActive}');
        return post.isActive;
      }) // Client-side filtering
          .toList();

      print('Aktif check-in sayısı: ${posts.length}');
      for (final post in posts) {
        print(
            'Profilde gösterilecek check-in: ${post.id} | ${post.message} | ${post.createdAt}');
      }

      setState(() {
        _userPosts = posts;
      });
    } catch (e) {
      print('Kullanıcı gönderileri yüklenirken hata: $e');
      // Hata durumunda boş liste göster
      setState(() {
        _userPosts = [];
      });
    } finally {
      setState(() => _isLoadingPosts = false);
    }
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Başarıyla çıkış yapıldı'),
            backgroundColor: AppTheme.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null)
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
                      color: AppTheme.iosOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person,
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
                          'Profilim',
                          style: AppTheme.iosFontMedium.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          '${_userPosts.length} paylaşım',
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
                    icon: Icon(
                      Icons.refresh,
                      color: AppTheme.iosOrange,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileEditScreen(),
                        ),
                      ).then((_) {
                        // Profil düzenlendikten sonra verileri yenile
                        _loadUserData();
                      });
                    },
                    icon: Icon(
                      Icons.edit,
                      color: AppTheme.iosOrange,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppTheme.iosOrange,
                    ),
                    onSelected: (value) {
                      if (value == 'logout') {
                        _logout();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: AppTheme.iosRed),
                            SizedBox(width: 8),
                            Text('Çıkış Yap'),
                          ],
                        ),
                      ),
                    ],
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
                              color: AppTheme.iosOrange,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Profil yükleniyor...',
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
                  : _buildProfileContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Profil Bilgileri
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.iosDarkSecondaryBackground
                  : AppTheme.iosSecondaryBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
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
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: AppTheme.iosOrange.withOpacity(0.2),
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: _userData?['photoURL'] != null
                            ? Image.network(
                                _userData!['photoURL'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: isDark
                                        ? AppTheme.iosDarkTertiaryBackground
                                        : AppTheme.iosTertiaryBackground,
                                    child: Icon(
                                      Icons.person,
                                      size: 40,
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
                                  size: 40,
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
                            _userData?['displayName'] ??
                                user?.displayName ??
                                'İsimsiz',
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
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.iosDarkTertiaryBackground
                                    : AppTheme.iosTertiaryBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _userData!['bio'],
                                style: AppTheme.iosFont.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // İstatistikler
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(
                        'Gönderi', _userPosts.length.toString(), isDark),
                    _buildStatColumn(
                        'Beğeni', '0', isDark), // TODO: Beğeni sayısını hesapla
                    _buildStatColumn('Takipçi', '0',
                        isDark), // TODO: Takipçi sayısını hesapla
                  ],
                ),
              ],
            ),
          ),

          // Gönderiler
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.iosDarkSecondaryBackground
                  : AppTheme.iosSecondaryBackground,
              borderRadius: BorderRadius.circular(20),
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
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.post_add,
                        color: AppTheme.iosOrange,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Gönderilerim',
                        style: AppTheme.iosFontMedium.copyWith(
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
                                    Icons.post_add,
                                    size: 64,
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
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.iosFontLarge.copyWith(
            color: AppTheme.iosOrange,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.iosFontSmall.copyWith(
            color: isDark
                ? AppTheme.iosDarkSecondaryText
                : AppTheme.iosSecondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(CheckinModel post, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.iosDarkTertiaryBackground
            : AppTheme.iosTertiaryBackground,
        borderRadius: BorderRadius.circular(12),
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
                                Icons.person,
                                size: 20,
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
                            Icons.person,
                            size: 20,
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
                          Icons.location_on,
                          size: 14,
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
                Icons.favorite,
                size: 16,
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
                Icons.comment,
                size: 16,
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
