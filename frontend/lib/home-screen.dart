// home-screen.dart
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'normal-mode.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final WebSocketChannel _channel;
  bool isConnecting = true;

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://192.168.0.5:8000/detect-gesture'),
      );
      _channel.stream.listen(
        (message) {
          if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
          final command = message.trim().toLowerCase();
          debugPrint("Mensaje recibido: '$command'");
          if (command == "thumbs_up") {
            _simulateButtonPressIA();
          }
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

  void _simulateButtonPressIA() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pulgar arriba detectado. ¡Accediendo con IA!'),
        duration: Duration(seconds: 1),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.primary),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'BIENVENIDO!',
              style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Image.asset('assets/pngegg.png', height: 300, width: 380),
            const SizedBox(height: 20),
            if (isConnecting)
              const Center(
                child: Text(
                  'Conectando con la IA...',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            // Información minimalista para el usuario:
            const SizedBox(height: 20),
            const Text(
              'Levanta el pulgar para acceder con IA, o presiona "Continuar" para ingresar de forma normal.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 30,
                    ),
                    textStyle: const TextStyle(fontSize: 22),
                  ),
                  onPressed: _simulateButtonPressContinuar,
                  child: const Text("Continuar"),
                ),
                const SizedBox(width: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 30,
                    ),
                    textStyle: const TextStyle(fontSize: 22),
                  ),
                  onPressed: _simulateButtonPressIA,
                  icon: const Icon(Icons.smart_toy),
                  label: const Text("Acceder con IA"),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
