/// 결정론적 런 맵 (기획서 §2.1, §4.1, §7.4).
library;

import '../rng/rng.dart';
import 'run_node_type.dart';
import 'run_tuning.dart';

class RunNode {
  RunNode({
    required this.id,
    required this.depth,
    required this.type,
    required List<int> nextNodeIds,
  }) : nextNodeIds = List.unmodifiable(nextNodeIds);

  /// 시드에서 항상 같은 순서로 만들어지는 결정론적 식별자.
  final int id;

  /// 시작 노드부터 세는 경로상의 위치. 같은 깊이의 후보 중 하나만 방문한다.
  final int depth;

  final RunNodeType type;

  /// 이 노드에서 곧바로 이동할 수 있는 노드 식별자.
  final List<int> nextNodeIds;

  /// 기존 전투 엔진을 붙일 전투 노드인지 여부.
  bool get hostsCombat => switch (type) {
    RunNodeType.combat || RunNodeType.elite || RunNodeType.boss => true,
    RunNodeType.shop || RunNodeType.wildCamp || RunNodeType.event => false,
  };
}

class RunMap {
  RunMap({required List<RunNode> nodes}) : nodes = List.unmodifiable(nodes) {
    assert(nodes.isNotEmpty);
  }

  final List<RunNode> nodes;

  RunNode nodeById(int id) => nodes.firstWhere((node) => node.id == id);
}

/// 1막 노드 맵을 만든다.
///
/// 맵에 필요한 난수는 반드시 [RngStream.encounter]에서만 뽑는다. 전투의
/// 적 행동은 [RngStream.combat]에 남아 있으므로, 여기서 노드 하나가
/// 추가되어도 전투 수열은 바뀌지 않는다.
///
/// §4.1의 “막당 노드 약 15개”는 한 경로의 방문 수(깊이)다. 같은 깊이에는
/// 여러 후보가 있을 수 있어 맵 전체 노드 수는 더 많지만, 모든 간선은 바로
/// 다음 깊이로만 향하고 마지막 깊이는 단일 보스다. 그래서 어느 선택을 해도
/// 방문 수는 같고 막다른 길이나 시작점에서 고립된 노드가 생기지 않는다.
RunMap generateActOneMap(int seed, {RunTuning tuning = RunTuning.m1}) {
  _validateTuning(tuning);
  var rng = Rng.forStream(seed, RngStream.encounter);
  var nextNodeId = 0;
  final nodeIdsByDepth = <List<int>>[];
  final nodeTypesByDepth = <List<RunNodeType>>[];

  for (var depth = 0; depth < tuning.nodesPerAct; depth++) {
    final isBossDepth = depth == tuning.nodesPerAct - 1;
    final nodeCountResult = isBossDepth
        ? (1, rng)
        : _pickNodeCount(depth, rng, tuning);
    final nodeCount = nodeCountResult.$1;
    rng = nodeCountResult.$2;
    final ids = <int>[];
    final types = <RunNodeType>[];

    for (var slot = 0; slot < nodeCount; slot++) {
      ids.add(nextNodeId++);
      if (isBossDepth) {
        types.add(RunNodeType.boss);
      } else if (depth == tuning.guaranteedEliteDepth) {
        types.add(RunNodeType.elite);
      } else {
        final picked = _pickNonBossNodeType(rng, tuning);
        types.add(picked.$1);
        rng = picked.$2;
      }
    }

    nodeIdsByDepth.add(ids);
    nodeTypesByDepth.add(types);
  }

  final nodes = <RunNode>[];
  for (var depth = 0; depth < tuning.nodesPerAct; depth++) {
    for (var slot = 0; slot < nodeIdsByDepth[depth].length; slot++) {
      final nextNodeIds = depth + 1 == tuning.nodesPerAct
          ? const <int>[]
          : _nextNodeIdsForSlot(
              currentSlot: slot,
              currentSlotCount: nodeIdsByDepth[depth].length,
              nextNodeIds: nodeIdsByDepth[depth + 1],
              tuning: tuning,
            );
      nodes.add(
        RunNode(
          id: nodeIdsByDepth[depth][slot],
          depth: depth,
          type: nodeTypesByDepth[depth][slot],
          nextNodeIds: nextNodeIds,
        ),
      );
    }
  }

  return RunMap(nodes: nodes);
}

(RunNodeType, Rng) _pickNonBossNodeType(Rng rng, RunTuning tuning) {
  final (roll, nextRng) = rng.nextInt(tuning.totalNodeWeight);
  var remaining = roll;

  for (final entry in tuning.nodeTypeWeights) {
    if (remaining < entry.weight) return (entry.type, nextRng);
    remaining -= entry.weight;
  }

  throw StateError('노드 종류 가중치가 난수 범위를 모두 덮지 못했다');
}

(int, Rng) _pickNodeCount(int depth, Rng rng, RunTuning tuning) {
  if (!tuning.isBranchingDepth(depth)) return (1, rng);
  if (depth == tuning.firstBranchDepth) return (tuning.firstBranchWidth, rng);
  if (depth == tuning.lastBranchDepth) return (tuning.lastBranchWidth, rng);
  return _pickBranchWidth(rng, tuning);
}

