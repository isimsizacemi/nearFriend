import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/question_bank.dart';
import '../models/question.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'main_app.dart';

class RegisterFlowScreen extends StatefulWidget {
  final String email;
  final String password;

  const RegisterFlowScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<RegisterFlowScreen> createState() => _RegisterFlowScreenState();
}

class _RegisterFlowScreenState extends State<RegisterFlowScreen> {
  final AuthService _authService = AuthService();

  // Flow durumu
  int _currentStep = 0; // 0: Quiz, 1: Profil Bilgileri, 2: Kayıt

  // Quiz değişkenleri
  late List<Question> _selectedQuestions;
  int _currentQuestionIndex = 0;
  int _correctCount = 0;
  List<int?> _userAnswers = [];
  bool _quizFinished = false;

  // Profil değişkenleri
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  String _selectedUniversity = '';
  String _selectedDepartment = '';
  int _selectedAge = 18;
  String _selectedGender = '';
  final List<String> _selectedInterests = [];
  bool _isLoading = false;

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

  final List<String> _departments = [
    'Bilgisayar Mühendisliği',
    'Elektrik-Elektronik Mühendisliği',
    'Makine Mühendisliği',
    'Endüstri Mühendisliği',
    'İnşaat Mühendisliği',
    'Mimarlık',
    'Tıp',
    'Hukuk',
    'İşletme',
    'Ekonomi',
    'Psikoloji',
    'Sosyoloji',
    'Tarih',
    'Edebiyat',
    'Matematik',
    'Fizik',
    'Kimya',
    'Biyoloji',
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
    _initializeQuiz();
  }

  void _initializeQuiz() {
    final random = Random();
    final questions = List<Question>.from(questionBank);
    questions.shuffle(random);
    _selectedQuestions = questions.take(3).toList();
    _userAnswers = List.filled(_selectedQuestions.length, null);
  }

