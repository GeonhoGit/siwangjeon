import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/m1_events.dart';
import 'package:siwangjeon/data/run_storage.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/rng/rng.dart';
import 'package:siwangjeon/domain/run/run_action.dart';
import 'package:siwangjeon/domain/run/run_content.dart';
import 'package:siwangjeon/domain/run/run_engine.dart';
import 'package:siwangjeon/domain/run/run_event.dart';
import 'package:siwangjeon/domain/run/run_map.dart';
import 'package:siwangjeon/domain/run/run_node_type.dart';
import 'package:siwangjeon/domain/run/run_state.dart';
import 'package:siwangjeon/domain/run/run_tuning.dart';

const _duplicateStrike = CardDef(
  id: 'node_test_strike',
  name: '중복 타격',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 1)],
);

const _defend = CardDef(
  id: 'node_test_defend',
  name: '시험 방어',
  type: CardType.skill,
  cost: 0,
  targeted: false,
  effects: [BlockEffect(1)],
);

const _shopA = CardDef(
  id: 'node_test_shop_a',
  name: '상점 갑',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 2)],
);

const _shopB = CardDef(
  id: 'node_test_shop_b',
  name: '상점 을',
  type: CardType.skill,
  cost: 0,
  targeted: false,
  effects: [BlockEffect(2)],
);

const _shopC = CardDef(
  id: 'node_test_shop_c',
  name: '상점 병',
  type: CardType.power,
  cost: 0,
  targeted: false,
  effects: [BlockEffect(3)],
);

const _shopD = CardDef(
  id: 'node_test_shop_d',
  name: '상점 정',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 4)],
);

const _shopTuning = RunTuning(
  nodeTypeWeights: [RunNodeWeight(RunNodeType.shop, 1)],
  shopCardChoiceCount: 3,
  shopCardPrice: 20,
  shopRemoveCardPrice: 30,
);

const _wildCampTuning = RunTuning(
  nodeTypeWeights: [RunNodeWeight(RunNodeType.wildCamp, 1)],
  wildCampRestHeal: 18,
  wildCampRepentKarmaCleanse: 3,
  wildCampRepentMoneyCost: 25,
);

const _eventThenWildCampTuning = RunTuning(
  nodeTypeWeights: [
    RunNodeWeight(RunNodeType.event, 1),
    RunNodeWeight(RunNodeType.wildCamp, 1),
  ],
  wildCampRestHeal: 5,
  wildCampRepentKarmaCleanse: 3,
  wildCampRepentMoneyCost: 25,
);

const _eventTuning = RunTuning(
  nodeTypeWeights: [RunNodeWeight(RunNodeType.event, 1)],
);

