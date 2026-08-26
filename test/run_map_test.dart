import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/domain/rng/rng.dart';
import 'package:siwangjeon/domain/run/run_action.dart';
import 'package:siwangjeon/domain/run/run_engine.dart';
import 'package:siwangjeon/domain/run/run_map.dart';
import 'package:siwangjeon/domain/run/run_node_type.dart';
import 'package:siwangjeon/domain/run/run_state.dart';
import 'package:siwangjeon/domain/run/run_tuning.dart';

void main() {
  group('1막 저승길 맵', () {
    test('같은 시드는 같은 맵을, 다른 시드는 다른 맵을 만든다', () {
      expect(
        _mapSignature(generateActOneMap(20260826)),
        _mapSignature(generateActOneMap(20260826)),
      );
      expect(
        _mapSignature(generateActOneMap(20260826)),
        isNot(_mapSignature(generateActOneMap(20260827))),
      );
    });

    test('7개 일반 노드마다 보스가 오고 1막 길이는 약 15개다', () {
      final map = generateActOneMap(20260826);
      const tuning = RunTuning.m1;
      final bossIndexes = <int>[];

      for (var index = 0; index < map.nodes.length; index++) {
        if (map.nodes[index].type == RunNodeType.boss) bossIndexes.add(index);
      }

      expect(
        map.nodes.length,
        inInclusiveRange(tuning.minNodesPerAct, tuning.maxNodesPerAct),
      );
      expect(bossIndexes, [tuning.nonBossNodesPerBoss, tuning.nodesPerAct - 1]);
      expect(
        map.nodes
            .where((node) => node.id < tuning.nonBossNodesPerBoss)
            .every((node) => node.type != RunNodeType.boss),
        isTrue,
      );
    });

    test('맵 생성은 encounter 수열을 쓰고 combat 수열을 바꾸지 않는다', () {
      const tuning = RunTuning(
        nodeTypeWeights: [
          RunNodeWeight(RunNodeType.combat, 1),
          RunNodeWeight(RunNodeType.elite, 1),
          RunNodeWeight(RunNodeType.shop, 1),
          RunNodeWeight(RunNodeType.wildCamp, 1),
          RunNodeWeight(RunNodeType.event, 1),
        ],
      );
      final seed = Iterable<int>.generate(100).firstWhere((candidate) {
        final encounter = Rng.forStream(
          candidate,
          RngStream.encounter,
        ).nextInt(tuning.totalNodeWeight).$1;
        final combat = Rng.forStream(
          candidate,
          RngStream.combat,
        ).nextInt(tuning.totalNodeWeight).$1;
        return encounter != combat;
      });
      final encounterRoll = Rng.forStream(
        seed,
        RngStream.encounter,
      ).nextInt(tuning.totalNodeWeight).$1;
      final combatBefore = Rng.forStream(seed, RngStream.combat);

      final map = generateActOneMap(seed, tuning: tuning);

      expect(map.nodes.first.type, tuning.nodeTypeWeights[encounterRoll].type);
      expect(Rng.forStream(seed, RngStream.combat), combatBefore);
    });
  });

  group('런 액션 로그 재생', () {
    test('같은 시드와 같은 액션 열은 같은 런 진행 상태를 복원한다', () {
      final original = startRun(seed: 53, characterId: 'm0');
      final afterFirstMove = applyRunAction(
        original,
        const MoveToNode(nodeId: 0),
      );
      final afterSecondMove = applyRunAction(
        afterFirstMove,
        const MoveToNode(nodeId: 1),
      );
      const restored = RunState(
        seed: 53,
        characterId: 'm0',
        actionLog: [MoveToNode(nodeId: 0), MoveToNode(nodeId: 1)],
      );

      final expected = replayRun(afterSecondMove);
      final actual = replayRun(restored);

      expect(_mapSignature(actual.map), _mapSignature(expected.map));
      expect(actual.visitedNodeIds, expected.visitedNodeIds);
      expect(actual.currentNodeId, expected.currentNodeId);
    });

    test('합법 이동은 legalRunActions 한곳에서 결정되고, 건너뛰기는 거부된다', () {
      final state = startRun(seed: 7, characterId: 'm0');

      expect(
        legalRunActions(
          state,
        ).whereType<MoveToNode>().map((action) => action.nodeId),
        [0],
      );
      expect(
        () => applyRunAction(state, const MoveToNode(nodeId: 1)),
        throwsA(isA<IllegalRunActionError>()),
      );

      final entered = applyRunAction(state, const MoveToNode(nodeId: 0));
      expect(
        legalRunActions(
          entered,
        ).whereType<MoveToNode>().map((action) => action.nodeId),
        [1],
      );
    });
  });
}

List<String> _mapSignature(RunMap map) {
  return [
    for (final node in map.nodes)
      '${node.id}:${node.type.name}:${node.nextNodeIds.join(',')}',
  ];
}
