import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'home-screen.dart';
import 'option-gesture-screen.dart';

class NormalModeScreen extends StatefulWidget {
  const NormalModeScreen({Key? key}) : super(key: key);

  @override
  State<NormalModeScreen> createState() => _NormalModeScreenState();
}

class _NormalModeScreenState extends State<NormalModeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _documentController = TextEditingController();
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _isSpeaking = false;
  DateTime? _ignoreUntil;
  String _previousRecognized = "";
  bool _eightDigitLimitReached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _configureTts();
    // Detenemos la escucha mientras se leen las instrucciones.
    _stopListening();
    // Leemos las instrucciones después de que la UI se renderice.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakInstructions();
    });
  }

  Future<void> _configureTts() async {
    await _flutterTts.setLanguage("es-AR");
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setPitch(1.0);
    // Cuando termina de hablar, marcamos que ya no se está reproduciendo
    // y establecemos un período para ignorar comandos (2 segundos)
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      _ignoreUntil = DateTime.now().add(const Duration(seconds: 2));
      if (mounted) _startListening();
    });
  }

  Future<void> _speakInstructions() async {
    _isSpeaking = true;
    await _flutterTts.speak(
      "Ingresa tu DNI escribiéndolo o diciéndolo en voz alta.\nLuego presiona 'Continuar' o di 'Continuar' en voz alta.",
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _documentController.dispose();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopListening();
    } else if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _startListening();
      });
    }
  }

  String _formatWithDots(String digits) {
    String digitsOnly = digits.replaceAll('.', '');
    if (digitsOnly.isEmpty) return '';
    int value = int.parse(digitsOnly);
    String s = value.toString();
    StringBuffer sb = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      sb.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        sb.write('.');
        count = 0;
      }
    }
    return sb.toString().split('').reversed.join('');
  }

  void _onDigitPressed(String digit) {
    if (!mounted) return;
    String digitsOnly = _documentController.text.replaceAll('.', '');
    if (digitsOnly.length >= 8) {
      _eightDigitLimitReached = true;
      return;
    } else {
      _eightDigitLimitReached = false;
    }
    digitsOnly += digit;
    String formatted = _formatWithDots(digitsOnly);
    setState(() {
      _documentController.text = formatted;
    });
  }

  void _onBackspacePressed() {
    if (!mounted) return;
    String digitsOnly = _documentController.text.replaceAll('.', '');
    if (digitsOnly.isNotEmpty) {
      digitsOnly = digitsOnly.substring(0, digitsOnly.length - 1);
    }
    _eightDigitLimitReached = digitsOnly.length >= 8;
    String formatted = _formatWithDots(digitsOnly);
    setState(() {
      _documentController.text = formatted;
    });
  }

  void _onClearAll() {
    if (!mounted) return;
    _eightDigitLimitReached = false;
    setState(() {
      _documentController.text = '';
    });
  }

  void _onFinishPressed() {
    if (!mounted) return;
    final documentValue = _documentController.text;
    debugPrint('Documento ingresado: $documentValue');
    _stopListening();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  }

  void _onContinuePressed() async {
    if (!mounted) return;
    final documentValue = _documentController.text;
    debugPrint('Documento ingresado: $documentValue');
    _onClearAll();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OptionGestureScreen(key: UniqueKey()),
      ),
    );
    if (mounted) {
      _startListening();
    }
  }

  void _startListening() async {
    if (_speech.isListening || _isListening) return;
    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Status: $status');
        if ((status == "done" || status == 'notListening') &&
            mounted &&
            !_isListening) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_isListening) _startListening();
          });
        }
      },
      onError: (error) {
        debugPrint('Error: $error');
      },
    );
    if (available) {
      if (!mounted) return;
      setState(() => _isListening = true);
      try {
        _speech.listen(
          localeId: 'es_CL',
          onResult: (result) {
            if (!mounted) return;
            // Si se está reproduciendo TTS o se ignoran comandos temporalmente, no procesamos.
            if (_isSpeaking ||
                (_ignoreUntil != null &&
                    DateTime.now().isBefore(_ignoreUntil!)))
              return;
            _processSpeech(result.recognizedWords.toLowerCase());
          },
          partialResults: true,
          pauseFor: const Duration(seconds: 10),
          listenFor: const Duration(minutes: 10),
          onSoundLevelChange: (level) {
            debugPrint("Nivel de sonido: $level");
          },
        );
      } catch (e) {
        debugPrint('Error al iniciar el reconocimiento: $e');
      }
    } else {
      debugPrint('El reconocimiento de voz no está disponible.');
    }
  }

  void _stopListening() {
    _speech.cancel();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  void _processSpeech(String spokenText) {
    if (!mounted) return;
    String newPart = spokenText;
    if (_previousRecognized.isNotEmpty &&
        spokenText.startsWith(_previousRecognized)) {
      newPart = spokenText.substring(_previousRecognized.length).trim();
    }
    if (newPart.isEmpty) return;
    _previousRecognized = spokenText;
    debugPrint('Reconocido (raw): $spokenText');
    debugPrint('Parte nueva: $newPart');
    String cleanedText = newPart.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    debugPrint('Reconocido (limpio): $cleanedText');
    List<String> tokens = cleanedText.split(RegExp(r'\s+'));
    for (var token in tokens) {
      if (token.contains("ayuda")) {
        _simulateHelpButton();
      } else if (token.contains("todo")) {
        _onClearAll();
      } else if (token.contains("rar")) {
        _onBackspacePressed();
      } else if (token.contains("lizar")) {
        _onFinishPressed();
      } else if (token.contains("continuar")) {
        _onContinuePressed();
      } else if (_isNumberWord(token)) {
        String digit = _wordToDigit(token);
        _onDigitPressed(digit);
      } else if (RegExp(r'^\d+$').hasMatch(token)) {
        for (var d in token.split('')) {
          _onDigitPressed(d);
        }
      } else {
        debugPrint('Token no válido: $token');
      }
    }
  }

  bool _isNumberWord(String word) {
    final set = {
      "uno",
      "dos",
      "tres",
      "cuatro",
      "cinco",
      "seis",
      "siete",
      "ocho",
      "nueve",
      "cero",
    };
    return set.contains(word);
  }

  String _wordToDigit(String word) {
    switch (word) {
      case "uno":
        return "1";
      case "dos":
        return "2";
      case "tres":
        return "3";
      case "cuatro":
        return "4";
      case "cinco":
        return "5";
      case "seis":
        return "6";
      case "siete":
        return "7";
      case "ocho":
        return "8";
      case "nueve":
        return "9";
      case "cero":
        return "0";
      default:
        return "";
    }
  }

  // Función para simular la acción del botón de ayuda mediante TTS
  void _simulateHelpButton() async {
    await _flutterTts.setLanguage("es-AR");
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(
      "Ingresá tu DNI escribiéndolo o diciéndolo en voz alta. Después, di 'continuar' para avanzar.",
    );
  }

  Widget _buildNumberButton(String digit) {
    return SizedBox(
      width: 80,
      height: 80,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 24),
        ),
        onPressed: () => _onDigitPressed(digit),
        child: Text(digit),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return SizedBox(
      width: 80,
      height: 80,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 24),
        ),
        onPressed: _onBackspacePressed,
        child: const Icon(Icons.backspace),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _speech.cancel();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen()),
            );
          },
        ),
        // Se elimina el botón de ayuda del AppBar
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 220),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Ingresá tu DNI escribiéndolo o diciéndolo en voz alta.\n Después, di 'continuar' para avanzar.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 90),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _documentController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: "DNI",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    IconButton(
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                      iconSize: 40,
                      color: const Color(0xFFF30C0C),
                      onPressed:
                          _isListening ? _stopListening : _startListening,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 300,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNumberButton("1"),
                              _buildNumberButton("2"),
                              _buildNumberButton("3"),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNumberButton("4"),
                              _buildNumberButton("5"),
                              _buildNumberButton("6"),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNumberButton("7"),
                              _buildNumberButton("8"),
                              _buildNumberButton("9"),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const SizedBox(width: 80, height: 80),
                              _buildNumberButton("0"),
                              _buildBackspaceButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 125),
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
                      onPressed: _onContinuePressed,
                      child: const Text("Continuar"),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
          // Botón de ayuda posicionado en la esquina superior derecha
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
                  "Ingresá tu DNI escribiéndolo o diciéndolo en voz alta. Después, di 'continuar' para avanzar.",
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
