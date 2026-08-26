/// 런 진행과 전투 노드 재생 규칙 (기획서 §2.1, §2.3, §7.4).
library;

import '../combat/combat_engine.dart';
import '../combat/tuning.dart';
import '../model/card.dart';
import '../model/combat_action.dart';
import '../model/combat_state.dart';
import '../model/enemy.dart';
import '../rng/rng.dart';
import 'run_action.dart';
import 'run_content.dart';
import 'run_event.dart';
import 'run_map.dart';
import 'run_node_type.dart';
import 'run_tuning.dart';
import 'run_state.dart';

/// 액션 로그에 현재 런에서 성립하지 않는 입력이 들어왔을 때 던진다.
///
/// UI와 저장 계층은 [legalRunActions]가 돌려준 값만 기록해야 한다. 불법 입력을
/// 조용히 무시하면 같은 로그를 재생할 때마다 어느 지점까지 믿을 수 있는지
/// 알 수 없어 §7.4의 복원 계약이 무너진다.
class IllegalRunActionError implements Exception {
  const IllegalRunActionError(this.message);

  final String message;

  @override
  String toString() => 'IllegalRunActionError: $message';
}

/// 런이 더 진행될 수 없는 결과. 전투 승리는 다음 노드로 이어지므로 여기에
/// 넣지 않는다.
enum RunOutcome { defeat }

/// 시드와 액션 로그에서 다시 만든 현재 런 진행 상태.
///
/// 이 값은 저장하지 않는다. [RunState]의 세 값과 버전 고정 [RunContent]를 매번
/// 재생해 만들므로, 체력·업·덱·적 구성·전투 결과가 저장 파일을 늘리지 않는다.
class RunProgress {
  RunProgress({
    required this.map,
    required List<int> visitedNodeIds,
    required this.hp,
    required this.maxHp,
    required this.karma,
    required this.money,
    List<CardDef>? deck,
    List<RunDeckCard>? deckCards,
    this.combat,
    this.pendingCardReward,
    this.pendingShop,
    this.pendingWildCamp,
    this.pendingEvent,
    this.outcome,
  }) : assert(deck != null || deckCards != null),
       visitedNodeIds = List.unmodifiable(visitedNodeIds),
       deckCards = List.unmodifiable(
         deckCards ?? _legacyDeckCards(deck ?? const <CardDef>[]),
       ),
       deck = List.unmodifiable(
         deck ??
             (deckCards ?? const <RunDeckCard>[]).map((entry) => entry.card),
       );

  final RunMap map;
  final List<int> visitedNodeIds;

  /// 런 전체에 이어지는 혼과 업. 전투 중에는 [combat]이 같은 값을 들고 있고,
  /// 전투가 끝나면 이 값으로 다시 접힌다.
  final int hp;
  final int maxHp;
  final int karma;

  /// 전투 승리 때 즉시 얻고, 이후 상점에서 쓸 런 지속 화폐.
  final int money;

  /// 전투 엔진에 넘길 카드 정의. 카드 제거의 안정적인 대상은 [deckCards]가
  /// 들고 있으므로 기존 호출자는 이 목록만 계속 읽으면 된다. [deck]만 넘기는
  /// 기존 프레젠테이션 테스트에는 임시 인스턴스 id를 만들어 호환한다.
  final List<CardDef> deck;

  /// 재생 가능한 카드 인스턴스 목록. 같은 카드 id가 여러 장 있어도 각각의
  /// [RunDeckCard.instanceId]가 시작 슬롯·보상 노드·상점 상품·사건 선택에 고정된다.
  final List<RunDeckCard> deckCards;

  /// 현재 전투 중이거나 패배로 끝난 전투 상태. 승리한 전투는 결과를 런 값으로
  /// 반영한 뒤 비워 다음 이동이 가능하게 한다.
  final CombatState? combat;

  /// 승리한 전투에서 다시 파생한 3택 1 후보. 저장하지 않고 액션 로그에서 복원한다.
  final CardReward? pendingCardReward;

  /// 비전투 노드는 선택이 끝날 때까지 이동을 잠근다. 후보·사건 자체는 모두
  /// 노드별 시드에서 다시 만들며 저장 대상이 아니다.
  final ShopInventory? pendingShop;
  final WildCampVisit? pendingWildCamp;
  final PendingRunEvent? pendingEvent;

  final RunOutcome? outcome;

  int? get currentNodeId => visitedNodeIds.isEmpty ? null : visitedNodeIds.last;

  RunNode? get currentNode =>
      currentNodeId == null ? null : map.nodeById(currentNodeId!);

  bool get isOver => outcome != null;

  bool get isInCombat => combat != null && !combat!.isOver;
}

