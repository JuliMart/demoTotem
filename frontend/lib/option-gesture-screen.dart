import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'IAchoose1.dart';
import 'IAchoose2.dart';
import 'IAchoose3.dart';
import 'color-detect.dart';
import 'home-screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class OptionGestureScreen extends StatefulWidget {
  const OptionGestureScreen({super.key});

  @override
  State<OptionGestureScreen> createState() => _OptionGestureScreenState();
}

class _OptionGestureScreenState extends State<OptionGestureScreen> {
  late final WebSocketChannel _channel;
  bool isConnecting = true;
  late stt.SpeechToText _speech;
  DateTime? _lastGestureTime;

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  void _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' && mounted) {
          _startListening();
        }
      },
      onError: (error) => debugPrint('Speech Error: $error'),
    );

    if (available) {
      _startListening();
    } else {
      debugPrint('Reconocimiento de voz no disponible.');
    }
  }

  void _startListening() {
    if (!_speech.isListening) {
      _speech.listen(
        localeId: 'es_CL',
        onResult: (result) {
          final currentTime = DateTime.now();
          if (_lastGestureTime != null &&
              currentTime.difference(_lastGestureTime!) <
                  const Duration(seconds: 2)) {
            return;
          }
          if (result.recognizedWords.toLowerCase().contains("atrás")) {
            _lastGestureTime = currentTime;
            _onCommandToExit();
          }
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(milliseconds: 500),
        partialResults: true,
      );
    }
  }

  void _connectToWebSocket() {
    String? _lastGesture; // Variable para almacenar el último gesto detectado

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://192.168.153.156:8000/detect-gesture'),
      );

      _channel.stream.listen(
        (message) {
          final currentTime = DateTime.now();
          final trimmedMessage = message.trim();

          // Verifica si el gesto es igual al último detectado y si ha pasado poco tiempo
          if (_lastGesture == trimmedMessage &&
              _lastGestureTime != null &&
              currentTime.difference(_lastGestureTime!) <
                  const Duration(seconds: 3)) {
            return; // Ignora detecciones repetidas en menos de 2 segundos
          }

          // Guarda el gesto y el tiempo de detección
          _lastGesture = trimmedMessage;
          _lastGestureTime = currentTime;

          debugPrint("Gesto detectado: '$trimmedMessage'");

          if (trimmedMessage == "number_1") {
            _navigateToScreen(IAchoose1(key: UniqueKey()));
          } else if (trimmedMessage == "number_2") {
            _navigateToScreen(const IAchoose2());
          } else if (trimmedMessage == "number_3") {
            _navigateToScreen(const IAchoose3());
          } else if (trimmedMessage == "number_4") {
            _navigateToScreen(const ColorDetect());
          }
        },
        onDone: () {
          debugPrint("Conexión cerrada.");
          setState(() => isConnecting = false);
        },
        onError: (error) {
          debugPrint("Error WebSocket: $error");
          setState(() => isConnecting = false);
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint("Error al conectar WebSocket: $e");
      setState(() => isConnecting = false);
    }
  }

  void _navigateToScreen(Widget screen) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gesto detectado, accediendo...'),
        duration: Duration(seconds: 1),
      ),
    );
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _onCommandToExit() {
    _speech.cancel();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onCommandToExit,
        ),
        title: const Text('Selecciona una opción con el gesto'),
        backgroundColor: const Color(0xFFF30C0C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Center(
              child: Text(
                '¿En qué puedo ayudarte?',
                style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
              ),
            ),

            Image.asset('assets/ejecutivo.png', height: 500, width: 500),
            const SizedBox(height: 20),
            if (isConnecting)
              const Text(
                'Conectando con la IA...',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            SizedBox(height: 80),

            const Text(
              'También puedes elegir las opciones haciendo gestos de los números del 1 al 4',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 30),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                SizedBox(
                  width: 300,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: () => _navigateToScreen(const IAchoose1()),
                    style: buttonStyle(),
                    child: const Text(
                      'Depósito cheques',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 300,
                  height: 30,

                  child: ElevatedButton(
                    onPressed: () => _navigateToScreen(const IAchoose2()),
                    style: buttonStyle(),
                    child: const Text(
                      'Atención por caja',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 300,
                  height: 30,

                  child: ElevatedButton(
                    onPressed: () => _navigateToScreen(const IAchoose3()),
                    style: buttonStyle(),
                    child: const Text(
                      'Hablar con un ejecutivo',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 300,
                  height: 30,

                  child: ElevatedButton(
                    onPressed: () => _navigateToScreen(const ColorDetect()),
                    style: buttonStyle(),
                    child: const Text(
                      'Cambiar tema',
                      style: TextStyle(fontSize: 18),
                    ),
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

  ButtonStyle buttonStyle() => ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFF30C0C),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 5,
  );
}
