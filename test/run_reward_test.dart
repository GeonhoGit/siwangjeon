import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/combat_action.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/rng/rng.dart';
import 'package:siwangjeon/domain/run/run_action.dart';
import 'package:siwangjeon/domain/run/run_content.dart';
import 'package:siwangjeon/domain/run/run_engine.dart';
import 'package:siwangjeon/domain/run/run_map.dart';
import 'package:siwangjeon/domain/run/run_node_type.dart';
import 'package:siwangjeon/domain/run/run_state.dart';
import 'package:siwangjeon/domain/run/run_tuning.dart';

const _rewardTuning = RunTuning(
  nodeTypeWeights: [RunNodeWeight(RunNodeType.combat, 1)],
  cardRewardChoiceCount: 3,
  baseMoneyReward: 17,
  eliteMoneyRewardMultiplier: 3,
);

const _finisher = CardDef(
  id: 'test_reward_finisher',
  name: '보상 시험 일격',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 999)],
);

const _rewardA = CardDef(
  id: 'test_reward_a',
  name: '보상 갑',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 999)],
);

const _rewardB = CardDef(
  id: 'test_reward_b',
  name: '보상 을',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 999)],
);

const _rewardC = CardDef(
  id: 'test_reward_c',
  name: '보상 병',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 999)],
);

const _rewardD = CardDef(
  id: 'test_reward_d',
  name: '보상 정',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 999)],
);

