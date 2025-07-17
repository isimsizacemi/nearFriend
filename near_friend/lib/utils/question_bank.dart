import '../models/question.dart';

final List<Question> questionBank = [
  Question(
    question: 'Türkiye Cumhuriyeti\'nin kurucusu kimdir?',
    options: [
      'Mustafa Kemal Atatürk',
      'Fatih Sultan Mehmet',
      'Yavuz Sultan Selim',
      'Abdülhamit II'
    ],
    correctIndex: 0,
  ),
  Question(
    question: 'İstiklal Marşı\'nı kim yazdı?',
    options: [
      'Mehmet Akif Ersoy',
      'Yahya Kemal Beyatlı',
      'Namık Kemal',
      'Tevfik Fikret'
    ],
    correctIndex: 0,
  ),
  Question(
    question: 'Türkiye\'nin başkenti neresidir?',
    options: ['Ankara', 'İstanbul', 'İzmir', 'Bursa'],
    correctIndex: 0,
  ),
  Question(
    question: '10 + 5 = ?',
    options: ['12', '13', '15', '20'],
    correctIndex: 2,
  ),
  Question(
    question: 'Atatürk\'ün soyadı kanunu ne zaman çıktı?',
    options: ['1934', '1923', '1945', '1919'],
    correctIndex: 0,
  ),
  Question(
    question: 'Ali 2 elma yedi, 4 kaldı. Kaç elmadan başladı?',
    options: ['4', '5', '6', '7'],
    correctIndex: 2,
  ),
];
