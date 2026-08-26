import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/m0_content.dart';
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

const _combatOnlyTuning = RunTuning(
  nodeTypeWeights: [RunNodeWeight(RunNodeType.combat, 1)],
  cardRewardChoiceCount: 1,
);

const _decisiveStrike = CardDef(
  id: 'test_decisive_strike',
  name: '판결 일격',
  type: CardType.attack,
  cost: 0,
  karma: 5,
  effects: [DamageEffect(value: 999)],
);

const _wait = CardDef(
  id: 'test_wait',
  name: '대기',
  type: CardType.skill,
  cost: 0,
  targeted: false,
  effects: [BlockEffect(0)],
);

void main() {
  group('M1-2 전투 노드 런 재생', () {
    test('전투 승리의 체력·업·덱이 다음 전투 노드로 이어진다', () {
      final content = _victoryContent();
      final entered = _enterFirstCombat(seed: 71, content: content);
      final started = replayRun(
        entered,
        tuning: _combatOnlyTuning,
        content: content,
      );

      expect(started.isInCombat, isTrue);
      expect(started.hp, 80);
      expect(started.karma, 0);
      expect(
        started.deck.map((card) => card.id),
        everyElement(_decisiveStrike.id),
      );

      final won = _winCombat(entered, content: content);
      final afterWin = replayRun(
        won,
        tuning: _combatOnlyTuning,
        content: content,
      );
      expect(afterWin.isInCombat, isFalse);
      expect(afterWin.hp, 80);
      expect(afterWin.karma, 15);
      expect(afterWin.money, _combatOnlyTuning.baseMoneyReward);
      expect(
        afterWin.deck.map((card) => card.id),
        everyElement(_decisiveStrike.id),
      );

      final rewarded = _chooseReward(won, content: content);
      final afterReward = replayRun(
        rewarded,
        tuning: _combatOnlyTuning,
        content: content,
      );
      expect(afterReward.pendingCardReward, isNull);
      expect(afterReward.deck, hasLength(9));

      final next = applyRunAction(
        rewarded,
        _nextMove(rewarded, content: content),
        tuning: _combatOnlyTuning,
        content: content,
      );
      final nextCombat = replayRun(
        next,
        tuning: _combatOnlyTuning,
        content: content,
      );

      expect(nextCombat.isInCombat, isTrue);
      expect(nextCombat.combat!.hp, 80);
      expect(nextCombat.combat!.karma, 15);
      expect(
        nextCombat.deck.map((card) => card.id),
        everyElement(_decisiveStrike.id),
      );
    });

    test('패배하면 런이 끝나고 더 이상 런 액션이 없다', () {
      final content = _defeatContent();
      final entered = _enterFirstCombat(seed: 72, content: content);
      final defeated = applyRunAction(
        entered,
        _combatLog(
          entered,
          content: content,
          matches: (action) => action is EndTurn,
        ),
        tuning: _combatOnlyTuning,
        content: content,
      );
      final progress = replayRun(
        defeated,
        tuning: _combatOnlyTuning,
        content: content,
      );

      expect(progress.outcome, RunOutcome.defeat);
      expect(progress.hp, 0);
      expect(progress.combat!.outcome, isNotNull);
      expect(
        legalRunActions(defeated, tuning: _combatOnlyTuning, content: content),
        isEmpty,
      );
      expect(
        () => applyRunAction(
          defeated,
          const MoveToNode(nodeId: 1),
          tuning: _combatOnlyTuning,
          content: content,
        ),
        throwsA(isA<IllegalRunActionError>()),
      );
    });

    test('같은 시드와 전투 입력은 체력·업·덱까지 같은 런 상태를 만든다', () {
      final content = _victoryContent();
      final a = _winCombat(
        _enterFirstCombat(seed: 73, content: content),
        content: content,
      );
      final b = _winCombat(
        _enterFirstCombat(seed: 73, content: content),
        content: content,
      );

      final left = replayRun(a, tuning: _combatOnlyTuning, content: content);
      final right = replayRun(b, tuning: _combatOnlyTuning, content: content);

      expect(left.visitedNodeIds, right.visitedNodeIds);
      expect(left.hp, right.hp);
      expect(left.maxHp, right.maxHp);
      expect(left.karma, right.karma);
      expect(left.money, right.money);
      expect(
        left.deck.map((card) => card.id).toList(),
        right.deck.map((card) => card.id).toList(),
      );
    });

    test('액션 로그 앞부분만 재생해도 해당 전투 턴을 정확히 복원한다', () {
      final content = _victoryContent();
      final entered = _enterFirstCombat(seed: 74, content: content);
      final prefix = applyRunAction(
        entered,
        _combatLog(
          entered,
          content: content,
          matches: (action) => action is PlayCard,
        ),
        tuning: _combatOnlyTuning,
        content: content,
      );
      final expected = replayRun(
        prefix,
        tuning: _combatOnlyTuning,
        content: content,
      );

      final continued = applyRunAction(
        prefix,
        _combatLog(
          prefix,
          content: content,
          matches: (action) => action is PlayCard,
        ),
        tuning: _combatOnlyTuning,
        content: content,
      );
      final restored = replayRun(
        RunState(
          seed: prefix.seed,
          characterId: prefix.characterId,
          actionLog: prefix.actionLog,
        ),
        tuning: _combatOnlyTuning,
        content: content,
      );

      expect(continued.actionLog.last, isA<CombatNodeLog>());
      _expectSameCombat(expected, restored);
    });

    test('한 전투의 입력이 달라도 다음 전투의 첫 손패는 노드 시드로 고정된다', () {
      final content = _victoryContent();
      final first = _winCombat(
        _enterFirstCombat(seed: 75, content: content),
        content: content,
        firstTargetIndex: 0,
      );
      final second = _winCombat(
        _enterFirstCombat(seed: 75, content: content),
        content: content,
        firstTargetIndex: 1,
      );

      final rewardedFirst = _chooseReward(first, content: content);
      final rewardedSecond = _chooseReward(second, content: content);
      final nextFirst = applyRunAction(
        rewardedFirst,
        _nextMove(rewardedFirst, content: content),
        tuning: _combatOnlyTuning,
        content: content,
      );
      final nextSecond = applyRunAction(
        rewardedSecond,
        _nextMove(rewardedSecond, content: content),
        tuning: _combatOnlyTuning,
        content: content,
      );
      final firstCombat = replayRun(
        nextFirst,
        tuning: _combatOnlyTuning,
        content: content,
      ).combat!;
      final secondCombat = replayRun(
        nextSecond,
        tuning: _combatOnlyTuning,
        content: content,
      ).combat!;

      final firstInput =
          (first.actionLog.last as CombatNodeLog).actions.first as PlayCard;
      final secondInput =
          (second.actionLog.last as CombatNodeLog).actions.first as PlayCard;
      expect(firstInput.targetIndex, 0);
      expect(secondInput.targetIndex, 1);
      expect(
        firstCombat.hand.map((card) => card.id).toList(),
        secondCombat.hand.map((card) => card.id).toList(),
      );
      expect(firstCombat.rng, secondCombat.rng);
    });

    test('적 구성은 encounter 스트림에서 결정론적으로 M0 적 풀을 뽑는다', () {
      final content = m0RunContent();
      final map = generateActOneMap(76, tuning: _combatOnlyTuning);
      final node = map.nodes.first;
      final a = encounterForNode(
        runSeed: 76,
        node: node,
        content: content,
        tuning: _combatOnlyTuning,
      );
      final b = encounterForNode(
        runSeed: 76,
        node: node,
        content: content,
        tuning: _combatOnlyTuning,
      );

      expect(content.encounterPool.map((enemy) => enemy.id), [
        'enemy_agwi',
        'enemy_wongwi',
        'enemy_dokgwi',
        'enemy_yacha',
        'enemy_nachal',
      ]);
      expect(a.map((enemy) => enemy.id).toList(), b.map((enemy) => enemy.id));

      var rng = Rng.forStream(
        encounterSeedForNode(76, node.id),
        RngStream.encounter,
      );
      final available = List<Enemy>.of(content.encounterPool);
      final expected = <String>[];
      for (var i = 0; i < _combatOnlyTuning.combatEncounterSize; i++) {
        final (index, next) = rng.nextInt(available.length);
        rng = next;
        expected.add(available.removeAt(index).id);
      }
      expect(a.map((enemy) => enemy.id), expected);
    });

    test('턴이 지날 때마다 현재 CombatNodeLog가 한 항목씩 자란다', () {
      final content = _waitingContent();
      final entered = _enterFirstCombat(seed: 77, content: content);
      final afterFirstTurn = applyRunAction(
        entered,
        _combatLog(
          entered,
          content: content,
          matches: (action) => action is EndTurn,
        ),
        tuning: _combatOnlyTuning,
        content: content,
      );
      final afterSecondTurn = applyRunAction(
        afterFirstTurn,
        _combatLog(
          afterFirstTurn,
          content: content,
          matches: (action) => action is EndTurn,
        ),
        tuning: _combatOnlyTuning,
        content: content,
      );
      final firstLog = afterFirstTurn.actionLog.last as CombatNodeLog;
      final secondLog = afterSecondTurn.actionLog.last as CombatNodeLog;

      expect(afterSecondTurn.actionLog, hasLength(2));
      expect(firstLog.actions, [const EndTurn()]);
      expect(secondLog.actions, [const EndTurn(), const EndTurn()]);
      expect(
        replayRun(
          afterSecondTurn,
          tuning: _combatOnlyTuning,
          content: content,
        ).combat!.turn,
        3,
      );
    });
  });
}