void main() {
  group('M1-3 전투 보상 런 재생', () {
    test('전투 승리는 카드 후보 3장과 노잣돈을 만들고 선택을 기다린다', () {
      final content = _rewardContent();
      final won = _winCurrentCombat(
        _enterFirstCombat(seed: 81, content: content),
        content: content,
      );
      final progress = replayRun(won, tuning: _rewardTuning, content: content);
      final legal = legalRunActions(
        won,
        tuning: _rewardTuning,
        content: content,
      );

      expect(progress.money, _rewardTuning.baseMoneyReward);
      expect(progress.pendingCardReward!.cards, hasLength(3));
      expect(
        progress.pendingCardReward!.cards.map((card) => card.id).toSet(),
        hasLength(3),
      );
      expect(legal, hasLength(3));
      expect(legal, everyElement(isA<ChooseCardReward>()));
      expect(legal.whereType<MoveToNode>(), isEmpty);
    });

    test('카드 후보는 노드별 reward 스트림에서 뽑고 encounter 구성은 유지한다', () {
      final content = _rewardContent();
      final entered = _enterFirstCombat(seed: 82, content: content);
      final beforeVictory = replayRun(
        entered,
        tuning: _rewardTuning,
        content: content,
      );
      final node = beforeVictory.currentNode!;
      final expectedEncounter = encounterForNode(
        runSeed: entered.seed,
        node: node,
        content: content,
        tuning: _rewardTuning,
      );
      final won = _winCurrentCombat(entered, content: content);
      final reward = replayRun(
        won,
        tuning: _rewardTuning,
        content: content,
      ).pendingCardReward!;

      var rng = Rng.forStream(
        rewardSeedForNode(entered.seed, node.id),
        RngStream.reward,
      );
      final available = List<CardDef>.of(content.cardRewardPool);
      final expectedRewardIds = <String>[];
      for (var i = 0; i < _rewardTuning.cardRewardChoiceCount; i++) {
        final (index, next) = rng.nextInt(available.length);
        rng = next;
        expectedRewardIds.add(available.removeAt(index).id);
      }

      expect(
        beforeVictory.combat!.enemies.map((enemy) => enemy.id),
        expectedEncounter.map((enemy) => enemy.id),
      );
      expect(reward.cards.map((card) => card.id), expectedRewardIds);
      expect(
        rewardSeedForNode(entered.seed, node.id),
        isNot(combatSeedForNode(entered.seed, node.id)),
      );
      expect(
        rewardSeedForNode(entered.seed, node.id),
        isNot(encounterSeedForNode(entered.seed, node.id)),
      );
    });

    test('선택한 카드가 다음 전투의 실제 덱에 들어간다', () {
      final content = _rewardContent();
      final won = _winCurrentCombat(
        _enterFirstCombat(seed: 83, content: content),
        content: content,
      );
      final choice = _rewardChoices(won, content: content).first;
      final selected = applyRunAction(
        won,
        choice,
        tuning: _rewardTuning,
        content: content,
      );
      final selectedProgress = replayRun(
        selected,
        tuning: _rewardTuning,
        content: content,
      );
      final next = applyRunAction(
        selected,
        _nextMove(selected, content: content),
        tuning: _rewardTuning,
        content: content,
      );
      final nextCombat = replayRun(
        next,
        tuning: _rewardTuning,
        content: content,
      ).combat!;
      final nextCombatCards = [
        ...nextCombat.hand,
        ...nextCombat.drawPile,
        ...nextCombat.discardPile,
        ...nextCombat.activePowers,
      ];

      expect(selectedProgress.deck, hasLength(9));
      expect(
        selectedProgress.deck.map((card) => card.id),
        contains(choice.cardId),
      );
      expect(nextCombatCards.map((card) => card.id), contains(choice.cardId));
    });

    test('같은 시드와 같은 보상 선택 액션은 덱과 노잣돈까지 같다', () {
      final content = _rewardContent();
      final leftWon = _winCurrentCombat(
        _enterFirstCombat(seed: 84, content: content),
        content: content,
      );
      final rightWon = _winCurrentCombat(
        _enterFirstCombat(seed: 84, content: content),
        content: content,
      );
      final choice = _rewardChoices(leftWon, content: content).last;
      final left = applyRunAction(
        leftWon,
        choice,
        tuning: _rewardTuning,
        content: content,
      );
      final right = applyRunAction(
        rightWon,
        choice,
        tuning: _rewardTuning,
        content: content,
      );
      final leftProgress = replayRun(
        left,
        tuning: _rewardTuning,
        content: content,
      );
      final rightProgress = replayRun(
        right,
        tuning: _rewardTuning,
        content: content,
      );

      expect(left.actionLog, hasLength(right.actionLog.length));
      expect(
        (left.actionLog.last as ChooseCardReward).cardId,
        (right.actionLog.last as ChooseCardReward).cardId,
      );
      expect(leftProgress.money, rightProgress.money);
      expect(
        leftProgress.deck.map((card) => card.id),
        rightProgress.deck.map((card) => card.id),
      );
      expect(leftProgress.pendingCardReward, isNull);
      expect(rightProgress.pendingCardReward, isNull);
    });

    test('앞 노드의 보상 선택이 달라도 다음 노드의 후보는 같다', () {
      final content = _rewardContent();
      final first = _winCurrentCombat(
        _enterFirstCombat(seed: 85, content: content),
        content: content,
      );
      final second = _winCurrentCombat(
        _enterFirstCombat(seed: 85, content: content),
        content: content,
      );
      final choseFirst = applyRunAction(
        first,
        _rewardChoices(first, content: content).first,
        tuning: _rewardTuning,
        content: content,
      );
      final choseSecond = applyRunAction(
        second,
        _rewardChoices(second, content: content).last,
        tuning: _rewardTuning,
        content: content,
      );
      final nextFirst = _winCurrentCombat(
        applyRunAction(
          choseFirst,
          _nextMove(choseFirst, content: content),
          tuning: _rewardTuning,
          content: content,
        ),
        content: content,
      );
      final nextSecond = _winCurrentCombat(
        applyRunAction(
          choseSecond,
          _nextMove(choseSecond, content: content),
          tuning: _rewardTuning,
          content: content,
        ),
        content: content,
      );
      final firstCandidates = replayRun(
        nextFirst,
        tuning: _rewardTuning,
        content: content,
      ).pendingCardReward!.cards;
      final secondCandidates = replayRun(
        nextSecond,
        tuning: _rewardTuning,
        content: content,
      ).pendingCardReward!.cards;

      expect(
        firstCandidates.map((card) => card.id),
        secondCandidates.map((card) => card.id),
      );
    });

    test('보상 선택 전 이동은 legalRunActions에서 제외되고 적용도 거부된다', () {
      final content = _rewardContent();
      final won = _winCurrentCombat(
        _enterFirstCombat(seed: 86, content: content),
        content: content,
      );
      final progress = replayRun(won, tuning: _rewardTuning, content: content);
      final nextNodeId = progress.currentNode!.nextNodeIds.first;

      expect(
        legalRunActions(
          won,
          tuning: _rewardTuning,
          content: content,
        ).whereType<MoveToNode>(),
        isEmpty,
      );
      expect(
        () => applyRunAction(
          won,
          MoveToNode(nodeId: nextNodeId),
          tuning: _rewardTuning,
          content: content,
        ),
        throwsA(isA<IllegalRunActionError>()),
      );
    });

    test('보상 선택까지의 액션 로그 접두사는 그 시점 상태를 재생한다', () {
      final content = _rewardContent();
      final won = _winCurrentCombat(
        _enterFirstCombat(seed: 87, content: content),
        content: content,
      );
      final selected = applyRunAction(
        won,
        _rewardChoices(won, content: content).first,
        tuning: _rewardTuning,
        content: content,
      );
      final continued = applyRunAction(
        selected,
        _nextMove(selected, content: content),
        tuning: _rewardTuning,
        content: content,
      );
      final restored = replayRun(
        RunState(
          seed: continued.seed,
          characterId: continued.characterId,
          actionLog: continued.actionLog.take(3).toList(),
        ),
        tuning: _rewardTuning,
        content: content,
      );
      final expected = replayRun(
        selected,
        tuning: _rewardTuning,
        content: content,
      );

      expect(restored.currentNodeId, expected.currentNodeId);
      expect(restored.money, expected.money);
      expect(restored.karma, expected.karma);
      expect(restored.pendingCardReward, isNull);
      expect(
        restored.deck.map((card) => card.id),
        expected.deck.map((card) => card.id),
      );
    });

    test('정예전은 일반 전투보다 더 많은 노잣돈을 준다', () {
      final map = generateActOneMap(88, tuning: _rewardTuning);
      final combat = map.nodes.firstWhere(
        (node) => node.type == RunNodeType.combat,
      );
      final elite = map.nodes.firstWhere(
        (node) => node.type == RunNodeType.elite,
      );

      expect(
        moneyRewardForNode(elite, tuning: _rewardTuning),
        moneyRewardForNode(combat, tuning: _rewardTuning) *
            _rewardTuning.eliteMoneyRewardMultiplier,
      );
    });
  });
}

