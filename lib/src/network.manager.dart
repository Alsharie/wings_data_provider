import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class WingsNetworkManager {
  final StreamController<bool> _networkChange = StreamController.broadcast();

  /// event handler functions are called.
  void onNetworkChange(
    Function(bool)? onData, {
    Function? onError,
    Function()? onDone,
    bool? cancelOnError,
  }) {
    _singleton!._networkChange.stream.listen(
      onData,
      cancelOnError: cancelOnError,
      onDone: onDone,
      onError: onError,
    );
  }

  factory WingsNetworkManager() {
    if (_singleton == null) {
      _singleton = WingsNetworkManager._();
      _singleton!._checker();
      _singleton!._connectivity.onConnectivityChanged.listen(
        _singleton!._updateState,
      );
    }
    return _singleton!;
  }

  WingsNetworkManager._();

  static WingsNetworkManager? _singleton;

  final Connectivity _connectivity = Connectivity();
  var _connectivityResult = ConnectivityResult.none;

  bool _hasConnection = false;

  final _connectionChecker = InternetConnectionChecker();

  bool get hasConnection {
    return _hasConnection;
  }

  _checker() async {
    try {
      await _updateState(await _connectivity.checkConnectivity());
    } catch (exception) {
      log(exception.toString());
      _hasConnection = false;
    }
    _connectionChecker.onStatusChange.listen((event) {
      if (_connectivityResult == ConnectivityResult.none) return;

      _hasConnection = event == InternetConnectionStatus.connected;

      log(_hasConnection.toString(), name: 'connection listener');
    });
  }

  Future<void> _updateState(ConnectivityResult result) async {
    _connectivityResult = result;
    if (_connectivityResult != ConnectivityResult.none) {
      _hasConnection = await _connectionChecker.hasConnection;
    } else {
      _hasConnection = false;
    }
    log('Has connection: $_hasConnection', name: 'WingsNetwork');
    _networkChange.add(_hasConnection);
  }
}