RunContent _victoryContent() => RunContent(
  maxHp: 80,
  deck: List<CardDef>.filled(8, _decisiveStrike),
  encounterPool: _enemies(hp: 1),
  cardRewardPool: [_decisiveStrike],
);

RunContent _defeatContent() => RunContent(
  maxHp: 10,
  deck: List<CardDef>.filled(8, _wait),
  encounterPool: _enemies(hp: 99, damage: 10),
  cardRewardPool: [_wait],
);

RunContent _waitingContent() => RunContent(
  maxHp: 80,
  deck: List<CardDef>.filled(8, _wait),
  encounterPool: _enemies(hp: 99),
  cardRewardPool: [_wait],
);

List<Enemy> _enemies({required int hp, int damage = 0}) => [
  for (var i = 0; i < 3; i++)
    Enemy(
      id: 'test_enemy_$i',
      name: '시험 적 $i',
      hp: hp,
      maxHp: hp,
      pattern: [damage == 0 ? const EnemyDefend(0) : EnemyAttack(damage)],
    ),
];

RunState _enterFirstCombat({required int seed, required RunContent content}) {
  final state = startRun(seed: seed, characterId: 'm0');
  return applyRunAction(
    state,
    _nextMove(state, content: content),
    tuning: _combatOnlyTuning,
    content: content,
  );
}

