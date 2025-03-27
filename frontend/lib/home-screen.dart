import 'package:flutter/material.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  bool isConnecting = true;
  html.VideoElement? videoElement;
  html.CanvasElement? canvasElement;
  Timer? snapshotTimer;

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://192.168.0.5:8000/detect-gesture'),
      );
      _channel.stream.listen(
        (message) {
          if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
          final command = message.trim().toLowerCase();
          debugPrint("Mensaje recibido: '$command'");
          if (command == "thumbs_up") {
            _simulateButtonPressIA();
          }
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pulgar arriba detectado. ¡Accediendo con IA!'),
        duration: Duration(seconds: 1),
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
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.primary),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 150),
            const Text(
              'BIENVENIDO!',
              style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Image.asset('assets/pngegg.png', height: 500, width: 300),
            const SizedBox(height: 20),
            if (isConnecting)
              const Center(
                child: Text(
                  'Conectando con la cámara...',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            const Text(
              'Presiona "Continuar" o levanta el pulgar para acceder con IA',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 200),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFFF30C0C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 30,
                    ),
                    textStyle: const TextStyle(fontSize: 22),
                  ),
                  onPressed: _simulateButtonPressContinuar,
                  child: const Text("Continuar"),
                ),
                const SizedBox(width: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 30,
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
                  label: const Text("Acceder con IA"),
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
