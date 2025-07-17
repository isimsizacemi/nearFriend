import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
  final List<String> _selectedInterests = [];
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
      setState(() {
        _displayNameController.text = user.displayName ?? '';
      });
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
      return await ref.getDownloadURL();
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

      // Fotoğraf yükle
      String? photoURL;
      if (_profileImage != null) {
        photoURL = await _uploadImage();
      }

      // Profil verilerini hazırla
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

      // Firestore'a kaydet
      await _authService.updateUserProfile(user.uid, profileData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil başarıyla oluşturuldu!')),
        );

        // Ana ekrana yönlendir
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil kaydedilirken hata: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Oluştur'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profil Fotoğrafı
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : null,
                            child: _profileImage == null
                                ? const Icon(Icons.person, size: 60)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: Colors.deepPurple,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt,
                                    color: Colors.white),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Ad Soyad
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ad soyad gerekli';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Üniversite
                    DropdownButtonFormField<String>(
                      value: _selectedUniversity.isEmpty
                          ? null
                          : _selectedUniversity,
                      decoration: const InputDecoration(
                        labelText: 'Üniversite',
                        border: OutlineInputBorder(),
                      ),
                      items: _universities.map((university) {
                        return DropdownMenuItem(
                          value: university,
                          child: Text(university),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUniversity = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Üniversite seçin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bölüm
                    DropdownButtonFormField<String>(
                      value: _selectedDepartment.isEmpty
                          ? null
                          : _selectedDepartment,
                      decoration: const InputDecoration(
                        labelText: 'Bölüm',
                        border: OutlineInputBorder(),
                      ),
                      items: _departments.map((department) {
                        return DropdownMenuItem(
                          value: department,
                          child: Text(department),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Bölüm seçin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Yaş
                    Row(
                      children: [
                        const Text('Yaş: '),
                        Expanded(
                          child: Slider(
                            value: _selectedAge.toDouble(),
                            min: 18,
                            max: 30,
                            divisions: 12,
                            label: _selectedAge.toString(),
                            onChanged: (value) {
                              setState(() {
                                _selectedAge = value.round();
                              });
                            },
                          ),
                        ),
                        Text(_selectedAge.toString()),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Cinsiyet
                    Row(
                      children: [
                        const Text('Cinsiyet: '),
                        Expanded(
                          child: Row(
                            children: [
                              Radio<String>(
                                value: 'Erkek',
                                groupValue: _selectedGender,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedGender = value ?? '';
                                  });
                                },
                              ),
                              const Text('Erkek'),
                              Radio<String>(
                                value: 'Kadın',
                                groupValue: _selectedGender,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedGender = value ?? '';
                                  });
                                },
                              ),
                              const Text('Kadın'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // İlgi Alanları
                    const Text('İlgi Alanları:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _interests.map((interest) {
                        final isSelected =
                            _selectedInterests.contains(interest);
                        return FilterChip(
                          label: Text(interest),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                if (_selectedInterests.length < 5) {
                                  _selectedInterests.add(interest);
                                }
                              } else {
                                _selectedInterests.remove(interest);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Biyografi
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Biyografi (Opsiyonel)',
                        border: OutlineInputBorder(),
                        hintText: 'Kendinizden bahsedin...',
                      ),
                      maxLines: 3,
                      maxLength: 200,
                    ),
                    const SizedBox(height: 24),

                    // Kaydet Butonu
                    ElevatedButton(
                      onPressed: _selectedGender.isEmpty ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Profili Kaydet'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