void main() {
  group('M1 상점 런 재생', () {
    test('구매는 노잣돈을 쓰고 덱에 넣으며, 중복 카드도 의도한 인스턴스만 제거한다', () {
      final content = _content(startingMoney: 100);
      final entered = _enterFirstNode(
        seed: 301,
        content: content,
        tuning: _shopTuning,
      );
      final before = replayRun(entered, tuning: _shopTuning, content: content);

      expect(before.pendingShop, isNotNull);
      expect(
        legalRunActions(
          entered,
          tuning: _shopTuning,
          content: content,
        ).whereType<MoveToNode>(),
        isEmpty,
      );

      final purchase = legalRunActions(
        entered,
        tuning: _shopTuning,
        content: content,
      ).whereType<BuyShopCard>().first;
      final bought = applyRunAction(
        entered,
        purchase,
        tuning: _shopTuning,
        content: content,
      );
      final afterBuy = replayRun(bought, tuning: _shopTuning, content: content);

      expect(afterBuy.money, 80);
      expect(afterBuy.deck.map((card) => card.id), contains(purchase.cardId));

      final removeSecondStrike =
          legalRunActions(
            bought,
            tuning: _shopTuning,
            content: content,
          ).whereType<RemoveShopCard>().firstWhere(
            (action) =>
                action.cardInstanceId == 'start:1:${_duplicateStrike.id}',
          );
      final removed = applyRunAction(
        bought,
        removeSecondStrike,
        tuning: _shopTuning,
        content: content,
      );
      final afterRemove = replayRun(
        removed,
        tuning: _shopTuning,
        content: content,
      );

      expect(afterRemove.money, 50);
      expect(
        afterRemove.deckCards.map((card) => card.instanceId),
        isNot(contains('start:1:${_duplicateStrike.id}')),
      );
      expect(
        afterRemove.deckCards.map((card) => card.instanceId),
        contains('start:0:${_duplicateStrike.id}'),
      );
      expect(
        legalRunActions(
          removed,
          tuning: _shopTuning,
          content: content,
        ).whereType<MoveToNode>(),
        isEmpty,
      );

      final left = applyRunAction(
        removed,
        legalRunActions(
          removed,
          tuning: _shopTuning,
          content: content,
        ).whereType<LeaveShop>().single,
        tuning: _shopTuning,
        content: content,
      );
      expect(
        legalRunActions(
          left,
          tuning: _shopTuning,
          content: content,
        ).whereType<MoveToNode>(),
        isNotEmpty,
      );
    });

    test('노잣돈이 모자라면 구매와 제거가 legalRunActions에 없다', () {
      final content = _content(startingMoney: 19);
      final entered = _enterFirstNode(
        seed: 302,
        content: content,
        tuning: _shopTuning,
      );
      final legal = legalRunActions(
        entered,
        tuning: _shopTuning,
        content: content,
      );

      expect(legal.whereType<BuyShopCard>(), isEmpty);
      expect(legal.whereType<RemoveShopCard>(), isEmpty);
      expect(legal.whereType<LeaveShop>(), hasLength(1));
    });

    test('상품은 노드별 파생 reward 스트림에서 독립적으로 다시 뽑는다', () {
      final content = _content(startingMoney: 100);
      final entered = _enterFirstNode(
        seed: 303,
        content: content,
        tuning: _shopTuning,
      );
      final node = replayRun(
        entered,
        tuning: _shopTuning,
        content: content,
      ).currentNode!;
      final inventory = shopInventoryForNode(
        runSeed: entered.seed,
        node: node,
        content: content,
        tuning: _shopTuning,
      );

      var rng = Rng.forStream(
        shopSeedForNode(entered.seed, node.id),
        RngStream.reward,
      );
      final available = List<CardDef>.of(content.shopCardPool);
      final expected = <String>[];
      for (var index = 0; index < _shopTuning.shopCardChoiceCount; index++) {
        final (choice, next) = rng.nextInt(available.length);
        rng = next;
        expected.add(available.removeAt(choice).id);
      }

      expect(inventory.cards.map((card) => card.id), expected);
      expect(
        shopInventoryForNode(
          runSeed: entered.seed,
          node: node,
          content: content,
          tuning: _shopTuning,
        ).cards.map((card) => card.id),
        expected,
      );
      expect(
        shopSeedForNode(entered.seed, node.id),
        isNot(rewardSeedForNode(entered.seed, node.id)),
      );
      final otherShop = generateActOneMap(entered.seed, tuning: _shopTuning)
          .nodes
          .firstWhere(
            (candidate) =>
                candidate.id != node.id && candidate.type == RunNodeType.shop,
          );
      expect(
        shopSeedForNode(entered.seed, otherShop.id),
        isNot(shopSeedForNode(entered.seed, node.id)),
      );
    });
  });

  group('M1 야장 런 재생', () {
    test('휴식은 체력을 회복하고 참회는 업과 노잣돈을 함께 줄인다', () {
      final restContent = _content(
        maxHp: 80,
        startingKarma: 10,
        startingMoney: 200,
        events: m1Events,
      );
      final route = _eventThenWildCamp(restContent);
      var resting = startRun(seed: route.seed, characterId: 'm0');
      resting = applyRunAction(
        resting,
        legalRunActions(
          resting,
          tuning: _eventThenWildCampTuning,
          content: restContent,
        ).whereType<MoveToNode>().single,
        tuning: _eventThenWildCampTuning,
        content: restContent,
      );
      final pendingEvent = replayRun(
        resting,
        tuning: _eventThenWildCampTuning,
        content: restContent,
      ).pendingEvent!;
      final eventChoice =
          legalRunActions(
            resting,
            tuning: _eventThenWildCampTuning,
            content: restContent,
          ).whereType<ChooseEventOption>().firstWhere((action) {
            final choice = pendingEvent.event.choices.firstWhere(
              (choice) => choice.id == action.choiceId,
            );
            return _eventThenWildCampTuning.eventDeltaFor(choice.effect).hp < 0;
          });
      resting = applyRunAction(
        resting,
        eventChoice,
        tuning: _eventThenWildCampTuning,
        content: restContent,
      );
      final wounded = replayRun(
        resting,
        tuning: _eventThenWildCampTuning,
        content: restContent,
      );
      expect(wounded.hp, lessThan(restContent.maxHp));
      resting = applyRunAction(
        resting,
        MoveToNode(nodeId: route.wildCampNodeId),
        tuning: _eventThenWildCampTuning,
        content: restContent,
      );
      final rested = applyRunAction(
        resting,
        legalRunActions(
          resting,
          tuning: _eventThenWildCampTuning,
          content: restContent,
        ).whereType<ChooseWildCampOption>().firstWhere(
          (action) => action.choice == WildCampChoice.rest,
        ),
        tuning: _eventThenWildCampTuning,
        content: restContent,
      );
      final afterRest = replayRun(
        rested,
        tuning: _eventThenWildCampTuning,
        content: restContent,
      );

      expect(
        afterRest.hp,
        wounded.hp + _eventThenWildCampTuning.wildCampRestHeal,
      );
      expect(afterRest.karma, wounded.karma);
      expect(afterRest.money, wounded.money);

      final repentContent = _content(startingKarma: 5, startingMoney: 100);
      final repenting = _enterFirstNode(
        seed: 305,
        content: repentContent,
        tuning: _wildCampTuning,
      );
      final repented = applyRunAction(
        repenting,
        legalRunActions(
          repenting,
          tuning: _wildCampTuning,
          content: repentContent,
        ).whereType<ChooseWildCampOption>().firstWhere(
          (action) => action.choice == WildCampChoice.repent,
        ),
        tuning: _wildCampTuning,
        content: repentContent,
      );
      final afterRepent = replayRun(
        repented,
        tuning: _wildCampTuning,
        content: repentContent,
      );

      expect(afterRepent.hp, repentContent.maxHp);
      expect(afterRepent.karma, 2);
      expect(afterRepent.money, 75);
    });
  });

  group('M1 사건 런 재생', () {
    test('사건은 노드별 파생 reward 스트림에서 다시 고른다', () {
      final content = _content(events: m1Events);
      final entered = _enterFirstNode(
        seed: 309,
        content: content,
        tuning: _eventTuning,
      );
      final node = replayRun(
        entered,
        tuning: _eventTuning,
        content: content,
      ).currentNode!;
      final expectedIndex = Rng.forStream(
        eventSeedForNode(entered.seed, node.id),
        RngStream.reward,
      ).nextInt(m1Events.length).$1;

      expect(
        eventForNode(runSeed: entered.seed, node: node, content: content).id,
        m1Events[expectedIndex].id,
      );
      expect(
        eventSeedForNode(entered.seed, node.id),
        isNot(rewardSeedForNode(entered.seed, node.id)),
      );
      expect(
        eventSeedForNode(entered.seed, node.id),
        isNot(shopSeedForNode(entered.seed, node.id)),
      );
    });

    test('사건의 업 증가는 전투와 같은 100 상한을 넘지 않는다', () {
      final event = m1Events.first;
      final content = _content(
        startingKarma: 100,
        startingMoney: 200,
        events: [event],
      );
      final entered = _enterFirstNode(
        seed: 310,
        content: content,
        tuning: _eventTuning,
      );
      final accepted =
          legalRunActions(entered, tuning: _eventTuning, content: content)
              .whereType<ChooseEventOption>()
              .firstWhere((action) => action.choiceId == 'accept');

      final progress = replayRun(
        applyRunAction(
          entered,
          accepted,
          tuning: _eventTuning,
          content: content,
        ),
        tuning: _eventTuning,
        content: content,
      );
      expect(progress.karma, 100);
    });

    test('사건 8종의 모든 선택지는 업 축의 의도한 상태 변화를 만든다', () {
      expect(m1Events, hasLength(8));
      expect(m1Events.every((event) => event.choices.length == 2), isTrue);

      for (final event in m1Events) {
        final content = _content(
          maxHp: 100,
          startingKarma: 10,
          startingMoney: 200,
          events: [event],
        );
        final entered = _enterFirstNode(
          seed: 306,
          content: content,
          tuning: _eventTuning,
        );
        final pending = replayRun(
          entered,
          tuning: _eventTuning,
          content: content,
        ).pendingEvent;

        expect(pending!.event.id, event.id);
        expect(
          legalRunActions(
            entered,
            tuning: _eventTuning,
            content: content,
          ).whereType<MoveToNode>(),
          isEmpty,
        );
        for (final choice in event.choices) {
          final selected = applyRunAction(
            entered,
            legalRunActions(entered, tuning: _eventTuning, content: content)
                .whereType<ChooseEventOption>()
                .firstWhere((action) => action.choiceId == choice.id),
            tuning: _eventTuning,
            content: content,
          );
          final progress = replayRun(
            selected,
            tuning: _eventTuning,
            content: content,
          );
          final delta = _eventTuning.eventDeltaFor(choice.effect);

          expect(progress.hp, (100 + delta.hp).clamp(1, 100));
          expect(progress.karma, 10 + delta.karma);
          expect(progress.money, 200 + delta.money);
          expect(progress.pendingEvent, isNull);
        }
      }
    });
  });

  test('같은 시드와 상점 액션 열은 덱·노잣돈·체력·업까지 같은 상태를 낸다', () {
    final content = _content(startingMoney: 100);
    final completed = _completeShop(seed: 307, content: content);
    final replayed = replayRun(
      RunState(
        seed: completed.seed,
        characterId: completed.characterId,
        actionLog: completed.actionLog,
      ),
      tuning: _shopTuning,
      content: content,
    );
    final expected = replayRun(
      completed,
      tuning: _shopTuning,
      content: content,
    );

    expect(
      replayed.deckCards.map((card) => card.instanceId),
      expected.deckCards.map((card) => card.instanceId),
    );
    expect(replayed.money, expected.money);
    expect(replayed.hp, expected.hp);
    expect(replayed.karma, expected.karma);
  });

  test('새 상점 액션 저장 왕복도 같은 런 상태를 재생한다', () {
    final content = _content(startingMoney: 100);
    final state = _completeShop(seed: 308, content: content);
    final restored = const RunSaveCodec().decode(
      const RunSaveCodec().encode(state),
    );
    final expected = replayRun(state, tuning: _shopTuning, content: content);
    final actual = replayRun(restored, tuning: _shopTuning, content: content);

    expect(
      actual.deckCards.map((card) => card.instanceId),
      expected.deckCards.map((card) => card.instanceId),
    );
    expect(actual.money, expected.money);
    expect(actual.hp, expected.hp);
    expect(actual.karma, expected.karma);
  });
}

