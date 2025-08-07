import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  static Future<String> getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      print(
          '🔍 Geocoding: Adres çözümleniyor... Lat: $latitude, Lng: $longitude');

      final url = Uri.parse(
          '$_baseUrl/reverse?format=json&lat=$latitude&lon=$longitude&zoom=16&addressdetails=1&accept-language=tr');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'nearFriend App', // Nominatim kullanım şartı
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String address = _formatAddress(data);
        print('✅ Geocoding: Adres bulundu: $address');
        return address;
      } else {
        print('❌ Geocoding: HTTP hatası: ${response.statusCode}');
        return _getFallbackAddress(latitude, longitude);
      }
    } catch (e) {
      print('❌ Geocoding: Hata: $e');
      return _getFallbackAddress(latitude, longitude);
    }
  }

  static String _formatAddress(Map<String, dynamic> data) {
    try {
      final address = data['address'] as Map<String, dynamic>?;
      final displayName = data['display_name'] as String?;

      if (address != null) {
        List<String> addressParts = [];

        if (address['road'] != null) {
          addressParts.add(address['road']);
        }

        if (address['neighbourhood'] != null) {
          addressParts.add(address['neighbourhood']);
        } else if (address['suburb'] != null) {
          addressParts.add(address['suburb']);
        }

        if (address['district'] != null) {
          addressParts.add(address['district']);
        } else if (address['town'] != null) {
          addressParts.add(address['town']);
        }

        if (address['city'] != null) {
          addressParts.add(address['city']);
        } else if (address['state'] != null) {
          addressParts.add(address['state']);
        }

        if (address['country'] != null) {
          addressParts.add(address['country']);
        }

        if (addressParts.isNotEmpty) {
          String formattedAddress =
              addressParts.take(3).join(', '); // İlk 3 parçayı al
          return formattedAddress;
        }
      }

      if (displayName != null && displayName.isNotEmpty) {
        List<String> parts = displayName.split(', ');
        if (parts.length >= 3) {
          return parts.take(3).join(', ');
        }
        return displayName;
      }

      return 'Adres bulunamadı';
    } catch (e) {
      print('❌ Geocoding: Adres formatlarken hata: $e');
      return 'Adres formatlanamadı';
    }
  }

  static String _getFallbackAddress(double latitude, double longitude) {
    if (latitude == 37.4219983 && longitude == -122.084) {
      return 'Google Plex, Mountain View, CA'; // Android emülatör varsayılan konumu
    }

    if (latitude == 37.7749 && longitude == -122.4194) {
      return 'San Francisco, CA';
    }

    if (latitude == 41.0082 && longitude == 28.9784) {
      return 'İstanbul, Türkiye';
    }

    if (latitude == 39.9334 && longitude == 32.8597) {
      return 'Ankara, Türkiye';
    }

    if (latitude >= 35.0 && latitude <= 42.0 && longitude >= 26.0 && longitude <= 45.0) {
      if (latitude >= 40.0 && longitude >= 34.0) {
        return 'Orta Anadolu, Türkiye';
      } else if (latitude >= 41.0 && longitude >= 28.0) {
        return 'Marmara Bölgesi, Türkiye';
      } else if (latitude >= 36.0 && longitude >= 30.0) {
        return 'Akdeniz Bölgesi, Türkiye';
      } else if (latitude >= 38.0 && longitude >= 27.0) {
        return 'Ege Bölgesi, Türkiye';
      } else {
        return 'Türkiye';
      }
    }

    return 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
  }

  static bool isValidAddress(String address) {
    return address.isNotEmpty &&
        !address.startsWith('Lat:') &&
        !address.contains('adres') &&
        address.length > 5;
  }

  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    try {
      if (query.length < 3) return [];

      final url = Uri.parse(
          '$_baseUrl/search?format=json&q=${Uri.encodeComponent(query)}&limit=5&addressdetails=1');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'nearFriend App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => {
                  'display_name': item['display_name'],
                  'lat': double.tryParse(item['lat']) ?? 0.0,
                  'lon': double.tryParse(item['lon']) ?? 0.0,
                })
            .toList();
      }

      return [];
    } catch (e) {
      print('❌ Geocoding: Arama hatası: $e');
      return [];
    }
  }
}
