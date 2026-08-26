import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/run_controller.dart';
import 'data/m0_content.dart';
import 'data/run_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 화면 전용 (기획서 §5.1).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final storage = FileRunStorage();
  final restored = await RunController.loadStoredRun(
    storage: storage,
    content: m0RunContent(),
  );

  runApp(
    ProviderScope(
      overrides: [
        runStorageProvider.overrideWithValue(storage),
        runInitialStateProvider.overrideWithValue(restored),
      ],
      child: const SiwangjeonApp(),
    ),
  );
}
