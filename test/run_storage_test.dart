import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/run_storage.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/combat_action.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/run/run_action.dart';
import 'package:siwangjeon/domain/run/run_content.dart';
import 'package:siwangjeon/domain/run/run_engine.dart';
import 'package:siwangjeon/domain/run/run_state.dart';

const _finisher = CardDef(
  id: 'save_test_finisher',
  name: '저장 시험 일격',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 999)],
);

const _rewardA = CardDef(
  id: 'save_test_reward_a',
  name: '저장 시험 보상 갑',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 1)],
);

const _rewardB = CardDef(
  id: 'save_test_reward_b',
  name: '저장 시험 보상 을',
  type: CardType.skill,
  cost: 0,
  targeted: false,
  effects: [BlockEffect(1)],
);

const _rewardC = CardDef(
  id: 'save_test_reward_c',
  name: '저장 시험 보상 병',
  type: CardType.power,
  cost: 0,
  targeted: false,
  effects: [BlockEffect(1)],
);

void main() {
  group('런 저장 직렬화', () {
    test('RunState는 모든 sealed 액션을 JSON 왕복해 같은 값을 유지한다', () {
      final state = RunState(
        seed: 20260827,
        characterId: 'm0',
        actionLog: [
          MoveToNode(nodeId: 3),
          CombatNodeLog(
            nodeId: 3,
            actions: [PlayCard(handIndex: 2, targetIndex: 1), EndTurn()],
          ),
          ChooseCardReward(nodeId: 3, cardId: 'card_strike'),
        ],
      );

      final restored = const RunSaveCodec().decode(
        const RunSaveCodec().encode(state),
      );

      expect(restored.seed, state.seed);
      expect(restored.characterId, state.characterId);
      expect(restored.actionLog, hasLength(3));
      expect(restored.actionLog[0], isA<MoveToNode>());
      expect((restored.actionLog[0] as MoveToNode).nodeId, 3);
      final combat = restored.actionLog[1] as CombatNodeLog;
      expect(combat.nodeId, 3);
      expect(combat.actions, hasLength(2));
      expect(combat.actions[0], isA<PlayCard>());
      expect((combat.actions[0] as PlayCard).handIndex, 2);
      expect((combat.actions[0] as PlayCard).targetIndex, 1);
      expect(combat.actions[1], isA<EndTurn>());
      final reward = restored.actionLog[2] as ChooseCardReward;
      expect(reward.nodeId, 3);
      expect(reward.cardId, 'card_strike');
    });

    test('버전 불일치와 손상 파일은 거부하고 원본을 지우지 않는다', () async {
      final directory = await Directory.systemTemp.createTemp(
        'siwangjeon_run_storage_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}run.json');
      final storage = FileRunStorage(documentsDirectory: () async => directory);

      const unsupported =
          '{"version": 999, "seed": 1, "characterId": "m0", "actionLog": []}';
      await file.writeAsString(unsupported);
      expect(await storage.load(), isA<RunLoadRejected>());
      expect(await file.readAsString(), unsupported);

      const damaged = '{not valid JSON';
      await file.writeAsString(damaged);
      expect(await storage.load(), isA<RunLoadRejected>());
      expect(await file.readAsString(), damaged);
    });

    test('파일 저장소는 최신 액션 로그를 다시 읽는다', () async {
      final directory = await Directory.systemTemp.createTemp(
        'siwangjeon_run_storage_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = FileRunStorage(documentsDirectory: () async => directory);
      final first = RunState(seed: 1, characterId: 'm0', actionLog: const []);
      final latest = RunState(
        seed: 1,
        characterId: 'm0',
        actionLog: const [MoveToNode(nodeId: 0)],
      );

      await storage.save(first);
      await storage.save(latest);
      final loaded = await storage.load();

      expect(loaded, isA<RunLoadFound>());
      expect((loaded as RunLoadFound).state.actionLog, hasLength(1));
      expect((loaded.state.actionLog.single as MoveToNode).nodeId, 0);
    });
  });

  group('런 저장 재생', () {
    test('전투 턴을 저장하고 불러오면 손패·적·난수 상태까지 재생된다', () async {
      final content = _content();
      final state = _afterOneCombatTurn(content);
      final storage = _SerializedMemoryStorage();
      await storage.save(state);
      final loaded = await storage.load();
      final restored = (loaded as RunLoadFound).state;

      final expected = replayRun(state, content: content);
      final actual = replayRun(restored, content: content);

      expect(actual.currentNodeId, expected.currentNodeId);
      expect(actual.hp, expected.hp);
      expect(actual.karma, expected.karma);
      expect(actual.money, expected.money);
      expect(
        actual.deck.map((card) => card.id),
        expected.deck.map((card) => card.id),
      );
      expect(actual.combat!.turn, expected.combat!.turn);
      expect(
        actual.combat!.hand.map((card) => card.id),
        expected.combat!.hand.map((card) => card.id),
      );
      expect(
        actual.combat!.enemies.map((enemy) => enemy.hp),
        expected.combat!.enemies.map((enemy) => enemy.hp),
      );
      expect(actual.combat!.rng, expected.combat!.rng);
    });
  });
}

RunContent _content() => RunContent(
  maxHp: 80,
  deck: List<CardDef>.filled(8, _finisher),
  encounterPool: [
    _enemy('save_test_enemy_a'),
    _enemy('save_test_enemy_b'),
    _enemy('save_test_enemy_c'),
  ],
  cardRewardPool: const [_rewardA, _rewardB, _rewardC],
);

Enemy _enemy(String id) =>
    Enemy(id: id, name: id, hp: 1, maxHp: 1, pattern: const [EnemyDefend(0)]);

RunState _afterOneCombatTurn(RunContent content) {
  final entered = _enterCombat(content);
  final turnEnd = legalRunActions(
    entered,
    content: content,
  ).whereType<CombatNodeLog>().firstWhere((log) => log.actions.last is EndTurn);
  return applyRunAction(entered, turnEnd, content: content);
}

RunState _enterCombat(RunContent content) {
  var state = startRun(seed: 20260827, characterId: 'm0');
  while (!replayRun(state, content: content).isInCombat) {
    final move = legalRunActions(
      state,
      content: content,
    ).whereType<MoveToNode>().first;
    state = applyRunAction(state, move, content: content);
  }
  return state;
}

class _SerializedMemoryStorage implements RunStorage {
  String? _source;

  @override
  Future<RunLoadResult> load() {
    final source = _source;
    return Future<RunLoadResult>.value(
      source == null
          ? const RunLoadMissing()
          : RunLoadFound(const RunSaveCodec().decode(source)),
    );
  }

  @override
  Future<void> save(RunState state) {
    _source = const RunSaveCodec().encode(state);
    return Future<void>.value();
  }
}
