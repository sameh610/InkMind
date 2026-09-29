import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/storage/repository_native.dart'
    if (dart.library.js_interop) 'core/storage/repository_web.dart';
import 'features/notebook/controller.dart';
import 'features/subscriptions/subscriptions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    WidgetsBinding.instance.ensureSemantics();
  }
  debugPrint('InkMind • Paper you can think with.');
  debugPrint(
    'Phone preview: flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080',
  );
  debugPrint(
    'Run ipconfig, then open http://<PC-LAN-IP>:8080 on your phone (same Wi-Fi).',
  );
  final controller = InkMindController(
    createRepository(),
    subscription: const bool.fromEnvironment('REVENUECAT_ENABLED')
        ? RevenueCatSubscriptionService()
        : DemoSubscriptionService(),
  );
  runApp(InkMindApp(controller: controller));
}
