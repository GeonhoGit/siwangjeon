/// 앱 루트와 전역 provider (기획서 §7.2).
///
/// 이 레이어는 `domain/`의 순수 상태를 Riverpod provider로 감싸 `ui/`에 넘긴다.
/// 게임 규칙은 여기 두지 않는다. 전부 `domain/`에 있어야 한다.
library;

import 'package:flutter/material.dart';

import '../ui/combat_screen.dart';

class SiwangjeonApp extends StatelessWidget {
  const SiwangjeonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '시왕전',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          // 시왕도의 주 색인 주홍(朱紅).
          seedColor: const Color(0xFFB2332B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF161114),
      ),
      // M0에는 화면이 이것 하나뿐이다. 지도·보상·상점은 M1의 일이다(§8).
      home: const CombatScreen(),
    );
  }
}
