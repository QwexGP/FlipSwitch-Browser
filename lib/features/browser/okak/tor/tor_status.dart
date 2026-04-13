import 'dart:async';

import 'arti_ffi.dart';

enum TorState {
  unavailable,
  connecting,
  ready,
}

class TorStatusController {
  TorStatusController._();

  static final TorStatusController instance = TorStatusController._();

  final StreamController<TorState> _streamController =
      StreamController<TorState>.broadcast();

  Stream<TorState> get stream => _streamController.stream;

  TorState _state = TorState.unavailable;

  TorState get state => _state;

  Timer? _pollTimer;

  Future<void> start() async {
    // Try load native bridge (optional).
    final ffi = await ArtiFfi.tryLoad();
    if (ffi == null) {
      _setState(TorState.unavailable);
      return;
    }

    // Best effort: ask native to bootstrap.
    _setState(TorState.connecting);
    try {
      ffi.tryBootstrap();
    } catch (_) {}

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      final ready = ffi.tryIsReady();
      if (ready == true) {
        _setState(TorState.ready);
      } else {
        _setState(TorState.connecting);
      }
    });
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _setState(TorState s) {
    if (_state == s) return;
    _state = s;
    _streamController.add(s);
  }
}

