import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/domain/combat/combat_engine.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/combat_action.dart';
import 'package:siwangjeon/domain/model/combat_state.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/model/game_event.dart';
import 'package:siwangjeon/domain/model/relic.dart';
import 'package:siwangjeon/domain/model/status.dart';

const _karmaStrike = CardDef(
  id: 'karma_strike',
  name: '업의 일격',
  type: CardType.attack,
  cost: 1,
  karma: 1,
  effects: [DamageEffect(value: 5)],
);

const _cleanGuard = CardDef(
  id: 'clean_guard',
  name: '청정의 수비',
  type: CardType.skill,
  cost: 1,
  targeted: false,
  effects: [BlockEffect(4)],
);

const _fatalStrike = CardDef(
  id: 'fatal_strike',
  name: '마무리 일격',
  type: CardType.attack,
  cost: 1,
  effects: [DamageEffect(value: 99)],
);

Enemy _enemy({int hp = 50, int damage = 0}) => Enemy(
  id: 'test_enemy',
  name: '시험 적',
  hp: hp,
  maxHp: hp,
  pattern: [damage == 0 ? const EnemyDefend(0) : EnemyAttack(damage)],
);

CombatState _start({
  required List<CardDef> deck,
  List<RelicDef> relics = const [],
  List<Enemy>? enemies,
  int karma = 0,
  int hp = 80,
}) => beginCombat(
  seed: 9,
  hp: hp,
  maxHp: 80,
  karma: karma,
  deck: deck,
  enemies: enemies ?? [_enemy()],
  relics: relics,
).state;

List<CardDef> _deck(CardDef card, [int count = 10]) =>
    List<CardDef>.filled(count, card);

int _handIndex(CombatState state, CardDef card) =>
    state.hand.indexWhere((candidate) => candidate.id == card.id);

RelicDef _relic(RelicEffect effect) =>
    RelicDef('test_${effect.runtimeType}', '시험 유물', effect.trigger, effect);