/// 같은 깊이의 슬롯은 다음 깊이에 투영한 구간과, 순서를 뒤집지 않는 오른쪽 슬롯만
/// 잇는다.
///
/// 투영 구간은 모든 출발 슬롯에 하나 이상의 출구를 주고 다음 깊이의 모든 슬롯을
/// 덮는다. 따라서 시작에서 도달할 수 없는 노드와 보스에 닿지 못하는 막다른 길은
/// 사후 보정 없이 생성되지 않는다. 오른쪽 슬롯은 바로 다음 출발 슬롯의 최소 후보를
/// 넘지 않을 때만 더한다. 그래서 인접 후보 구간은 많아야 한 슬롯만 공유하고, 구간의
/// 순서가 유지되어 간선도 교차하지 않는다.
List<int> _nextNodeIdsForSlot({
  required int currentSlot,
  required int currentSlotCount,
  required List<int> nextNodeIds,
  required RunTuning tuning,
}) {
  final nextSlotCount = nextNodeIds.length;
  final firstTargetSlot = (currentSlot * nextSlotCount) ~/ currentSlotCount;
  final lastTargetSlotExclusive =
      ((currentSlot + 1) * nextSlotCount + currentSlotCount - 1) ~/
      currentSlotCount;
  final targetSlots = <int>[];

  for (
    var targetSlot = firstTargetSlot;
    targetSlot < lastTargetSlotExclusive;
    targetSlot++
  ) {
    if ((targetSlot - currentSlot).abs() <= tuning.maxAdjacentSlotDistance) {
      targetSlots.add(targetSlot);
    }
  }

  assert(targetSlots.isNotEmpty);
  final rightNeighborSlot = targetSlots.last + 1;
  final nextFirstTargetSlot = currentSlot + 1 < currentSlotCount
      ? ((currentSlot + 1) * nextSlotCount) ~/ currentSlotCount
      : nextSlotCount;
  if (rightNeighborSlot < nextSlotCount &&
      rightNeighborSlot <= nextFirstTargetSlot &&
      (rightNeighborSlot - currentSlot).abs() <=
          tuning.maxAdjacentSlotDistance) {
    targetSlots.add(rightNeighborSlot);
  }

  return [for (final targetSlot in targetSlots) nextNodeIds[targetSlot]];
}

(int, Rng) _pickBranchWidth(Rng rng, RunTuning tuning) {
  final range = tuning.maxBranchWidth - tuning.minBranchWidth + 1;
  final (offset, nextRng) = rng.nextInt(range);
  return (tuning.minBranchWidth + offset, nextRng);
}

void _validateTuning(RunTuning tuning) {
  if (tuning.bossesPerAct != 1) {
    throw ArgumentError.value(
      tuning.bossesPerAct,
      'tuning.bossesPerAct',
      'M1의 막당 보스는 마지막 깊이의 시왕 1명이어야 한다',
    );
  }
  if (tuning.nodesPerAct < tuning.minNodesPerAct ||
      tuning.nodesPerAct > tuning.maxNodesPerAct) {
    throw ArgumentError.value(
      tuning.nodesPerAct,
      'tuning.nodesPerAct',
      '막당 노드 수는 선언한 범위 안에 있어야 한다',
    );
  }
  if (tuning.guaranteedEliteDepth <= 0 ||
      tuning.guaranteedEliteDepth >= tuning.nodesPerAct - 1) {
    throw ArgumentError.value(
      tuning.guaranteedEliteDepth,
      'tuning.guaranteedEliteDepth',
      '정예전은 시작과 마지막 보스 사이의 깊이에 있어야 한다',
    );
  }
  if (tuning.minBranchWidth < 2 ||
      tuning.maxBranchWidth < tuning.minBranchWidth ||
      tuning.firstBranchWidth < tuning.minBranchWidth ||
      tuning.firstBranchWidth > tuning.maxBranchWidth ||
      tuning.lastBranchWidth < tuning.minBranchWidth ||
      tuning.lastBranchWidth > tuning.maxBranchWidth ||
      tuning.maxAdjacentSlotDistance <= 0 ||
      tuning.maxBranchWidth - tuning.minBranchWidth >
          tuning.maxAdjacentSlotDistance ||
      tuning.firstBranchWidth > tuning.maxAdjacentSlotDistance + 1 ||
      tuning.lastBranchWidth > tuning.maxAdjacentSlotDistance + 1 ||
      tuning.firstBranchDepth <= 0 ||
      tuning.lastBranchDepth < tuning.firstBranchDepth ||
      tuning.lastBranchDepth >= tuning.nodesPerAct - 1) {
    throw ArgumentError.value(
      tuning,
      'tuning',
      '분기는 시작과 보스 사이에 폭 2 이상으로 배치해야 한다',
    );
  }
  if (tuning.nodeTypeWeights.isEmpty ||
      tuning.nodeTypeWeights.any(
        (entry) => entry.weight <= 0 || entry.type == RunNodeType.boss,
      )) {
    throw ArgumentError.value(
      tuning.nodeTypeWeights,
      'tuning.nodeTypeWeights',
      '일반 노드 가중치는 양수이고 보스를 포함하면 안 된다',
    );
  }
}
