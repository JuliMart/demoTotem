import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart'; // CAMBIO AQUÍ

class GestureWebSocketService {
  static final GestureWebSocketService _instance =
      GestureWebSocketService._internal();

  factory GestureWebSocketService() => _instance;

  GestureWebSocketService._internal();

  WebSocketChannel? _channel;

  Timer? _pingTimer;
  bool _isConnected = false;

  Function(String message)? onMessage;

  void connect({required String url, Function(String)? onMessageCallback}) {
    if (_isConnected) return;

    _channel = WebSocketChannel.connect(Uri.parse(url));
    _isConnected = true;

    if (onMessageCallback != null) {
      onMessage = onMessageCallback;
    }

    _channel!.stream.listen(
      (message) {
        print("📨 Mensaje recibido: $message");
        onMessage?.call(message);
      },
      onDone: () {
        print("🔌 WebSocket desconectado.");
        _isConnected = false;
        _pingTimer?.cancel();
      },
      onError: (error) {
        print("❌ Error WebSocket: $error");
        _isConnected = false;
        _pingTimer?.cancel();
      },
    );

    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        send(jsonEncode({"type": "ping"}));
        print("🔁 Ping enviado");
      }
    });

    print("✅ WebSocket conectado a $url");
  }

  void send(dynamic data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(data);
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    if (_channel != null) {
      _channel?.sink.close();
      print("👋 WebSocket cerrado por cliente.");
    }
    _isConnected = false;
  }

  bool get isConnected => _isConnected;
}
