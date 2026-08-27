import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/domain/combat/combat_engine.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/boss.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/combat_action.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/model/relic.dart';
import 'package:siwangjeon/domain/model/status.dart';
import 'package:siwangjeon/domain/run/run_action.dart';
import 'package:siwangjeon/domain/run/run_content.dart';
import 'package:siwangjeon/domain/run/run_engine.dart';
import 'package:siwangjeon/domain/run/run_map.dart';
import 'package:siwangjeon/domain/run/run_node_type.dart';
import 'package:siwangjeon/domain/run/run_state.dart';
import 'package:siwangjeon/domain/run/run_tuning.dart';

const _finisher = CardDef(
  id: 'judgment_finisher',
  name: '심판 종결',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 999)],
);

const _phaseStrike = CardDef(
  id: 'phase_strike',
  name: '페이즈 확인',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 51)],
);

final _relic = RelicDef(
  'judgment_relic',
  '심판의 패',
  RelicTrigger.combatStarted,
  const OpeningDrawEffect(),
);

const _tuning = RunTuning(
  nodeTypeWeights: [RunNodeWeight(RunNodeType.combat, 1)],
  cardRewardChoiceCount: 1,
  relicRewardChoiceCount: 1,
);

void main() {
  group('시왕 심판', () {
    test('업 네 구간이 시왕의 체력·순환·시작 페이즈를 각각 바꾼다', () {
      final boss = _boss(hp: 100);

      final pure = judgmentEnemyFor(boss: boss, karma: 19, tuning: _tuning);
      final ordinary = judgmentEnemyFor(boss: boss, karma: 20, tuning: _tuning);
      final turbid = judgmentEnemyFor(boss: boss, karma: 50, tuning: _tuning);
      final wicked = judgmentEnemyFor(boss: boss, karma: 80, tuning: _tuning);

      expect(pure.hp, 80);
      expect(pure.maxHp, 80);
      expect(ordinary.hp, 100);
      expect(ordinary.activePattern, hasLength(2));
      expect(turbid.activePattern, hasLength(3));
      expect(turbid.activePattern.last, isA<EnemyInflict>());
      expect(wicked.phaseIndex, 1);
      expect(wicked.intent, isA<EnemyAttack>());
    });

    test('보스 노드는 일반 조우 대신 보스 풀의 시왕 한 명만 배치한다', () {
      final node = RunNode(
        id: 99,
        depth: 14,
        type: RunNodeType.boss,
        nextNodeIds: [],
      );

      final enemies = encounterForNode(
        runSeed: 1,
        node: node,
        content: _content(),
        tuning: _tuning,
      );

      expect(_tuning.bossEncounterSize, 1);
      expect(enemies.map((enemy) => enemy.id), ['test_yeomra']);
    });

    test('악업이 아니면 체력 임계 이하에서 2페이즈로 전환한다', () {
      final state = beginCombat(
        seed: 49,
        hp: 80,
        maxHp: 80,
        deck: List<CardDef>.filled(8, _phaseStrike),
        enemies: [judgmentEnemyFor(boss: _boss(hp: 100), karma: 20)],
      ).state;

      final next = applyAction(
        state,
        const PlayCard(handIndex: 0, targetIndex: 0),
      ).state;

      expect(next.enemies.single.hp, 49);
      expect(next.enemies.single.phaseIndex, 1);
      expect(next.enemies.single.intent, isA<EnemyAttack>());
    });

    test('보스 바로 전 런 진행은 도메인 심판 안내를 만든다', () {
      final state = _reachJudgment(seed: 913, karma: 50);
      final progress = replayRun(
        state,
        tuning: _tuning,
        content: _content(startingKarma: 50),
      );

      expect(progress.currentNode?.type, isNot(RunNodeType.boss));
      expect(progress.judgmentPreview?.title, '시험 염라의 심판');
      expect(progress.judgmentPreview?.effectLabel, '추가 판결 행동 1개');
    });

    test('같은 시드와 액션 로그는 같은 심판 결과와 확정 유물을 복원한다', () {
      final completed = _completeAct(seed: 914, karma: 80);
      final restored = replayRun(
        completed,
        tuning: _tuning,
        content: _content(startingKarma: 80),
      );
      final replayed = replayRun(
        completed,
        tuning: _tuning,
        content: _content(startingKarma: 80),
      );

      expect(restored.outcome, RunOutcome.victory);
      expect(restored.victoryRelics.map((relic) => relic.id), [_relic.id]);
      expect(restored.relics.map((relic) => relic.id), contains(_relic.id));
      expect(
        replayed.victoryRelics.map((relic) => relic.id),
        restored.victoryRelics.map((relic) => relic.id),
      );
      expect(replayed.combat, restored.combat);
    });

    test('시왕 승리 뒤에는 보상·이동을 포함한 추가 런 액션이 없다', () {
      final completed = _completeAct(seed: 915, karma: 20);
      final progress = replayRun(
        completed,
        tuning: _tuning,
        content: _content(startingKarma: 20),
      );

      expect(progress.outcome, RunOutcome.victory);
      expect(progress.pendingCardReward, isNull);
      expect(progress.pendingRelicReward, isNull);
      expect(
        legalRunActions(completed, tuning: _tuning, content: _content()),
        isEmpty,
      );
    });
  });
}

