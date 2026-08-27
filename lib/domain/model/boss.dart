/// 시왕 심판에 쓰는 보스 콘텐츠 모델 (§3.3, §4.1).
library;

import 'enemy.dart';

/// 일반 조우와 분리된 시왕 하나의 정의.
///
/// 보스도 전투 엔진에는 [Enemy]로 들어간다. 다만 탁함 심판만이 추가하는 행동은
/// 일반 적의 규칙이 아니므로, 그 콘텐츠 경계를 [BossDef]에 둔다.
class BossDef {
  const BossDef({required this.enemy, required this.turbidExtraMove});

  final Enemy enemy;

  /// 업 50~79에서 시왕의 각 페이즈 순환에 하나씩 더하는 판결 행동.
  final EnemyMove turbidExtraMove;
}