/// 전투 승리 뒤 선택을 기다리는 카드 보상.
///
/// 후보는 저장 상태가 아니라 노드별 reward 시드에서 다시 뽑는다. [nodeId]는
/// 선택 액션이 현재 보상에 속하는지 검증하는 최소한의 문맥이다.
class CardReward {
  CardReward({required this.nodeId, required List<CardDef> cards})
    : cards = List.unmodifiable(cards);

  final int nodeId;
  final List<CardDef> cards;
}

/// 덱 안의 물리적 카드 한 장. id 중복이 가능한 [card]와 달리 [instanceId]는
/// 런 액션 로그를 재생했을 때 같은 한 장을 가리킨다.
class RunDeckCard {
  const RunDeckCard({required this.instanceId, required this.card});

  final String instanceId;
  final CardDef card;
}

/// 아직 떠나지 않은 상점의 남은 상품. 가격은 [RunTuning]에 있고, 목록은
/// 노드별 reward 시드에서 다시 뽑는다.
class ShopInventory {
  ShopInventory({required this.nodeId, required List<CardDef> cards})
    : cards = List.unmodifiable(cards);

  final int nodeId;
  final List<CardDef> cards;
}

/// 야장 선택 대기 상태. 강화는 후속 카드 모델 단계에서 붙일 자리다.
class WildCampVisit {
  const WildCampVisit({required this.nodeId});

  final int nodeId;
}

/// 노드별 reward 시드에서 골라진 사건과 아직 선택하지 않은 문맥.
class PendingRunEvent {
  const PendingRunEvent({required this.nodeId, required this.event});

  final int nodeId;
  final RunEventDef event;
}

/// 새 런의 저장 가능한 뼈대를 만든다.
RunState startRun({required int seed, required String characterId}) {
  return RunState(seed: seed, characterId: characterId, actionLog: const []);
}

/// 현재 런 상태에서 규칙상 가능한 모든 입력.
///
/// 전투 중에는 전투 액션 하나를 덧붙인 [CombatNodeLog]만 돌려준다. 런 엔진은
/// 손패나 대상 규칙을 판단하지 않고, 그 후보를 [legalActions]에 위임한다.
List<RunAction> legalRunActions(
  RunState state, {
  RunTuning tuning = RunTuning.m1,
  RunContent? content,
}) {
  final progress = replayRun(state, tuning: tuning, content: content);
  if (progress.isOver) return const [];

  final pendingCardReward = progress.pendingCardReward;
  if (pendingCardReward != null) {
    // §2.1은 카드 보상을 3택 1로 정한다. 덱을 얇게 유지하는 건 중요한 전략이지만,
    // 건너뛰기는 그 선택지를 명시하는 후속 기획이 생길 때까지 추가하지 않는다.
    return [
      for (final card in pendingCardReward.cards)
        ChooseCardReward(nodeId: pendingCardReward.nodeId, cardId: card.id),
    ];
  }

  final shop = progress.pendingShop;
  if (shop != null) {
    final canBuy = progress.money >= tuning.shopCardPrice;
    final canRemove =
        progress.money >= tuning.shopRemoveCardPrice &&
        progress.deckCards.length > 1;
    return [
      if (canBuy)
        for (final card in shop.cards)
          BuyShopCard(nodeId: shop.nodeId, cardId: card.id),
      if (canRemove)
        for (final card in progress.deckCards)
          RemoveShopCard(nodeId: shop.nodeId, cardInstanceId: card.instanceId),
      LeaveShop(nodeId: shop.nodeId),
    ];
  }

  final wildCamp = progress.pendingWildCamp;
  if (wildCamp != null) {
    return [
      ChooseWildCampOption(
        nodeId: wildCamp.nodeId,
        choice: WildCampChoice.rest,
      ),
      if (progress.karma >= tuning.wildCampRepentKarmaCleanse &&
          progress.money >= tuning.wildCampRepentMoneyCost)
        ChooseWildCampOption(
          nodeId: wildCamp.nodeId,
          choice: WildCampChoice.repent,
        ),
    ];
  }

  final pendingEvent = progress.pendingEvent;
  if (pendingEvent != null) {
    final karmaBand = tuning.karmaBandFor(progress.karma);
    return [
      for (final choice in pendingEvent.event.choices)
        if (choice.isAvailableIn(karmaBand) &&
            _canApplyEventDelta(progress, tuning.eventDeltaFor(choice.effect)))
          ChooseEventOption(nodeId: pendingEvent.nodeId, choiceId: choice.id),
    ];
  }

  if (progress.isInCombat) {
    final nodeId = progress.currentNodeId!;
    final actions = _currentCombatActions(state, nodeId);
    return [
      for (final action in legalActions(progress.combat!))
        CombatNodeLog(nodeId: nodeId, actions: [...actions, action]),
    ];
  }

  return [
    for (final nodeId in _legalNextNodeIds(progress))
      MoveToNode(nodeId: nodeId),
  ];
}

