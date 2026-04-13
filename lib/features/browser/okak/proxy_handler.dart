import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../data/models/settings_model.dart';

class ProxyHandler {
  static Future<void> apply(SettingsModel s) async {
    if (kIsWeb) return;

    // Network routing policy:
    // - Direct: clear proxy override.
    // - Bridges/Snowflake: route WebView via local SOCKS5 (Arti).
    final needsTor = s.networkMode != NetworkMode.direct;

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final supported =
            await WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE);
        if (!supported) return;

        final proxyController = ProxyController.instance();
        await proxyController.clearProxyOverride();

        if (needsTor) {
          await proxyController.setProxyOverride(
            settings: ProxySettings(
              proxyRules: [
                ProxyRule(url: 'socks5://127.0.0.1:9050'),
              ],
              bypassRules: [],
            ),
          );
        }
      } catch (_) {}
    }
  }
}

