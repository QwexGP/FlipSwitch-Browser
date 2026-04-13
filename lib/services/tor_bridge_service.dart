import '../data/models/settings_model.dart';
import '../features/browser/okak/tor/arti_ffi.dart';

/// Bridge control for Arti.
///
/// This is "best-effort": it calls optional rust symbols if present.
class TorBridgeService {
  static final TorBridgeService instance = TorBridgeService._();

  TorBridgeService._();

  Future<void> applyNetworkSettings(SettingsModel s) async {
    final ffi = await ArtiFfi.tryLoad();
    if (ffi == null) return;

    // If rust_core doesn't expose configuration symbols yet, these calls are no-ops.
    switch (s.networkMode) {
      case NetworkMode.direct:
        ffi.trySetTorModeDirect();
        break;
      case NetworkMode.bridgesObfs4:
        ffi.trySetTorModeBridgesObfs4(s.bridgesObfs4Lines);
        break;
      case NetworkMode.snowflake:
        ffi.trySetTorModeSnowflake();
        break;
    }

    // Ensure tor starts.
    ffi.tryBootstrap();
  }
}

