import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/location_debug.dart';

class LocationTestScreen extends StatefulWidget {
  const LocationTestScreen({super.key});

  @override
  State<LocationTestScreen> createState() => _LocationTestScreenState();
}

class _LocationTestScreenState extends State<LocationTestScreen> {
  Map<String, dynamic>? _testResults;
  bool _isLoading = false;
  String _statusMessage = 'Konum testi henüz çalıştırılmadı';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum Servisi Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konum Servisi Durumu',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _runQuickTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading 
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoActivityIndicator(),
                      SizedBox(width: 8),
                      Text('Hızlı Test Çalışıyor...'),
                    ],
                  )
                : const Text('Hızlı Konum Testi'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _runFullTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading 
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoActivityIndicator(),
                      SizedBox(width: 8),
                      Text('Tam Test Çalışıyor...'),
                    ],
                  )
                : const Text('Kapsamlı Konum Testi'),
            ),
            
            const SizedBox(height: 16),
            
            if (_testResults != null) ...[
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test Sonuçları',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildTestResults(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (_testResults == null) return Colors.grey;
    if (_testResults!['success'] == true) return Colors.green;
    return Colors.red;
  }

  Future<void> _runQuickTest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Hızlı konum testi çalışıyor...';
    });

    try {
      bool success = await LocationDebugger.quickLocationTest();
      setState(() {
        _testResults = {'success': success, 'type': 'quick'};
        _statusMessage = success 
          ? '✅ Hızlı test başarılı - Konum servisi çalışıyor!'
          : '❌ Hızlı test başarısız - Konum servisi çalışmıyor';
      });
    } catch (e) {
      setState(() {
        _testResults = {'success': false, 'error': e.toString(), 'type': 'quick'};
        _statusMessage = '❌ Hızlı test hatası: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _runFullTest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Kapsamlı konum testi çalışıyor...';
    });

    try {
      Map<String, dynamic> results = await LocationDebugger.testLocationService();
      setState(() {
        _testResults = results;
        _statusMessage = results['success'] == true
          ? '✅ Kapsamlı test başarılı - Konum servisi tam çalışıyor!'
          : '❌ Kapsamlı test başarısız - ${results['error'] ?? 'Bilinmeyen hata'}';
      });
    } catch (e) {
      setState(() {
        _testResults = {'success': false, 'error': e.toString(), 'type': 'full'};
        _statusMessage = '❌ Kapsamlı test hatası: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildTestResults() {
    if (_testResults == null) return const Text('Test sonucu yok');

    List<Widget> widgets = [];

    if (_testResults!['type'] != null) {
      widgets.add(
        _buildResultItem(
          'Test Türü', 
          _testResults!['type'] == 'quick' ? 'Hızlı Test' : 'Kapsamlı Test',
          Colors.blue,
        ),
      );
    }

    widgets.add(
      _buildResultItem(
        'Durum', 
        _testResults!['success'] == true ? 'BAŞARILI' : 'BAŞARISIZ',
        _testResults!['success'] == true ? Colors.green : Colors.red,
      ),
    );

    if (_testResults!['serviceEnabled'] != null) {
      widgets.add(
        _buildResultItem(
          'Konum Servisi', 
          _testResults!['serviceEnabled'] ? 'Aktif' : 'Kapalı',
          _testResults!['serviceEnabled'] ? Colors.green : Colors.red,
        ),
      );
    }

    if (_testResults!['initialPermission'] != null) {
      widgets.add(
        _buildResultItem(
          'İzin Durumu', 
          _testResults!['initialPermission'],
          _testResults!['initialPermission'] == 'PermissionStatus.granted' 
            ? Colors.green : Colors.orange,
        ),
      );
    }

    if (_testResults!['locationData'] != null) {
      final locationData = _testResults!['locationData'];
      widgets.add(const Divider());
      widgets.add(
        Text(
          'Konum Bilgileri',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
      );
      widgets.add(
        _buildResultItem(
          'Enlem', 
          '${locationData['latitude']?.toStringAsFixed(6) ?? 'N/A'}',
          Colors.black,
        ),
      );
      widgets.add(
        _buildResultItem(
          'Boylam', 
          '${locationData['longitude']?.toStringAsFixed(6) ?? 'N/A'}',
          Colors.black,
        ),
      );
      widgets.add(
        _buildResultItem(
          'Doğruluk', 
          '${locationData['accuracy']?.toStringAsFixed(1) ?? 'N/A'} m',
          Colors.black,
        ),
      );
      widgets.add(
        _buildResultItem(
          'Süre', 
          '${locationData['timeTaken'] ?? 'N/A'} ms',
          Colors.black,
        ),
      );
    }

    if (_testResults!['error'] != null) {
      widgets.add(const Divider());
      widgets.add(
        Text(
          'Hata Detayı',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
      );
      widgets.add(
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _testResults!['error'],
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildResultItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
