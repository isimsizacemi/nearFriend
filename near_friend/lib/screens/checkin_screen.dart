import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/auth_service.dart';

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

  Future<void> _getCurrentLocation() async {
    try {
      // Konum izni kontrol et
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocationLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocationLoading = false);
        return;
      }

      // Mevcut konumu al
      _currentPosition = await Geolocator.getCurrentPosition();

      // Konum adını al
      if (_currentPosition != null) {
        final placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          setState(() {
            _locationName = '${placemark.street}, ${placemark.locality}';
          });
        }
      }
    } catch (e) {
      print('Konum alınırken hata: $e');
    } finally {
      setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _createCheckin() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir mesaj yazın')),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum alınamadı')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Kullanıcı bilgilerini al
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı bilgileri bulunamadı')),
        );
        return;
      }

      final userData = userDoc.data()!;

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

      await FirebaseFirestore.instance.collection('checkins').add(checkinData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in başarıyla oluşturuldu!')),
        );

        // Mesajı temizle
        _messageController.clear();

        // Ana ekrana dön
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Check-in oluşturulurken hata: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in / Plan Paylaş'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _createCheckin,
              child: const Text('Paylaş'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Konum bilgisi
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.deepPurple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _isLocationLoading
                                ? const Text('Konum alınıyor...')
                                : Text(
                                    _locationName.isNotEmpty
                                        ? _locationName
                                        : 'Konum alınamadı',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _getCurrentLocation,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mesaj alanı
                  TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Ne yapıyorsun?',
                      hintText:
                          'Örn: MackBear\'dayım, tekim kahve arkadaşı arıyorum.',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 16),

                  // Görünürlük ayarları
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Görünürlük',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Switch(
                                value: _isPublic,
                                onChanged: (value) {
                                  setState(() {
                                    _isPublic = value;
                                  });
                                },
                              ),
                              Text(_isPublic ? 'Herkese Açık' : 'Filtreli'),
                            ],
                          ),
                          if (!_isPublic) ...[
                            const SizedBox(height: 16),
                            const Text('Kimler görebilir?',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),

                            // Cinsiyet filtresi
                            const Text('Cinsiyet:'),
                            Row(
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

                            // Yaş aralığı
                            const Text('Yaş Aralığı:'),
                            RangeSlider(
                              values: RangeValues(
                                  _minAge.toDouble(), _maxAge.toDouble()),
                              min: 18,
                              max: 30,
                              divisions: 12,
                              labels: RangeLabels('$_minAge', '$_maxAge'),
                              onChanged: (values) {
                                setState(() {
                                  _minAge = values.start.round();
                                  _maxAge = values.end.round();
                                });
                              },
                            ),

                            // Üniversite filtresi
                            const Text('Üniversite:'),
                            Wrap(
                              spacing: 8,
                              children: _universities.map((university) {
                                final isSelected =
                                    _selectedUniversities.contains(university);
                                return FilterChip(
                                  label: Text(university),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedUniversities.add(university);
                                      } else {
                                        _selectedUniversities
                                            .remove(university);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),

                            // İlgi alanları filtresi
                            const Text('İlgi Alanları:'),
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
                                        _selectedInterests.add(interest);
                                      } else {
                                        _selectedInterests.remove(interest);
                                      }
                                    });
                                  },
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
}
