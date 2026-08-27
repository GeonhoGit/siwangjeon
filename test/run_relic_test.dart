import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/run_storage.dart';
import 'package:siwangjeon/data/m1_relics.dart';
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

const _tuning = RunTuning(
  nodeTypeWeights: [RunNodeWeight(RunNodeType.combat, 1)],
  guaranteedEliteDepth: 2,
  cardRewardChoiceCount: 1,
  relicRewardChoiceCount: 3,
  eliteKarmaReward: 3,
);

const _finisher = CardDef(
  id: 'relic_test_finisher',
  name: '유물 시험 일격',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 999)],
);

void main() {
  group('정예 유물 보상', () {
    test('정예 승리는 돈과 카드 대신 업보 3 및 고유 유물 후보 3개를 남긴다', () {
      final content = _content();
      final won = _winElite(seed: 31, content: content);
      final progress = replayRun(won, tuning: _tuning, content: content);

      expect(progress.money, _tuning.baseMoneyReward * 2);
      expect(progress.karma, _tuning.eliteKarmaReward);
      expect(progress.pendingCardReward, isNull);
      expect(progress.pendingRelicReward!.relics, hasLength(3));
      expect(
        progress.pendingRelicReward!.relics.map((relic) => relic.id).toSet(),
        hasLength(3),
      );
      expect(
        legalRunActions(won, tuning: _tuning, content: content),
        everyElement(isA<ChooseRelicReward>()),
      );
    });

    test('유물 후보는 reward 스트림과 전용 node salt로 결정된다', () {
      final node = RunNode(
        id: 22,
        depth: 2,
        type: RunNodeType.elite,
        nextNodeIds: const [],
      );
      final content = _content();
      final reward = relicRewardForNode(
        runSeed: 123,
        node: node,
        content: content,
        tuning: _tuning,
      );
      var rng = Rng.forStream(
        relicRewardSeedForNode(123, node.id),
        RngStream.reward,
      );
      final available = List.of(content.relicRewardPool);
      final expectedIds = <String>[];
      for (var i = 0; i < 3; i++) {
        final (index, next) = rng.nextInt(available.length);
        rng = next;
        expectedIds.add(available.removeAt(index).id);
      }

      expect(reward.relics.map((relic) => relic.id), expectedIds);
      expect(
        relicRewardSeedForNode(123, 22),
        isNot(rewardSeedForNode(123, 22)),
      );
      expect(
        relicRewardSeedForNode(123, 22),
        isNot(relicRewardSeedForNode(123, 23)),
      );
      expect(
        () => relicRewardForNode(
          runSeed: 123,
          node: RunNode(
            id: 1,
            depth: 1,
            type: RunNodeType.combat,
            nextNodeIds: const [],
          ),
          content: content,
          tuning: _tuning,
        ),
        throwsArgumentError,
      );
    });

    test('선택한 유물은 로그만으로 복원된다', () {
      final content = _content();
      final won = _winElite(seed: 32, content: content);
      final choice = legalRunActions(
        won,
        tuning: _tuning,
        content: content,
      ).whereType<ChooseRelicReward>().first;
      final selected = applyRunAction(
        won,
        choice,
        tuning: _tuning,
        content: content,
      );
      final restored = replayRun(selected, tuning: _tuning, content: content);
      final next = applyRunAction(
        selected,
        legalRunActions(
          selected,
          tuning: _tuning,
          content: content,
        ).whereType<MoveToNode>().first,
        tuning: _tuning,
        content: content,
      );
      final nextCombat = replayRun(
        next,
        tuning: _tuning,
        content: content,
      ).combat!;

      final repeatedWon = _winElite(seed: 32, content: content);
      final repeated = applyRunAction(
        repeatedWon,
        choice,
        tuning: _tuning,
        content: content,
      );

      expect(restored.relics.single.id, choice.relicId);
      expect(restored.pendingRelicReward, isNull);
      expect(selected.actionLog.last, isA<ChooseRelicReward>());
      expect(nextCombat.relics.single.id, choice.relicId);
      expect(
        replayRun(repeated, tuning: _tuning, content: content).relics.single.id,
        choice.relicId,
      );
      expect(
        () => applyRunAction(
          won,
          MoveToNode(
            nodeId: replayRun(
              won,
              tuning: _tuning,
              content: content,
            ).currentNode!.nextNodeIds.first,
          ),
          tuning: _tuning,
          content: content,
        ),
        throwsA(isA<IllegalRunActionError>()),
      );
    });

    test('빈 유물 풀로 정예에 진입하면 즉시 명확하게 거부한다', () {
      final content = _contentWithoutRelics();
      final beforeElite = _beforeElite(seed: 33, content: content);

      expect(
        () => replayRun(
          applyRunAction(
            beforeElite,
            legalRunActions(
              beforeElite,
              tuning: _tuning,
              content: content,
            ).whereType<MoveToNode>().first,
            tuning: _tuning,
            content: content,
          ),
          tuning: _tuning,
          content: content,
        ),
        throwsArgumentError,
      );
    });

    test('저장한 유물 선택 로그도 같은 보유 유물로 재생된다', () {
      final content = _content();
      final won = _winElite(seed: 34, content: content);
      final selected = applyRunAction(
        won,
        legalRunActions(
          won,
          tuning: _tuning,
          content: content,
        ).whereType<ChooseRelicReward>().last,
        tuning: _tuning,
        content: content,
      );
      final restored = const RunSaveCodec().decode(
        const RunSaveCodec().encode(selected),
      );

      expect(
        replayRun(restored, tuning: _tuning, content: content).relics.single.id,
        replayRun(selected, tuning: _tuning, content: content).relics.single.id,
      );
    });
  });
}

