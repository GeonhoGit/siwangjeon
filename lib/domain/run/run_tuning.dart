/// 런 맵 구조 상수 (기획서 §2.1, §4.1, §8.2).
///
/// 막의 길이·보스 수·분기 폭·노드 비율은 전투 수치와 독립적으로 조정해야 하므로
/// `combat/tuning.dart`가 아닌 이 파일에 모은다. M2 시뮬레이터는 이 값들을
/// 바꿔 런 길이와 경로 구성을 따로 측정한다.
library;

import 'run_node_type.dart';
import 'run_event.dart';

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
    this.combatEncounterSize = 3,
    this.eliteEncounterSize = 3,
    this.bossEncounterSize = 3,
    this.cardRewardChoiceCount = 3,
    this.relicRewardChoiceCount = 3,
    this.baseMoneyReward = 30,
    this.eliteKarmaReward = 3,
    this.shopCardChoiceCount = 3,
    this.shopCardPrice = 30,
    this.shopRemoveCardPrice = 60,
    this.wildCampRestHeal = 24,
    this.wildCampRepentKarmaCleanse = 3,
    this.wildCampRepentMoneyCost = 30,
    this.cleanKarmaMax = 19,
    this.ordinaryKarmaMax = 49,
    this.turbidKarmaMax = 79,
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
       assert(lastBranchDepth < nodesPerAct - 1),
       assert(combatEncounterSize > 0),
       assert(eliteEncounterSize > 0),
       assert(bossEncounterSize > 0),
       assert(cardRewardChoiceCount > 0),
       assert(relicRewardChoiceCount > 0),
       assert(baseMoneyReward >= 0),
       assert(eliteKarmaReward >= 0),
       assert(shopCardChoiceCount > 0),
       assert(shopCardPrice >= 0),
       assert(shopRemoveCardPrice >= 0),
       assert(wildCampRestHeal > 0),
       assert(wildCampRepentKarmaCleanse > 0),
       assert(wildCampRepentMoneyCost >= 0),
       assert(cleanKarmaMax >= 0),
       assert(ordinaryKarmaMax >= cleanKarmaMax),
       assert(turbidKarmaMax >= ordinaryKarmaMax);

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

  /// 일반 전투에 배치할 적 수. 적 원형과 수치는 콘텐츠에, 구성 규칙은 런
  /// 튜닝에 둔다.
  final int combatEncounterSize;

  /// 전용 정예 적이 생기기 전의 임시 구성 수. M1에서는 M0 적 풀을 재사용하며,
  /// 전용 적을 도입할 다음 단계에서 이 자리가 정예 구성을 가리킨다.
  final int eliteEncounterSize;

  /// 전용 보스 적이 생기기 전의 임시 구성 수. M1에서는 M0 적 풀을 재사용하며,
  /// 전용 보스를 도입할 다음 단계에서 이 자리가 보스 구성을 가리킨다.
  final int bossEncounterSize;

  /// §2.1의 전투 카드 보상 후보 수. M1-3에서는 항상 이 중 하나를 고른다.
  final int cardRewardChoiceCount;

  final int relicRewardChoiceCount;

  /// 일반 전투와 임시 보스 승리 뒤 즉시 더하는 노잣돈.
  ///
  /// M1 정예전은 §2.1의 유물+업보가 임시 현금 보상을 대체하므로 0을 준다.
  /// 반면 일반 전투의 30과 상점 카드 가격 30은 첫 상점에서 카드 한 장을 살 수
  /// 있는 루프를 보존한다. 이는 M2의 10만 런 시뮬레이터 조율 전 임시값이다.
  final int baseMoneyReward;

  /// M1 정예 승리 뒤 추가하는 업보. §2.1의 유물+업보가 임시 현금 보상을
  /// 대체하므로 정예 노잣돈은 0이다. 일반 전투의 30과 상점 가격 30은 첫 상점
  /// 루프를 유지한다.
  final int eliteKarmaReward;

  /// 상점 한 곳에서 제시하는 서로 다른 카드 수와 카드 한 장의 가격.
  ///
  /// 첫 일반 전투 보상과 같게 두어 셋 중 한 장만 살 수 있게 한다. 제거 가격은
  /// 더 높게 유지해 덱 압축이 첫 상점의 자동 정답이 되지 않게 한다.
  final int shopCardChoiceCount;
  final int shopCardPrice;

  /// 상점에서 카드 한 장을 덱에서 제거하는 가격. 제거는 강한 덱 압축이므로
  /// 구매보다 높게 두되, 밸런스 시뮬레이터가 이 값만 흔들 수 있게 모은다.
  final int shopRemoveCardPrice;

  /// 야장의 휴식 회복량과 참회가 씻는 업·노잣돈 대가.
  ///
  /// §2.1에는 카드 강화도 야장 선택지로 적혀 있지만, 강화 상태는 카드 모델·보상
  /// 풀·저장 참조를 함께 바꾸므로 이번 도메인 범위에서는 넣지 않는다. 후속 단계는
  /// 이 세 값 옆에 강화 비용과 효과를 추가해 세 선택지로 확장한다.
  final int wildCampRestHeal;
  final int wildCampRepentKarmaCleanse;
  final int wildCampRepentMoneyCost;

  /// §3.3의 청정·평범·탁함·악업 경계. 사건 콘텐츠는 숫자를 직접 비교하지
  /// 않고 [karmaBandFor]가 돌려주는 의미 구간만 사용한다.
  final int cleanKarmaMax;
  final int ordinaryKarmaMax;
  final int turbidKarmaMax;

  /// 사건 결과의 모든 수치. data의 사건 정의는 [RunEventEffect]만 고르므로,
  /// 콘텐츠 문구를 고쳐도 밸런스 수치가 흩어지지 않는다.
  RunEventDelta eventDeltaFor(RunEventEffect effect) => switch (effect) {
    RunEventEffect.acceptBribe => const RunEventDelta(karma: 3, money: 30),
    RunEventEffect.returnBribe => const RunEventDelta(),
    RunEventEffect.consumeOffering => const RunEventDelta(hp: 18, karma: 2),
    RunEventEffect.shareOffering => const RunEventDelta(),
    RunEventEffect.takeSmugglerCoin => const RunEventDelta(karma: 3, money: 35),
    RunEventEffect.payFerryman => const RunEventDelta(money: -20),
    RunEventEffect.turnAwaySmuggler => const RunEventDelta(),
    RunEventEffect.falsifyLedger => const RunEventDelta(karma: 3, money: 35),
    RunEventEffect.confessLedger => const RunEventDelta(karma: -8, money: -20),
    RunEventEffect.sealLedger => const RunEventDelta(),
    RunEventEffect.burnAncestralAshes => const RunEventDelta(hp: 16),
    RunEventEffect.tendAncestralAshes => const RunEventDelta(
      karma: -4,
      money: -15,
    ),
    RunEventEffect.stealWidowCandle => const RunEventDelta(money: 20),
    RunEventEffect.lightWidowCandle => const RunEventDelta(karma: -3, hp: -7),
    RunEventEffect.drinkOblivion => const RunEventDelta(hp: 15, karma: 3),
    RunEventEffect.refuseOblivion => const RunEventDelta(karma: -5),
    RunEventEffect.sellOblivion => const RunEventDelta(money: 20),
    RunEventEffect.takeWardenFavor => const RunEventDelta(karma: 5),
    RunEventEffect.endureWardenTrial => const RunEventDelta(hp: -12),
  };

  KarmaBand karmaBandFor(int karma) {
    if (karma <= cleanKarmaMax) return KarmaBand.clean;
    if (karma <= ordinaryKarmaMax) return KarmaBand.ordinary;
    if (karma <= turbidKarmaMax) return KarmaBand.turbid;
    return KarmaBand.evil;
  }

  bool isBranchingDepth(int depth) =>
      depth >= firstBranchDepth && depth <= lastBranchDepth;

  int get totalNodeWeight =>
      nodeTypeWeights.fold(0, (sum, entry) => sum + entry.weight);

  int encounterSizeFor(RunNodeType type) => switch (type) {
    RunNodeType.combat => combatEncounterSize,
    RunNodeType.elite => eliteEncounterSize,
    RunNodeType.boss => bossEncounterSize,
    RunNodeType.shop ||
    RunNodeType.wildCamp ||
    RunNodeType.event => throw ArgumentError.value(type, 'type', '전투 노드가 아니다'),
  };

  static const RunTuning m1 = RunTuning();
}
