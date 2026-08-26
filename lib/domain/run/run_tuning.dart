/// 런 맵 구조 상수 (기획서 §2.1, §4.1, §8.2).
///
/// 막의 길이·보스 수·분기 폭·노드 비율은 전투 수치와 독립적으로 조정해야 하므로
/// `combat/tuning.dart`가 아닌 이 파일에 모은다. M2 시뮬레이터는 이 값들을
/// 바꿔 런 길이와 경로 구성을 따로 측정한다.
library;

import 'run_node_type.dart';

class RunNodeWeight {
  const RunNodeWeight(this.type, this.weight);

  final RunNodeType type;
  final int weight;
}

class RunTuning {
  const RunTuning({
    this.bossesPerAct = 1,
    this.nodesPerAct = 15,
    this.minNodesPerAct = 15,
    this.maxNodesPerAct = 15,
    this.guaranteedEliteDepth = 7,
    this.minBranchWidth = 2,
    this.maxBranchWidth = 3,
    this.firstBranchWidth = 2,
    this.lastBranchWidth = 2,
    this.maxAdjacentSlotDistance = 1,
    this.firstBranchDepth = 1,
    this.lastBranchDepth = 13,
    this.nodeTypeWeights = const [
      RunNodeWeight(RunNodeType.combat, 50),
      RunNodeWeight(RunNodeType.elite, 10),
      RunNodeWeight(RunNodeType.shop, 15),
      RunNodeWeight(RunNodeType.wildCamp, 15),
      RunNodeWeight(RunNodeType.event, 10),
    ],
  }) : assert(bossesPerAct == 1),
       assert(nodesPerAct > 1),
       assert(minNodesPerAct > 0),
       assert(maxNodesPerAct >= minNodesPerAct),
       assert(guaranteedEliteDepth > 0),
       assert(guaranteedEliteDepth < nodesPerAct - 1),
       assert(minBranchWidth > 1),
       assert(maxBranchWidth >= minBranchWidth),
       assert(firstBranchWidth >= minBranchWidth),
       assert(firstBranchWidth <= maxBranchWidth),
       assert(lastBranchWidth >= minBranchWidth),
       assert(lastBranchWidth <= maxBranchWidth),
       assert(maxAdjacentSlotDistance > 0),
       assert(maxBranchWidth - minBranchWidth <= maxAdjacentSlotDistance),
       assert(firstBranchWidth <= maxAdjacentSlotDistance + 1),
       assert(lastBranchWidth <= maxAdjacentSlotDistance + 1),
       assert(firstBranchDepth > 0),
       assert(lastBranchDepth >= firstBranchDepth),
       assert(lastBranchDepth < nodesPerAct - 1);

  /// 기획서 §2.1의 “7 노드마다 시왕 심판”과 §4.1의 “막당 약 15개”는
  /// 함께 만족할 수 없다. 사용자는 막당 마지막 시왕 1명과 방문 깊이 15개를
  /// 결정했고, 따라서 §2.1의 보스 주기는 완화한다. 중간 리듬은
  /// [guaranteedEliteDepth]의 정예전이 맡는다.
  final int bossesPerAct;

  /// 플레이어가 한 막에서 방문하는 노드(보스 포함)의 깊이.
  ///
  /// §4.1의 “막당 노드 약 15개”는 맵 전체 노드 수가 아니라 경로 하나의
  /// 방문 수로 해석한다. 같은 깊이의 후보는 여럿일 수 있지만 모든 경로는
  /// 이 깊이를 정확히 한 번씩 지난다.
  final int nodesPerAct;

  /// §4.1의 목표 방문 수를 드러내는 하한.
  final int minNodesPerAct;

  /// §4.1의 목표 방문 수를 드러내는 상한.
  final int maxNodesPerAct;

  /// 막의 중간 지점에서 모든 경로가 지나는 정예전의 깊이.
  /// 0 기반 깊이 7은 보스를 포함한 15회 방문의 정중앙이다.
  final int guaranteedEliteDepth;

  /// 분기 깊이 하나에 encounter 수열로 뽑는 후보 노드 수의 하한.
  final int minBranchWidth;

  /// 분기 깊이 하나에 encounter 수열로 뽑는 후보 노드 수의 상한.
  final int maxBranchWidth;

  /// 시작과 마지막 분기 깊이의 슬롯 수.
  ///
  /// 시작 노드와 단일 보스에 닿는 간선도 인접 슬롯 안에 머물려면 이 값은
  /// [maxAdjacentSlotDistance]보다 하나까지만 클 수 있다.
  final int firstBranchWidth;
  final int lastBranchWidth;

  /// 한 간선이 양 끝 깊이에서 벌어질 수 있는 최대 슬롯 거리.
  final int maxAdjacentSlotDistance;

  /// 분기를 시작하는 깊이. 시작 노드는 하나라 저장 로그의 첫 이동도 명확하다.
  final int firstBranchDepth;

  /// 분기를 끝내는 깊이. 다음 마지막 깊이의 단일 보스로 모든 경로가 합류한다.
  final int lastBranchDepth;

  /// 보스 이외 노드를 뽑는 가중치. 보스는 마지막 깊이에만 둔다.
  final List<RunNodeWeight> nodeTypeWeights;

  bool isBranchingDepth(int depth) =>
      depth >= firstBranchDepth && depth <= lastBranchDepth;

  int get totalNodeWeight =>
      nodeTypeWeights.fold(0, (sum, entry) => sum + entry.weight);

  static const RunTuning m1 = RunTuning();
}