/// 런 액션 하나를 기록한 다음 저장 가능한 상태를 돌려준다.
///
/// [CombatNodeLog]는 전투 노드마다 하나만 두는 하위 로그 스냅샷이다. 전투
/// 액션을 받을 때마다 그 마지막 항목을 교체하므로, 앱이 턴 끝마다 저장해도
/// 최신 로그 하나만 남고 중단 지점까지 정확히 재생된다.
RunState applyRunAction(
  RunState state,
  RunAction action, {
  RunTuning tuning = RunTuning.m1,
  RunContent? content,
}) {
  final legal = legalRunActions(state, tuning: tuning, content: content);
  if (!legal.any((candidate) => _sameRunAction(candidate, action))) {
    throw IllegalRunActionError('현재 런 상태에서 기록할 수 없는 액션이다');
  }

  final replaceLastCombatLog =
      action is CombatNodeLog &&
      state.actionLog.isNotEmpty &&
      state.actionLog.last is CombatNodeLog &&
      (state.actionLog.last as CombatNodeLog).nodeId == action.nodeId;
  final nextLog = replaceLastCombatLog
      ? [...state.actionLog.sublist(0, state.actionLog.length - 1), action]
      : [...state.actionLog, action];

  return RunState(
    seed: state.seed,
    characterId: state.characterId,
    actionLog: nextLog,
  );
}

