/// 앱 시작 경계가 만든 M1 런 콘텐츠 주입점이다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/run/run_content.dart';

/// JSON은 비동기로 읽으므로 main이 검증한 결과를 이 provider에 주입한다.
/// 기본값을 별도 Dart 카드 상수로 두면 JSON 단일 출처가 다시 깨진다.
final runContentProvider = Provider<RunContent>((ref) {
  throw StateError('M1 런 콘텐츠는 앱 시작 시 JSON 로더 결과를 주입해야 한다');
});
