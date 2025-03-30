import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'normal-mode.dart';

import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum LanguageOption { spanish, english }

class _HomeScreenState extends State<HomeScreen> {
  bool isConnecting = true;
  final FlutterTts _flutterTts = FlutterTts();
  LanguageOption _selectedLanguage = LanguageOption.spanish;


  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakInstructions();
    });
  }

  Future<void> _speakInstructions() async {
    String message = _getInstructionMessage();
    await _flutterTts.setLanguage(_getTtsLanguageCode());
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(message);
  }

  String _getInstructionMessage() {
    switch (_selectedLanguage) {
      case LanguageOption.english:
        return "Press Continue or raise your thumb to access with A I";
      case LanguageOption.spanish:
      default:
        return "Presioná Continuar o levantá el pulgar para acceder con I A";
    }
  }

  String _getTtsLanguageCode() {
    switch (_selectedLanguage) {
      case LanguageOption.english:
        return "en-US";
      case LanguageOption.spanish:
      default:
        return "es-AR";
    }
  }

  void _changeLanguage(LanguageOption option) {
    setState(() {
      _selectedLanguage = option;
    });
    _speakInstructions();
  }

  void _connectToWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8000/detect-gesture'),
      );
      _channel.stream.listen(
        (message) {
          if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
          final command = message.trim().toLowerCase();
          debugPrint("Mensaje recibido: '$command'");

          if (command != "thumbs_up") return;
          _simulateButtonPressIA();
        },
        onDone: () => setState(() => isConnecting = false),
        onError: (error) => setState(() => isConnecting = false),
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint("Error al conectar al WebSocket: $e");
      setState(() => isConnecting = false);
    }
    Future.delayed(
      const Duration(seconds: 2),
      () => setState(() => isConnecting = false),
    );
    _startCameraAndDetect();
  }

  void _simulateButtonPressIA() {
    final snackBarText =
        _selectedLanguage == LanguageOption.english
            ? 'Thumbs up detected. Accessing with A.I.!'
            : 'Pulgar arriba detectado. ¡Accediendo con IA!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackBarText),
        duration: const Duration(seconds: 1),
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NormalModeScreen()),
    );
  }

  void _simulateButtonPressContinuar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NormalModeScreen()),
    );
  }

  void _startCameraAndDetect() async {
    final stream = await html.window.navigator.mediaDevices!.getUserMedia({
      'video': true,
    });

    videoElement =
        html.VideoElement()
          ..autoplay = true
          ..srcObject = stream
          ..style.display = 'none';

    html.document.body!.append(videoElement!);

    canvasElement = html.CanvasElement(width: 640, height: 480);
    isConnecting = false;
    setState(() {});

    snapshotTimer = Timer.periodic(Duration(milliseconds: 500), (_) async {
      if (videoElement == null || canvasElement == null) return;

      final ctx = canvasElement!.context2D;
      ctx.drawImage(videoElement!, 0, 0);

      final blob = await canvasElement!.toBlob('image/jpeg');
      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob!);
      await reader.onLoad.first;
      final imageBytes = reader.result as Uint8List;

      final uri = Uri.parse('http://167.99.114.20:8000/detect-gesture-image');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: 'frame.jpg',
          ),
        );

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final decoded = jsonDecode(responseBody);
        final gesture = decoded['gesture'];
        if (gesture == 'thumbs_up') {
          _simulateButtonPressIA();
        }
      }
    });
  }

  void _stopCamera() {
    videoElement?.srcObject?.getTracks().forEach((track) => track.stop());
    videoElement?.remove();
    snapshotTimer?.cancel();
  }

  @override
  void dispose() {
    _channel.sink.close();
    _flutterTts.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSpanish = _selectedLanguage == LanguageOption.spanish;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _speakInstructions,
          ),
          PopupMenuButton<LanguageOption>(
            onSelected: _changeLanguage,
            icon: const Icon(Icons.language),
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: LanguageOption.spanish,
                    child: Text('Español'),
                  ),
                  const PopupMenuItem(
                    value: LanguageOption.english,
                    child: Text('English'),
                  ),
                ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 300),
            Text(
              isSpanish ? '¡BIENVENIDO!' : 'WELCOME!',
              style: const TextStyle(fontSize: 90, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Image.asset('assets/pngegg.png', height: 800, width: 800),
            const SizedBox(height: 20),
            if (isConnecting)
              Text(
                isSpanish ? 'Conectando con la IA...' : 'Connecting to A.I...',
                style: const TextStyle(fontSize: 16, color: Colors.black54),

              ),
            Text(
              _getInstructionMessage(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 200),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF30C0C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 70,
                      vertical: 50,
                    ),
                    textStyle: const TextStyle(fontSize: 22),
                  ),
                  onPressed: _simulateButtonPressContinuar,
                  child: Text(isSpanish ? "Continuar" : "Continue"),
                ),
                const SizedBox(width: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 70,
                      vertical: 50,
                    ),
                    textStyle: const TextStyle(fontSize: 22),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Detectando gestos en tiempo real...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.smart_toy),
                  label: Text(
                    isSpanish ? "Acceder con IA" : "Access with A.I.",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