/// 저장된 런 로그를 처음부터 적용해 현재 상태를 복원한다.
///
/// [content]는 저장 대상이 아닌, 이 앱 버전에 함께 배포된 카드·적 정의다.
/// 콘텐츠를 생략한 호출은 M1-1 호환의 지도 전용 재생이며 전투를 시작하지
/// 않는다. 실제 런은 반드시 콘텐츠를 주입해 전투 노드를 복원한다.
RunProgress replayRun(
  RunState state, {
  RunTuning tuning = RunTuning.m1,
  RunContent? content,
}) {
  final map = generateActOneMap(state.seed, tuning: tuning);
  final visitedNodeIds = <int>[];
  final deckCards = _initialDeckCards(content?.deck ?? const <CardDef>[]);
  var hp = content?.maxHp ?? 0;
  final maxHp = content?.maxHp ?? 0;
  var karma = content?.startingKarma ?? 0;
  var money = content?.startingMoney ?? 0;
  CombatState? combat;
  CardReward? pendingCardReward;
  ShopInventory? pendingShop;
  WildCampVisit? pendingWildCamp;
  PendingRunEvent? pendingEvent;
  RunOutcome? outcome;
  final combatLogNodeIds = <int>{};

  for (final action in state.actionLog) {
    switch (action) {
      case MoveToNode(:final nodeId):
        if (outcome != null) {
          throw IllegalRunActionError('끝난 런에는 이동을 기록할 수 없다');
        }
        if (combat != null) {
          throw IllegalRunActionError('전투가 끝나기 전에는 다음 노드로 이동할 수 없다');
        }
        if (pendingCardReward != null) {
          throw IllegalRunActionError('카드 보상을 고르기 전에는 다음 노드로 이동할 수 없다');
        }
        if (pendingShop != null) {
          throw IllegalRunActionError('상점 선택을 끝내기 전에는 다음 노드로 이동할 수 없다');
        }
        if (pendingWildCamp != null) {
          throw IllegalRunActionError('야장 선택을 끝내기 전에는 다음 노드로 이동할 수 없다');
        }
        if (pendingEvent != null) {
          throw IllegalRunActionError('사건 선택을 끝내기 전에는 다음 노드로 이동할 수 없다');
        }

        final progress = RunProgress(
          map: map,
          visitedNodeIds: visitedNodeIds,
          hp: hp,
          maxHp: maxHp,
          karma: karma,
          money: money,
          deckCards: deckCards,
        );
        if (!_legalNextNodeIds(progress).contains(nodeId)) {
          throw IllegalRunActionError('로그가 현재 위치에서 갈 수 없는 노드 $nodeId를 가리킨다');
        }

        visitedNodeIds.add(nodeId);
        final node = map.nodeById(nodeId);
        if (content != null) {
          switch (node.type) {
            case RunNodeType.combat || RunNodeType.elite || RunNodeType.boss:
              combat = _beginNodeCombat(
                runSeed: state.seed,
                node: node,
                hp: hp,
                maxHp: maxHp,
                karma: karma,
                deck: deckCards.map((entry) => entry.card).toList(),
                content: content,
                tuning: tuning,
              );
            case RunNodeType.shop:
              pendingShop = shopInventoryForNode(
                runSeed: state.seed,
                node: node,
                content: content,
                tuning: tuning,
              );
            case RunNodeType.wildCamp:
              pendingWildCamp = WildCampVisit(nodeId: node.id);
            case RunNodeType.event:
              pendingEvent = PendingRunEvent(
                nodeId: node.id,
                event: eventForNode(
                  runSeed: state.seed,
                  node: node,
                  content: content,
                ),
              );
          }
        }

      case CombatNodeLog(:final nodeId, :final actions):
        if (outcome != null) {
          throw IllegalRunActionError('끝난 런에는 전투 입력을 기록할 수 없다');
        }
        if (visitedNodeIds.isEmpty || visitedNodeIds.last != nodeId) {
          throw IllegalRunActionError('전투 로그가 현재 노드와 맞지 않는다');
        }
        if (combat == null) {
          throw IllegalRunActionError('전투가 아닌 노드에는 전투 로그를 기록할 수 없다');
        }
        if (!combatLogNodeIds.add(nodeId)) {
          throw IllegalRunActionError('한 전투 노드에는 전투 로그를 하나만 기록할 수 있다');
        }

        var currentCombat = combat;
        for (final combatAction in actions) {
          final legal = legalActions(currentCombat);
          if (!legal.any(
            (candidate) => _sameCombatAction(candidate, combatAction),
          )) {
            throw IllegalRunActionError('전투 로그에 불법 전투 액션이 있다');
          }
          currentCombat = applyAction(currentCombat, combatAction).state;
        }

        switch (currentCombat.outcome) {
          case CombatOutcome.victory:
            hp = currentCombat.hp;
            karma = currentCombat.karma;
            combat = null;
            final node = map.nodeById(nodeId);
            money += moneyRewardForNode(node, tuning: tuning);
            pendingCardReward = cardRewardForNode(
              runSeed: state.seed,
              node: node,
              content: content!,
              tuning: tuning,
            );
          case CombatOutcome.defeat:
            hp = currentCombat.hp;
            karma = currentCombat.karma;
            combat = currentCombat;
            outcome = RunOutcome.defeat;
          case null:
            combat = currentCombat;
            break;
        }

      case ChooseCardReward(:final nodeId, :final cardId):
        if (outcome != null) {
          throw IllegalRunActionError('끝난 런에는 카드 보상을 고를 수 없다');
        }
        final reward = pendingCardReward;
        if (reward == null) {
          throw IllegalRunActionError('고를 카드 보상이 없다');
        }
        if (reward.nodeId != nodeId) {
          throw IllegalRunActionError('카드 보상 노드가 현재 보상과 맞지 않는다');
        }
        CardDef? selectedCard;
        for (final card in reward.cards) {
          if (card.id == cardId) {
            selectedCard = card;
            break;
          }
        }
        if (selectedCard == null) {
          throw IllegalRunActionError('카드 보상 후보에 없는 카드를 골랐다');
        }
        deckCards.add(
          RunDeckCard(
            instanceId: _rewardCardInstanceId(nodeId, selectedCard.id),
            card: selectedCard,
          ),
        );
        pendingCardReward = null;

      case BuyShopCard(:final nodeId, :final cardId):
        if (outcome != null) {
          throw IllegalRunActionError('끝난 런에는 상점 거래를 기록할 수 없다');
        }
        final shop = pendingShop;
        if (shop == null || shop.nodeId != nodeId) {
          throw IllegalRunActionError('현재 상점과 맞지 않는 구매다');
        }
        if (money < tuning.shopCardPrice) {
          throw IllegalRunActionError('상점 카드 가격을 낼 노잣돈이 없다');
        }
        CardDef? selectedCard;
        for (final card in shop.cards) {
          if (card.id == cardId) {
            selectedCard = card;
            break;
          }
        }
        if (selectedCard == null) {
          throw IllegalRunActionError('상점 상품에 없는 카드를 샀다');
        }
        money -= tuning.shopCardPrice;
        deckCards.add(
          RunDeckCard(
            instanceId: _shopCardInstanceId(nodeId, selectedCard.id),
            card: selectedCard,
          ),
        );
        pendingShop = ShopInventory(
          nodeId: nodeId,
          cards: shop.cards.where((card) => card.id != cardId).toList(),
        );

      case RemoveShopCard(:final nodeId, :final cardInstanceId):
        if (outcome != null) {
          throw IllegalRunActionError('끝난 런에는 상점 거래를 기록할 수 없다');
        }
        final shop = pendingShop;
        if (shop == null || shop.nodeId != nodeId) {
          throw IllegalRunActionError('현재 상점과 맞지 않는 카드 제거다');
        }
        if (money < tuning.shopRemoveCardPrice) {
          throw IllegalRunActionError('카드 제거 가격을 낼 노잣돈이 없다');
        }
        if (deckCards.length <= 1) {
          throw IllegalRunActionError('마지막 카드 한 장은 제거할 수 없다');
        }
        final index = deckCards.indexWhere(
          (card) => card.instanceId == cardInstanceId,
        );
        if (index < 0) {
          throw IllegalRunActionError('덱에 없는 카드 인스턴스를 제거할 수 없다');
        }
        money -= tuning.shopRemoveCardPrice;
        deckCards.removeAt(index);

      case LeaveShop(:final nodeId):
        if (outcome != null) {
          throw IllegalRunActionError('끝난 런에는 상점을 나갈 수 없다');
        }
        final shop = pendingShop;
        if (shop == null || shop.nodeId != nodeId) {
          throw IllegalRunActionError('현재 상점과 맞지 않는 종료다');
        }
        pendingShop = null;

      case ChooseWildCampOption(:final nodeId, :final choice):
        if (outcome != null) {
          throw IllegalRunActionError('끝난 런에는 야장 선택을 기록할 수 없다');
        }
        final wildCamp = pendingWildCamp;
        if (wildCamp == null || wildCamp.nodeId != nodeId) {
          throw IllegalRunActionError('현재 야장과 맞지 않는 선택이다');
        }
        switch (choice) {
          case WildCampChoice.rest:
            hp = _heal(hp, tuning.wildCampRestHeal, maxHp);
          case WildCampChoice.repent:
            if (karma < tuning.wildCampRepentKarmaCleanse ||
                money < tuning.wildCampRepentMoneyCost) {
              throw IllegalRunActionError('참회의 업 또는 노잣돈 대가를 낼 수 없다');
            }
            karma -= tuning.wildCampRepentKarmaCleanse;
            money -= tuning.wildCampRepentMoneyCost;
        }
        pendingWildCamp = null;

      case ChooseEventOption(:final nodeId, :final choiceId):
        if (outcome != null) {
          throw IllegalRunActionError('끝난 런에는 사건 선택을 기록할 수 없다');
        }
        final event = pendingEvent;
        if (event == null || event.nodeId != nodeId) {
          throw IllegalRunActionError('현재 사건과 맞지 않는 선택이다');
        }
        RunEventChoice? selectedChoice;
        for (final choice in event.event.choices) {
          if (choice.id == choiceId) {
            selectedChoice = choice;
            break;
          }
        }
        if (selectedChoice == null) {
          throw IllegalRunActionError('사건 선택지에 없는 값을 골랐다');
        }
        final delta = tuning.eventDeltaFor(selectedChoice.effect);
        final progress = RunProgress(
          map: map,
          visitedNodeIds: visitedNodeIds,
          hp: hp,
          maxHp: maxHp,
          karma: karma,
          money: money,
          deckCards: deckCards,
        );
        if (!selectedChoice.isAvailableIn(
          tuning.karmaBandFor(progress.karma),
        )) {
          throw IllegalRunActionError('현재 업 구간에는 없는 사건 선택지다');
        }
        if (!_canApplyEventDelta(progress, delta)) {
          throw IllegalRunActionError('사건 선택의 대가를 낼 수 없다');
        }
        hp = _heal(hp, delta.hp, maxHp);
        // 업 상한은 전투와 런 사이에 달라지면 안 된다. 사건도 전투 카드 효과와
        // 같은 상한을 적용해, 다음 전투에 들어갈 때만 값이 조용히 바뀌지 않게 한다.
        karma = (karma + delta.karma).clamp(0, CombatTuning.m0.maxKarma);
        money += delta.money;
        final gainedCardId = selectedChoice.gainedCardId;
        if (gainedCardId != null) {
          final card = _eventCardFor(content, gainedCardId);
          deckCards.add(
            RunDeckCard(
              instanceId: _eventCardInstanceId(
                nodeId,
                selectedChoice.id,
                card.id,
              ),
              card: card,
            ),
          );
        }
        pendingEvent = null;
    }
  }

  return RunProgress(
    map: map,
    visitedNodeIds: visitedNodeIds,
    hp: hp,
    maxHp: maxHp,
    karma: karma,
    money: money,
    deckCards: deckCards,
    combat: combat,
    pendingCardReward: pendingCardReward,
    pendingShop: pendingShop,
    pendingWildCamp: pendingWildCamp,
    pendingEvent: pendingEvent,
    outcome: outcome,
  );
}

