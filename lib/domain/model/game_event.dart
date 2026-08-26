/// 전투 엔진이 뱉는 이벤트 (기획서 §7.2).
///
/// UI는 상태를 직접 해석하지 않고 이 이벤트 목록을 **재생**하기만 한다.
/// 덕분에 애니메이션 코드가 전투 규칙을 알 필요가 없다.
library;

sealed class GameEvent {
  const GameEvent();
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

final class KarmaGained extends GameEvent {
  const KarmaGained(this.amount);

  final int amount;
}

final class TurnEnded extends GameEvent {
  const TurnEnded(this.turn);

  final int turn;
}
