import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/domain/rng/rng.dart';
import 'package:siwangjeon/domain/run/run_action.dart';
import 'package:siwangjeon/domain/run/run_engine.dart';
import 'package:siwangjeon/domain/run/run_map.dart';
import 'package:siwangjeon/domain/run/run_node_type.dart';
import 'package:siwangjeon/domain/run/run_state.dart';
import 'package:siwangjeon/domain/run/run_tuning.dart';

const _mapSeeds = [0, 1, 7, 53, 20260826, 20260827, 987654321];

void main() {
  group('1막 결정론적 맵', () {
    test('같은 시드는 분기를 포함해 같은 맵을, 다른 시드는 다른 맵을 만든다', () {
      expect(
        _mapSignature(generateActOneMap(20260826)),
        _mapSignature(generateActOneMap(20260826)),
      );
      expect(
        _mapSignature(generateActOneMap(20260826)),
        isNot(_mapSignature(generateActOneMap(20260827))),
      );
      expect(
        _branchSignature(generateActOneMap(20260826)),
        isNot(_branchSignature(generateActOneMap(20260827))),
      );
    });

    test('같은 깊이의 서로 다른 노드는 이후 선택지를 다르게 제한한다', () {
      for (final seed in _mapSeeds) {
        final nodesByDepth = <int, List<RunNode>>{};
        for (final node in generateActOneMap(seed).nodes) {
          nodesByDepth.putIfAbsent(node.depth, () => []).add(node);
        }

        final informativeDepths = nodesByDepth.entries.where((entry) {
          final candidateSets = entry.value
              .map((node) => node.nextNodeIds.join(','))
              .toSet();
          return entry.value.length > 1 && candidateSets.length > 1;
        });

        expect(
          informativeDepths,
          isNotEmpty,
          reason: 'seed $seed에서 같은 깊이의 노드들이 이후 선택지를 제한하지 않는다',
        );
      }
    });

    test('대표 시드에서 슬롯 순서를 뒤집는 간선이 없다', () {
      for (final seed in _mapSeeds) {
        _expectNonCrossingEdges(generateActOneMap(seed), seed);
      }
    });

    test('대표 시드에서 맵 경로 성질을 보존한다', () {
      const tuning = RunTuning.m1;

      for (final seed in _mapSeeds) {
        final map = generateActOneMap(seed);
        final bosses = map.nodes
            .where((node) => node.type == RunNodeType.boss)
            .toList();
        final reachableNodeIds = _reachableNodeIds(map, map.nodes.first.id);
        final middleNodes = map.nodes
            .where((node) => node.depth == tuning.guaranteedEliteDepth)
            .toList();

        expect(bosses, hasLength(tuning.bossesPerAct));
        expect(bosses.single.depth, tuning.nodesPerAct - 1);
        expect(bosses.single.nextNodeIds, isEmpty);
        expect(reachableNodeIds, map.nodes.map((node) => node.id).toSet());
        expect(_pathLengthsToBoss(map, map.nodes.first.id), {
          tuning.nodesPerAct,
        });
        for (final node in map.nodes) {
          expect(_pathLengthsToBoss(map, node.id), isNotEmpty);
        }
        expect(middleNodes, isNotEmpty);
        expect(
          middleNodes.every((node) => node.type == RunNodeType.elite),
          isTrue,
        );
        expect(map.nodes.any((node) => node.nextNodeIds.length >= 2), isTrue);
      }
    });

    test('막당 보스는 마지막 깊이의 1명이고 방문 깊이는 정확히 15개다', () {
      final map = generateActOneMap(20260826);
      const tuning = RunTuning.m1;
      final bosses = map.nodes
          .where((node) => node.type == RunNodeType.boss)
          .toList();

      expect(tuning.nodesPerAct, 15);
      expect(tuning.minNodesPerAct, 15);
      expect(tuning.maxNodesPerAct, 15);
      expect(bosses, hasLength(tuning.bossesPerAct));
      expect(bosses.single.depth, tuning.nodesPerAct - 1);
      expect(bosses.single.nextNodeIds, isEmpty);
      expect(
        map.nodes
            .where((node) => node.depth < bosses.single.depth)
            .every((node) => node.type != RunNodeType.boss),
        isTrue,
      );
    });

    test('모든 경로는 15개를 방문하고 어느 노드도 보스에 막히지 않는다', () {
      final map = generateActOneMap(20260826);
      const tuning = RunTuning.m1;

      for (final node in map.nodes) {
        expect(_pathLengthsToBoss(map, node.id), isNotEmpty);
      }
      expect(_pathLengthsToBoss(map, map.nodes.first.id), {tuning.nodesPerAct});
    });

    test('시작점에서 모든 노드가 닿고 실제 갈림길이 있다', () {
      final map = generateActOneMap(20260826);
      final reachableNodeIds = _reachableNodeIds(map, map.nodes.first.id);

      expect(reachableNodeIds, map.nodes.map((node) => node.id).toSet());
      final choiceDepths = map.nodes
          .where((node) => node.nextNodeIds.length >= 2)
          .map((node) => node.depth)
          .toSet();
      const tuning = RunTuning.m1;

      expect(
        choiceDepths.length,
        tuning.lastBranchDepth - tuning.firstBranchDepth + 1,
      );
      expect(choiceDepths.length, greaterThanOrEqualTo(2));
    });

    test('중간 정예전은 어떤 경로에서도 보장된다', () {
      final map = generateActOneMap(20260826);
      const tuning = RunTuning.m1;
      final middleNodes = map.nodes
          .where((node) => node.depth == tuning.guaranteedEliteDepth)
          .toList();

      expect(middleNodes, isNotEmpty);
      expect(
        middleNodes.every((node) => node.type == RunNodeType.elite),
        isTrue,
      );
    });

    test('맵 생성은 encounter 수열만 읽고 combat 수열은 바꾸지 않는다', () {
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
    test('같은 시드와 같은 분기 선택 액션 열은 같은 런 진행 상태를 복원한다', () {
      final original = startRun(seed: 53, characterId: 'm0');
      final map = generateActOneMap(original.seed);
      final selectedBranchId = map.nodes.first.nextNodeIds.last;
      final afterFirstMove = applyRunAction(
        original,
        const MoveToNode(nodeId: 0),
      );
      final afterSecondMove = applyRunAction(
        afterFirstMove,
        MoveToNode(nodeId: selectedBranchId),
      );
      final restored = RunState(
        seed: 53,
        characterId: 'm0',
        actionLog: [
          MoveToNode(nodeId: 0),
          MoveToNode(nodeId: selectedBranchId),
        ],
      );

      final expected = replayRun(afterSecondMove);
      final actual = replayRun(restored);

      expect(_mapSignature(actual.map), _mapSignature(expected.map));
      expect(actual.visitedNodeIds, expected.visitedNodeIds);
      expect(actual.currentNodeId, expected.currentNodeId);
    });

    test('합법 이동은 legalRunActions 한곳에서 결정되고, 갈 수 없는 분기는 거부된다', () {
      final state = startRun(seed: 7, characterId: 'm0');
      final map = generateActOneMap(state.seed);
      final firstNodeId = map.nodes.first.id;
      final unreachableFromFirstNode = map.nodes.firstWhere(
        (node) => node.depth == 3,
      );

      expect(
        legalRunActions(
          state,
        ).whereType<MoveToNode>().map((action) => action.nodeId),
        [firstNodeId],
      );
      expect(
        () => applyRunAction(
          state,
          MoveToNode(nodeId: unreachableFromFirstNode.id),
        ),
        throwsA(isA<IllegalRunActionError>()),
      );

      final entered = applyRunAction(state, MoveToNode(nodeId: firstNodeId));
      expect(
        legalRunActions(
          entered,
        ).whereType<MoveToNode>().map((action) => action.nodeId),
        map.nodeById(firstNodeId).nextNodeIds,
      );
      expect(
        () => applyRunAction(
          entered,
          MoveToNode(nodeId: unreachableFromFirstNode.id),
        ),
        throwsA(isA<IllegalRunActionError>()),
      );
    });
  });
}

List<String> _mapSignature(RunMap map) {
  return [
    for (final node in map.nodes)
      '${node.id}:${node.depth}:${node.type.name}:${node.nextNodeIds.join(',')}',
  ];
}

List<String> _branchSignature(RunMap map) {
  return [
    for (final node in map.nodes) '${node.depth}:${node.nextNodeIds.join(',')}',
  ];
}

void _expectNonCrossingEdges(RunMap map, int seed) {
  final nodesByDepth = <int, List<RunNode>>{};
  for (final node in map.nodes) {
    nodesByDepth.putIfAbsent(node.depth, () => []).add(node);
  }

  final lastDepth = nodesByDepth.keys.reduce(
    (current, depth) => current > depth ? current : depth,
  );
  for (var depth = 0; depth < lastDepth; depth++) {
    final currentNodes = [...nodesByDepth[depth]!]
      ..sort((left, right) => left.id.compareTo(right.id));
    final nextNodes = [...nodesByDepth[depth + 1]!]
      ..sort((left, right) => left.id.compareTo(right.id));
    final targetSlotById = {
      for (var slot = 0; slot < nextNodes.length; slot++)
        nextNodes[slot].id: slot,
    };

    for (var leftSlot = 0; leftSlot < currentNodes.length; leftSlot++) {
      final left = currentNodes[leftSlot];
      final leftMaxTargetSlot = left.nextNodeIds
          .map((id) => targetSlotById[id]!)
          .reduce((current, slot) => current > slot ? current : slot);
      for (
        var rightSlot = leftSlot + 1;
        rightSlot < currentNodes.length;
        rightSlot++
      ) {
        final right = currentNodes[rightSlot];
        final rightMinTargetSlot = right.nextNodeIds
            .map((id) => targetSlotById[id]!)
            .reduce((current, slot) => current < slot ? current : slot);

        expect(
          leftMaxTargetSlot,
          lessThanOrEqualTo(rightMinTargetSlot),
          reason:
              'seed $seed depth $depth '
              '${left.id}->${left.nextNodeIds} vs '
              '${right.id}->${right.nextNodeIds}',
        );
      }
    }
  }
}

Set<int> _pathLengthsToBoss(RunMap map, int nodeId) {
  final node = map.nodeById(nodeId);
  if (node.type == RunNodeType.boss) return {1};

  return {
    for (final nextNodeId in node.nextNodeIds)
      for (final length in _pathLengthsToBoss(map, nextNodeId)) length + 1,
  };
}

Set<int> _reachableNodeIds(RunMap map, int startNodeId) {
  final reached = <int>{startNodeId};
  final pending = <int>[startNodeId];

  while (pending.isNotEmpty) {
    final node = map.nodeById(pending.removeLast());
    for (final nextNodeId in node.nextNodeIds) {
      if (reached.add(nextNodeId)) pending.add(nextNodeId);
    }
  }

  return reached;
}
