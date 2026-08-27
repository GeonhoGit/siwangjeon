import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/run_controller.dart';
import 'data/card_content_loader.dart';
import 'data/run_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 화면 전용 (기획서 §5.1).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final storage = FileRunStorage();
  final content = await loadM1RunContent();
  final restored = await RunController.loadStoredRun(
    storage: storage,
    content: content,
  );

  runApp(
    ProviderScope(
      overrides: [
        runStorageProvider.overrideWithValue(storage),
        runContentProvider.overrideWithValue(content),
        runInitialStateProvider.overrideWithValue(restored),
      ],
      child: const SiwangjeonApp(),
    ),
  );
}