  void _answerQuestion(int selectedIndex) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = selectedIndex;
      if (_selectedQuestions[_currentQuestionIndex].correctIndex ==
          selectedIndex) {
        _correctCount++;
      }
      if (_currentQuestionIndex < _selectedQuestions.length - 1) {
        _currentQuestionIndex++;
      } else {
        _quizFinished = true;
      }
    });
  }

  void _restartQuiz() {
    setState(() {
      _initializeQuiz();
      _currentQuestionIndex = 0;
      _correctCount = 0;
      _quizFinished = false;
    });
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Quiz'den geçti, profil bilgilerine geç
      if (_correctCount == _selectedQuestions.length) {
        setState(() {
          _currentStep = 1;
        });
      }
    } else if (_currentStep == 1) {
      // Profil bilgileri tamamlandı, kayıt işlemini başlat
      if (_formKey.currentState!.validate()) {
        _registerUser();
      }
    }
  }

  Future<void> _registerUser() async {
    setState(() => _isLoading = true);

    try {
      // Firebase Auth'da kullanıcı oluştur
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      if (userCredential.user != null) {
        // Profil bilgilerini hazırla
        final profileData = {
          'displayName': _displayNameController.text.trim(),
          'university': _selectedUniversity,
          'department': _selectedDepartment,
          'age': _selectedAge,
          'gender': _selectedGender,
          'interests': _selectedInterests,
          'bio': _bioController.text.trim(),
          'hasPassedQuiz': true,
          'hasCreatedProfile': true,
          'quizPassedAt': FieldValue.serverTimestamp(),
          'profileCreatedAt': FieldValue.serverTimestamp(),
        };

        // Kullanıcı kaydını oluştur
        await _authService.createUserRecord(userCredential.user!);

        // Profil bilgilerini güncelle
        await _authService.updateUserProfile(
            userCredential.user!.uid, profileData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Hesabınız başarıyla oluşturuldu!'),
              backgroundColor: AppTheme.iosGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );

          // Ana ekrana yönlendir
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainApp()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('Kayıt hatası: $e');
      String errorMessage = 'Kayıt başarısız';
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'Bu email adresi zaten kullanımda.';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'Şifre çok zayıf. En az 6 karakter kullanın.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Geçersiz email adresi.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.iosRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
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
            // Progress Bar
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 3,
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[300],
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.iosBlue),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_currentStep + 1}/3',
                    style: AppTheme.iosFontSmall.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                  ),
                ],
              ),
            ),

            // Step Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.iosPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _currentStep == 0 ? Icons.quiz : Icons.person,
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
                          _currentStep == 0
                              ? 'Zeka & Milli Değerler Testi'
                              : 'Profil Bilgileri',
                          style: AppTheme.iosFontMedium.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          _currentStep == 0
                              ? '3 soru cevaplayın'
                              : 'Kendinizi tanıtın',
                          style: AppTheme.iosFontSmall.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkSecondaryText
                                : AppTheme.iosSecondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Content
            Expanded(
              child: _currentStep == 0
                  ? _buildQuizContent()
                  : _buildProfileContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_quizFinished) {
      final passed = _correctCount == _selectedQuestions.length;
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.iosDarkSecondaryBackground
              : AppTheme.iosSecondaryBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: passed ? AppTheme.iosGreen : AppTheme.iosRed,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: (passed ? AppTheme.iosGreen : AppTheme.iosRed)
                        .withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                passed ? Icons.verified : Icons.error,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              passed ? 'Tebrikler!' : 'Tekrar Deneyin',
              style: AppTheme.iosFontLarge.copyWith(
                color: isDark
                    ? AppTheme.iosDarkPrimaryText
                    : AppTheme.iosPrimaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              passed
                  ? 'Tüm soruları doğru cevapladınız.'
                  : 'Bazı soruları yanlış cevapladınız.',
              style: AppTheme.iosFont.copyWith(
                color: isDark
                    ? AppTheme.iosDarkSecondaryText
                    : AppTheme.iosSecondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: passed ? _nextStep : _restartQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      passed ? AppTheme.iosGreen : AppTheme.iosBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  passed ? 'Devam Et' : 'Tekrar Dene',
                  style: AppTheme.iosFontMedium.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final question = _selectedQuestions[_currentQuestionIndex];
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.iosDarkSecondaryBackground
            : AppTheme.iosSecondaryBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soru ${_currentQuestionIndex + 1} / ${_selectedQuestions.length}',
            style: AppTheme.iosFontSmall.copyWith(
              color: isDark
                  ? AppTheme.iosDarkSecondaryText
                  : AppTheme.iosSecondaryText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            question.question,
            style: AppTheme.iosFontMedium.copyWith(
              color: isDark
                  ? AppTheme.iosDarkPrimaryText
                  : AppTheme.iosPrimaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          ...question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = _userAnswers[_currentQuestionIndex] == index;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _answerQuestion(index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.iosBlue.withOpacity(0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.iosBlue
                          : Colors.grey.withOpacity(0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.iosBlue
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppTheme.iosBlue : Colors.grey,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          option,
                          style: AppTheme.iosFont.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display Name
            Text(
              'Ad Soyad *',
              style: AppTheme.iosFontMedium.copyWith(
                color: isDark
                    ? AppTheme.iosDarkPrimaryText
                    : AppTheme.iosPrimaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _displayNameController,
              decoration: InputDecoration(
                hintText: 'Adınız ve soyadınız',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ad soyad gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // University
            Text(
              'Üniversite *',
              style: AppTheme.iosFontMedium.copyWith(
                color: isDark
                    ? AppTheme.iosDarkPrimaryText
                    : AppTheme.iosPrimaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedUniversity.isEmpty ? null : _selectedUniversity,
              decoration: InputDecoration(
                hintText: 'Üniversitenizi seçin',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
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
                  return 'Üniversite seçimi gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Department
            Text(
              'Bölüm *',
              style: AppTheme.iosFontMedium.copyWith(
                color: isDark
                    ? AppTheme.iosDarkPrimaryText
                    : AppTheme.iosPrimaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDepartment.isEmpty ? null : _selectedDepartment,
              decoration: InputDecoration(
                hintText: 'Bölümünüzü seçin',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
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
                  return 'Bölüm seçimi gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Age and Gender Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yaş *',
                        style: AppTheme.iosFontMedium.copyWith(
                          color: isDark
                              ? AppTheme.iosDarkPrimaryText
                              : AppTheme.iosPrimaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedAge,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.iosDarkSecondaryBackground
                              : AppTheme.iosSecondaryBackground,
                        ),
                        items:
                            List.generate(83, (index) => index + 18).map((age) {
                          return DropdownMenuItem(
                            value: age,
                            child: Text(age.toString()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAge = value ?? 18;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cinsiyet *',
                        style: AppTheme.iosFontMedium.copyWith(
                          color: isDark
                              ? AppTheme.iosDarkPrimaryText
                              : AppTheme.iosPrimaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedGender.isEmpty ? null : _selectedGender,
                        decoration: InputDecoration(
                          hintText: 'Seçin',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.iosDarkSecondaryBackground
                              : AppTheme.iosSecondaryBackground,
                        ),
                        items: ['Erkek', 'Kadın', 'Diğer'].map((gender) {
                          return DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value ?? '';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Cinsiyet seçimi gerekli';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Interests
            Text(
              'İlgi Alanları',
              style: AppTheme.iosFontMedium.copyWith(
                color: isDark
                    ? AppTheme.iosDarkPrimaryText
                    : AppTheme.iosPrimaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
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
                  backgroundColor: isDark
                      ? AppTheme.iosDarkSecondaryBackground
                      : AppTheme.iosSecondaryBackground,
                  selectedColor: AppTheme.iosBlue.withOpacity(0.2),
                  checkmarkColor: AppTheme.iosBlue,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Bio
            Text(
              'Hakkımda',
              style: AppTheme.iosFontMedium.copyWith(
                color: isDark
                    ? AppTheme.iosDarkPrimaryText
                    : AppTheme.iosPrimaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bioController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Kendinizi kısaca tanıtın...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark
                    ? AppTheme.iosDarkSecondaryBackground
                    : AppTheme.iosSecondaryBackground,
              ),
            ),
            const SizedBox(height: 32),

            // Register Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.iosBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: AppTheme.iosFontBold,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Hesabı Oluştur'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
