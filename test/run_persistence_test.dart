import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/app/run_controller.dart';
import 'package:siwangjeon/data/m1_events.dart';
import 'package:siwangjeon/data/m1_relics.dart';
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
  id: 'persistence_test_finisher',
  name: '복원 시험 일격',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 999)],
);

const _rewardA = CardDef(
  id: 'persistence_test_reward_a',
  name: '복원 시험 보상 갑',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 1)],
);

const _rewardB = CardDef(
  id: 'persistence_test_reward_b',
  name: '복원 시험 보상 을',
  type: CardType.skill,
  cost: 0,
  targeted: false,
  effects: [BlockEffect(1)],
);

const _rewardC = CardDef(
  id: 'persistence_test_reward_c',
  name: '복원 시험 보상 병',
  type: CardType.power,
  cost: 0,
  targeted: false,
  effects: [BlockEffect(1)],
);

void main() {
  test('읽기 거부 파일은 앱 시작을 막지 않고 새 런으로 넘긴다', () async {
    final restored = await RunController.loadStoredRun(
      storage: const _LoadedMemoryStorage(RunLoadRejected()),
      content: _content(),
    );

    expect(restored, isNull);
  });

  test('사라진 카드 id의 보상 로그는 런 전체를 복원하지 않는다', () async {
    final content = _content();
    final chosen = _completedRewardChoice(content);
    final reward = chosen.actionLog.last as ChooseCardReward;
    final missingCard = RunState(
      seed: chosen.seed,
      characterId: chosen.characterId,
      actionLog: [
        ...chosen.actionLog.sublist(0, chosen.actionLog.length - 1),
        ChooseCardReward(nodeId: reward.nodeId, cardId: 'removed_card_id'),
      ],
    );

    final restored = await RunController.loadStoredRun(
      storage: _LoadedMemoryStorage(RunLoadFound(missingCard)),
      content: content,
    );

    expect(restored, isNull);
  });

  test('유효한 저장 런은 앱 시작 전에 그대로 복원한다', () async {
    final content = _content();
    final saved = _afterOneCombatTurn(content);

    final restored = await RunController.loadStoredRun(
      storage: _LoadedMemoryStorage(RunLoadFound(saved)),
      content: content,
    );

    expect(restored, isNotNull);
    expect(restored!.seed, saved.seed);
    expect(restored.characterId, saved.characterId);
    expect(restored.actionLog, hasLength(saved.actionLog.length));
  });
}

RunContent _content() => RunContent(
  maxHp: 80,
  deck: List<CardDef>.filled(8, _finisher),
  encounterPool: [
    _enemy('persistence_test_enemy_a'),
    _enemy('persistence_test_enemy_b'),
    _enemy('persistence_test_enemy_c'),
  ],
  cardRewardPool: const [_rewardA, _rewardB, _rewardC],
  events: m1Events,
  relicRewardPool: m1Relics,
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

RunState _completedRewardChoice(RunContent content) {
  var state = _enterCombat(content);
  while (replayRun(state, content: content).isInCombat) {
    final actions = legalRunActions(
      state,
      content: content,
    ).whereType<CombatNodeLog>().toList();
    final next = actions.firstWhere(
      (log) => log.actions.last is PlayCard,
      orElse: () => actions.first,
    );
    state = applyRunAction(state, next, content: content);
  }
  final reward = legalRunActions(
    state,
    content: content,
  ).whereType<ChooseCardReward>().first;
  return applyRunAction(state, reward, content: content);
}

RunState _enterCombat(RunContent content) {
  var state = startRun(seed: 81, characterId: 'm0');
  while (!replayRun(state, content: content).isInCombat) {
    final legal = legalRunActions(state, content: content);
    final moves = legal.whereType<MoveToNode>();
    state = applyRunAction(
      state,
      moves.isNotEmpty ? moves.first : legal.first,
      content: content,
    );
  }
  return state;
}

class _LoadedMemoryStorage implements RunStorage {
  const _LoadedMemoryStorage(this._result);

  final RunLoadResult _result;

  @override
  Future<RunLoadResult> load() => Future<RunLoadResult>.value(_result);

  @override
  Future<void> save(RunState state) => Future<void>.value();
}
