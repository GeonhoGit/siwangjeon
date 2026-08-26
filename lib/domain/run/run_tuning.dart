/// 런 맵 구조 상수 (기획서 §2.1, §4.1, §8.2).
///
/// 맵의 길이·보스 주기·노드 비율은 전투 수치와 독립적으로 조정돼야 하므로
/// `combat/tuning.dart`가 아니라 런 도메인에 모은다. M2 시뮬레이터는 이 값을
/// 바꿔 런 길이와 경로 구성을 함께 측정할 수 있다.
library;

import 'run_node_type.dart';

class RunNodeWeight {
  const RunNodeWeight(this.type, this.weight);

  final RunNodeType type;
  final int weight;
}

class RunTuning {
  const RunTuning({
    this.nonBossNodesPerBoss = 7,
    this.bossesPerAct = 2,
    this.minNodesPerAct = 14,
    this.maxNodesPerAct = 16,
    this.nodeTypeWeights = const [
      RunNodeWeight(RunNodeType.combat, 50),
      RunNodeWeight(RunNodeType.elite, 10),
      RunNodeWeight(RunNodeType.shop, 15),
      RunNodeWeight(RunNodeType.wildCamp, 15),
      RunNodeWeight(RunNodeType.event, 10),
    ],
  }) : assert(nonBossNodesPerBoss > 0),
       assert(bossesPerAct > 0),
       assert(minNodesPerAct > 0),
       assert(maxNodesPerAct >= minNodesPerAct);

  /// §2.1 — 보스 하나 앞에 놓이는 일반 노드 수.
  final int nonBossNodesPerBoss;

  /// 1막에서 만나는 심판 횟수. M1은 두 번의 7일 주기를 만든다.
  final int bossesPerAct;

  /// §4.1의 "막당 약 15개"를 검증하기 위한 하한.
  final int minNodesPerAct;

  /// §4.1의 "막당 약 15개"를 검증하기 위한 상한.
  final int maxNodesPerAct;

  /// 보스 이외 노드를 뽑는 가중치. 보스는 [nonBossNodesPerBoss] 주기로만 둔다.
  final List<RunNodeWeight> nodeTypeWeights;

  /// 7개 일반 노드 + 보스의 두 주기라 총 16개다. §4.1의 약 15개 범위 안이다.
  int get nodesPerAct => bossesPerAct * (nonBossNodesPerBoss + 1);

  int get totalNodeWeight =>
      nodeTypeWeights.fold(0, (sum, entry) => sum + entry.weight);

  static const RunTuning m1 = RunTuning();
}
