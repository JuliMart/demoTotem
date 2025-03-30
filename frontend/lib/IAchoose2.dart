import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'home-screen.dart';

class IAchoose2 extends StatefulWidget {
  const IAchoose2({super.key});

  @override
  State<IAchoose2> createState() => _IAchoose2State();
}

class _IAchoose2State extends State<IAchoose2> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  int? _ticketNumber;
  bool _commandExecuted = false;
  int _retryCount = 0;
  static const int _maxRetries = 5;

  @override
  void initState() {
    super.initState();
    _ticketNumber = null;
    _speech = stt.SpeechToText();
    _commandExecuted = false;
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
        if ((status == "done" || status == "notListening") && mounted) {
          Future.delayed(const Duration(seconds: 1), () {
            if (!_commandExecuted) _startListening();
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
          if (words.isEmpty) return;

          // Si se detecta "continuar" (exactamente) vía voz, se ejecuta el comando
          if (words.any((word) => word == "continuar") && !_commandExecuted) {
            _onContinuePressed();
          }
        },
      );
    }
  }

  void _stopListening() {
    _speech.cancel();
    setState(() => _isListening = false);
  }

  void _onContinuePressed() {
    _stopListening();

    setState(() {
      _ticketNumber = 100 + (DateTime.now().millisecondsSinceEpoch % 900);
      _commandExecuted = true;
    });

    // Se muestra el ticket por 4 segundos y luego se navega a HomeScreen.
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        ).then((_) {
          // Al volver, reseteamos el flujo
          setState(() {
            _commandExecuted = false;
            _ticketNumber = null;
          });
        });
      }
    });
  }

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
        title: const Text('Atención por Caja'),
        backgroundColor: const Color(0xFFF30C0C),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Imagen grande (cajero)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset('assets/cashier.png', height: 400),
              ),
              const SizedBox(height: 40),
              if (_ticketNumber != null) ...[
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
                  'Presione o diga "Continuar" \npara generar su número de atención.',
                  style: TextStyle(fontSize: 30),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botón "Continuar"
                  FilledButton(
                    style: buttonStyle(const Color(0xFFF30C0C)),
                    onPressed: _onContinuePressed,
                    child: const Text("Continuar"),
                  ),
                  const SizedBox(width: 20),
                  // Botón "Volver"
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