void main() {
  group('유물 선언', () {
    test('효과는 고정 발동 시점과 다른 선언을 거부한다', () {
      expect(
        () => RelicDef(
          'invalid',
          '잘못된 유물',
          RelicTrigger.turnEnded,
          const OpeningDrawEffect(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('15개 효과는 각각 고정 발동 시점을 제공한다', () {
      final effects = <RelicEffect>[
        const KarmaScaledStrengthEffect(),
        const PureDexterityEffect(),
        const OpeningDrawEffect(),
        const OpeningCleanseEffect(),
        const KarmaBandBlockEffect(),
        const TurbidEnergyEffect(),
        const KarmaCardBonusDamageEffect(),
        const CleanCardBlockEffect(),
        const UnblockedDamageVulnerableEffect(),
        const UnblockedDamageKarmaEffect(),
        const KarmaBurstEffect(),
        const TurnEndCleanseEffect(),
        const EnemyDeathHealEffect(),
        const EnemyDeathBlockEffect(),
        const TurbidDamageReductionEffect(),
      ];

      expect(effects.map((effect) => _relic(effect).trigger), [
        RelicTrigger.combatStarted,
        RelicTrigger.combatStarted,
        RelicTrigger.combatStarted,
        RelicTrigger.combatStarted,
        RelicTrigger.turnStarted,
        RelicTrigger.turnStarted,
        RelicTrigger.cardPlayed,
        RelicTrigger.cardPlayed,
        RelicTrigger.playerDamageDealt,
        RelicTrigger.playerDamageDealt,
        RelicTrigger.turnEnded,
        RelicTrigger.turnEnded,
        RelicTrigger.enemyDied,
        RelicTrigger.enemyDied,
        RelicTrigger.playerDamageTaken,
      ]);
    });
  });

  group('유물 전투 해석', () {
    test('전투 시작 드로우 유물은 TurnStarted 전 1장과 기본 5장을 모두 뽑는다', () {
      final result = beginCombat(
        seed: 9,
        hp: 80,
        maxHp: 80,
        karma: 50,
        deck: _deck(_cleanGuard),
        enemies: [_enemy()],
        relics: [
          _relic(const KarmaScaledStrengthEffect()),
          _relic(const OpeningDrawEffect()),
          _relic(const OpeningCleanseEffect()),
        ],
      );
      final withoutRelic = beginCombat(
        seed: 9,
        hp: 80,
        maxHp: 80,
        karma: 50,
        deck: _deck(_cleanGuard),
        enemies: [_enemy()],
      );

      expect(result.state.statuses[StatusId.strength], 2);
      expect(result.state.karma, 47);
      expect(withoutRelic.state.hand, hasLength(5));
      expect(result.state.hand, hasLength(6));
      expect(
        result.events.whereType<CardsDrawn>().map(
          (event) => event.cards.length,
        ),
        [1, 5],
      );
      expect(
        result.events.indexWhere((event) => event is TurnStarted),
        greaterThan(result.events.indexWhere((event) => event is CardsDrawn)),
      );
    });

    test('청정 시작 유물은 굳음을 얻고 업 구간 방어·탁함 기력을 턴 시작에 적용한다', () {
      final pure = _start(
        deck: _deck(_cleanGuard),
        karma: 5,
        relics: [_relic(const PureDexterityEffect())],
      );
      expect(pure.statuses[StatusId.dexterity], 1);

      final turbid = _start(
        deck: _deck(_cleanGuard),
        karma: 50,
        relics: [
          _relic(const KarmaBandBlockEffect()),
          _relic(const TurbidEnergyEffect()),
        ],
      );
      final next = applyAction(turbid, const EndTurn()).state;
      expect(next.block, 2);
      expect(next.energy, 4);
    });

    test('업 카드 보너스와 청정 카드 방어는 미리보기와 실제 카드 해석이 같다', () {
      final damageState = _start(
        deck: _deck(_karmaStrike),
        relics: [_relic(const KarmaCardBonusDamageEffect())],
      );
      final damagePreview = previewDamage(
        damageState,
        _karmaStrike,
        targetIndex: 0,
      );
      final damageResult = applyAction(
        damageState,
        PlayCard(
          handIndex: _handIndex(damageState, _karmaStrike),
          targetIndex: 0,
        ),
      );
      expect(damagePreview, 8);
      expect(damageResult.state.enemies.single.hp, 42);

      final blockState = _start(
        deck: _deck(_cleanGuard),
        relics: [_relic(const CleanCardBlockEffect())],
      );
      final blockPreview = previewBlock(blockState, _cleanGuard);
      final blockResult = applyAction(
        blockState,
        PlayCard(handIndex: _handIndex(blockState, _cleanGuard)),
      );
      expect(blockPreview, 6);
      expect(blockResult.state.block, 6);
    });

    test('무방어 피해 유물은 적에게 취약을 주고 업을 올린다', () {
      final state = _start(
        deck: _deck(_karmaStrike),
        relics: [
          _relic(const UnblockedDamageVulnerableEffect()),
          _relic(const UnblockedDamageKarmaEffect()),
        ],
      );
      final result = applyAction(
        state,
        PlayCard(handIndex: _handIndex(state, _karmaStrike), targetIndex: 0),
      );

      expect(result.state.enemies.single.statuses[StatusId.vulnerable], 1);
      expect(result.state.karma, 2);
    });

    test('턴 종료 유물은 업 비례 광역 피해 뒤 업을 정화한다', () {
      final state = _start(
        deck: _deck(_cleanGuard),
        karma: 40,
        enemies: [_enemy(), _enemy()],
        relics: [
          _relic(const KarmaBurstEffect()),
          _relic(const TurnEndCleanseEffect()),
        ],
      );
      final result = applyAction(state, const EndTurn());

      expect(result.state.enemies.map((enemy) => enemy.hp), [48, 48]);
      expect(result.state.karma, 39);
    });

    test('턴 종료 업 폭발로 마지막 적을 쓰러뜨리면 즉시 승리한다', () {
      final state = _start(
        deck: _deck(_cleanGuard),
        karma: 20,
        enemies: [_enemy(hp: 1)],
        relics: [_relic(const KarmaBurstEffect())],
      );

      final result = applyAction(state, const EndTurn());

      expect(result.state.outcome, CombatOutcome.victory);
      expect(
        result.events.whereType<CombatEnded>().single.outcome,
        CombatOutcome.victory,
      );
    });

    test('적 사망 회복은 EnemyDied와 함께 최대 체력에서 멈춘다', () {
      final state = _start(
        deck: _deck(_fatalStrike),
        hp: 79,
        enemies: [_enemy(hp: 20)],
        relics: [_relic(const EnemyDeathHealEffect())],
      );
      final result = applyAction(
        state,
        PlayCard(handIndex: _handIndex(state, _fatalStrike), targetIndex: 0),
      );

      expect(result.events.whereType<EnemyDied>().single.index, 0);
      expect(result.events.whereType<HpGained>().single.amount, 1);
      expect(result.state.enemies.single.hp, 0);
      expect(result.state.hp, 80);
    });

    test('적 사망 방어 유물은 방어도와 이벤트를 남긴다', () {
      final state = _start(
        deck: _deck(_fatalStrike),
        enemies: [_enemy(hp: 20)],
        relics: [_relic(const EnemyDeathBlockEffect())],
      );
      final result = applyAction(
        state,
        PlayCard(handIndex: _handIndex(state, _fatalStrike), targetIndex: 0),
      );

      expect(result.state.block, 5);
      expect(result.events.whereType<BlockGained>().single.amount, 5);
    });

    test('탁함 피격 감쇠는 예고와 실제 피격 모두에서 방어 전에 적용한다', () {
      final state = _start(
        deck: _deck(_cleanGuard),
        karma: 50,
        enemies: [_enemy(damage: 5)],
        relics: [_relic(const TurbidDamageReductionEffect())],
      );

      expect(previewEnemyDamage(state, 0), 4);
      final result = applyAction(state, const EndTurn());
      expect(result.state.hp, 76);
    });
  });
}