/// 전투는 노드별로 독립된 시드를 쓴다.
///
/// 하나의 combat 스트림을 전투 사이에 이어 쓰면 앞 전투에서 카드 한 장을 더
/// 뽑은 변화가 다음 전투 손패까지 밀어 낸다. 런 시드와 노드 id로 전투 시드를
/// 파생한 뒤 `beginCombat`에 넘기면 같은 노드의 손패는 앞 전투 입력과 무관하고,
/// 저장 로그의 한 전투를 고쳐도 이후 전투를 독립적으로 재생할 수 있다.
int combatSeedForNode(int runSeed, int nodeId) =>
    _nodeSeed(runSeed, nodeId, 0xC2B2AE35);

/// 적 구성도 노드마다 분리한 encounter 스트림으로 뽑는다.
int encounterSeedForNode(int runSeed, int nodeId) =>
    _nodeSeed(runSeed, nodeId, 0x85EBCA6B);

/// 카드 보상도 노드별로 독립된 reward 시드를 쓴다.
///
/// 앞 노드에서 어느 보상을 골랐는지와 무관하게 다음 노드의 후보를 재생해야 한다.
/// combat·encounter 소금과 다른 값을 써서 스트림과 파생 시드가 겹치지 않게 한다.
int rewardSeedForNode(int runSeed, int nodeId) =>
    _nodeSeed(runSeed, nodeId, 0x27D4EB2F);