RunContent _content({
  int maxHp = 80,
  int startingKarma = 0,
  int startingMoney = 0,
  List<RunEventDef> events = const [],
}) => RunContent(
  maxHp: maxHp,
  deck: const [_duplicateStrike, _duplicateStrike, _defend],
  encounterPool: [_enemy('node_test_enemy_a')],
  startingKarma: startingKarma,
  startingMoney: startingMoney,
  cardRewardPool: const [_shopA, _shopB, _shopC, _shopD],
  shopCardPool: const [_shopA, _shopB, _shopC, _shopD],
  events: events,
);

Enemy _enemy(String id) =>
    Enemy(id: id, name: id, hp: 1, maxHp: 1, pattern: const [EnemyDefend(0)]);

RunState _enterFirstNode({
  required int seed,
  required RunContent content,
  required RunTuning tuning,
}) {
  final state = startRun(seed: seed, characterId: 'm0');
  return applyRunAction(
    state,
    legalRunActions(
      state,
      tuning: tuning,
      content: content,
    ).whereType<MoveToNode>().single,
    tuning: tuning,
    content: content,
  );
}

RunState _completeShop({required int seed, required RunContent content}) {
  final entered = _enterFirstNode(
    seed: seed,
    content: content,
    tuning: _shopTuning,
  );
  final bought = applyRunAction(
    entered,
    legalRunActions(
      entered,
      tuning: _shopTuning,
      content: content,
    ).whereType<BuyShopCard>().first,
    tuning: _shopTuning,
    content: content,
  );
  final removed = applyRunAction(
    bought,
    legalRunActions(bought, tuning: _shopTuning, content: content)
        .whereType<RemoveShopCard>()
        .firstWhere((action) => action.cardInstanceId.startsWith('start:')),
    tuning: _shopTuning,
    content: content,
  );
  return applyRunAction(
    removed,
    legalRunActions(
      removed,
      tuning: _shopTuning,
      content: content,
    ).whereType<LeaveShop>().single,
    tuning: _shopTuning,
    content: content,
  );
}

({int seed, int wildCampNodeId}) _eventThenWildCamp(RunContent content) {
  for (var seed = 0; seed < 10000; seed++) {
    final map = generateActOneMap(seed, tuning: _eventThenWildCampTuning);
    final first = map.nodes.first;
    if (first.type != RunNodeType.event) continue;
    final event = eventForNode(runSeed: seed, node: first, content: content);
    if (!event.choices.any(
      (choice) => _eventThenWildCampTuning.eventDeltaFor(choice.effect).hp < 0,
    )) {
      continue;
    }
    for (final nextNodeId in first.nextNodeIds) {
      if (map.nodeById(nextNodeId).type == RunNodeType.wildCamp) {
        return (seed: seed, wildCampNodeId: nextNodeId);
      }
    }
  }
  throw StateError('체력 대가 사건 뒤 야장 경로를 찾지 못했다');
}
