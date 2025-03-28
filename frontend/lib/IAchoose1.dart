import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'home-screen.dart';

class IAchoose1 extends StatefulWidget {
  const IAchoose1({super.key});

  @override
  State<IAchoose1> createState() => _IAchoose1State();
}

class _IAchoose1State extends State<IAchoose1> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _documentEntered = false; // Para evitar errores
  int? _ticketNumber;
  bool _commandExecuted = false; // Bandera para evitar múltiples ejecuciones
  int _retryCount = 0;
  static const int _maxRetries = 5;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _commandExecuted = false;
    _documentEntered = false;
    _startListening();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _startListening() async {
    if (_speech.isListening || _retryCount >= _maxRetries) return;

    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Estado del micrófono: $status');
        if (status == "done" || status == 'notListening') {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted && !_commandExecuted) _startListening();
          });
        }
      },
      onError: (error) {
        debugPrint('Error en reconocimiento de voz: $error');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _retryCount < _maxRetries) _startListening();
        });
      },
    );

    if (available) {
      _retryCount = 0;
      setState(() => _isListening = true);

      _speech.listen(
        localeId: 'es_CL',
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 1),
        partialResults: true,
        onResult: (result) {
          final recognized = result.recognizedWords.toLowerCase().trim();
          debugPrint('Texto detectado: "$recognized"');

          List<String> words = recognized.split(RegExp(r'\s+'));

          if (_documentEntered) {
            // Bloquea números una vez ingresado
            words.removeWhere((word) => RegExp(r'^\d+$').hasMatch(word));
          }

          if (words.isEmpty) return;

          // Si reconoce algo como "finalizar", ejecuta la lógica
          if (words.any((word) => word.contains("lizar")) &&
              !_commandExecuted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!_commandExecuted) {
                _onFinishPressed();
              }
            });
          }
        },
      );
    }
  }

  void _stopListening() {
    _speech.cancel();
    setState(() => _isListening = false);
  }

  void _onFinishPressed() {
    _stopListening();

    setState(() {
      _ticketNumber = 100 + (DateTime.now().millisecondsSinceEpoch % 900);
      _commandExecuted = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        ).then((_) {
          // Al volver a esta pantalla, reseteamos el flujo
          setState(() {
            _commandExecuted = false;
            _documentEntered = false;
          });
        });
      }
    });
  }

  /// Unificamos el estilo de los botones con bordes redondeados (radio 50)
  ButtonStyle buttonStyle(Color color) {
    return FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 50),
      textStyle: const TextStyle(fontSize: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      elevation: 5,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Depósito de Cheques'),
        backgroundColor: const Color(0xFFF30C0C),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Imagen grande
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset('assets/check.png', height: 400),
              ),
              const SizedBox(height: 40),
              if (_ticketNumber != null) ...[
                // Texto grande
                const Text(
                  'Su número de atención es:',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                Text(
                  'A-$_ticketNumber',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF30C0C),
                  ),
                ),
                const SizedBox(height: 30),
              ] else ...[
                const Text(
                  'Presione o diga "Finalizar" \npara generar su número de atención.',
                  style: TextStyle(fontSize: 30),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botón "Finalizar"
                  FilledButton(
                    style: buttonStyle(const Color(0xFFF30C0C)),
                    onPressed: _onFinishPressed,
                    child: const Text("Finalizar"),
                  ),
                  const SizedBox(width: 20),
                  // Botón "Volver" con el mismo estilo
                  FilledButton(
                    style: buttonStyle(Colors.grey),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Volver"),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Ícono micrófono
              Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                size: 50,
                color: const Color(0xFFF30C0C),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
