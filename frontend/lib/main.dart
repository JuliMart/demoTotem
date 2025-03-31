import 'package:flutter/material.dart';
import 'home-screen.dart';
import 'gesture-websocket_service.dart';

void main() {
  // Conectar WebSocket global al iniciar la app
  GestureWebSocketService().connect(
    url: 'ws://localhost:8000/ws-detect-gesture-image',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Santander Kiosco',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF30C0C),
          primary: const Color(0xFFF30C0C),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
