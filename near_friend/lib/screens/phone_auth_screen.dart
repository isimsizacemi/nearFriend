import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();
  final AuthService _authService = AuthService();
  String? _verificationId;
  bool _codeSent = false;
  bool _loading = false;

  Future<void> _verifyPhone() async {
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneController.text.trim(),
      verificationCompleted: (PhoneAuthCredential credential) async {
        final userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
        if (userCredential.user != null) {
          await _authService.createUserRecord(userCredential.user!);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Doğrulama başarısız: \n${e.message}'),
            backgroundColor: AppTheme.iosRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('SMS kodu gönderildi!'),
            backgroundColor: AppTheme.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        setState(() => _verificationId = verificationId);
      },
    );
  }

  Future<void> _signInWithSmsCode() async {
    if (_verificationId == null) return;
    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsController.text.trim(),
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _authService.createUserRecord(userCredential.user!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kod doğrulama başarısız: \n${e.toString()}'),
          backgroundColor: AppTheme.iosRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => _loading = false);
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
                      color: AppTheme.iosBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.phone,
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
                          'Telefon ile Giriş',
                          style: AppTheme.iosFontMedium.copyWith(
                            color: isDark
                                ? AppTheme.iosDarkPrimaryText
                                : AppTheme.iosPrimaryText,
                          ),
                        ),
                        Text(
                          _codeSent
                              ? 'SMS kodunu girin'
                              : 'Telefon numaranızı girin',
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

            // Content
            Expanded(
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
                  child: _loading
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.iosBlue,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'İşleniyor...',
                              style: AppTheme.iosFont.copyWith(
                                color: isDark
                                    ? AppTheme.iosDarkSecondaryText
                                    : AppTheme.iosSecondaryText,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _codeSent ? Icons.sms : Icons.phone_android,
                              size: 64,
                              color: AppTheme.iosBlue,
                            ),
                            const SizedBox(height: 24),
                            if (!_codeSent) ...[
                              Text(
                                'Telefon Numaranız',
                                style: AppTheme.iosFontMedium.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'SMS doğrulama kodu almak için telefon numaranızı girin',
                                style: AppTheme.iosFontSmall.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkSecondaryText
                                      : AppTheme.iosSecondaryText,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  hintText: '+90 5xx xxx xx xx',
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
                                      color: AppTheme.iosBlue,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? AppTheme.iosDarkTertiaryBackground
                                      : AppTheme.iosTertiaryBackground,
                                  prefixIcon: Icon(
                                    Icons.phone,
                                    color: isDark
                                        ? AppTheme.iosDarkSecondaryText
                                        : AppTheme.iosSecondaryText,
                                  ),
                                ),
                                style: AppTheme.iosFont.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _verifyPhone,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.iosBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.send,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'SMS Gönder',
                                        style: AppTheme.iosFontMedium.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              Text(
                                'SMS Kodu',
                                style: AppTheme.iosFontMedium.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Telefonunuza gönderilen 6 haneli kodu girin',
                                style: AppTheme.iosFontSmall.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkSecondaryText
                                      : AppTheme.iosSecondaryText,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _smsController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: InputDecoration(
                                  hintText: '000000',
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
                                      color: AppTheme.iosBlue,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? AppTheme.iosDarkTertiaryBackground
                                      : AppTheme.iosTertiaryBackground,
                                  prefixIcon: Icon(
                                    Icons.sms,
                                    color: isDark
                                        ? AppTheme.iosDarkSecondaryText
                                        : AppTheme.iosSecondaryText,
                                  ),
                                ),
                                style: AppTheme.iosFont.copyWith(
                                  color: isDark
                                      ? AppTheme.iosDarkPrimaryText
                                      : AppTheme.iosPrimaryText,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _signInWithSmsCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.iosGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.login,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Giriş Yap',
                                        style: AppTheme.iosFontMedium.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _codeSent = false;
                                    _smsController.clear();
                                  });
                                },
                                child: Text(
                                  'Farklı numara kullan',
                                  style: AppTheme.iosFontSmall.copyWith(
                                    color: AppTheme.iosBlue,
                                  ),
                                ),
                              ),
                            ],
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
