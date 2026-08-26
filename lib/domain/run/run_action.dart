/// 런 액션과 저장용 전투 하위 로그 (기획서 §2.3, §7.4).
///
/// 런의 바깥 흐름과 전투의 안쪽 규칙은 서로 다른 엔진이 맡는다. 전투 카드를
/// 런 액션의 하위 클래스로 넓히면 런 엔진이 손패·대상 같은 전투 규칙을 알아야
/// 한다. 대신 이동은 [MoveToNode]로 평평하게 기록하고, 전투는
/// [CombatNodeLog] 안에 해당 노드의 [CombatAction] 열을 넣는다.
///
/// 따라서 저장 형태는 계속 `{seed, characterId, actionLog}` 하나이며, 예를
/// 들면 `MoveToNode(3)` 뒤에 `CombatNodeLog(3, [...])`가 온다. 모든 필드는
/// 숫자·문자열·다른 직렬화 가능 액션 값뿐이라 객체 참조나 런타임 상태를 담지
/// 않는다. 현재 단계는 이동만 실행하며, 전투 하위 로그는 다음 단계에서
/// 기존 전투 엔진의 턴 단위 저장을 붙일 자리다.
library;

import '../model/combat_action.dart';

sealed class RunAction {
  const RunAction();
}

/// 저승길의 다음 노드로 들어간다.
final class MoveToNode extends RunAction {
  const MoveToNode({required this.nodeId});

  /// 생성된 맵 안에서 안정적인 노드 식별자. 객체 참조를 저장하지 않는다.
  final int nodeId;
}

/// 한 전투 노드에서 일어난 전투 액션 전체.
///
/// 이 값은 전투 결과가 아니라 입력만 저장한다. 재생할 때는 노드의 전투를
/// 같은 시드에서 시작한 뒤 [actions]를 기존 전투 엔진에 순서대로 적용한다.
final class CombatNodeLog extends RunAction {
  CombatNodeLog({required this.nodeId, required List<CombatAction> actions})
    : actions = List.unmodifiable(actions);

  /// 이 하위 로그가 속한 전투·정예전·보스 노드의 식별자.
  final int nodeId;

  /// 해당 노드에서 턴 단위로 저장할 전투 입력.
  final List<CombatAction> actions;
}
