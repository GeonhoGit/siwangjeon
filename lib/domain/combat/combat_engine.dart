/// 전투 엔진 (기획서 §7.2).
///
/// 계약은 단 하나다 — **순수 함수**여야 한다.
///
/// ```
/// (CombatState, CombatAction) → (CombatState, List<GameEvent>)
/// ```
///
/// 이 계약이 지켜지는 동안에만 다음이 가능하다.
/// - UI 없이 유닛 테스트 수천 개를 돌린다
/// - 밸런스 시뮬레이터가 CLI에서 10만 런을 자동 플레이한다 (§8.2)
/// - 애니메이션은 반환된 이벤트 목록을 재생만 한다
///
/// 그래서 이 파일에는 난수·시계·파일 접근·전역 상태가 들어가면 안 된다.
/// 난수가 필요하면 [CombatState]가 들고 있는 명시적 RNG 스트림에서 뽑는다 (§7.4).
library;

import '../model/combat_action.dart';
import '../model/combat_state.dart';
import '../model/game_event.dart';

/// 엔진 1회 적용의 결과.
class CombatResult {
  const CombatResult(this.state, this.events);

  final CombatState state;
  final List<GameEvent> events;
}

/// 액션 하나를 적용해 다음 상태와 그 과정에서 일어난 이벤트를 돌려준다.
CombatResult applyAction(CombatState state, CombatAction action) {
  // M0에서 구현한다. 지금은 계약만 고정해 둔다.
  throw UnimplementedError('전투 엔진은 M0에서 구현한다 (기획서 §8)');
}