/// 상점 상품은 카드 보상과 같은 reward 스트림을 쓰되, 보상·전투·조우의 소금과
/// 겹치지 않는 노드별 시드를 쓴다. 앞 상점의 거래가 다음 상품을 밀지 않는다.
int shopSeedForNode(int runSeed, int nodeId) =>
    _nodeSeed(runSeed, nodeId, 0x165667B1);

/// 사건도 선택지를 저장하지 않고 노드별 reward 시드에서 다시 고른다.
int eventSeedForNode(int runSeed, int nodeId) =>
    _nodeSeed(runSeed, nodeId, 0xD3A2646C);

/// [RngStream.encounter]에서 현재 노드의 적을 결정론적으로 구성한다.
///
/// 정예와 보스의 전용 적은 아직 없으므로 [RunTuning]이 정한 수만큼 M0 적 풀을
/// 뽑는다. 전용 콘텐츠가 생기면 이 함수의 입력 풀만 역할별로 바꾸면 된다.
List<Enemy> encounterForNode({
  required int runSeed,
  required RunNode node,
  required RunContent content,
  RunTuning tuning = RunTuning.m1,
}) {
  if (!node.hostsCombat) {
    throw ArgumentError.value(node, 'node', '전투가 아닌 노드에는 적 구성이 없다');
  }

  final count = tuning.encounterSizeFor(node.type);
  if (count > content.encounterPool.length) {
    throw ArgumentError.value(
      count,
      'tuning encounter size',
      '적 풀보다 많은 서로 다른 적을 배치할 수 없다',
    );
  }

  var rng = Rng.forStream(
    encounterSeedForNode(runSeed, node.id),
    RngStream.encounter,
  );
  final available = List<Enemy>.of(content.encounterPool);
  final enemies = <Enemy>[];

  for (var i = 0; i < count; i++) {
    final (index, next) = rng.nextInt(available.length);
    rng = next;
    enemies.add(available.removeAt(index));
  }

  return List.unmodifiable(enemies);
}

/// 현재 노드의 카드 보상 후보를 `RngStream.reward`에서 뽑는다.
///
/// 정예는 유물이 없는 M1-3 동안 같은 카드 보상을 임시로 사용한다. 유물 콘텐츠가
/// 들어오면 이 함수가 정예의 유물 후보를 함께 만들 위치이며, 선택 기록은 여전히
/// 액션 로그만으로 복원되어야 한다.
CardReward cardRewardForNode({
  required int runSeed,
  required RunNode node,
  required RunContent content,
  RunTuning tuning = RunTuning.m1,
}) {
  if (!node.hostsCombat) {
    throw ArgumentError.value(node, 'node', '전투가 아닌 노드에는 카드 보상이 없다');
  }
  if (tuning.cardRewardChoiceCount > content.cardRewardPool.length) {
    throw ArgumentError.value(
      tuning.cardRewardChoiceCount,
      'tuning card reward choice count',
      '카드 보상 풀보다 많은 서로 다른 후보를 제시할 수 없다',
    );
  }

  var rng = Rng.forStream(
    rewardSeedForNode(runSeed, node.id),
    RngStream.reward,
  );
  final available = List<CardDef>.of(content.cardRewardPool);
  final cards = <CardDef>[];
  for (var i = 0; i < tuning.cardRewardChoiceCount; i++) {
    final (index, next) = rng.nextInt(available.length);
    rng = next;
    cards.add(available.removeAt(index));
  }

  return CardReward(nodeId: node.id, cards: cards);
}

