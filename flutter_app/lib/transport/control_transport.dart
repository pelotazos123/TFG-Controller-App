abstract class ControlTransport {
  bool get isConnected;
  Future<void> connect();
  void disconnect();
  void send({required double tx, required double ty, required double sx, required double sy});
}
