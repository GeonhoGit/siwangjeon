/// 런 진행 상태 (기획서 §7.4).
///
/// 저장 파일은 **시드 + 액션 로그**가 전부다. 수십 KB면 충분하다.
/// 전투 결과를 저장하지 않고 재생으로 복원하기 때문에,
/// 앱이 죽어도 정확히 복구되고 버그 리포트도 시드만 있으면 재현된다.
library;

import '../model/combat_action.dart';

class RunState {
  const RunState({
    required this.seed,
    required this.characterId,
    required this.actionLog,
  });

  /// 이 런의 모든 난수가 파생되는 뿌리.
  final int seed;

  final String characterId;

  /// 지금까지의 모든 액션. 이것을 재생하면 현재 상태가 나온다.
  final List<CombatAction> actionLog;
}

/// 난수 스트림 구분 (§7.4).
///
/// 하나의 스트림을 공유하면 보상 롤 한 번이 어긋났을 때 이후 전투까지 전부
/// 밀린다. 용도별로 분리해 두면 그런 연쇄가 생기지 않는다.
enum RngStream {
  /// 카드·유물 보상 롤.
  reward,

  /// 노드 맵 생성과 적 배치.
  encounter,

  /// 전투 내부 (드로우, 적 행동 선택).
  combat,
}
