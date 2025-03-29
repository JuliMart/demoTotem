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
  bool _gestureProcessed = false; // Bandera para evitar múltiples detecciones

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
    String? _lastGesture; // Último gesto detectado

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://127.0.0.1:8000/detect-gesture'),
      );

      _channel.stream.listen(
        (message) {
          final currentTime = DateTime.now();
          final trimmedMessage = message.trim();

          // Si el gesto detectado es el mismo que el anterior, y no ha pasado suficiente tiempo,
          // y además no es "waiting", se ignora para evitar repeticiones.
          if (_lastGesture == trimmedMessage &&
              _lastGesture != "waiting" &&
              _lastGestureTime != null &&
              currentTime.difference(_lastGestureTime!) <
                  const Duration(seconds: 5)) {
            return;
          }

          // Si ya se procesó un gesto (distinto a "waiting"), no se procesa de nuevo.
          if (trimmedMessage != "waiting" && _gestureProcessed) {
            return;
          }

          _lastGesture = trimmedMessage;
          _lastGestureTime = currentTime;

          debugPrint("Gesto detectado: '$trimmedMessage'");

          if (trimmedMessage == "number_1") {
            _gestureProcessed = true;
            _navigateToScreen(IAchoose1(key: UniqueKey()));
          } else if (trimmedMessage == "number_2") {
            _gestureProcessed = true;
            _navigateToScreen(const IAchoose2());
          } else if (trimmedMessage == "number_3") {
            _gestureProcessed = true;
            _navigateToScreen(const IAchoose3());
          } else if (trimmedMessage == "number_4") {
            _gestureProcessed = true;
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
  } // <-- Aquí se cierra correctamente el dispose()

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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Centrar el contenido horizontalmente
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
                'También puedes elegir las opciones haciendo gestos de los números del 1 al 4',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 150),
              _buildMenuButtons(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primera fila de botones
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMenuButton('Depósito cheques', const IAchoose1()),
            const SizedBox(width: 16),
            _buildMenuButton('Atención por caja', const IAchoose2()),
          ],
        ),
        const SizedBox(height: 16),
        // Segunda fila de botones
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMenuButton('Hablar con un ejecutivo', const IAchoose3()),
            const SizedBox(width: 16),
            _buildMenuButton('Cambiar tema', const ColorDetect()),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuButton(String text, Widget screen) {
    return Center(
      child: SizedBox(
        width: 350, // Ajusta este valor al ancho deseado
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
