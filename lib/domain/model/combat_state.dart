/// 전투 상태 (기획서 §3.1~3.3).
///
/// 이 레이어는 순수 Dart다. Flutter를 import 하지 않는다.
/// 이 규칙은 `test/architecture_test.dart`가 강제한다 (기획서 §7.2).
library;

import '../rng/rng.dart';
import 'card.dart';
import 'enemy.dart';
import 'status.dart';

/// 전투가 끝난 방식.
enum CombatOutcome { victory, defeat }

/// 한 전투의 전체 상태. **불변**이며, 엔진은 변경 대신 새 인스턴스를 반환한다.
///
/// 리스트 필드는 관례상 읽기 전용으로 다룬다. 엔진은 항상 새 리스트를
/// 만들어 넣으므로 밖에서 수정할 일이 없다.
class CombatState {
  const CombatState({
    required this.turn,
    required this.hp,
    required this.maxHp,
    required this.energy,
    required this.block,
    required this.karma,
    required this.hand,
    required this.drawPile,
    required this.discardPile,
    required this.enemies,
    required this.rng,
    this.statuses = const {},
    this.outcome,
  });

  /// 이벤트에서 플레이어를 가리키는 대상 인덱스.
  ///
  /// 적은 0부터 세므로 음수 하나를 비워 두면 대상 표현이 int 하나로 끝난다.
  /// 이벤트는 UI가 재생만 하는 값이고(§7.2), 단순할수록 좋다.
  static const int playerIndex = -1;

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

  final List<CardDef> hand;
  final List<CardDef> drawPile;
  final List<CardDef> discardPile;

  final List<Enemy> enemies;

  /// 플레이어에게 걸린 상태 효과. 스택이 0이 되면 항목 자체를 지운다.
  final Map<StatusId, int> statuses;

  /// 전투 내부용 난수기 (§7.4의 [RngStream.combat]).
  final Rng rng;

  /// 전투가 끝났으면 그 결과. 진행 중이면 null.
  final CombatOutcome? outcome;

  bool get isOver => outcome != null;

  Iterable<Enemy> get livingEnemies => enemies.where((e) => e.isAlive);

  /// 현재 업이 속한 심판 등급 (§3.3).
  KarmaBand get karmaBand => KarmaBand.of(karma);

  CombatState copyWith({
    int? turn,
    int? hp,
    int? maxHp,
    int? energy,
    int? block,
    int? karma,
    List<CardDef>? hand,
    List<CardDef>? drawPile,
    List<CardDef>? discardPile,
    List<Enemy>? enemies,
    Map<StatusId, int>? statuses,
    Rng? rng,
    CombatOutcome? outcome,
  }) {
    return CombatState(
      turn: turn ?? this.turn,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      energy: energy ?? this.energy,
      block: block ?? this.block,
      karma: karma ?? this.karma,
      hand: hand ?? this.hand,
      drawPile: drawPile ?? this.drawPile,
      discardPile: discardPile ?? this.discardPile,
      enemies: enemies ?? this.enemies,
      statuses: statuses ?? this.statuses,
      rng: rng ?? this.rng,
      outcome: outcome ?? this.outcome,
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
