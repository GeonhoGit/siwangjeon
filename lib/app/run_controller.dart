/// 런 진행 상태를 UI에 전달하는 Riverpod 어댑터 (§7.2, §7.4).
///
/// 이 파일은 `domain/run`의 재생 결과와 합법 액션을 그대로 노출한다. 이동,
/// 전투, 보상 선택의 규칙은 여기서 판단하지 않고 모두 domain 함수에 위임한다.
library;

import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/run_storage.dart';
import '../domain/combat/combat_engine.dart';
import '../domain/model/combat_action.dart';
import '../domain/model/game_event.dart';
import '../domain/run/run_action.dart';
import '../domain/run/run_content.dart';
import '../domain/run/run_engine.dart';
import '../domain/run/run_state.dart';
import 'combat_controller.dart';
import 'run_content_provider.dart';

export 'run_content_provider.dart' show runContentProvider;

/// 새 런의 시드를 만드는 바깥 레이어의 의존성이다.
///
/// 런이 시작된 뒤의 모든 상태는 [RunState]의 시드와 액션 로그에서 재생하므로,
/// 이 시계 접근은 새 저장 단위를 시작하는 순간에만 쓰인다.
final runSeedFactoryProvider = Provider<int Function()>((ref) {
  return () => DateTime.now().millisecondsSinceEpoch;
});

/// 앱 시작점에서 이미 복원한 런을 전달하는 경계다.
///
/// 파일 읽기는 비동기라서, 여기서 다시 읽으면 새 런 지도가 잠깐 보인 뒤 바뀐다.
/// main은 [RunController.loadStoredRun]으로 먼저 검증한 값만 이 provider에 넣고,
/// 위젯 테스트의 기본값은 null로 유지한다.
final runInitialStateProvider = Provider<RunState?>((ref) => null);

/// 런 저장소의 주입점이다.
///
/// 기본값은 테스트가 실제 디스크를 공유하지 않게 하는 무동작 구현이고, 실앱은
/// main에서 [FileRunStorage]를 주입한다.
final runStorageProvider = Provider<RunStorage>(
  (ref) => const NoopRunStorage(),
);

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

  final Queue<RunState> _saveQueue = Queue<RunState>();
  Future<void> _pendingSave = Future<void>.value();
  var _isSaving = false;

  @override
  RunSession build() {
    final restored = ref.read(runInitialStateProvider);
    return _snapshot(
      restored ??
          startRun(
            seed: ref.read(runSeedFactoryProvider)(),
            characterId: _characterId,
          ),
    );
  }

  /// 앱이 UI를 만들기 전에 저장 런을 읽고 재생 가능한지 검증한다.
  ///
  /// 저장 파일이 없거나, 버전·JSON·콘텐츠가 달라 액션 하나라도 재생되지 않으면
  /// null을 돌려 새 런을 시작한다. 특히 사라진 카드 id의 보상 선택은 그 뒤 덱을
  /// 믿을 수 없으므로 로그 일부만 살리지 않는다. 이 경로에서는 저장소를 쓰지
  /// 않아 손상 파일을 플레이어가 다음 액션을 확정하기 전까지 보존한다.
  static Future<RunState?> loadStoredRun({
    required RunStorage storage,
    required RunContent content,
  }) async {
    try {
      final result = await storage.load();
      switch (result) {
        case RunLoadFound(:final state):
          replayRun(state, content: content);
          return state;
        case RunLoadMissing():
        case RunLoadRejected():
          return null;
      }
    } catch (_) {
      // 읽기 실패와 콘텐츠 변경으로 생긴 불법 로그는 앱 시작을 막지 않는다.
      return null;
    }
  }

  /// domain이 발행한 합법 액션 하나를 기록한다.
  ///
  /// 최종 검증은 [applyRunAction]이 내부에서 [legalRunActions]로 수행한다. 앱
  /// 레이어에는 이동 경로, 보상, 전투의 별도 합법성 규칙이 없다.
  void dispatch(RunAction action) {
    final next = applyRunAction(
      state.state,
      action,
      content: ref.read(runContentProvider),
    );
    state = _snapshot(next);
    _enqueueSave(next);
  }

  /// 패배 뒤 새 런을 시작하는 UI용 진입점이다.
  void restart({int? seed}) {
    final next = startRun(
      seed: seed ?? ref.read(runSeedFactoryProvider)(),
      characterId: _characterId,
    );
    state = _snapshot(next);
    // 재시작은 플레이어가 이전 런을 버리겠다고 명시한 경우라 새 런 골격도
    // 저장한다. 반대로 시작 시 읽기 실패만으로는 저장하지 않는다.
    _enqueueSave(next);
  }

  /// 테스트가 저장 큐가 비워질 때까지 기다리는 경계다.
  Future<void> flushPersistence() => _pendingSave;

  void _enqueueSave(RunState runState) {
    _saveQueue.add(runState);
    if (_isSaving) return;

    // 첫 저장은 액션 처리와 같은 호출 스택에서 시작한다. 이후 입력은 한 줄씩
    // 이어 써서 오래된 스냅샷이 최신 저장을 덮어쓰지 못하게 한다.
    _isSaving = true;
    _pendingSave = _drainSaveQueue();
  }

  Future<void> _drainSaveQueue() async {
    while (_saveQueue.isNotEmpty) {
      await _trySave(_saveQueue.removeFirst());
    }
    _isSaving = false;
  }

  Future<void> _trySave(RunState runState) async {
    try {
      await ref.read(runStorageProvider).save(runState);
    } catch (_) {
      // 저장 실패가 전투 입력과 화면 상태를 되돌리지는 않는다. 다음 액션에서
      // 다시 저장을 시도하며, 파일 저장소의 임시 파일 전략은 기존 파일을 보존한다.
    }
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