BossDef _boss({required int hp}) => BossDef(
  enemy: Enemy(
    id: 'test_yeomra',
    name: '시험 염라',
    hp: hp,
    maxHp: hp,
    pattern: const [EnemyDefend(0), EnemyDefend(0)],
    phases: [
      EnemyPhase(pattern: const [EnemyDefend(0), EnemyDefend(0)]),
      EnemyPhase(pattern: const [EnemyAttack(7), EnemyDefend(0)]),
    ],
  ),
  turbidExtraMove: const EnemyInflict(StatusId.weak, 1),
);

RunContent _content({int startingKarma = 0}) => RunContent(
  maxHp: 80,
  startingKarma: startingKarma,
  deck: List<CardDef>.filled(64, _finisher),
  encounterPool: [
    for (var index = 0; index < 3; index++)
      Enemy(
        id: 'judgment_enemy_$index',
        name: '시험 적 $index',
        hp: 1,
        maxHp: 1,
        pattern: const [EnemyDefend(0)],
      ),
  ],
  bossPool: [_boss(hp: 1)],
  cardRewardPool: const [_finisher],
  relicRewardPool: [_relic],
);

RunState _completeAct({required int seed, required int karma}) {
  final content = _content(startingKarma: karma);
  var state = startRun(seed: seed, characterId: 'm0');

  while (!replayRun(state, tuning: _tuning, content: content).isOver) {
    final legal = legalRunActions(state, tuning: _tuning, content: content);
    final progress = replayRun(state, tuning: _tuning, content: content);
    if (progress.pendingCardReward != null) {
      state = applyRunAction(
        state,
        legal.whereType<ChooseCardReward>().first,
        tuning: _tuning,
        content: content,
      );
    } else if (progress.pendingRelicReward != null) {
      state = applyRunAction(
        state,
        legal.whereType<ChooseRelicReward>().first,
        tuning: _tuning,
        content: content,
      );
    } else if (progress.isInCombat) {
      state = applyRunAction(
        state,
        legal.whereType<CombatNodeLog>().firstWhere(
          (log) => log.actions.last is PlayCard,
        ),
        tuning: _tuning,
        content: content,
      );
    } else {
      state = applyRunAction(
        state,
        legal.whereType<MoveToNode>().first,
        tuning: _tuning,
        content: content,
      );
    }
  }
  return state;
}

RunState _reachJudgment({required int seed, required int karma}) {
  final content = _content(startingKarma: karma);
  var state = startRun(seed: seed, characterId: 'm0');

  while (true) {
    final progress = replayRun(state, tuning: _tuning, content: content);
    if (progress.judgmentPreview != null) return state;
    final legal = legalRunActions(state, tuning: _tuning, content: content);
    if (progress.pendingCardReward != null) {
      state = applyRunAction(
        state,
        legal.whereType<ChooseCardReward>().first,
        tuning: _tuning,
        content: content,
      );
    } else if (progress.pendingRelicReward != null) {
      state = applyRunAction(
        state,
        legal.whereType<ChooseRelicReward>().first,
        tuning: _tuning,
        content: content,
      );
    } else if (progress.isInCombat) {
      state = applyRunAction(
        state,
        legal.whereType<CombatNodeLog>().firstWhere(
          (log) => log.actions.last is PlayCard,
        ),
        tuning: _tuning,
        content: content,
      );
    } else {
      state = applyRunAction(
        state,
        legal.whereType<MoveToNode>().first,
        tuning: _tuning,
        content: content,
      );
    }
  }
}
