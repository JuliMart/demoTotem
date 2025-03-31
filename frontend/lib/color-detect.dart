import 'package:flutter/material.dart';
import 'package:flutter_app/age-recognizer.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'normal-mode.dart';
import 'home-screen.dart';
import 'option-gesture-screen.dart';
import 'age-recognizer.dart';

class ColorDetect extends StatefulWidget {
  const ColorDetect({super.key});

  @override
  State<ColorDetect> createState() => _ColorDetectState();
}

class _ColorDetectState extends State<ColorDetect> {
  final WebSocketChannel clothingChannel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8000/detect-clothing'),
  );

  String _getMessageForColor(Color color) {
    final red = color.red;
    final green = color.green;
    final blue = color.blue;

    if (red >= 200 && green >= 230 && blue >= 230) {
      return "Un nuevo comienzo está por llegar. Prepárate para oportunidades inesperadas.";
    } else if (red <= 40 && green <= 40 && blue <= 40) {
      return "La determinación te llevará lejos. Mantén tu enfoque y alcanzarás el éxito.";
    } else if ((red - green).abs() < 30 &&
        (red - blue).abs() < 30 &&
        (green - blue).abs() < 30) {
      return "El equilibrio en tu vida traerá tranquilidad y estabilidad.";
    } else if (red > 80 && (red > green + 30) && (red > blue + 30)) {
      return "Un momento de pasión y aventura está por llegar. ¡Aprovecha la oportunidad!";
    } else if (green > red && green > blue) {
      return "El crecimiento personal y profesional se avecina. Confía en ti mismo.";
    } else if (blue > red && blue > green) {
      return "Un periodo de calma y reflexión te ayudará a tomar mejores decisiones.";
    } else {
      return "El destino tiene una sorpresa especial para ti. ¡Mantente atento!";
    }
  }

  @override
  void dispose() {
    clothingChannel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OptionGestureScreen(),
              ),
            );
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: StreamBuilder(
            stream: clothingChannel.stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasData) {
                final colorStr = snapshot.data.toString().trim();
                Color displayColor = Colors.grey;
                try {
                  if (colorStr.startsWith('#') && colorStr.length == 7) {
                    displayColor = Color(
                      int.parse("0xff" + colorStr.substring(1)),
                    );
                  }
                } catch (e) {
                  debugPrint("Error al convertir color: $e");
                  displayColor = Colors.grey;
                }

                String message = _getMessageForColor(displayColor);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Color de Ropa Detectado:',
                      style: TextStyle(fontSize: 20, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    CircleAvatar(radius: 80, backgroundColor: displayColor),
                    const SizedBox(height: 10),
                    Text(
                      colorStr,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Tu mensaje de la fortuna:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed:
                          () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AgeRecognizerScreen(),
                            ),
                          ),

                      child: const Text("Volver"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                );
              }
              return const CircularProgressIndicator();
            },
          ),
        ),
      ),
    );
  }
}
