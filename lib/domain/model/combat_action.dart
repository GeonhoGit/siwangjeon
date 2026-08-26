/// 플레이어가 전투 중 취할 수 있는 액션 (기획서 §7.2, §7.4).
///
/// 액션은 저장 파일에 그대로 기록되어 런 재현에 쓰인다.
/// 따라서 **직렬화 가능한 값만** 담는다. 객체 참조를 넣지 않는다.
library;

sealed class CombatAction {
  const CombatAction();
}

/// 손패의 카드를 사용한다.
final class PlayCard extends CombatAction {
  const PlayCard({required this.handIndex, this.targetIndex});

  /// 손패에서의 위치.
  final int handIndex;

  /// 대상 적의 인덱스. 대상이 없는 카드면 null.
  final int? targetIndex;
}

/// 턴을 종료한다. 남은 손패를 버리고 방어도가 소멸한다 (§3.1).
final class EndTurn extends CombatAction {
  const EndTurn();
}
