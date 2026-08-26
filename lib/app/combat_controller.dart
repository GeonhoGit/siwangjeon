/// 전투 provider (기획서 §7.2).
///
/// 이 레이어가 하는 일은 딱 하나다 — `domain/`의 순수 함수를 Riverpod 상태에
/// 얹어 `ui/`에 넘긴다. **게임 규칙은 여기 한 줄도 없다.** 규칙이 조금이라도
/// 새어 나오면 §8.2의 CLI 시뮬레이터가 UI 없이 돌 때 다른 게임이 되어 버린다.
///
/// 그래서 이 파일에서 하는 판단은 "액션을 언제 엔진에 넘길 것인가"뿐이고,
/// "그 액션이 합법인가"는 [legalActions]에게 묻는다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/m0_content.dart';
import '../domain/combat/combat_engine.dart';
import '../domain/model/combat_action.dart';
import '../domain/model/combat_state.dart';
import '../domain/model/game_event.dart';

/// 화면이 보고 있는 전투 한 판.
class CombatSession {
  const CombatSession({
    required this.seed,
    required this.state,
    required this.lastEvents,
    required this.actionLog,
  });

  /// 이 전투의 시드. 버그를 만나면 이 숫자만 있으면 재현된다 (§7.4).
  final int seed;

  final CombatState state;

  /// 직전 액션이 만들어 낸 이벤트. UI는 이것만 재생한다 (§7.2).
  final List<GameEvent> lastEvents;

  /// 지금까지의 액션 전부. 저장 파일의 실체가 될 목록이다 (§7.4).
  ///
  /// M0에서는 저장하지 않지만 지금부터 쌓아 둔다. 나중에 붙이려면
  /// 액션이 어디서 만들어지는지를 다시 찾아다녀야 한다.
  final List<CombatAction> actionLog;
}

class CombatController extends Notifier<CombatSession> {
  @override
  CombatSession build() => _newRun(DateTime.now().millisecondsSinceEpoch);

  static CombatSession _newRun(int seed) {
    final result = beginCombat(
      seed: seed,
      hp: startingHp,
      maxHp: startingHp,
      deck: starterDeck,
      enemies: defaultEncounter(),
    );

    return CombatSession(
      seed: seed,
      state: result.state,
      lastEvents: result.events,
      actionLog: const [],
    );
  }

  void _dispatch(CombatAction action) {
    final session = state;
    if (session.state.isOver) return;

    final result = applyAction(session.state, action);

    state = CombatSession(
      seed: session.seed,
      state: result.state,
      lastEvents: result.events,
      actionLog: [...session.actionLog, action],
    );
  }

  /// 손패의 카드를 낸다. 합법이 아니면 아무 일도 하지 않는다.
  ///
  /// 화면이 이미 [legalActions]로 걸러 주지만, 탭 두 번이 겹치는 순간처럼
  /// 화면이 한 프레임 뒤처진 상태에서 들어오는 액션이 있다. 그것 때문에
  /// 엔진이 던지게 두면 안 된다.
  void play(int handIndex, {int? targetIndex}) {
    final action = PlayCard(handIndex: handIndex, targetIndex: targetIndex);
    if (!_isLegal(action)) return;
    _dispatch(action);
  }

  void endTurn() => _dispatch(const EndTurn());

  /// 새 전투. 시드를 넘기면 그 판을 그대로 다시 볼 수 있다 (§7.4).
  void restart({int? seed}) {
    state = _newRun(seed ?? DateTime.now().millisecondsSinceEpoch);
  }

  bool _isLegal(PlayCard action) {
    return legalActions(state.state).whereType<PlayCard>().any(
      (a) =>
          a.handIndex == action.handIndex &&
          a.targetIndex == action.targetIndex,
    );
  }
}

final combatControllerProvider =
    NotifierProvider<CombatController, CombatSession>(CombatController.new);
