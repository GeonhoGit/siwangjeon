/// 앱 루트와 전역 provider (기획서 §7.2).
///
/// 이 레이어는 `domain/`의 순수 상태를 Riverpod provider로 감싸 `ui/`에 넘긴다.
/// 게임 규칙은 여기 두지 않는다. 전부 `domain/`에 있어야 한다.
library;

import 'package:flutter/material.dart';

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
      ),
      home: const Scaffold(
        body: Center(
          child: Text('시왕전'),
        ),
      ),
    );
  }
}
