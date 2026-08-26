import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/app/run_controller.dart';
import 'package:siwangjeon/data/run_storage.dart';
import 'package:siwangjeon/domain/run/run_action.dart';
import 'package:siwangjeon/domain/run/run_engine.dart';
import 'package:siwangjeon/domain/run/run_state.dart';

void main() {
  test('런 컨트롤러는 domain이 준 이동 액션을 그대로 재생한다', () {
    final container = ProviderContainer(
      overrides: [runSeedFactoryProvider.overrideWithValue(() => 20260827)],
    );
    addTearDown(container.dispose);

    final before = container.read(runControllerProvider);
    final move = before.legalActions.whereType<MoveToNode>().single;
    final expected = applyRunAction(
      before.state,
      move,
      content: container.read(runContentProvider),
    );

    container.read(runControllerProvider.notifier).dispatch(move);
    final after = container.read(runControllerProvider);

    expect(after.state.actionLog, hasLength(1));
    expect((after.state.actionLog.single as MoveToNode).nodeId, move.nodeId);
    expect(
      after.state.actionLog.single.runtimeType,
      expected.actionLog.single.runtimeType,
    );
    expect(after.progress.currentNodeId, move.nodeId);
  });

  test('적용한 모든 런 액션을 주입된 저장소에 순서대로 저장한다', () async {
    final storage = _SavingMemoryStorage();
    final container = ProviderContainer(
      overrides: [
        runSeedFactoryProvider.overrideWithValue(() => 20260828),
        runStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(runControllerProvider.notifier);
    final first = container.read(runControllerProvider).legalActions.first;
    controller.dispatch(first);
    final second = container.read(runControllerProvider).legalActions.first;
    controller.dispatch(second);
    await controller.flushPersistence();

    expect(storage.saved, hasLength(2));
    expect(storage.saved[0].actionLog, hasLength(1));
    expect(storage.saved[1].actionLog, hasLength(2));
  });

  test('시작 전에 주입된 저장 런으로 새 시드 대신 이어서 시작한다', () {
    const restored = RunState(seed: 20260829, characterId: 'm0', actionLog: []);
    final container = ProviderContainer(
      overrides: [runInitialStateProvider.overrideWithValue(restored)],
    );
    addTearDown(container.dispose);

    final session = container.read(runControllerProvider);

    expect(session.state.seed, restored.seed);
    expect(session.state.characterId, restored.characterId);
    expect(session.state.actionLog, isEmpty);
  });
}

class _SavingMemoryStorage implements RunStorage {
  final saved = <RunState>[];

  @override
  Future<RunLoadResult> load() =>
      Future<RunLoadResult>.value(const RunLoadMissing());

  @override
  Future<void> save(RunState state) {
    saved.add(state);
    return Future<void>.value();
  }
}
