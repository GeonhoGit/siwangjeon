/// 런 진행 상태 (기획서 §7.4).
///
/// 저장 파일은 **시드 + 액션 로그**가 전부다. 수십 KB면 충분하다.
/// 전투 결과를 저장하지 않고 재생으로 복원하기 때문에,
/// 앱이 죽어도 정확히 복구되고 버그 리포트도 시드만 있으면 재현된다.
library;

import 'run_action.dart';

// RngStream은 rng/rng.dart로 옮겼다. 스트림 구분은 난수기의 일부이고,
// 런 상태가 아니라 난수 구현과 함께 읽혀야 이해된다.
export '../rng/rng.dart' show RngStream;

class RunState {
  const RunState({
    required this.seed,
    required this.characterId,
    required this.actionLog,
  });

  /// 이 런의 모든 난수가 파생되는 뿌리.
  final int seed;

  final String characterId;

  /// 지금까지의 모든 런 액션. 이것을 재생하면 현재 상태가 나온다.
  ///
  /// 전투 안의 턴 로그와 노드 이동은 둘 다 저장돼야 하지만, 전투 규칙은
  /// `combat/`에 남아야 한다. 그래서 [RunAction]은 이동을 평평하게 기록하고,
  /// 전투 로그는 노드에 귀속된 하위 로그로 보관한다. 저장 파일은 계속
  /// `{seed, characterId, actionLog}`뿐이며, 결과·맵·난수 상태는 넣지 않는다.
  final List<RunAction> actionLog;
}
