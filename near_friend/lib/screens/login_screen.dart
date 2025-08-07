import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';
import '../utils/app_theme.dart';
import 'register_flow_screen.dart';

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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      print('Register flow başlatılıyor...');
      print('Email: $email');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RegisterFlowScreen(
              email: email,
              password: password,
            ),
          ),
        );
      }
    } catch (e) {
      print('Register flow başlatma hatası: $e');
      _showError('Kayıt işlemi başlatılamadı');
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

                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.iosBlue,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    CupertinoIcons.person_2_fill,
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
                      CupertinoIcons.lock,
                      color: isDark
                          ? AppTheme.iosDarkSecondaryText
                          : AppTheme.iosSecondaryText,
                    ),
                    suffixIcon: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      child: Icon(
                        _obscurePassword
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        color: isDark
                            ? AppTheme.iosDarkSecondaryText
                            : AppTheme.iosSecondaryText,
                      ),
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
                        CupertinoIcons.lock,
                        color: isDark
                            ? AppTheme.iosDarkSecondaryText
                            : AppTheme.iosSecondaryText,
                      ),
                      suffixIcon: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        child: Icon(
                          _obscureConfirmPassword
                              ? CupertinoIcons.eye_slash
                              : CupertinoIcons.eye,
                          color: isDark
                              ? AppTheme.iosDarkSecondaryText
                              : AppTheme.iosSecondaryText,
                        ),
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

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: CupertinoButton.filled(
                    onPressed:
                        _isLoading ? null : (_isLoginMode ? _login : _register),
                    borderRadius: BorderRadius.circular(16),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CupertinoActivityIndicator(
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isLoginMode ? 'Giriş Yap' : 'Kayıt Ol',
                            style: AppTheme.iosFontBold.copyWith(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                CupertinoButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                      _resetForm();
                    });
                  },
                  child: Text(
                    _isLoginMode
                        ? 'Hesabınız yok mu? Kayıt olun'
                        : 'Zaten hesabınız var mı? Giriş yapın',
                    style: AppTheme.iosFontBold.copyWith(
                      color: AppTheme.iosBlue,
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
}
