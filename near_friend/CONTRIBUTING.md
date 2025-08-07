# 🤝 Katkıda Bulunma Rehberi

nearFriend projesine katkıda bulunmak istediğiniz için teşekkürler! Bu rehber, projeye nasıl katkıda bulunabileceğinizi açıklar.

## 📋 İçindekiler

- [Nasıl Başlarım?](#nasıl-başlarım)
- [Geliştirme Ortamı](#geliştirme-ortamı)
- [Kod Standartları](#kod-standartları)
- [Commit Mesajları](#commit-mesajları)
- [Pull Request Süreci](#pull-request-süreci)
- [Hata Bildirimi](#hata-bildirimi)
- [Özellik İsteği](#özellik-isteği)

## 🚀 Nasıl Başlarım?

1. **Repository'yi fork edin**
   ```bash
   git clone https://github.com/yourusername/nearfriend.git
   cd nearfriend
   ```

2. **Geliştirme branch'i oluşturun**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Değişikliklerinizi yapın**

4. **Test edin**
   ```bash
   flutter test
   flutter analyze
   ```

5. **Commit edin**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

6. **Push edin**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Pull Request oluşturun**

## 🛠️ Geliştirme Ortamı

### Gereksinimler
- Flutter SDK 3.16.0+
- Dart SDK 3.2.0+
- Android Studio / VS Code
- Firebase hesabı

### Kurulum
```bash
flutter pub get
flutter doctor
```

## 📝 Kod Standartları

### Dart/Flutter
- **Dart Style Guide**'a uyun
- **Effective Dart** kurallarını takip edin
- **flutter analyze** komutunu çalıştırın
- **flutter format** ile kodunuzu formatlayın

### Dosya İsimlendirme
- **snake_case** kullanın: `user_profile.dart`
- **PascalCase** sınıf isimleri: `UserProfile`
- **camelCase** değişken isimleri: `userName`

### Kod Yapısı
```dart
// ✅ İyi örnek
class UserService {
  static const String _baseUrl = 'https://api.example.com';
  
  Future<User> getUser(String id) async {
    try {
      final response = await http.get('$_baseUrl/users/$id');
      return User.fromJson(jsonDecode(response.body));
    } catch (e) {
      throw UserException('Kullanıcı alınamadı: $e');
    }
  }
}

// ❌ Kötü örnek
class userService {
  Future getUser(id) async {
    var response = await http.get('https://api.example.com/users/' + id);
    return User.fromJson(jsonDecode(response.body));
  }
}
```

## 💬 Commit Mesajları

[Conventional Commits](https://www.conventionalcommits.org/) standardını kullanın:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Commit Tipleri
- **feat**: Yeni özellik
- **fix**: Hata düzeltmesi
- **docs**: Dokümantasyon değişiklikleri
- **style**: Kod formatı değişiklikleri
- **refactor**: Kod yeniden düzenleme
- **test**: Test ekleme veya düzenleme
- **chore**: Yapılandırma değişiklikleri

### Örnekler
```bash
feat: add user profile screen
fix: resolve location permission issue
docs: update README with installation steps
refactor: improve distance calculation algorithm
test: add unit tests for auth service
```

## 🔄 Pull Request Süreci

### PR Oluşturma
1. **Açıklayıcı başlık** yazın
2. **Detaylı açıklama** ekleyin
3. **Ekran görüntüleri** ekleyin (UI değişiklikleri için)
4. **Test sonuçları** paylaşın

### PR Şablonu
```markdown
## 📝 Açıklama
Bu PR ne yapıyor?

## 🔧 Değişiklikler
- [ ] Yeni özellik eklendi
- [ ] Hata düzeltildi
- [ ] Performans iyileştirmesi
- [ ] Dokümantasyon güncellendi

## 🧪 Testler
- [ ] Unit testler geçiyor
- [ ] Widget testler geçiyor
- [ ] Manuel test yapıldı

## 📱 Ekran Görüntüleri
[Varsa ekran görüntüleri ekleyin]

## ✅ Kontrol Listesi
- [ ] Kod standartlarına uygun
- [ ] Commit mesajları düzgün
- [ ] Gereksiz dosyalar eklenmedi
- [ ] API anahtarları gizlendi
```

## 🐛 Hata Bildirimi

### Hata Raporu Şablonu
```markdown
## 🐛 Hata Açıklaması
Hatanın kısa açıklaması

## 🔄 Tekrar Adımları
1. Uygulamayı aç
2. Ana sayfaya git
3. Check-in butonuna tıkla
4. Hata oluşuyor

## 📱 Cihaz Bilgileri
- **Cihaz**: Samsung Galaxy S21
- **Android Sürümü**: 12
- **Uygulama Sürümü**: 1.0.0

## 📋 Beklenen Davranış
Ne olması gerekiyordu?

## 🔍 Gerçekleşen Davranış
Ne oldu?

## 📸 Ekran Görüntüleri
[Varsa ekran görüntüleri]

## 📝 Loglar
```
[Log mesajları buraya]
```
```

## 💡 Özellik İsteği

### Özellik İsteği Şablonu
```markdown
## 💡 Özellik Açıklaması
İstenen özelliğin detaylı açıklaması

## 🎯 Kullanım Senaryosu
Bu özellik ne zaman kullanılacak?

## 🔧 Teknik Detaylar
Gerekli teknik bilgiler

## 📱 UI/UX Önerileri
Tasarım önerileri

## 🔗 Benzer Örnekler
Varsa benzer uygulamalardan örnekler
```

## 🏷️ Etiketler

### Issue Etiketleri
- `bug`: Hata raporu
- `enhancement`: İyileştirme önerisi
- `feature`: Yeni özellik isteği
- `documentation`: Dokümantasyon
- `good first issue`: Yeni başlayanlar için
- `help wanted`: Yardım gerekli

### PR Etiketleri
- `WIP`: Çalışma devam ediyor
- `ready for review`: İncelemeye hazır
- `breaking change`: Geriye uyumsuz değişiklik

## 📞 İletişim

- **GitHub Issues**: [Issues sayfası](https://github.com/yourusername/nearfriend/issues)
- **Email**: your.email@example.com
- **Discord**: [Discord sunucusu linki]

## 🙏 Teşekkürler

Katkıda bulunduğunuz için teşekkürler! Her katkınız projeyi daha iyi hale getiriyor. 🚀

---

**Not**: Bu rehber sürekli güncellenmektedir. Önerileriniz için issue açabilirsiniz. 