/// 전투 엔진이 뱉는 이벤트 (기획서 §7.2).
///
/// UI는 상태를 직접 해석하지 않고 이 이벤트 목록을 **재생**하기만 한다.
/// 덕분에 애니메이션 코드가 전투 규칙을 알 필요가 없다.
///
/// 대상은 [CombatState.playerIndex](-1)가 플레이어, 0 이상이 적 인덱스다.
library;

import 'card.dart';
import 'combat_state.dart';
import 'status.dart';

sealed class GameEvent {
  const GameEvent();
}

final class CardPlayed extends GameEvent {
  const CardPlayed(this.card);

  final CardDef card;
}

final class DamageDealt extends GameEvent {
  const DamageDealt({
    required this.targetIndex,
    required this.amount,
    required this.blocked,
  });

  final int targetIndex;

  /// 방어도를 통과해 체력에 실제로 들어간 피해.
  final int amount;

  /// 방어도가 흡수한 양.
  final int blocked;
}

final class BlockGained extends GameEvent {
  const BlockGained({required this.targetIndex, required this.amount});

  final int targetIndex;
  final int amount;
}

final class EnergyGained extends GameEvent {
  const EnergyGained(this.amount);

  final int amount;
}

/// 회복으로 실제로 늘어난 플레이어 체력.
///
/// 최대 체력에 막혀 늘지 않은 양은 포함하지 않는다. UI는 전투 상태를 다시 읽지
/// 않고 이 이벤트만 재생해 회복 연출을 만든다 (§7.2).
final class HpGained extends GameEvent {
  const HpGained(this.amount);

  final int amount;
}

final class StatusApplied extends GameEvent {
  const StatusApplied({
    required this.targetIndex,
    required this.status,
    required this.stacks,
  });

  final int targetIndex;
  final StatusId status;
  final int stacks;
}

final class KarmaGained extends GameEvent {
  const KarmaGained(this.amount);

  /// 실제로 변한 업의 부호 있는 값. 음수면 정화로 업이 줄었다는 뜻이다.
  final int amount;
}

final class CardsDrawn extends GameEvent {
  const CardsDrawn(this.cards);

  final List<CardDef> cards;
}

/// 뽑을 카드가 없어 버림더미를 섞어 되돌렸다.
final class DeckReshuffled extends GameEvent {
  const DeckReshuffled(this.count);

  final int count;
}

final class EnemyDied extends GameEvent {
  const EnemyDied(this.index);

  final int index;
}

final class TurnEnded extends GameEvent {
  const TurnEnded(this.turn);

  final int turn;
}

final class TurnStarted extends GameEvent {
  const TurnStarted(this.turn);

  final int turn;
}

final class CombatEnded extends GameEvent {
  const CombatEnded(this.outcome);

  final CombatOutcome outcome;
}