/// 현재 상점의 서로 다른 상품 후보를 `RngStream.reward`에서 뽑는다.
ShopInventory shopInventoryForNode({
  required int runSeed,
  required RunNode node,
  required RunContent content,
  RunTuning tuning = RunTuning.m1,
}) {
  if (node.type != RunNodeType.shop) {
    throw ArgumentError.value(node, 'node', '상점이 아닌 노드에는 상품이 없다');
  }
  if (tuning.shopCardChoiceCount > content.shopCardPool.length) {
    throw ArgumentError.value(
      tuning.shopCardChoiceCount,
      'tuning shopCardChoiceCount',
      '상점 카드 풀보다 많은 서로 다른 상품을 제시할 수 없다',
    );
  }

  var rng = Rng.forStream(shopSeedForNode(runSeed, node.id), RngStream.reward);
  final available = List<CardDef>.of(content.shopCardPool);
  final cards = <CardDef>[];
  for (var i = 0; i < tuning.shopCardChoiceCount; i++) {
    final (index, next) = rng.nextInt(available.length);
    rng = next;
    cards.add(available.removeAt(index));
  }
  return ShopInventory(nodeId: node.id, cards: cards);
}

/// 현재 사건을 `RngStream.reward`에서 노드별로 독립적으로 고른다.
RunEventDef eventForNode({
  required int runSeed,
  required RunNode node,
  required RunContent content,
}) {
  if (node.type != RunNodeType.event) {
    throw ArgumentError.value(node, 'node', '사건이 아닌 노드에는 사건이 없다');
  }
  if (content.events.isEmpty) {
    throw ArgumentError.value(content.events, 'events', '사건 노드에는 사건 콘텐츠가 필요하다');
  }
  final (index, _) = Rng.forStream(
    eventSeedForNode(runSeed, node.id),
    RngStream.reward,
  ).nextInt(content.events.length);
  return content.events[index];
}

/// 전투 승리 때 즉시 얻는 노잣돈. 정예는 유물 보상 전까지 더 많은 화폐를 준다.
int moneyRewardForNode(RunNode node, {RunTuning tuning = RunTuning.m1}) {
  if (!node.hostsCombat) {
    throw ArgumentError.value(node, 'node', '전투가 아닌 노드에는 노잣돈 보상이 없다');
  }
  return switch (node.type) {
    RunNodeType.elite =>
      tuning.baseMoneyReward * tuning.eliteMoneyRewardMultiplier,
    RunNodeType.combat || RunNodeType.boss => tuning.baseMoneyReward,
    RunNodeType.shop ||
    RunNodeType.wildCamp ||
    RunNodeType.event => throw ArgumentError.value(
      node.type,
      'node.type',
      '전투가 아닌 노드에는 노잣돈 보상이 없다',
    ),
  };
}

CombatState _beginNodeCombat({
  required int runSeed,
  required RunNode node,
  required int hp,
  required int maxHp,
  required int karma,
  required List<CardDef> deck,
  required RunContent content,
  required RunTuning tuning,
}) {
  return beginCombat(
    seed: combatSeedForNode(runSeed, node.id),
    hp: hp,
    maxHp: maxHp,
    deck: deck,
    enemies: encounterForNode(
      runSeed: runSeed,
      node: node,
      content: content,
      tuning: tuning,
    ),
    karma: karma,
  ).state;
}

List<int> _legalNextNodeIds(RunProgress progress) {
  final currentNodeId = progress.currentNodeId;
  return currentNodeId == null
      ? [progress.map.nodes.first.id]
      : progress.map.nodeById(currentNodeId).nextNodeIds;
}

List<CombatAction> _currentCombatActions(RunState state, int nodeId) {
  if (state.actionLog.isEmpty) return const [];
  final last = state.actionLog.last;
  return switch (last) {
    CombatNodeLog(nodeId: final logNodeId, :final actions)
        when logNodeId == nodeId =>
      actions,
    _ => const [],
  };
}

