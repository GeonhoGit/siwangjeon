/// 결정론적 저승길 노드 맵 (기획서 §2.1, §4.1, §7.4).
library;

import '../rng/rng.dart';
import 'run_node_type.dart';
import 'run_tuning.dart';

class RunNode {
  RunNode({
    required this.id,
    required this.type,
    required List<int> nextNodeIds,
  }) : nextNodeIds = List.unmodifiable(nextNodeIds);

  /// 시드에서 항상 같은 순서로 만들어지는 안정적인 식별자.
  final int id;

  final RunNodeType type;

  /// 이 노드에서 곧바로 이동할 수 있는 노드 식별자.
  final List<int> nextNodeIds;

  /// 기존 전투 엔진을 붙일 노드인지 여부.
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
/// 드로우·적 행동은 [RngStream.combat]에 남아 있으므로, 여기서 노드 하나가
/// 추가돼도 전투 수열은 바뀌지 않는다.
RunMap generateActOneMap(int seed, {RunTuning tuning = RunTuning.m1}) {
  _validateTuning(tuning);
  var rng = Rng.forStream(seed, RngStream.encounter);
  final nodes = <RunNode>[];

  for (var index = 0; index < tuning.nodesPerAct; index++) {
    final isBoss = (index + 1) % (tuning.nonBossNodesPerBoss + 1) == 0;
    final RunNodeType type;

    if (isBoss) {
      type = RunNodeType.boss;
    } else {
      final picked = _pickNonBossNodeType(rng, tuning);
      type = picked.$1;
      rng = picked.$2;
    }

    nodes.add(
      RunNode(
        id: index,
        type: type,
        nextNodeIds: index + 1 == tuning.nodesPerAct ? const [] : [index + 1],
      ),
    );
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

void _validateTuning(RunTuning tuning) {
  if (tuning.nodesPerAct < tuning.minNodesPerAct ||
      tuning.nodesPerAct > tuning.maxNodesPerAct) {
    throw ArgumentError.value(
      tuning.nodesPerAct,
      'tuning.nodesPerAct',
      '막당 노드 수는 선언한 범위 안이어야 한다',
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
