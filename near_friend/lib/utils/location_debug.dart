import 'package:location/location.dart';
import 'package:flutter/foundation.dart';

class LocationDebugger {
  static const String tag = 'LocationDebugger';
  
  static void log(String message) {
    if (kDebugMode) {
      print('[$tag] $message');
    }
  }

  static Future<Map<String, dynamic>> testLocationService() async {
    final Map<String, dynamic> results = {};
    log('🔍 Konum servisi testi başlıyor...');
    
    try {
      Location location = Location();
      
      log('1️⃣ Konum servisi durumu kontrol ediliyor...');
      bool serviceEnabled = await location.serviceEnabled();
      results['serviceEnabled'] = serviceEnabled;
      log('   Konum servisi aktif: $serviceEnabled');
      
      if (!serviceEnabled) {
        log('   🚨 Konum servisi kapalı, açılmaya çalışılıyor...');
        serviceEnabled = await location.requestService();
        results['serviceEnabledAfterRequest'] = serviceEnabled;
        log('   Konum servisi açıldı mı: $serviceEnabled');
        
        if (!serviceEnabled) {
          log('   ❌ Konum servisi açılamadı');
          results['error'] = 'Konum servisi açılamadı';
          return results;
        }
      }
      
      log('2️⃣ Konum izni kontrol ediliyor...');
      PermissionStatus permissionGranted = await location.hasPermission();
      results['initialPermission'] = permissionGranted.toString();
      log('   Mevcut konum izni: $permissionGranted');
      
      if (permissionGranted == PermissionStatus.denied) {
        log('   🚨 Konum izni yok, izin isteniyor...');
        permissionGranted = await location.requestPermission();
        results['permissionAfterRequest'] = permissionGranted.toString();
        log('   İzin sonucu: $permissionGranted');
        
        if (permissionGranted != PermissionStatus.granted) {
          log('   ❌ Konum izni alınamadı');
          results['error'] = 'Konum izni alınamadı: $permissionGranted';
          return results;
        }
      }
      
      log('3️⃣ Konum ayarları kontrol ediliyor...');
      try {
        await location.changeSettings(
          accuracy: LocationAccuracy.high,
          interval: 1000,
          distanceFilter: 0,
        );
        results['settingsChanged'] = true;
        log('   ✅ Konum ayarları güncellendi');
      } catch (e) {
        log('   ⚠️ Konum ayarları güncellenemedi: $e');
        results['settingsError'] = e.toString();
      }
      
      log('4️⃣ Konum alınmaya çalışılıyor...');
      final DateTime startTime = DateTime.now();
      LocationData locationData = await location.getLocation();
      final Duration timeTaken = DateTime.now().difference(startTime);
      
      results['locationData'] = {
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'accuracy': locationData.accuracy,
        'altitude': locationData.altitude,
        'heading': locationData.heading,
        'speed': locationData.speed,
        'speedAccuracy': locationData.speedAccuracy,
        'time': locationData.time,
        'timeTaken': timeTaken.inMilliseconds,
      };
      
      log('   ✅ Konum başarıyla alındı! (${timeTaken.inMilliseconds}ms)');
      log('   📍 Lat: ${locationData.latitude}, Lng: ${locationData.longitude}');
      log('   🎯 Doğruluk: ${locationData.accuracy}m');
      
      results['success'] = true;
      
    } catch (e, stackTrace) {
      log('   ❌ Konum alma hatası: $e');
      log('   📋 Stack trace: $stackTrace');
      results['error'] = e.toString();
      results['stackTrace'] = stackTrace.toString();
    }
    
    log('🏁 Konum servisi testi tamamlandı');
    return results;
  }
  
  static Future<bool> quickLocationTest() async {
    try {
      log('⚡ Hızlı konum testi...');
      Location location = Location();
      
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return false;
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return false;
      }

      LocationData locationData = await location.getLocation();
      log('✅ Hızlı test başarılı: ${locationData.latitude}, ${locationData.longitude}');
      return true;
      
    } catch (e) {
      log('❌ Hızlı test başarısız: $e');
      return false;
    }
  }
}
