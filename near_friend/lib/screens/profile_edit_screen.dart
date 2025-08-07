import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../utils/university_list.dart';

const List<String> femaleAvatars = [
  'assets/images/avatars/female1.png',
  'assets/images/avatars/female2.png',
  'assets/images/avatars/female3.png',
  'assets/images/avatars/female4.png',
  'assets/images/avatars/female5.png',
  'assets/images/avatars/female6.png',
  'assets/images/avatars/female7.png',
  'assets/images/avatars/female8.png',
  'assets/images/avatars/female9.png',
  'assets/images/avatars/female10.png',
];
const List<String> maleAvatars = [
  'assets/images/avatars/male1.png',
  'assets/images/avatars/male2.png',
  'assets/images/avatars/male3.png',
  'assets/images/avatars/male4.png',
  'assets/images/avatars/male5.png',
  'assets/images/avatars/male6.png',
  'assets/images/avatars/male7.png',
  'assets/images/avatars/male8.png',
  'assets/images/avatars/male9.png',
  'assets/images/avatars/male10.png',
];
const List<String> allAvatars = [
  ...femaleAvatars,
  ...maleAvatars,
];

const List<String> departmentList = [
  'Bilgisayar Mühendisliği',
  'Elektrik-Elektronik Mühendisliği',
  'Makine Mühendisliği',
  'İnşaat Mühendisliği',
  'Endüstri Mühendisliği',
  'Tıp',
  'Hukuk',
  'İşletme',
  'Psikoloji',
  'Mimarlık',
  'Ekonomi',
  'Sosyoloji',
  'Fizik',
  'Kimya',
  'Biyoloji',
  'Matematik',
  'İstatistik',
  'Moleküler Biyoloji ve Genetik',
  'Uluslararası İlişkiler',
  'Siyaset Bilimi',
  'Gazetecilik',
  'Radyo, Televizyon ve Sinema',
  'Hemşirelik',
  'Diş Hekimliği',
  'Eczacılık',
  'Veterinerlik',
  'Felsefe',
  'Tarih',
  'Coğrafya',
  'Müzik',
  'Resim',
  'Beden Eğitimi',
  'Diğer',
];

const List<String> interestList = [
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
  'Moda',
  'Hayvanlar',
  'Bahçe',
  'Kamp',
  'Yazılım',
  'Girişimcilik',
  'Podcast',
  'Yazarlık',
  'Şiir',
  'Astronomi',
  'Bilim',
];

class ProfileEditScreen extends StatefulWidget {
  final UserModel user;

  const ProfileEditScreen({Key? key, required this.user}) : super(key: key);

  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _universityController = TextEditingController();
  final _ageController = TextEditingController();
  final _interestController = TextEditingController();

  String? _selectedGender;
  List<String> _selectedInterests = [];
  String? _selectedAvatar;
  String _selectedDepartment = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.displayName ?? '';
    _bioController.text = widget.user.bio ?? '';
    _universityController.text = widget.user.university ?? '';
    _ageController.text = widget.user.age?.toString() ?? '';
    _selectedGender = widget.user.gender;
    _selectedInterests = List.from(widget.user.interests);
    _selectedAvatar = widget.user.photoURL;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _universityController.dispose();
    _ageController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('Kullanıcı oturumu bulunamadı');
        }

        final updatedUser = widget.user.copyWith(
          displayName: _nameController.text.trim(),
          bio: _bioController.text.trim(),
          university: _universityController.text.trim(),
          age: int.tryParse(_ageController.text.trim()),
          gender: _selectedGender,
          photoURL: _selectedAvatar,
          interests: _selectedInterests,
          hasCreatedProfile: true,
          lastActiveAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updatedUser.toFirestore());

        try {
          await user.updateDisplayName(_nameController.text.trim());
        } catch (authError) {
          print('Firebase Auth güncelleme hatası: $authError');
        }

        setState(() {
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil başarıyla güncellendi'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        print('Profil güncelleme hatası: $e');
        setState(() {
          _isSaving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profil güncellenirken hata oluştu: $e'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Widget _buildAvatarGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: allAvatars.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final avatar = allAvatars[index];
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedAvatar = avatar;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedAvatar == avatar
                    ? Colors.blue
                    : Colors.transparent,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Image.asset(avatar, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _selectedAvatar != null
                            ? AssetImage(_selectedAvatar!) as ImageProvider
                            : AssetImage('assets/images/avatars/male1.png'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'İsim',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'İsim gerekli';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Hakkımda',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: universityList.contains(_universityController.text)
                      ? _universityController.text
                      : null,
                  decoration: InputDecoration(labelText: 'Üniversite'),
                  items: universityList
                      .map((uni) =>
                          DropdownMenuItem(value: uni, child: Text(uni)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _universityController.text = val ?? '';
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: departmentList.contains(_selectedDepartment)
                      ? _selectedDepartment
                      : null,
                  decoration: InputDecoration(labelText: 'Bölüm'),
                  items: departmentList
                      .map((dep) =>
                          DropdownMenuItem(value: dep, child: Text(dep)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDepartment = val ?? '';
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: 'Yaş',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Yaş gerekli';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 18 || age > 100) {
                      return 'Geçerli bir yaş girin (18-100)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Cinsiyet',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Erkek', child: Text('Erkek')),
                    DropdownMenuItem(value: 'Kadın', child: Text('Kadın')),
                    DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Cinsiyet seçin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'İlgi Alanları',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: interestList.map((interest) {
                    final selected = _selectedInterests.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedInterests.add(interest);
                          } else {
                            _selectedInterests.remove(interest);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _interestController,
                  decoration: InputDecoration(
                    labelText: 'Yeni ilgi alanı ekle',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final interest = _interestController.text.trim();
                        if (interest.isNotEmpty &&
                            !_selectedInterests.contains(interest)) {
                          setState(() {
                            _selectedInterests.add(interest);
                            _interestController.clear();
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Avatarını Seç',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildAvatarGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
