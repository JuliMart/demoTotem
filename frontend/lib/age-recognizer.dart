import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AgeRecognizerScreen extends StatefulWidget {
  const AgeRecognizerScreen({Key? key}) : super(key: key);

  @override
  State<AgeRecognizerScreen> createState() => _AgeRecognizerScreenState();
}

class _AgeRecognizerScreenState extends State<AgeRecognizerScreen> {
  String? _ageRange;
  bool _isLoading = false;
  String _errorMessage = '';

  // Función para obtener el rango de edad desde el endpoint de FastAPI.
  Future<void> _fetchAgeRange() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/age-recognizer'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _ageRange = data['age_range'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAgeRange();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Age Recognizer')),
      body: Center(
        child:
            _isLoading
                ? const CircularProgressIndicator()
                : _errorMessage.isNotEmpty
                ? Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 20),
                  textAlign: TextAlign.center,
                )
                : _ageRange != null
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Rango de edad detectado: $_ageRange',
                      style: const TextStyle(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _fetchAgeRange,
                      child: const Text('Refrescar'),
                    ),
                  ],
                )
                : const Text('No se detectó ningún rango de edad'),
      ),
    );
  }
}
