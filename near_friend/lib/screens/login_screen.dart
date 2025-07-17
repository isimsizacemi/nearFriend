import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/email_service.dart';

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
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoginMode ? 'Giriş Yap' : 'Kayıt Ol'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Logo ve başlık
              const Icon(
                Icons.person_pin_circle,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 24),
              Text(
                'nearFriend',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLoginMode
                    ? 'Hesabınıza giriş yapın'
                    : 'Yeni hesap oluşturun',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),

              // Email alanı
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Adresi',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
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
              const SizedBox(height: 20),

              // Şifre alanı
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
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
              const SizedBox(height: 20),

              // Şifre tekrar alanı (sadece register modunda)
              if (!_isLoginMode) ...[
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Şifre Tekrar',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
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
                const SizedBox(height: 20),
              ],

              // Ana buton
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : (_isLoginMode ? _login : _register),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isLoginMode ? 'Giriş Yap' : 'Kayıt Ol',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Mod değiştirme butonu
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                          _resetForm();
                        });
                      },
                child: Text(
                  _isLoginMode
                      ? 'Hesabınız yok mu? Kayıt olun'
                      : 'Zaten hesabınız var mı? Giriş yapın',
                  style: const TextStyle(color: Colors.deepPurple),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
