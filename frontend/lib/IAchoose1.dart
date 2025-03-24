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
  bool _documentEntered = false; // 🔥 Agregada para evitar errores
  int? _ticketNumber;
  bool _commandExecuted = false; // Bandera para evitar múltiples ejecuciones

  int _retryCount = 0;
  static const int _maxRetries = 5; // Corrección de constante

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _commandExecuted =
        false; // 🔥 Resetear para evitar activaciones incorrectas
    _documentEntered = false; // 🔥 Permitir ingreso de un nuevo documento
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
            words.removeWhere(
              (word) => RegExp(r'^\d+$').hasMatch(word),
            ); // 🔥 Bloquea números
          }

          if (words.isEmpty) return;

          // 🔥 Si la palabra reconocida contiene "lizar", ejecuta el mismo flujo del botón "Finalizar"
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
          // 🔥 Cuando vuelva a esta pantalla, reseteamos el flujo
          setState(() {
            _commandExecuted = false;
            _documentEntered = false;
          });
        });
      }
    });
  }

  ButtonStyle buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset('assets/check.png', height: 150),
              ),
              const SizedBox(height: 40),
              if (_ticketNumber != null) ...[
                const Text(
                  'Su número de atención es:',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'A-$_ticketNumber',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF30C0C),
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const Text(
                  'Presione o diga "Finalizar" \npara generar su número de atención.',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔥 Botón ahora es "Finalizar" en lugar de "Continuar"
                  ElevatedButton(
                    onPressed: _onFinishPressed,
                    style: buttonStyle(const Color(0xFFF30C0C)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text('Finalizar', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: buttonStyle(Colors.grey),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text('Volver', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                size: 40,
                color: Color(0xFFF30C0C),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
