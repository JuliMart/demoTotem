import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'IAchoose1.dart';
import 'IAchoose2.dart';
import 'IAchoose3.dart';
import 'color-detect.dart';
import 'home-screen.dart';
import 'normal-mode.dart';
import 'option-gesture-screen.dart';

class IAchoose1 extends StatefulWidget {
  const IAchoose1({super.key});

  @override
  State<IAchoose1> createState() => _IAchoose1State();
}

class _IAchoose1State extends State<IAchoose1> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _documentEntered = false;
  int? _ticketNumber;
  bool _commandExecuted = false;
  late FlutterTts _flutterTts;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  int? _waitTime;
  bool _isTtsSpeaking = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initializeSpeechAndInstructions();
  }

  @override
  void dispose() {
    _stopListening();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initializeSpeechAndInstructions() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Estado del micrófono: $status');
        if ((status == "done" || status == 'notListening') &&
            mounted &&
            !_commandExecuted &&
            !_isTtsSpeaking) {
          Future.delayed(const Duration(seconds: 1), _startListening);
        }
      },
      onError: (error) => debugPrint('Error en reconocimiento de voz: $error'),
    );

    if (!available) {
      debugPrint("Reconocimiento de voz no disponible.");
      return;
    }

    await _speech.stop();
    _isListening = false;

    await _flutterTts.setLanguage("es-AR");
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setPitch(1.0);

    _isTtsSpeaking = true;
    _flutterTts.setCompletionHandler(() {
      _isTtsSpeaking = false;
      if (!_speech.isListening && mounted && !_commandExecuted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _startListening();
        });
      }
    });

    await _flutterTts.speak(
      "Presione o diga 'Finalizar' para generar su número de atención.",
    );
  }

  void _startListening() async {
    if (_speech.isListening || _commandExecuted || _isTtsSpeaking) return;

    bool available = await _speech.initialize();
    if (available) {
      _retryCount = 0;
      setState(() => _isListening = true);

      _speech.listen(
        localeId: 'es_CL',
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 15),
        partialResults: true,
        onResult: (result) {
          final recognized = result.recognizedWords.toLowerCase().trim();
          debugPrint('Texto detectado: "$recognized"');

          List<String> words = recognized.split(RegExp(r'\s+'));

          if (_documentEntered) {
            words.removeWhere((word) => RegExp(r'^\d+\$').hasMatch(word));
          }

          if (words.isEmpty) return;

          if (words.any((word) => word.contains("lizar")) &&
              !_commandExecuted) {
            _onVoiceFinishCommand();
          }
        },
      );
    } else {
      debugPrint("No se pudo iniciar el reconocimiento de voz.");
    }
  }

  void _stopListening() {
    _speech.cancel();
    setState(() => _isListening = false);
  }

  void _onVoiceFinishCommand() {
    _speech.cancel();
    setState(() {
      _ticketNumber = 100 + (DateTime.now().millisecondsSinceEpoch % 900);
      _waitTime = Random().nextInt(10) + 1;
      _commandExecuted = true;
    });

    _flutterTts.speak(
      "Su número de atención es A-$_ticketNumber. Su tiempo de espera es de aproximadamente $_waitTime minutos.",
    );

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        ).then((_) {
          setState(() {
            _commandExecuted = false;
            _documentEntered = false;
            _ticketNumber = null;
            _waitTime = null;
          });
        });
      }
    });
  }

  void _onButtonFinishPressed() {
    _speech.cancel();
    setState(() {
      _ticketNumber = 100 + (DateTime.now().millisecondsSinceEpoch % 900);
      _waitTime = Random().nextInt(10) + 1;
      _commandExecuted = true;
    });

    _flutterTts.speak(
      "Su número de atención es A-$_ticketNumber. Su tiempo de espera es de aproximadamente $_waitTime minutos.",
    );

    Future.delayed(const Duration(seconds: 7), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        ).then((_) {
          setState(() {
            _commandExecuted = false;
            _documentEntered = false;
            _ticketNumber = null;
            _waitTime = null;
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
        title: const Text('Depósito de Cheques'),
        backgroundColor: const Color(0xFFF30C0C),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _speech.cancel();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => OptionGestureScreen()),
            );
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                iconSize: 40,
                color: const Color(0xFFF30C0C),
                onPressed: _isListening ? _stopListening : _startListening,
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.asset('assets/check.png', height: 400),
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
                if (_waitTime != null)
                  Text(
                    'Su tiempo de espera es de aproximadamente $_waitTime minutos',
                    style: const TextStyle(fontSize: 36, color: Colors.black87),
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
                  FilledButton(
                    style: buttonStyle(const Color(0xFFF30C0C)),
                    onPressed: _onButtonFinishPressed,
                    child: const Text("Finalizar"),
                  ),
                  const SizedBox(width: 20),
                  FilledButton(
                    style: buttonStyle(Colors.grey),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Volver"),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
