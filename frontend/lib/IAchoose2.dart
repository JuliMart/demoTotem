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

          if (words.isEmpty) return;
          String lastWord = words.last;

          if (lastWord == "continuar" && !_commandExecuted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!_commandExecuted) {
                _onContinuePressed();
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

  void _onContinuePressed() {
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
          setState(() {
            _commandExecuted = false;
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
        title: const Text('Atención por Caja'),
        backgroundColor: const Color(0xFFF30C0C),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset(
                  'assets/cashier.png',
                  height: 300,
                  width: 300,
                ),
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
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const Text(
                  'Presione o diga "Continuar" \npara generar su número de atención.',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _onContinuePressed,
                    style: buttonStyle(const Color(0xFFF30C0C)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text('Continuar', style: TextStyle(fontSize: 16)),
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
                color: Colors.red[600],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
