import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'normal-mode.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'gesture-websocket_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum LanguageOption { spanish, english }

class _HomeScreenState extends State<HomeScreen> {
  late final WebSocketChannel _channel;
  bool isConnecting = true;
  final FlutterTts _flutterTts = FlutterTts();
  LanguageOption _selectedLanguage = LanguageOption.spanish;

  // Variables para el reconocimiento de voz
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();

    // Conecta el WebSocket global para mantener la sesión activa
    GestureWebSocketService().connect(
      url: 'ws://127.0.0.1:8000/ws-detect-gesture-image',
    );
    _connectToWebSocket();
    _initSpeechRecognizer(); // Inicia el reconocimiento de voz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakInstructions();
    });
  }

  Future<void> _speakInstructions() async {
    String message = _getInstructionMessage();
    await _flutterTts.setLanguage(_getTtsLanguageCode());
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      if (!_speech.isListening) {
        _startListening(); // Reactiva el micrófono tras la instrucción inicial
      }
    });
    await _flutterTts.speak(message);
  }

  String _getInstructionMessage() {
    switch (_selectedLanguage) {
      case LanguageOption.english:
        return "Press Continue or raise your thumb to access with A I";
      case LanguageOption.spanish:
      default:
        return "Presiona el botón 'Continuar' o levanta tu dedo pulgar para acceder con I A";
    }
  }

  String _getTtsLanguageCode() {
    switch (_selectedLanguage) {
      case LanguageOption.english:
        return "en-US";
      case LanguageOption.spanish:
      default:
        return "es-AR"; // <--- Esto fuerza el acento argentino 🇦🇷
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
  }

  // Funciones para el reconocimiento de voz
  Future<void> _initSpeechRecognizer() async {
    _speech = stt.SpeechToText();
    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );
    if (available) {
      _startListening();
    } else {
      debugPrint("El reconocimiento de voz no está disponible");
    }
  }

  void _startListening() {
    if (_speech.isListening) return;
    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords.toLowerCase();
        });
        if (_lastWords.contains('ayuda')) {
          _simulateHelpButton();
        }
      },
    );
  }

  bool _helpSpoken = false; // 🔹 Nueva variable de control

  void _simulateHelpButton() async {
    if (_helpSpoken) return; // Evita múltiples llamadas simultáneas
    _helpSpoken = true;

    await _flutterTts.setLanguage("es-AR");
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      _helpSpoken = false;
      if (!_speech.isListening) {
        _startListening(); // Reactiva el micrófono al terminar el TTS
      }
    });

    await _flutterTts.speak(
      "Presiona el botón  'Continuar' o levanta tu dedo pulgar para acceder con I A",
    );
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

  @override
  void dispose() {
    _channel.sink.close();
    _flutterTts.stop();
    _speech.stop();
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
          PopupMenuButton<LanguageOption>(
            onSelected: _changeLanguage,
            icon: const Icon(Icons.language),
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: LanguageOption.spanish,
                    child: Text('Español'),
                  ),
                  PopupMenuItem(
                    value: LanguageOption.english,
                    child: Text('English'),
                  ),
                ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 300),
                Text(
                  isSpanish ? '¡BIENVENIDO!' : 'WELCOME!',
                  style: const TextStyle(
                    fontSize: 90,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Image.asset('assets/pngegg.png', height: 800, width: 800),
                const SizedBox(height: 20),
                if (isConnecting)
                  Text(
                    isSpanish
                        ? 'Conectando con la IA...'
                        : 'Connecting to A.I...',
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                Text(
                  _getInstructionMessage(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, color: Colors.black54),
                ),
                const SizedBox(height: 200),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.grey,
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
                      onPressed: _simulateButtonPressIA,
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

          // 🔹 Botón de ayuda fuera del AppBar
          Positioned(
            top: 16,
            right: 16,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 30,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () async {
                // Configura TTS y reproduce las instrucciones
                await _flutterTts.setLanguage("es-AR");
                await _flutterTts.setSpeechRate(1.0);
                await _flutterTts.setPitch(1.0);
                await _flutterTts.speak(
                  "Presiona el botón  'Continuar' o levanta tu dedo pulgar para acceder con I A",
                );
              },
              child: const Text("Ayuda"),
            ),
          ),
        ],
      ),
    );
  }
}