RunContent _content() => RunContent(
  maxHp: 80,
  deck: List.filled(8, _finisher),
  encounterPool: [
    for (var i = 0; i < 3; i++)
      Enemy(
        id: 'relic_test_enemy_$i',
        name: '적 $i',
        hp: 1,
        maxHp: 1,
        pattern: const [EnemyDefend(0)],
      ),
  ],
  cardRewardPool: const [_finisher],
  relicRewardPool: m1Relics,
);

RunContent _contentWithoutRelics() => RunContent(
  maxHp: 80,
  deck: List.filled(8, _finisher),
  encounterPool: [
    for (var i = 0; i < 3; i++)
      Enemy(
        id: 'empty_relic_test_enemy_$i',
        name: '적 $i',
        hp: 1,
        maxHp: 1,
        pattern: const [EnemyDefend(0)],
      ),
  ],
  cardRewardPool: const [_finisher],
);

RunState _beforeElite({required int seed, required RunContent content}) {
  var state = startRun(seed: seed, characterId: 'm0');
  while (replayRun(
        state,
        tuning: _tuning,
        content: content,
      ).currentNode?.depth !=
      1) {
    final progress = replayRun(state, tuning: _tuning, content: content);
    if (progress.pendingCardReward != null) {
      state = applyRunAction(
        state,
        legalRunActions(
          state,
          tuning: _tuning,
          content: content,
        ).whereType<ChooseCardReward>().first,
        tuning: _tuning,
        content: content,
      );
    } else if (progress.isInCombat) {
      state = applyRunAction(
        state,
        legalRunActions(state, tuning: _tuning, content: content)
            .whereType<CombatNodeLog>()
            .firstWhere((log) => log.actions.last is PlayCard),
        tuning: _tuning,
        content: content,
      );
    } else {
      state = applyRunAction(
        state,
        legalRunActions(
          state,
          tuning: _tuning,
          content: content,
        ).whereType<MoveToNode>().first,
        tuning: _tuning,
        content: content,
      );
    }
  }
  while (replayRun(state, tuning: _tuning, content: content).isInCombat) {
    state = applyRunAction(
      state,
      legalRunActions(state, tuning: _tuning, content: content)
          .whereType<CombatNodeLog>()
          .firstWhere((log) => log.actions.last is PlayCard),
      tuning: _tuning,
      content: content,
    );
  }
  state = applyRunAction(
    state,
    legalRunActions(
      state,
      tuning: _tuning,
      content: content,
    ).whereType<ChooseCardReward>().first,
    tuning: _tuning,
    content: content,
  );
  return state;
}

RunState _winElite({required int seed, required RunContent content}) {
  var state = startRun(seed: seed, characterId: 'm0');
  while (true) {
    final progress = replayRun(state, tuning: _tuning, content: content);
    if (progress.pendingCardReward != null) {
      state = applyRunAction(
        state,
        legalRunActions(
          state,
          tuning: _tuning,
          content: content,
        ).whereType<ChooseCardReward>().first,
        tuning: _tuning,
        content: content,
      );
      continue;
    }
    if (progress.currentNode?.type == RunNodeType.elite &&
        !progress.isInCombat) {
      return state;
    }
    if (!progress.isInCombat) {
      state = applyRunAction(
        state,
        legalRunActions(
          state,
          tuning: _tuning,
          content: content,
        ).whereType<MoveToNode>().first,
        tuning: _tuning,
        content: content,
      );
      continue;
    }
    state = applyRunAction(
      state,
      legalRunActions(state, tuning: _tuning, content: content)
          .whereType<CombatNodeLog>()
          .firstWhere((log) => log.actions.last is PlayCard),
      tuning: _tuning,
      content: content,
    );
  }
}
