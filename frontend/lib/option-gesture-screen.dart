import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart'; // <-- Agregado
import 'package:web_socket_channel/web_socket_channel.dart';
import 'IAchoose1.dart';
import 'color-detect.dart';
import 'home-screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'normal-mode.dart';

class OptionGestureScreen extends StatefulWidget {
  const OptionGestureScreen({super.key});

  @override
  State<OptionGestureScreen> createState() => _OptionGestureScreenState();
}

class _OptionGestureScreenState extends State<OptionGestureScreen> {
  late final WebSocketChannel _channel;
  bool isConnecting = true;
  late stt.SpeechToText _speech;
  // Agregamos FlutterTts para instrucciones por voz:
  late FlutterTts _flutterTts;
  DateTime? _lastGestureTime;
  bool _gestureProcessed = false; // Bandera para evitar múltiples detecciones

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
    _speech = stt.SpeechToText();
    // Inicializamos TTS:
    _flutterTts = FlutterTts();
    _configureTts();
    // Detenemos la escucha mientras se reproducen las instrucciones.
    _stopListening();
    // Reproducimos las instrucciones luego de renderizar la UI.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakInstructions();
    });
    _initSpeech();
  }

  Future<void> _configureTts() async {
    await _flutterTts.setLanguage("es-AR");
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        _startListening();
      }
    });
  }

  Future<void> _speakInstructions() async {
    await _flutterTts.speak(
      "Usá tu mano izquierda o derecha para seleccionar entre las opciones disponibles.",
    );
  }

  void _stopListening() {
    _speech.stop();
    debugPrint('Listening stopped.');
  }

  void _startListening() {
    _speech.listen(
      onResult: (result) {
        debugPrint('Speech result: ${result.recognizedWords}');
        // Aquí se puede procesar el resultado del reconocimiento
      },
    );
    debugPrint('Listening started.');
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

  void _connectToWebSocket() {
    String? _lastGesture; // Último gesto detectado
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:8000/detect-gesture'),
      );
      _channel.stream.listen(
        (message) {
          final currentTime = DateTime.now();
          final trimmedMessage = message.trim();
          if (_lastGesture == trimmedMessage &&
              _lastGesture != "waiting" &&
              _lastGestureTime != null &&
              currentTime.difference(_lastGestureTime!) <
                  const Duration(seconds: 5)) {
            return;
          }
          if (trimmedMessage != "waiting" && _gestureProcessed) {
            return;
          }
          _lastGesture = trimmedMessage;
          _lastGestureTime = currentTime;
          debugPrint("Gesto detectado: '$trimmedMessage'");
          if (trimmedMessage == "left_hand") {
            _gestureProcessed = true;
            _navigateToScreen(const ColorDetect()); // Depósito de cheques
          } else if (trimmedMessage == "right_hand") {
            _gestureProcessed = true;
            _navigateToScreen(const IAchoose1()); // Cambiar tema
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
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onCommandToExit,
        ),
        title: const Text('Selecciona una opción con el gesto'),
        foregroundColor: Colors.white,
        // Quitamos el botón de ayuda del AppBar para colocarlo fuera.
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 150),
                  const Text(
                    'Elige una opción',
                    style: TextStyle(fontSize: 90, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Image.asset('assets/ejecutivo.png', height: 600),
                  const SizedBox(height: 20),
                  if (isConnecting)
                    const Text(
                      'Conectando con la IA...',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  const SizedBox(height: 80),
                  const Text(
                    "Usá tu mano izquierda o derecha para seleccionar entre las opciones disponibles.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, color: Colors.black54),
                  ),
                  const SizedBox(height: 150),
                  _buildMenuButtons(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Botón de ayuda posicionado en la esquina superior derecha, tamaño 70.
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.help_outline),
              iconSize: 70,
              onPressed: () async {
                await _flutterTts.setLanguage("es-AR");
                await _flutterTts.setSpeechRate(1.0);
                await _flutterTts.setPitch(1.0);
                await _flutterTts.speak(
                  "Usá tu mano izquierda o derecha para seleccionar entre las opciones disponibles.",
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMenuButton('Atención por caja', const IAchoose1()),
        const SizedBox(width: 16),
        _buildMenuButton('Cambiar tema', const ColorDetect()),
      ],
    );
  }

  Widget _buildMenuButton(String text, Widget screen) {
    return Center(
      child: SizedBox(
        width: 350,
        height: 80,
        child: FilledButton(
          onPressed: () => _navigateToScreen(screen),
          style: buttonStyle(),
          child: Text(text, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }

  ButtonStyle buttonStyle() => FilledButton.styleFrom(
    backgroundColor: const Color(0xFFF30C0C),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    elevation: 5,
    textStyle: const TextStyle(fontSize: 22),
  );
}
