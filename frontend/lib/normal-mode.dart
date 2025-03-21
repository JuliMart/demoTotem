import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'option-gesture-screen.dart';
import 'home-screen.dart';

class NormalModeScreen extends StatefulWidget {
  const NormalModeScreen({Key? key}) : super(key: key);

  @override
  State<NormalModeScreen> createState() => _NormalModeScreenState();
}

class _NormalModeScreenState extends State<NormalModeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _documentController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _previousRecognized = "";
  bool _eightDigitLimitReached = false; // Variable de control

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = stt.SpeechToText();
    _startListening();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _documentController.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Detenemos la escucha cuando la app pasa a segundo plano
    if (state == AppLifecycleState.paused) {
      _stopListening();
    }
    // Al reanudarse, esperamos unos milisegundos para reiniciar la escucha
    else if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _startListening();
        }
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
    // Elimina los puntos para obtener solo los dígitos.
    String digitsOnly = _documentController.text.replaceAll('.', '');

    // Si ya alcanzó o superó los 8 dígitos...
    if (digitsOnly.length >= 8) {
      if (!_eightDigitLimitReached) {
        _eightDigitLimitReached = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo de 8 dígitos alcanzado')),
        );
      }
      return;
    } else {
      _eightDigitLimitReached = false;
    }

    // Se añade el nuevo dígito y se formatea
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
    _stopListening(); // Detener la escucha antes de cambiar de pantalla
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _onContinuePressed() async {
    if (!mounted) return;
    final documentValue = _documentController.text;
    debugPrint('Documento ingresado: $documentValue');

    _onClearAll(); // 🔥 Borra el campo ANTES de avanzar

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OptionGestureScreen(key: UniqueKey()),
      ),
    );

    // 🔥 Si deseas reanudar la escucha después de regresar:
    if (mounted) {
      _startListening();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_speech.isListening) {
      debugPrint("Reactivando escucha desde didChangeDependencies");
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
            if (mounted && !_isListening) {
              _startListening();
            }
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
            _processSpeech(result.recognizedWords.toLowerCase());
          },
          partialResults: true,
          pauseFor: const Duration(
            seconds: 10,
          ), // 🔥 Esperar 10 segundos antes de pausar
          listenFor: const Duration(
            minutes: 10,
          ), // 🔥 Mantener escucha por 10 minutos
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
      if (token.contains("todo")) {
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
    }
    return "";
  }

  Widget _buildNumberButton(String digit) {
    return SizedBox(
      width: 80,
      height: 80,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.grey[700],
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
          backgroundColor: Colors.grey[700],
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _speech.cancel();
            Navigator.pop(context);
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
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
                  color: Colors.red[600],
                  onPressed: _isListening ? _stopListening : _startListening,
                ),
                // Información para el usuario:
                const SizedBox(height: 20),
                const Text(
                  'Puedes ingresar los números hablando y confirmar con la palabra "continuar".',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                Container(
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
                const SizedBox(height: 40),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 30,
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: _onContinuePressed,
                  child: const Text("Continuar"),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
