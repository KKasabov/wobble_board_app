import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue/flutter_blue.dart';

import 'wobbly_data.dart';

const int SCAN_CONNECT_TIMEOUT = 6;

enum AccAxis { X, Y }

class BleConnectionUtils {
  static final BleConnectionUtils _instance = BleConnectionUtils._internal();
  static BleConnectionUtils get instance => _instance;

  BleConnectionUtils._internal() {
    _flutterBlue = FlutterBlue.instance;
  }

  ByteData _buffer;
  FlutterBlue _flutterBlue;
  BluetoothDevice _wobbly;
  BluetoothCharacteristic _wobblyChar;
  StreamSubscription _wobblyDataSubscription;


  Stream<BluetoothDeviceState> connectToWobbly() {
    return _flutterBlue.connect(_wobbly,
        timeout: Duration(seconds: SCAN_CONNECT_TIMEOUT));
  }

  Future<bool> discoverWobbly() async {
    _wobbly = (await _flutterBlue.scan(
            timeout: const Duration(seconds: SCAN_CONNECT_TIMEOUT),
            withServices: [Guid(SERVICE_UUID)]).firstWhere((scanR) {
      return scanR.device.name == DEVICE_NAME;
    }, orElse: () => null))
        ?.device;
    return _wobbly != null;
  }

  Future<StreamSubscription<Map<AccAxis, double>>> getWobblyData() async {
    return await _discoverServicesAndChars();
  }

   Stream<BluetoothState> getBleStateStream() {
    return _flutterBlue.onStateChanged();
  }

  Future<BluetoothState> getBleCurrentState() {
    return _flutterBlue.state;
  }

  void onDisconnect() {
    _disconnect();
  }

  void onDispose() {

  }

  void onInitState() {}

  void _disconnect() {
    _wobbly = null;
  }

  Future<StreamSubscription<Map<AccAxis, double>>> _discoverServicesAndChars() async {
    if(_wobblyDataSubscription != null) {
      return _wobblyDataSubscription;
    }
    _wobblyChar = (await _wobbly.discoverServices())
        .firstWhere((s) {
          return s.uuid.toString() == SERVICE_UUID;
        })
        .characteristics
        .firstWhere((ch) {
          return ch.uuid.toString() == CHAR_UUID;
        });

    await _wobbly.setNotifyValue(_wobblyChar, true);
    _wobblyDataSubscription = _getXyStream(_wobbly.onValueChanged(_wobblyChar)).listen(null);
    return _wobblyDataSubscription;
  }

  Stream<Map<AccAxis, double>> _getXyStream(Stream<List<int>> source) async* {
    await for (var list in source) {
      _buffer = ByteData.view(Uint8List.fromList(list).buffer);
      yield {
        AccAxis.X: _normalize(_buffer.getFloat32(1, Endian.little)),
        AccAxis.Y: _normalize(_buffer.getFloat32(5, Endian.little))
      };
    }
  }

  double _normalize(double n) {
    return double.parse(n.toStringAsFixed(2));
  }
}
