/// 전투 상태 (기획서 §3.1~3.3).
///
/// 이 레이어는 순수 Dart다. Flutter를 import 하지 않는다.
/// 이 규칙은 `test/architecture_test.dart`가 강제한다 (기획서 §7.2).
library;

/// 한 전투의 전체 상태. **불변**이며, 엔진은 변경 대신 새 인스턴스를 반환한다.
///
/// 골격 단계라 필드는 §3.2의 자원만 담고 있다.
/// 손패·덱·버림더미·적 목록은 M0 전투 엔진 구현 시 추가한다.
class CombatState {
  const CombatState({
    required this.turn,
    required this.hp,
    required this.maxHp,
    required this.energy,
    required this.block,
    required this.karma,
  });

  /// 현재 턴. 1부터 센다.
  final int turn;

  /// 체력(魂). 런 전체에 지속되며 회복 수단이 희소하다.
  final int hp;
  final int maxHp;

  /// 기력(氣). 매 턴 3으로 회복되고, 카드 사용에 소모된다.
  final int energy;

  /// 방어(魄). 턴 종료 시 소멸한다.
  final int block;

  /// 업(業). 0~100, 런 전체에 지속된다. 전투 중에는 페널티가 없고
  /// 심판(보스전) 시작 시에만 청구된다 (§3.3).
  final int karma;

  CombatState copyWith({
    int? turn,
    int? hp,
    int? maxHp,
    int? energy,
    int? block,
    int? karma,
  }) {
    return CombatState(
      turn: turn ?? this.turn,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      energy: energy ?? this.energy,
      block: block ?? this.block,
      karma: karma ?? this.karma,
    );
  }
}

/// 업 구간에 따른 심판 등급 (§3.3).
enum KarmaBand {
  /// 0~19 청정 — 보스 체력 -20%, 보상 등급 하락.
  pure,

  /// 20~49 평범 — 기준값.
  ordinary,

  /// 50~79 탁함 — 보스가 추가 패턴 1개 획득, 보상 등급 상승.
  turbid,

  /// 80~100 악업 — 보스 2페이즈 즉시 진입, 최상급 유물 확정.
  wicked;

  static KarmaBand of(int karma) {
    if (karma < 20) return KarmaBand.pure;
    if (karma < 50) return KarmaBand.ordinary;
    if (karma < 80) return KarmaBand.turbid;
    return KarmaBand.wicked;
  }
}
