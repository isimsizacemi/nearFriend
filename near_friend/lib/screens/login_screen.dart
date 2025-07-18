import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Login işlemi
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('Giriş yapılıyor...');
      print('Email: ${_emailController.text.trim()}');

      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        print('Giriş başarılı!');
        print('User ID: ${userCredential.user!.uid}');
        print('Email: ${userCredential.user!.email}');
        print('Email Verified: ${userCredential.user!.emailVerified}');

        await _authService.createUserRecord(userCredential.user!);
        _showSuccess('Başarıyla giriş yapıldı!');
      }
    } catch (e) {
      print('Giriş hatası: $e');
      String errorMessage = 'Giriş başarısız';
      if (e.toString().contains('user-not-found')) {
        errorMessage = 'Bu email adresi ile kayıtlı kullanıcı bulunamadı.';
      } else if (e.toString().contains('wrong-password')) {
        errorMessage = 'Şifre yanlış.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Geçersiz email adresi.';
      }
      _showError(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Register işlemi
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      print('Kullanıcı oluşturuluyor...');
      print('Email: $email');

      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        print('Kullanıcı oluşturuldu!');
        print('User ID: ${userCredential.user!.uid}');
        print('Email: ${userCredential.user!.email}');
        print('Email Verified: ${userCredential.user!.emailVerified}');

        await _authService.createUserRecord(userCredential.user!);
        _showSuccess('Hesap başarıyla oluşturuldu!');
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
      _showError(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.iosRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.iosGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.iosDarkBackground : AppTheme.iosBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // Logo ve başlık
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.iosBlue,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.people,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'nearFriend',
                  style: AppTheme.iosFontLarge.copyWith(
                    color: isDark
                        ? AppTheme.iosDarkPrimaryText
                        : AppTheme.iosPrimaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode
                      ? 'Hesabınıza giriş yapın'
                      : 'Yeni hesap oluşturun',
                  style: AppTheme.iosFontSmall.copyWith(
                    color: isDark
                        ? AppTheme.iosDarkSecondaryText
                        : AppTheme.iosSecondaryText,
                  ),
                ),
                const SizedBox(height: 48),

                // Email alanı
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTheme.iosFont.copyWith(
                    color: isDark
                        ? AppTheme.iosDarkPrimaryText
                        : AppTheme.iosPrimaryText,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Email Adresi',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppTheme.iosDarkTertiaryBackground
                        : AppTheme.iosTertiaryBackground,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    labelStyle: AppTheme.iosFont.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email adresi gerekli';
                    }
                    if (!value.contains('@')) {
                      return 'Geçerli bir email adresi girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Şifre alanı
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: AppTheme.iosFont.copyWith(
                    color: isDark
                        ? AppTheme.iosDarkPrimaryText
                        : AppTheme.iosPrimaryText,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: Icon(
                      Icons.lock_outlined,
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: isDark
                            ? AppTheme.iosDarkSecondaryText
                            : AppTheme.iosSecondaryText,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppTheme.iosDarkTertiaryBackground
                        : AppTheme.iosTertiaryBackground,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    labelStyle: AppTheme.iosFont.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Şifre gerekli';
                    }
                    if (value.length < 6) {
                      return 'Şifre en az 6 karakter olmalı';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Şifre onay alanı (sadece kayıt modunda)
                if (!_isLoginMode) ...[
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: AppTheme.iosFont.copyWith(
                      color: isDark
                          ? AppTheme.iosDarkPrimaryText
                          : AppTheme.iosPrimaryText,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Şifre Tekrar',
                      prefixIcon: Icon(
                        Icons.lock_outlined,
                        color: isDark
                            ? AppTheme.iosDarkSecondaryText
                            : AppTheme.iosSecondaryText,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppTheme.iosDarkTertiaryBackground
                          : AppTheme.iosTertiaryBackground,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      labelStyle: AppTheme.iosFont.copyWith(
                        color: isDark
                            ? AppTheme.iosDarkSecondaryText
                            : AppTheme.iosSecondaryText,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Şifre tekrarı gerekli';
                      }
                      if (value != _passwordController.text) {
                        return 'Şifreler eşleşmiyor';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Giriş/Kayıt butonu
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading ? null : (_isLoginMode ? _login : _register),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.iosBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: AppTheme.iosFontBold,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_isLoginMode ? 'Giriş Yap' : 'Kayıt Ol'),
                  ),
                ),
                const SizedBox(height: 24),

                // Mod değiştirme butonu
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                      _resetForm();
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.iosBlue,
                    textStyle: AppTheme.iosFontBold,
                  ),
                  child: Text(
                    _isLoginMode
                        ? 'Hesabınız yok mu? Kayıt olun'
                        : 'Zaten hesabınız var mı? Giriş yapın',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
