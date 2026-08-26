import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/app/run_controller.dart';
import 'package:siwangjeon/domain/run/run_action.dart';
import 'package:siwangjeon/domain/run/run_engine.dart';

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
}