RunContent _rewardContent() => RunContent(
  maxHp: 80,
  deck: List<CardDef>.filled(8, _finisher),
  encounterPool: _rewardEnemies(),
  cardRewardPool: const [_rewardA, _rewardB, _rewardC, _rewardD],
);

List<Enemy> _rewardEnemies() => [
  for (var i = 0; i < 3; i++)
    Enemy(
      id: 'test_reward_enemy_$i',
      name: '보상 시험 적 $i',
      hp: 1,
      maxHp: 1,
      pattern: const [EnemyDefend(0)],
    ),
];

RunState _enterFirstCombat({required int seed, required RunContent content}) {
  final state = startRun(seed: seed, characterId: 'm0');
  return applyRunAction(
    state,
    _nextMove(state, content: content),
    tuning: _rewardTuning,
    content: content,
  );
}

RunState _winCurrentCombat(RunState state, {required RunContent content}) {
  var next = state;
  while (replayRun(next, tuning: _rewardTuning, content: content).isInCombat) {
    final action =
        legalRunActions(next, tuning: _rewardTuning, content: content)
            .whereType<CombatNodeLog>()
            .firstWhere((log) => log.actions.last is PlayCard);
    next = applyRunAction(
      next,
      action,
      tuning: _rewardTuning,
      content: content,
    );
  }
  return next;
}

MoveToNode _nextMove(RunState state, {required RunContent content}) =>
    legalRunActions(
      state,
      tuning: _rewardTuning,
      content: content,
    ).whereType<MoveToNode>().first;

List<ChooseCardReward> _rewardChoices(
  RunState state, {
  required RunContent content,
}) => legalRunActions(
  state,
  tuning: _rewardTuning,
  content: content,
).whereType<ChooseCardReward>().toList();
