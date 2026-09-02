import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:voycontigo/core/router/app_router.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:voycontigo/core/services/notification_service.dart';
import 'package:voycontigo/features/trips/presentation/providers/trip_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización de Firebase conectada al proyecto
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configurar persistencia offline
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Inicializar Variables de Entorno
  await dotenv.load(fileName: ".env");

  // Inicializar Notificaciones (FCM & Local)
  await NotificationService().initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final currentMode = ref.watch(boardModeProvider);

    return MaterialApp.router(
      title: 'VoyContigo',
      theme: AppTheme.getTheme(currentMode),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
