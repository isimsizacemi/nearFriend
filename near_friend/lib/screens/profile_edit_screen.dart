import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // Form controllers
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  // Form values
  String _selectedUniversity = '';
  String _selectedDepartment = '';
  int _selectedAge = 18;
  String _selectedGender = '';
  List<String> _selectedInterests = [];
  File? _profileImage;
  bool _isLoading = false;

  // Options
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
    'Diğer',
  ];

  final List<String> _departments = [
    'Bilgisayar Mühendisliği',
    'Elektrik-Elektronik Mühendisliği',
    'Makine Mühendisliği',
    'Endüstri Mühendisliği',
    'İnşaat Mühendisliği',
    'Tıp',
    'Hukuk',
    'İşletme',
    'Ekonomi',
    'Psikoloji',
    'Matematik',
    'Fizik',
    'Kimya',
    'Biyoloji',
    'Tarih',
    'Edebiyat',
    'Diğer',
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
    _loadUserData();
  }

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
            _displayNameController.text =
                userData['displayName'] ?? user.displayName ?? '';
            _bioController.text = userData['bio'] ?? '';
            _selectedUniversity = userData['university'] ?? '';
            _selectedDepartment = userData['department'] ?? '';
            _selectedAge = userData['age'] ?? 18;
            _selectedGender = userData['gender'] ?? '';
            _selectedInterests = List<String>.from(userData['interests'] ?? []);
          });
        }
      } catch (e) {
        print('Kullanıcı verileri yüklenirken hata: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_profileImage == null) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');

      await ref.putFile(_profileImage!);
      final downloadURL = await ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('Fotoğraf yüklenirken hata: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? photoURL;
      if (_profileImage != null) {
        photoURL = await _uploadImage();
      }

      final profileData = {
        'displayName': _displayNameController.text.trim(),
        'university': _selectedUniversity,
        'department': _selectedDepartment,
        'age': _selectedAge,
        'gender': _selectedGender,
        'interests': _selectedInterests,
        'bio': _bioController.text.trim(),
        if (photoURL != null) 'photoURL': photoURL,
      };

      await _authService.updateUserProfile(user.uid, profileData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil başarıyla güncellendi!'),
            backgroundColor: AppTheme.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil kaydedilirken hata: $e'),
          backgroundColor: AppTheme.iosRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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
                      color: AppTheme.iosOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit,
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
                          'Profili Düzenle',
                          style: AppTheme.iosFontMedium.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          'Bilgilerinizi güncelleyin',
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
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Profile Image
                      Container(
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
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(60),
                                  border: Border.all(
                                    color: AppTheme.iosOrange.withOpacity(0.2),
                                    width: 3,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(60),
                                  child: _profileImage != null
                                      ? Image.file(
                                          _profileImage!,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: isDark
                                              ? AppTheme
                                                  .iosDarkTertiaryBackground
                                              : AppTheme.iosTertiaryBackground,
                                          child: Icon(
                                            Icons.camera_alt,
                                            size: 48,
                                            color: isDark
                                                ? AppTheme.iosDarkSecondaryText
                                                : AppTheme.iosSecondaryText,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Profil Fotoğrafı',
                              style: AppTheme.iosFontMedium.copyWith(
                                color: isDark
                                    ? AppTheme.iosDarkPrimaryText
                                    : AppTheme.iosPrimaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fotoğraf eklemek için dokunun',
                              style: AppTheme.iosFontSmall.copyWith(
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Basic Info
                      Container(
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.iosBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: AppTheme.iosBlue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Temel Bilgiler',
                                  style: AppTheme.iosFontMedium.copyWith(
                                    color: isDark
                                        ? AppTheme.iosDarkPrimaryText
                                        : AppTheme.iosPrimaryText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _displayNameController,
                              decoration: InputDecoration(
                                labelText: 'Ad Soyad',
                                hintText: 'Ad Soyad',
                                labelStyle: AppTheme.iosFont.copyWith(
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
                                    color: AppTheme.iosBlue,
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
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Ad Soyad gerekli';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedGender.isNotEmpty
                                        ? _selectedGender
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: 'Cinsiyet',
                                      labelStyle: AppTheme.iosFont.copyWith(
                                        color: isDark
                                            ? AppTheme.iosDarkSecondaryText
                                            : AppTheme.iosSecondaryText,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? AppTheme
                                                  .iosDarkTertiaryBackground
                                              : AppTheme.iosTertiaryBackground,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? AppTheme
                                                  .iosDarkTertiaryBackground
                                              : AppTheme.iosTertiaryBackground,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppTheme.iosBlue,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? AppTheme.iosDarkTertiaryBackground
                                          : AppTheme.iosTertiaryBackground,
                                    ),
                                    items: ['Erkek', 'Kadın'].map((gender) {
                                      return DropdownMenuItem(
                                        value: gender,
                                        child: Text(
                                          gender,
                                          style: AppTheme.iosFont.copyWith(
                                            color: isDark
                                                ? AppTheme.iosDarkPrimaryText
                                                : AppTheme.iosPrimaryText,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedGender = value ?? '';
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedAge,
                                    decoration: InputDecoration(
                                      labelText: 'Yaş',
                                      labelStyle: AppTheme.iosFont.copyWith(
                                        color: isDark
                                            ? AppTheme.iosDarkSecondaryText
                                            : AppTheme.iosSecondaryText,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? AppTheme
                                                  .iosDarkTertiaryBackground
                                              : AppTheme.iosTertiaryBackground,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? AppTheme
                                                  .iosDarkTertiaryBackground
                                              : AppTheme.iosTertiaryBackground,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppTheme.iosBlue,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? AppTheme.iosDarkTertiaryBackground
                                          : AppTheme.iosTertiaryBackground,
                                    ),
                                    items: List.generate(13, (index) {
                                      return DropdownMenuItem(
                                        value: 18 + index,
                                        child: Text(
                                          '${18 + index}',
                                          style: AppTheme.iosFont.copyWith(
                                            color: isDark
                                                ? AppTheme.iosDarkPrimaryText
                                                : AppTheme.iosPrimaryText,
                                          ),
                                        ),
                                      );
                                    }),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedAge = value ?? 18;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Education
                      Container(
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
                                    Icons.school,
                                    color: AppTheme.iosGreen,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Eğitim Bilgileri',
                                  style: AppTheme.iosFontMedium.copyWith(
                                    color: isDark
                                        ? AppTheme.iosDarkPrimaryText
                                        : AppTheme.iosPrimaryText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedUniversity.isNotEmpty
                                  ? _selectedUniversity
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'Üniversite',
                                labelStyle: AppTheme.iosFont.copyWith(
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
                              items: _universities.map((university) {
                                return DropdownMenuItem(
                                  value: university,
                                  child: Text(
                                    university,
                                    style: AppTheme.iosFont.copyWith(
                                      color: isDark
                                          ? AppTheme.iosDarkPrimaryText
                                          : AppTheme.iosPrimaryText,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedUniversity = value ?? '';
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedDepartment.isNotEmpty
                                  ? _selectedDepartment
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'Bölüm',
                                labelStyle: AppTheme.iosFont.copyWith(
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
                              items: _departments.map((department) {
                                return DropdownMenuItem(
                                  value: department,
                                  child: Text(
                                    department,
                                    style: AppTheme.iosFont.copyWith(
                                      color: isDark
                                          ? AppTheme.iosDarkPrimaryText
                                          : AppTheme.iosPrimaryText,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDepartment = value ?? '';
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Bio
                      Container(
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
                                    Icons.description,
                                    color: AppTheme.iosPurple,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Hakkımda',
                                  style: AppTheme.iosFontMedium.copyWith(
                                    color: isDark
                                        ? AppTheme.iosDarkPrimaryText
                                        : AppTheme.iosPrimaryText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _bioController,
                              maxLines: 4,
                              maxLength: 200,
                              decoration: InputDecoration(
                                hintText: 'Kendinizden bahsedin...',
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
                                    color: AppTheme.iosPurple,
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

                      // Interests
                      Container(
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.iosPink.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.favorite,
                                    color: AppTheme.iosPink,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'İlgi Alanları',
                                  style: AppTheme.iosFontMedium.copyWith(
                                    color: isDark
                                        ? AppTheme.iosDarkPrimaryText
                                        : AppTheme.iosPrimaryText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _interests.map((interest) {
                                final isSelected =
                                    _selectedInterests.contains(interest);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedInterests.remove(interest);
                                      } else {
                                        if (_selectedInterests.length < 5) {
                                          _selectedInterests.add(interest);
                                        }
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.iosPink
                                          : isDark
                                              ? AppTheme
                                                  .iosDarkTertiaryBackground
                                              : AppTheme.iosTertiaryBackground,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.iosPink
                                            : isDark
                                                ? AppTheme
                                                    .iosDarkTertiaryBackground
                                                : AppTheme
                                                    .iosTertiaryBackground,
                                      ),
                                    ),
                                    child: Text(
                                      interest,
                                      style: AppTheme.iosFontSmall.copyWith(
                                        color: isSelected
                                            ? Colors.white
                                            : isDark
                                                ? AppTheme.iosDarkSecondaryText
                                                : AppTheme.iosSecondaryText,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'En fazla 5 ilgi alanı seçebilirsiniz',
                              style: AppTheme.iosFontCaption.copyWith(
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfile,
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
                                      'Kaydediliyor...',
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
                                      Icons.save,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Kaydet',
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
            ),
          ],
        ),
      ),
    );
  }
}
