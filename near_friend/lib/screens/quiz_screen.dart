import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/question_bank.dart';
import '../models/question.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'profile_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<Question> _selectedQuestions;
  int _currentIndex = 0;
  int _correctCount = 0;
  List<int?> _userAnswers = [];
  bool _quizFinished = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _selectedQuestions = _getRandomQuestions(3);
    _userAnswers = List.filled(_selectedQuestions.length, null);
  }

  List<Question> _getRandomQuestions(int count) {
    final random = Random();
    final questions = List<Question>.from(questionBank);
    questions.shuffle(random);
    return questions.take(count).toList();
  }

  void _answerQuestion(int selectedIndex) {
    setState(() {
      _userAnswers[_currentIndex] = selectedIndex;
      if (_selectedQuestions[_currentIndex].correctIndex == selectedIndex) {
        _correctCount++;
      }
      if (_currentIndex < _selectedQuestions.length - 1) {
        _currentIndex++;
      } else {
        _quizFinished = true;
      }
    });
  }

  void _restartQuiz() {
    setState(() {
      _selectedQuestions = _getRandomQuestions(3);
      _currentIndex = 0;
      _correctCount = 0;
      _userAnswers = List.filled(_selectedQuestions.length, null);
      _quizFinished = false;
    });
  }

  Future<void> _handleQuizPassed() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Kullanıcı kaydını oluştur (eğer yoksa)
        await _authService.createUserRecord(user);
        // Quiz'i geçti olarak işaretle
        await _authService.markQuizAsPassed(user.uid);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      }
    } catch (e) {
      print('Quiz geçildi işaretlenirken hata: $e');
      // Hata olsa bile profil ekranına yönlendir
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_quizFinished) {
      final passed = _correctCount == _selectedQuestions.length;
      return Scaffold(
        backgroundColor:
            isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
        body: SafeArea(
          child: Center(
            child: Container(
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
                      onPressed: passed ? _handleQuizPassed : _restartQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            passed ? AppTheme.iosGreen : AppTheme.iosBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        passed ? 'Profil Oluştur' : 'Tekrar Dene',
                        style: AppTheme.iosFontMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final question = _selectedQuestions[_currentIndex];
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
                      color: AppTheme.iosPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.quiz,
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
                          'Zeka & Milli Değerler Testi',
                          style: AppTheme.iosFontMedium.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          'Soru ${_currentIndex + 1} / ${_selectedQuestions.length}',
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

            // Progress Bar
            Container(
              margin: const EdgeInsets.all(20),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / _selectedQuestions.length,
                backgroundColor: isDark
                    ? AppTheme.iosDarkTertiaryBackground
                    : AppTheme.iosTertiaryBackground,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.iosPurple),
                borderRadius: BorderRadius.circular(8),
                minHeight: 8,
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Question
                    Container(
                      padding: const EdgeInsets.all(24),
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
                          Icon(
                            Icons.help_outline,
                            size: 48,
                            color: AppTheme.iosPurple,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            question.question,
                            style: AppTheme.iosFontLarge.copyWith(
                              color: isDark
                                  ? AppTheme.iosDarkPrimaryText
                                  : AppTheme.iosPrimaryText,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Options
                    Expanded(
                      child: ListView.builder(
                        itemCount: question.options.length,
                        itemBuilder: (context, index) {
                          final isSelected =
                              _userAnswers[_currentIndex] == index;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: _userAnswers[_currentIndex] == null
                                  ? () => _answerQuestion(index)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.iosPurple
                                      : isDark
                                          ? AppTheme.iosDarkSecondaryBackground
                                          : AppTheme.iosSecondaryBackground,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.iosPurple
                                        : isDark
                                            ? AppTheme.iosDarkTertiaryBackground
                                            : AppTheme.iosTertiaryBackground,
                                    width: 2,
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
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : isDark
                                                ? AppTheme
                                                    .iosDarkTertiaryBackground
                                                : AppTheme
                                                    .iosTertiaryBackground,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : isDark
                                                  ? AppTheme
                                                      .iosDarkSecondaryText
                                                  : AppTheme.iosSecondaryText,
                                        ),
                                      ),
                                      child: isSelected
                                          ? Icon(
                                              Icons.check,
                                              size: 16,
                                              color: AppTheme.iosPurple,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        question.options[index],
                                        style: AppTheme.iosFontMedium.copyWith(
                                          color: isSelected
                                              ? Colors.white
                                              : isDark
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
                        },
                      ),
                    ),
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
