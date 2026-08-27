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

/// 전투 보상에서 카드 하나를 덱에 넣는다.
///
/// 후보 배열의 위치 대신 [cardId]를 기록한다. 카드 보상 풀의 순서나 구성은
/// 콘텐츠 갱신에서 바뀔 수 있지만, §7.3의 콘텐츠 id는 같은 카드의 식별자로
/// 유지되므로 과거 액션 로그가 다른 카드를 가리키지 않는다.
final class ChooseCardReward extends RunAction {
  const ChooseCardReward({required this.nodeId, required this.cardId});

  /// 보상을 낸 전투 노드. 현재 대기 중인 보상과 로그를 대조한다.
  final int nodeId;

  /// 선택한 카드 정의의 안정적인 콘텐츠 id.
  final String cardId;
}

/// 정예 유물 보상 후보 하나를 선택한다.
final class ChooseRelicReward extends RunAction {
  const ChooseRelicReward({required this.nodeId, required this.relicId});

  final int nodeId;
  final String relicId;
}

/// 상점 상품 한 장을 산다. 상품 후보 자체는 노드별 reward 시드에서 다시 만들고,
/// 로그에는 선택한 콘텐츠 id만 남긴다.
final class BuyShopCard extends RunAction {
  const BuyShopCard({required this.nodeId, required this.cardId});

  final int nodeId;
  final String cardId;
}

/// 상점 비용을 내고 덱의 한 카드 인스턴스를 제거한다.
///
/// 카드 id만으로는 「타격」처럼 중복된 카드를 구별할 수 없고, 덱 인덱스는 앞선
/// 로그가 바뀌면 다른 카드를 가리킬 수 있다. 따라서 시작 덱 슬롯·보상 노드·상점
/// 상품에서 결정론적으로 만든 [cardInstanceId]를 기록한다. 이 값은 재생 중인 덱
/// 구성 순서와 무관하게 같은 물리적 카드 한 장을 가리킨다.
final class RemoveShopCard extends RunAction {
  const RemoveShopCard({required this.nodeId, required this.cardInstanceId});

  final int nodeId;
  final String cardInstanceId;
}

/// 상점에서 더 사거나 제거하지 않고 선택을 끝낸다.
///
/// 상점은 여러 거래를 허용하므로 이 액션이 있어야 선택을 마친 뒤에만 이동할 수
/// 있다. 종료도 action log에 남겨 재생 시 같은 거래 경계를 복원한다.
final class LeaveShop extends RunAction {
  const LeaveShop({required this.nodeId});

  final int nodeId;
}

/// 야장의 세 선택지.
///
/// §2.1은 휴식·강화를, §3.3은 참회를 각각 야장의 수단으로 적는다. 둘 중 하나를
/// 빼면 기획서의 다른 줄을 깨므로, M1은 세 선택지를 함께 두기로 해석한다.
/// enum은 저장할 때 문자열 이름으로 바뀐다.
enum WildCampChoice { rest, repent, enhance }

/// 야장에서 휴식 또는 참회를 고른다.
final class ChooseWildCampOption extends RunAction {
  const ChooseWildCampOption({required this.nodeId, required this.choice});

  final int nodeId;
  final WildCampChoice choice;
}

/// 야장에서 강화할 덱 카드 한 장을 확정한다.
///
/// `cardId`는 중복 「타격」을 구분하지 못한다. 상점 제거와 같은 결정론적
/// [cardInstanceId]를 기록하면 저장은 계속 `{seed, characterId, actionLog}`뿐이고,
/// 재생 중에도 정확히 그 한 장만 강화할 수 있다.
final class EnhanceWildCampCard extends RunAction {
  const EnhanceWildCampCard({
    required this.nodeId,
    required this.cardInstanceId,
  });

  final int nodeId;
  final String cardInstanceId;
}

/// 노드별로 다시 뽑은 사건의 선택지 하나를 고른다.
///
/// 사건 종류·선택지 목록은 저장하지 않고, [nodeId]의 reward 시드에서 복원한다.
/// 그래서 로그에는 사건 안에서 실제로 고른 [choiceId]만 남는다.
final class ChooseEventOption extends RunAction {
  const ChooseEventOption({required this.nodeId, required this.choiceId});

  final int nodeId;
  final String choiceId;
}
