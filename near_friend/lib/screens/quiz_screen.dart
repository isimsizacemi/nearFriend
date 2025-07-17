import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/question_bank.dart';
import '../models/question.dart';
import '../services/auth_service.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    if (_quizFinished) {
      final passed = _correctCount == _selectedQuestions.length;
      return Scaffold(
        appBar: AppBar(title: const Text('Zeka & Milli Değerler Testi')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                passed ? Icons.verified : Icons.error,
                color: passed ? Colors.green : Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                passed
                    ? 'Tebrikler! Tüm soruları doğru cevapladınız.'
                    : 'Bazı soruları yanlış cevapladınız.',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (passed)
                ElevatedButton(
                  onPressed: _handleQuizPassed,
                  child: const Text('Profil Oluştur'),
                )
              else
                ElevatedButton(
                  onPressed: _restartQuiz,
                  child: const Text('Tekrar Dene'),
                ),
            ],
          ),
        ),
      );
    }

    final question = _selectedQuestions[_currentIndex];
    return Scaffold(
      appBar: AppBar(title: const Text('Zeka & Milli Değerler Testi')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Soru ${_currentIndex + 1} / ${_selectedQuestions.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              question.question,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 24),
            ...List.generate(question.options.length, (i) {
              final isSelected = _userAnswers[_currentIndex] == i;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? Colors.deepPurple : null,
                  ),
                  onPressed: _userAnswers[_currentIndex] == null
                      ? () => _answerQuestion(i)
                      : null,
                  child: Text(question.options[i]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
