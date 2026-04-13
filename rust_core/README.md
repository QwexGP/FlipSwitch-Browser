## rust_core

Папка для Rust-ядра (Arti Tor Client) и FFI-экспорта в Dart.

Ожидается, что библиотека будет собираться в динамическую:
- Linux: `librust_core.so`
- macOS: `librust_core.dylib`
- Windows: `rust_core.dll`

Dart-обертка лежит в `lib/features/browser/okak/tor/arti_ffi.dart`.

