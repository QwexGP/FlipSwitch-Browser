import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Minimal FFI bridge to rust_core (Arti).
///
/// This file is intentionally defensive: the app must compile and run
/// even if the native library is not present yet.
class ArtiFfi {
  ArtiFfi._(this._lib);

  final DynamicLibrary _lib;

  static ArtiFfi? _instance;

  static ArtiFfi? get instance => _instance;

  static Future<ArtiFfi?> tryLoad() async {
    if (_instance != null) return _instance;
    try {
      final lib = _open();
      _instance = ArtiFfi._(lib);
      return _instance;
    } catch (_) {
      return null;
    }
  }

  static DynamicLibrary _open() {
    // iOS static-link: symbols are in the main process image.
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    // Android/macOS/Linux/Windows: dynamic library beside the executable/app.
    return DynamicLibrary.open(_defaultLibName());
  }

  static String _defaultLibName() {
    if (Platform.isMacOS) return 'librust_core.dylib';
    if (Platform.isWindows) return 'rust_core.dll';
    return 'librust_core.so';
  }

  /// Optional rust symbol: `arti_is_ready() -> u8` (0/1).
  /// If absent, returns null.
  bool? tryIsReady() {
    try {
      // Prefer the new API, fallback to legacy.
      try {
        final fn = _lib.lookupFunction<Uint8 Function(), int Function()>('is_tor_ready');
        return fn() != 0;
      } catch (_) {
        final fn = _lib.lookupFunction<Uint8 Function(), int Function()>('arti_is_ready');
        return fn() != 0;
      }
    } catch (_) {
      return null;
    }
  }

  /// Optional rust symbol: `arti_bootstrap() -> u8` (0/1).
  bool? tryBootstrap() {
    try {
      final fn = _lib.lookupFunction<Uint8 Function(), int Function()>('arti_bootstrap');
      return fn() != 0;
    } catch (_) {
      return null;
    }
  }

  /// Optional rust symbol: `tor_mode_direct() -> u8`
  bool? trySetTorModeDirect() {
    try {
      final fn = _lib.lookupFunction<Uint8 Function(), int Function()>('tor_mode_direct');
      return fn() != 0;
    } catch (_) {
      return null;
    }
  }

  /// Optional rust symbol: `tor_mode_snowflake() -> u8`
  bool? trySetTorModeSnowflake() {
    try {
      final fn = _lib.lookupFunction<Uint8 Function(), int Function()>('tor_mode_snowflake');
      return fn() != 0;
    } catch (_) {
      return null;
    }
  }

  /// Optional rust symbol: `tor_mode_bridges_obfs4(const char*) -> u8`
  bool? trySetTorModeBridgesObfs4(String lines) {
    try {
      final fn = _lib.lookupFunction<Uint8 Function(Pointer<Utf8>), int Function(Pointer<Utf8>)>(
        'tor_mode_bridges_obfs4',
      );
      final ptr = lines.toNativeUtf8();
      try {
        return fn(ptr) != 0;
      } finally {
        malloc.free(ptr);
      }
    } catch (_) {
      return null;
    }
  }
}