RunState _winCombat(
  RunState state, {
  required RunContent content,
  int? firstTargetIndex,
}) {
  var next = state;
  var isFirst = true;

  while (replayRun(
    next,
    tuning: _combatOnlyTuning,
    content: content,
  ).isInCombat) {
    next = applyRunAction(
      next,
      _combatLog(
        next,
        content: content,
        matches: (action) =>
            action is PlayCard &&
            (!isFirst ||
                firstTargetIndex == null ||
                action.targetIndex == firstTargetIndex),
      ),
      tuning: _combatOnlyTuning,
      content: content,
    );
    isFirst = false;
  }

  return next;
}

MoveToNode _nextMove(RunState state, {required RunContent content}) =>
    legalRunActions(
      state,
      tuning: _combatOnlyTuning,
      content: content,
    ).whereType<MoveToNode>().first;

RunState _chooseReward(RunState state, {required RunContent content}) =>
    applyRunAction(
      state,
      legalRunActions(
        state,
        tuning: _combatOnlyTuning,
        content: content,
      ).whereType<ChooseCardReward>().first,
      tuning: _combatOnlyTuning,
      content: content,
    );

CombatNodeLog _combatLog(
  RunState state, {
  required RunContent content,
  required bool Function(CombatAction action) matches,
}) => legalRunActions(
  state,
  tuning: _combatOnlyTuning,
  content: content,
).whereType<CombatNodeLog>().firstWhere((log) => matches(log.actions.last));

void _expectSameCombat(RunProgress expected, RunProgress actual) {
  expect(actual.visitedNodeIds, expected.visitedNodeIds);
  expect(actual.hp, expected.hp);
  expect(actual.karma, expected.karma);
  expect(
    actual.deck.map((card) => card.id),
    expected.deck.map((card) => card.id),
  );
  expect(actual.combat!.turn, expected.combat!.turn);
  expect(actual.combat!.hp, expected.combat!.hp);
  expect(actual.combat!.karma, expected.combat!.karma);
  expect(
    actual.combat!.hand.map((card) => card.id),
    expected.combat!.hand.map((card) => card.id),
  );
  expect(
    actual.combat!.enemies.map((enemy) => enemy.hp),
    expected.combat!.enemies.map((enemy) => enemy.hp),
  );
  expect(actual.combat!.rng, expected.combat!.rng);
}
