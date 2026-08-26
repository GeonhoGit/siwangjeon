/// 런 진행 상태를 UI에 전달하는 Riverpod 어댑터 (§7.2, §7.4).
///
/// 이 파일은 `domain/run`의 재생 결과와 합법 액션을 그대로 노출한다. 이동,
/// 전투, 보상 선택의 규칙은 여기서 판단하지 않고 모두 domain 함수에 위임한다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/m0_content.dart';
import '../domain/combat/combat_engine.dart';
import '../domain/model/combat_action.dart';
import '../domain/model/game_event.dart';
import '../domain/run/run_action.dart';
import '../domain/run/run_content.dart';
import '../domain/run/run_engine.dart';
import '../domain/run/run_state.dart';
import 'combat_controller.dart';

/// 새 런의 시드를 만드는 바깥 레이어의 의존성이다.
///
/// 런이 시작된 뒤의 모든 상태는 [RunState]의 시드와 액션 로그에서 재생하므로,
/// 이 시계 접근은 새 저장 단위를 시작하는 순간에만 쓰인다.
final runSeedFactoryProvider = Provider<int Function()>((ref) {
  return () => DateTime.now().millisecondsSinceEpoch;
});

/// M1에서 사용하는 버전 고정 런 콘텐츠다. domain은 data 레이어를 모르므로
/// 이 경계에서 주입한다.
final runContentProvider = Provider<RunContent>((ref) => m0RunContent());

/// UI가 한 프레임에 읽는 런 스냅샷.
class RunSession {
  RunSession({
    required this.state,
    required this.progress,
    required List<RunAction> legalActions,
  }) : legalActions = List.unmodifiable(legalActions);

  /// 저장 가능한 원본. `{seed, characterId, actionLog}` 외의 상태는 넣지 않는다.
  final RunState state;

  /// 위 원본을 domain에서 재생한 현재 진행도.
  final RunProgress progress;

  /// 지금 입력할 수 있는 액션의 유일한 목록. UI는 이 목록을 다시 계산하지 않는다.
  final List<RunAction> legalActions;
}

/// 순수 런 엔진을 Riverpod 상태로 감싼다.
///
/// 이 컨트롤러는 액션을 해석하지 않는다. 화면이 [legalRunActions]가 만든
/// 액션을 전달하면 [applyRunAction]에 넘기고, 그 결과를 다시 재생할 뿐이다.
class RunController extends Notifier<RunSession> {
  static const _characterId = 'm0';

  @override
  RunSession build() => _snapshot(
    startRun(
      seed: ref.read(runSeedFactoryProvider)(),
      characterId: _characterId,
    ),
  );

  /// domain이 발행한 합법 액션 하나를 기록한다.
  ///
  /// 최종 검증은 [applyRunAction]이 내부에서 [legalRunActions]로 수행한다. 앱
  /// 레이어에는 이동 경로, 보상, 전투의 별도 합법성 규칙이 없다.
  void dispatch(RunAction action) {
    state = _snapshot(
      applyRunAction(
        state.state,
        action,
        content: ref.read(runContentProvider),
      ),
    );
  }

  /// 패배 뒤 새 런을 시작하는 UI용 진입점이다. 저장/불러오기는 M1 범위 밖이다.
  void restart({int? seed}) {
    state = _snapshot(
      startRun(
        seed: seed ?? ref.read(runSeedFactoryProvider)(),
        characterId: _characterId,
      ),
    );
  }

  RunSession _snapshot(RunState runState) {
    final content = ref.read(runContentProvider);
    return RunSession(
      state: runState,
      progress: replayRun(runState, content: content),
      legalActions: legalRunActions(runState, content: content),
    );
  }
}

final runControllerProvider = NotifierProvider<RunController, RunSession>(
  RunController.new,
);

/// 런 안의 한 전투를 기존 [CombatScreen]에 연결하는 어댑터다.
///
/// `CombatScreen` 자체는 검수 완료한 M0 레이아웃을 유지한다. 런 화면 아래의
/// ProviderScope에서만 기존 [combatControllerProvider]를 이 컨트롤러로 바꿔,
/// 같은 주입 경로로 런이 재생한 전투 세션을 건넨다.
class RunCombatController extends CombatController {
  List<GameEvent> _lastEvents = const [];

  @override
  CombatSession build() {
    final run = ref.watch(runControllerProvider);
    final progress = run.progress;
    final combat = progress.combat;
    final nodeId = progress.currentNodeId;
    if (!progress.isInCombat || combat == null || nodeId == null) {
      throw StateError('진행 중인 런 전투가 없다');
    }

    return CombatSession(
      seed: combatSeedForNode(run.state.seed, nodeId),
      state: combat,
      // 전투 결과는 replayRun이 가진 상태가 권위다. 이벤트는 그 상태를 바꾸지
      // 않는 화면 재생 정보로만 domain 전투 엔진에서 한 번 더 얻는다.
      lastEvents: _lastEvents,
      actionLog: _combatActionsFor(run.state, nodeId),
    );
  }

  @override
  void play(int handIndex, {int? targetIndex}) {
    _dispatchMatching(PlayCard(handIndex: handIndex, targetIndex: targetIndex));
  }

  @override
  void endTurn() => _dispatchMatching(const EndTurn());

  @override
  void restart({int? seed}) =>
      ref.read(runControllerProvider.notifier).restart(seed: seed);

  void _dispatchMatching(CombatAction requested) {
    final run = ref.read(runControllerProvider);
    CombatNodeLog? matched;
    for (final action in run.legalActions.whereType<CombatNodeLog>()) {
      if (_sameCombatAction(action.actions.last, requested)) {
        matched = action;
        break;
      }
    }
    if (matched == null || run.progress.combat == null) return;

    // 애니메이션/이벤트 표시에만 사용한다. 실제 런 상태 변경은 아래의
    // RunController → applyRunAction → replayRun 경로 하나로만 일어난다.
    _lastEvents = applyAction(run.progress.combat!, requested).events;
    ref.read(runControllerProvider.notifier).dispatch(matched);
  }
}

List<CombatAction> _combatActionsFor(RunState state, int nodeId) {
  if (state.actionLog.isEmpty) return const [];
  final last = state.actionLog.last;
  return last is CombatNodeLog && last.nodeId == nodeId
      ? last.actions
      : const [];
}

/// 이 비교는 합법성을 판단하지 않는다. `legalRunActions()`가 이미 만든 전투
/// 로그 중 화면 입력과 같은 항목을 고르는 데만 쓴다.
bool _sameCombatAction(CombatAction left, CombatAction right) =>
    switch ((left, right)) {
      (
        PlayCard(
          handIndex: final leftHandIndex,
          targetIndex: final leftTargetIndex,
        ),
        PlayCard(
          handIndex: final rightHandIndex,
          targetIndex: final rightTargetIndex,
        ),
      ) =>
        leftHandIndex == rightHandIndex && leftTargetIndex == rightTargetIndex,
      (EndTurn(), EndTurn()) => true,
      _ => false,
    };