bool _sameRunAction(RunAction left, RunAction right) => switch ((left, right)) {
  (
    MoveToNode(nodeId: final leftNodeId),
    MoveToNode(nodeId: final rightNodeId),
  ) =>
    leftNodeId == rightNodeId,
  (
    CombatNodeLog(nodeId: final leftNodeId, actions: final leftActions),
    CombatNodeLog(nodeId: final rightNodeId, actions: final rightActions),
  ) =>
    leftNodeId == rightNodeId &&
        _sameCombatActionLists(leftActions, rightActions),
  (
    ChooseCardReward(nodeId: final leftNodeId, cardId: final leftCardId),
    ChooseCardReward(nodeId: final rightNodeId, cardId: final rightCardId),
  ) =>
    leftNodeId == rightNodeId && leftCardId == rightCardId,
  (
    BuyShopCard(nodeId: final leftNodeId, cardId: final leftCardId),
    BuyShopCard(nodeId: final rightNodeId, cardId: final rightCardId),
  ) =>
    leftNodeId == rightNodeId && leftCardId == rightCardId,
  (
    RemoveShopCard(
      nodeId: final leftNodeId,
      cardInstanceId: final leftCardInstanceId,
    ),
    RemoveShopCard(
      nodeId: final rightNodeId,
      cardInstanceId: final rightCardInstanceId,
    ),
  ) =>
    leftNodeId == rightNodeId && leftCardInstanceId == rightCardInstanceId,
  (LeaveShop(nodeId: final leftNodeId), LeaveShop(nodeId: final rightNodeId)) =>
    leftNodeId == rightNodeId,
  (
    ChooseWildCampOption(nodeId: final leftNodeId, choice: final leftChoice),
    ChooseWildCampOption(nodeId: final rightNodeId, choice: final rightChoice),
  ) =>
    leftNodeId == rightNodeId && leftChoice == rightChoice,
  (
    ChooseEventOption(nodeId: final leftNodeId, choiceId: final leftChoiceId),
    ChooseEventOption(nodeId: final rightNodeId, choiceId: final rightChoiceId),
  ) =>
    leftNodeId == rightNodeId && leftChoiceId == rightChoiceId,
  _ => false,
};

bool _sameCombatActionLists(List<CombatAction> left, List<CombatAction> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (!_sameCombatAction(left[i], right[i])) return false;
  }
  return true;
}

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

int _nodeSeed(int runSeed, int nodeId, int salt) {
  const mask = 0xFFFFFFFF;
  var mixed = (runSeed ^ salt ^ (nodeId + 1) * 0x9E3779B9) & mask;
  mixed ^= mixed >> 16;
  mixed = (mixed * 0x85EBCA6B) & mask;
  mixed ^= mixed >> 13;
  mixed = (mixed * 0xC2B2AE35) & mask;
  return (mixed ^ (mixed >> 16)) & mask;
}

List<RunDeckCard> _initialDeckCards(List<CardDef> cards) => [
  for (var index = 0; index < cards.length; index++)
    RunDeckCard(
      // 고정 콘텐츠의 시작 덱 슬롯은 앞선 런 액션과 무관하다. 같은 카드 id가
      // 두 번 있어도 각각의 슬롯이 남으므로 카드 제거 로그가 다른 사본을 지우지
      // 않는다.
      instanceId: 'start:$index:${cards[index].id}',
      card: cards[index],
    ),
];

List<RunDeckCard> _legacyDeckCards(List<CardDef> cards) => [
  for (var index = 0; index < cards.length; index++)
    RunDeckCard(
      instanceId: 'legacy:$index:${cards[index].id}',
      card: cards[index],
    ),
];

String _rewardCardInstanceId(int nodeId, String cardId) =>
    'reward:$nodeId:$cardId';

String _shopCardInstanceId(int nodeId, String cardId) => 'shop:$nodeId:$cardId';

String _eventCardInstanceId(int nodeId, String choiceId, String cardId) =>
    'event:$nodeId:$choiceId:$cardId';

CardDef _eventCardFor(RunContent? content, String cardId) {
  if (content == null) {
    throw StateError('사건 카드 보상에는 런 콘텐츠가 필요하다');
  }
  for (final card in content.cardRewardPool) {
    if (card.id == cardId) return card;
  }
  throw IllegalRunActionError('사건이 카드 보상 풀에 없는 카드 $cardId를 가리킨다');
}

bool _canApplyEventDelta(RunProgress progress, RunEventDelta delta) {
  // 체력 비용으로 사건에서 죽는 선택지는 내지 않는다. 회복은 최대 체력에서
  // 멈추고, 정화량보다 업이 적거나 노잣돈이 모자란 경우도 비용을 낼 수 없다.
  return progress.hp + delta.hp > 0 &&
      progress.karma + delta.karma >= 0 &&
      progress.money + delta.money >= 0;
}

int _heal(int hp, int amount, int maxHp) {
  final next = hp + amount;
  if (next < 1) return 1;
  return next > maxHp ? maxHp : next;
}
