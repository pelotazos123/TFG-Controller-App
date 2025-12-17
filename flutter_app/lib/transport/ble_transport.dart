import 'package:flutter_rccontroller_app/transport/control_transport.dart';

class BluetoothTransport implements ControlTransport {
  // Aquí guardas tu objeto BluetoothDevice / connection
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    // Lógica de conexión Bluetooth 
    _connected = true;
  }

  @override
  void disconnect() {
    // Cierra conexión Bluetooth
    _connected = false;
  }

  @override
  void send({required double tx, required double ty, required double sx, required double sy}) {
    if (!_connected) return;
    final payload = '$tx,$ty,$sx,$sy'; 
  }
}
