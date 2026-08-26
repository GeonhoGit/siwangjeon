// M0 전투 엔진 테스트 (기획서 §12-1 "카드 3장으로 순수 Dart 테스트 통과").
//
// 실제 카드 3장은 `data/m0_content.dart`에서 가져다 쓴다. 테스트가 자기만의
// 사본을 들고 있으면 밸런스를 만졌을 때 테스트는 옛 수치를 계속 통과시키고,
// 그 순간부터 이 파일은 게임이 아니라 과거를 검사하게 된다.
//
// 다만 경계 조건용 허수아비 적이나 「비싼카드」처럼 규칙만 찌르는 것들은
// 여기서 만든다. 그건 콘텐츠가 아니라 시험 도구다.
//
// 이 파일은 Flutter를 쓰지 않는다. `flutter_test`의 `test`/`expect`만 빌려 쓰며,
// 엔진이 순수 Dart라는 것(§7.2)을 확인하는 것도 이 테스트의 목적 중 하나다.

import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/m0_content.dart';
import 'package:siwangjeon/domain/combat/combat_engine.dart';
import 'package:siwangjeon/domain/combat/tuning.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/combat_action.dart';
import 'package:siwangjeon/domain/model/combat_state.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/model/game_event.dart';
import 'package:siwangjeon/domain/model/status.dart';

// ── 적 ────────────────────────────────────────────────────

/// 계속 때리기만 하는 적. 플레이어 피해 테스트용.
Enemy attacker({int hp = 20, int damage = 5}) => Enemy(
  id: 'enemy_agwi',
  name: '아귀',
  hp: hp,
  maxHp: hp,
  pattern: [EnemyAttack(damage)],
);

/// 아무것도 하지 않는(방어만 하는) 적. 다른 규칙을 격리해 볼 때 쓴다.
Enemy dummy({int hp = 100, int block = 0}) => Enemy(
  id: 'enemy_dummy',
  name: '허수아비',
  hp: hp,
  maxHp: hp,
  block: block,
  pattern: const [EnemyDefend(0)],
);

// ── 도우미 ─────────────────────────────────────────────────

CombatState start({
  required List<CardDef> deck,
  List<Enemy>? enemies,
  int seed = 1234,
  int hp = 80,
  int karma = 0,
}) {
  return beginCombat(
    seed: seed,
    hp: hp,
    maxHp: 80,
    karma: karma,
    deck: deck,
    enemies: enemies ?? [dummy()],
  ).state;
}

/// 손패에서 해당 카드의 위치. 덱이 섞이므로 인덱스를 상수로 쓸 수 없다.
int handIndexOf(CombatState state, CardDef card) {
  final index = state.hand.indexWhere((c) => c.id == card.id);
  expect(index, isNot(-1), reason: '손패에 ${card.name}이 없다');
  return index;
}

List<CardDef> deckOf(CardDef card, int count) =>
    List<CardDef>.filled(count, card);

void main() {
  group('전투 시작', () {
    test('손패 5장, 기력 3, 1턴으로 시작한다', () {
      final result = beginCombat(
        seed: 7,
        hp: 80,
        maxHp: 80,
        deck: deckOf(strike, 10),
        enemies: [dummy()],
      );

      expect(result.state.turn, 1);
      expect(result.state.energy, 3, reason: '§3.2 — 기력은 매 턴 3');
      expect(result.state.hand.length, 5, reason: '§3.1 — 손패 5장까지 드로우');
      expect(result.state.drawPile.length, 5);
      expect(result.state.discardPile, isEmpty);
      expect(result.state.isOver, isFalse);
      expect(result.events.whereType<CardsDrawn>().single.cards.length, 5);
    });

    test('업은 런 단위 자원이므로 이전 전투 값을 그대로 들고 들어온다', () {
      final state = start(deck: deckOf(strike, 10), karma: 42);
      expect(state.karma, 42);
      expect(state.karmaBand, KarmaBand.ordinary);
    });
  });

  group('카드 사용', () {
    test('힘 카드는 활성 영역에 남고 재섞은 뒤에도 다시 뽑히지 않는다', () {
      const power = CardDef(
        id: 'card_test_power',
        name: '시험의 기세',
        type: CardType.power,
        cost: 1,
        targeted: false,
        effects: [
          ApplyStatusEffect(
            status: StatusId.strength,
            stacks: 1,
            target: EffectTarget.self,
          ),
        ],
      );
      final state = CombatState(
        turn: 1,
        hp: 80,
        maxHp: 80,
        energy: 3,
        block: 0,
        karma: 0,
        hand: const [power],
        drawPile: const [],
        discardPile: deckOf(strike, 5),
        enemies: [dummy()],
        rng: start(deck: deckOf(strike, 5)).rng,
      );

      final played = applyAction(state, const PlayCard(handIndex: 0));

      expect(played.state.activePowers, hasLength(1));
      expect(played.state.activePowers.single.id, power.id);
      expect(played.state.discardPile, hasLength(5));
      expect(played.state.statuses[StatusId.strength], 1);

      final nextTurn = applyAction(played.state, const EndTurn()).state;
      expect(nextTurn.hand.map((card) => card.id), everyElement(strike.id));
      expect(nextTurn.activePowers.single.id, power.id);
      expect(nextTurn.drawPile, isEmpty);
      expect(nextTurn.discardPile, isEmpty);
    });

    test('타격은 적 체력을 6 깎는다', () {
      final state = start(deck: deckOf(strike, 10), enemies: [dummy(hp: 20)]);

      final result = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, strike), targetIndex: 0),
      );

      expect(result.state.enemies[0].hp, 14);
      expect(result.state.energy, 2);
      expect(result.state.hand.length, 4);
      expect(result.state.discardPile.single.id, strike.id);

      final damage = result.events.whereType<DamageDealt>().single;
      expect(damage.targetIndex, 0);
      expect(damage.amount, 6);
      expect(damage.blocked, 0);
    });

    test('적의 방어도가 피해를 먼저 흡수한다', () {
      final state = start(
        deck: deckOf(strike, 10),
        enemies: [dummy(hp: 20, block: 4)],
      );

      final result = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, strike), targetIndex: 0),
      );

      expect(result.state.enemies[0].block, 0);
      expect(result.state.enemies[0].hp, 18, reason: '6 중 4는 방어도가 먹는다');

      final damage = result.events.whereType<DamageDealt>().single;
      expect(damage.blocked, 4);
      expect(damage.amount, 2);
    });

    test('수비는 대상 없이 방어도 5를 준다', () {
      final state = start(deck: deckOf(defend, 10));

      final result = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, defend)),
      );

      expect(result.state.block, 5);
      expect(
        result.events.whereType<BlockGained>().single.targetIndex,
        CombatState.playerIndex,
      );
    });

    test('기력이 모자라면 액션을 거부한다', () {
      var state = start(deck: deckOf(strike, 10), enemies: [dummy()]);

      // 기력 3을 전부 쓴다.
      for (var i = 0; i < 3; i++) {
        state = applyAction(state, const PlayCard(handIndex: 0, targetIndex: 0))
            .state;
      }
      expect(state.energy, 0);

      expect(
        () => applyAction(state, const PlayCard(handIndex: 0, targetIndex: 0)),
        throwsA(isA<IllegalActionError>()),
        reason: '불법 액션은 조용히 무시하면 §7.4의 재생 복구가 무너진다',
      );
    });

    test('죽은 적을 대상으로 삼을 수 없다', () {
      var state = start(deck: deckOf(strike, 10), enemies: [dummy(hp: 6), dummy()]);

      state = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, strike), targetIndex: 0),
      ).state;
      expect(state.enemies[0].isAlive, isFalse);

      expect(
        () => applyAction(state, const PlayCard(handIndex: 0, targetIndex: 0)),
        throwsA(isA<IllegalActionError>()),
      );
    });
  });

  group('업(業) — §3.3', () {
    test('원한의 칼날은 업을 3 쌓는다', () {
      final state = start(deck: deckOf(bladeOfGrudge, 10), enemies: [dummy()]);

      final result = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, bladeOfGrudge), targetIndex: 0),
      );

      expect(result.state.karma, 3);
      expect(result.events.whereType<KarmaGained>().single.amount, 3);
    });

    test('업은 자기 자신의 피해를 키우지 않는다', () {
      final state = start(deck: deckOf(bladeOfGrudge, 10), enemies: [dummy(hp: 50)]);

      final result = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, bladeOfGrudge), targetIndex: 0),
      );

      expect(
        result.state.enemies[0].hp,
        44,
        reason: '업 0에서 쓴 카드는 6만 넣는다. 자기가 쌓은 업 3이 되먹임되면 안 된다',
      );
    });

    test('이미 쌓인 업에는 비례해 세진다', () {
      final state = start(
        deck: deckOf(bladeOfGrudge, 10),
        enemies: [dummy(hp: 50)],
        karma: 50,
      );

      final result = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, bladeOfGrudge), targetIndex: 0),
      );

      expect(result.state.enemies[0].hp, 39, reason: '6 + floor(50 * 0.1) = 11');
    });

    test('업은 100을 넘지 않는다', () {
      final state = start(
        deck: deckOf(bladeOfGrudge, 10),
        enemies: [dummy()],
        karma: 99,
      );

      final result = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, bladeOfGrudge), targetIndex: 0),
      );

      expect(result.state.karma, 100);
      expect(result.events.whereType<KarmaGained>().single.amount, 1);
    });

    test('심판 등급 경계는 19/20, 49/50, 79/80이다', () {
      expect(KarmaBand.of(0), KarmaBand.pure);
      expect(KarmaBand.of(19), KarmaBand.pure);
      expect(KarmaBand.of(20), KarmaBand.ordinary);
      expect(KarmaBand.of(49), KarmaBand.ordinary);
      expect(KarmaBand.of(50), KarmaBand.turbid);
      expect(KarmaBand.of(79), KarmaBand.turbid);
      expect(KarmaBand.of(80), KarmaBand.wicked);
      expect(KarmaBand.of(100), KarmaBand.wicked);
    });
  });

  group('정화·드로우·기력 효과', () {
    const purification = CardDef(
      id: 'test_purification',
      name: '시험용 정화',
      type: CardType.skill,
      cost: 0,
      targeted: false,
      effects: [LoseHpEffect(6), ChangeKarmaEffect(-20)],
    );
    const karmaOffering = CardDef(
      id: 'test_karma_offering',
      name: '시험용 업 부과',
      type: CardType.skill,
      cost: 0,
      targeted: false,
      effects: [ChangeKarmaEffect(20)],
    );
    const drawTwo = CardDef(
      id: 'test_draw_two',
      name: '시험용 두 장 드로우',
      type: CardType.skill,
      cost: 0,
      targeted: false,
      effects: [DrawCardsEffect(2)],
    );
    const drawThree = CardDef(
      id: 'test_draw_three',
      name: '시험용 세 장 드로우',
      type: CardType.skill,
      cost: 0,
      targeted: false,
      effects: [DrawCardsEffect(3)],
    );

    test('정화는 업을 0 아래로 내리지 않고 체력 대가를 방어도와 무관하게 낸다', () {
      final initial = start(deck: deckOf(strike, 10), karma: 10).copyWith(
        block: 5,
        hand: const [purification],
        drawPile: const [],
        discardPile: const [],
      );

      final result = applyAction(initial, const PlayCard(handIndex: 0));

      expect(result.state.karma, 0);
      expect(result.state.hp, 74, reason: '정화 비용은 방어도가 흡수하지 않는다');
      expect(result.state.block, 5);
      expect(result.events.whereType<KarmaGained>().single.amount, -10);
      final cost = result.events.whereType<DamageDealt>().single;
      expect(cost.amount, 6);
      expect(cost.blocked, 0);
    });

    test('효과로 늘린 업도 상한을 넘지 않는다', () {
      final initial = start(deck: deckOf(strike, 10), karma: 95).copyWith(
        hand: const [karmaOffering],
        drawPile: const [],
        discardPile: const [],
      );

      final result = applyAction(initial, const PlayCard(handIndex: 0));

      expect(result.state.karma, 100);
      expect(result.events.whereType<KarmaGained>().single.amount, 5);
    });

    test('드로우 효과는 요청한 장수를 손패에 더한다', () {
      final initial = start(deck: deckOf(drawTwo, 10));

      final result = applyAction(initial, const PlayCard(handIndex: 0));

      expect(result.state.hand.length, 6, reason: '사용한 1장 뒤 2장을 뽑는다');
      expect(result.events.whereType<CardsDrawn>().single.cards.length, 2);
    });

    test('손패 상한에서는 드로우가 빈자리만 채우고 나머지 덱은 보존한다', () {
      final initial = start(deck: deckOf(strike, 10)).copyWith(
        hand: const [drawTwo, strike, strike, strike, strike, strike],
        drawPile: const [defend, strike],
        discardPile: const [],
      );

      final result = applyAction(initial, const PlayCard(handIndex: 0));

      expect(result.state.hand.length, CombatTuning.m0.maxHandSize);
      expect(result.events.whereType<CardsDrawn>().single.cards, [defend]);
      expect(
        result.state.drawPile.map((card) => card.id),
        [strike.id],
        reason: '상한 때문에 못 뽑은 카드는 덱 순서 그대로 남는다',
      );
    });

    test('드로우 효과도 덱이 모자라면 버림더미를 재셔플한다', () {
      final initial = start(deck: deckOf(strike, 5)).copyWith(
        hand: const [drawThree],
        drawPile: const [strike],
        discardPile: const [defend, strike],
      );

      final result = applyAction(initial, const PlayCard(handIndex: 0));

      expect(result.events.whereType<DeckReshuffled>().single.count, 2);
      expect(result.events.whereType<CardsDrawn>().single.cards.length, 3);
      expect(result.state.hand.length, 3);
      expect(result.state.drawPile, isEmpty);
      expect(result.state.discardPile.single.id, drawThree.id);
    });

    test('드로우가 있는 같은 액션 열은 같은 최종 상태를 낸다', () {
      final deck = List.generate(
        8,
        (index) => CardDef(
          id: 'test_draw_$index',
          name: '시험용 드로우 $index',
          type: CardType.skill,
          cost: 1,
          targeted: false,
          effects: const [DrawCardsEffect(2)],
        ),
      );
      const actions = <CombatAction>[
        PlayCard(handIndex: 0),
        PlayCard(handIndex: 0),
        PlayCard(handIndex: 0),
        EndTurn(),
        PlayCard(handIndex: 0),
        PlayCard(handIndex: 0),
        PlayCard(handIndex: 0),
        EndTurn(),
      ];

      CombatState replay() {
        var state = start(deck: deck, seed: 20260826);
        for (final action in actions) {
          state = applyAction(state, action).state;
        }
        return state;
      }

      final a = replay();
      final b = replay();

      expect(a.hp, b.hp);
      expect(a.energy, b.energy);
      expect(a.karma, b.karma);
      expect(a.turn, b.turn);
      expect(a.rng, b.rng, reason: '드로우 재셔플 뒤 난수기 상태도 같아야 한다');
      expect(
        a.hand.map((card) => card.id).toList(),
        b.hand.map((card) => card.id).toList(),
      );
      expect(
        a.drawPile.map((card) => card.id).toList(),
        b.drawPile.map((card) => card.id).toList(),
      );
      expect(
        a.discardPile.map((card) => card.id).toList(),
        b.discardPile.map((card) => card.id).toList(),
      );
    });

    test('기력 회복은 같은 턴에 고비용 카드를 더 낼 수 있게 한다', () {
      const recoverEnergy = CardDef(
        id: 'test_recover_energy',
        name: '시험용 기력 회복',
        type: CardType.skill,
        cost: 1,
        targeted: false,
        effects: [GainEnergyEffect(2)],
      );
      const costlyGuard = CardDef(
        id: 'test_costly_guard',
        name: '시험용 고비용 수비',
        type: CardType.skill,
        cost: 3,
        targeted: false,
        effects: [BlockEffect(1)],
      );
      final initial = start(deck: deckOf(strike, 10)).copyWith(
        hand: const [recoverEnergy, costlyGuard],
        drawPile: const [],
        discardPile: const [],
      );

      final recovered = applyAction(initial, const PlayCard(handIndex: 0));
      var state = recovered.state;
      expect(state.energy, 4, reason: '3 - 사용 비용 1 + 회복 2');
      expect(recovered.events.whereType<EnergyGained>().single.amount, 2);
      expect(legalActions(state).whereType<PlayCard>().single.handIndex, 0);

      state = applyAction(state, const PlayCard(handIndex: 0)).state;
      expect(state.energy, 1);
    });
  });

  group('원한 — 업을 전투 안에서 체감시키는 장치', () {
    test('원한 스택은 턴 종료 시 업에 비례한 피해를 넣는다', () {
      var state = start(
        deck: deckOf(bladeOfGrudge, 10),
        enemies: [dummy(hp: 50)],
        karma: 50,
      );

      state = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, bladeOfGrudge), targetIndex: 0),
      ).state;

      expect(state.enemies[0].statuses[StatusId.grudge], 1);
      expect(state.karma, 53);
      final hpBeforeEndTurn = state.enemies[0].hp;

      final result = applyAction(state, const EndTurn());

      // 업 53 → 20점당 1, 올림해서 3. 스택 1이므로 3 피해.
      expect(result.state.enemies[0].hp, hpBeforeEndTurn - 3);
    });

    test('업이 0이면 원한은 아무 일도 하지 않는다', () {
      final state = CombatState(
        turn: 1,
        hp: 80,
        maxHp: 80,
        energy: 3,
        block: 0,
        karma: 0,
        hand: const [],
        drawPile: deckOf(strike, 5),
        discardPile: const [],
        enemies: [
          Enemy(
            id: 'e',
            name: '허수아비',
            hp: 30,
            maxHp: 30,
            pattern: const [EnemyDefend(0)],
            statuses: const {StatusId.grudge: 3},
          ),
        ],
        rng: start(deck: deckOf(strike, 5)).rng,
      );

      final result = applyAction(state, const EndTurn());
      expect(result.state.enemies[0].hp, 30);
    });
  });

  group('턴 진행 — §3.1', () {
    test('턴 종료 시 손패를 버리고 방어도가 사라진다', () {
      var state = start(deck: deckOf(defend, 12), enemies: [dummy()]);

      state = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, defend)),
      ).state;
      expect(state.block, 5);

      final result = applyAction(state, const EndTurn());

      expect(result.state.block, 0, reason: '§3.1 — 방어도 소멸');
      expect(result.state.turn, 2);
      expect(result.state.energy, 3, reason: '§3.1 — 기력 3 회복');
      expect(result.state.hand.length, 5, reason: '§3.1 — 손패 5장까지 드로우');
      expect(
        result.state.discardPile.length,
        5,
        reason: '사용한 1장 + 남은 손패 4장',
      );
    });

    test('적은 예고한 행동을 실행하고 다음 행동을 예고한다', () {
      final enemy = Enemy(
        id: 'e',
        name: '아귀',
        hp: 30,
        maxHp: 30,
        pattern: const [EnemyAttack(5), EnemyDefend(4)],
      );
      final state = start(deck: deckOf(strike, 12), enemies: [enemy]);

      expect(state.enemies[0].intent, isA<EnemyAttack>());

      final result = applyAction(state, const EndTurn());

      expect(result.state.hp, 75, reason: '방어도 없이 5를 맞는다');
      expect(
        result.state.enemies[0].intent,
        isA<EnemyDefend>(),
        reason: '§3.1 — 다음 행동은 항상 미리 표시된다',
      );
    });

    test('방어도가 적의 공격을 막는다', () {
      var state = start(
        deck: deckOf(defend, 12),
        enemies: [attacker(damage: 5)],
      );

      state = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, defend)),
      ).state;

      final result = applyAction(state, const EndTurn());

      expect(result.state.hp, 80, reason: '방어도 5가 피해 5를 전부 먹는다');
    });
  });

  group('덱', () {
    test('뽑을 카드가 떨어지면 버림더미를 섞어 되돌린다', () {
      // 6장이면 첫 손패 5장 뒤 덱에 1장만 남는다.
      var state = start(deck: deckOf(strike, 6), enemies: [dummy()]);
      expect(state.drawPile.length, 1);

      final result = applyAction(state, const EndTurn());
      state = result.state;

      expect(result.events.whereType<DeckReshuffled>().single.count, 5);
      expect(state.hand.length, 5);
      expect(state.drawPile.length, 1);
      expect(state.discardPile, isEmpty);
    });

    test('양쪽이 다 비면 더 뽑지 않는다 (예외를 던지지 않는다)', () {
      var state = start(deck: deckOf(strike, 3), enemies: [dummy()]);
      expect(state.hand.length, 3);

      state = applyAction(state, const EndTurn()).state;
      expect(state.hand.length, 3, reason: '3장짜리 덱은 3장만 돈다');
    });
  });

  group('결정론 — §7.4', () {
    test('같은 시드는 같은 첫 손패를 낸다', () {
      final deck = [
        strike,
        defend,
        bladeOfGrudge,
        strike,
        defend,
        strike,
        defend,
        bladeOfGrudge,
      ];

      final a = start(deck: deck, seed: 20260826);
      final b = start(deck: deck, seed: 20260826);

      expect(
        a.hand.map((c) => c.id).toList(),
        b.hand.map((c) => c.id).toList(),
      );
      expect(a.rng, b.rng);
    });

    test('다른 시드는 다른 배열을 낸다', () {
      final deck = List.generate(
        12,
        (i) => CardDef(
          id: 'card_$i',
          name: '카드$i',
          type: CardType.attack,
          cost: 1,
          effects: const [DamageEffect(value: 1)],
        ),
      );

      final orders = <String>{};
      for (final seed in [1, 2, 3, 4, 5]) {
        final s = start(deck: deck, seed: seed);
        orders.add(s.hand.map((c) => c.id).join(','));
      }

      expect(
        orders.length,
        greaterThan(1),
        reason: '시드가 다른데 배열이 전부 같다면 시드가 쓰이지 않고 있다',
      );
    });

    test('같은 액션 열은 같은 최종 상태를 낸다', () {
      final deck = [
        strike,
        defend,
        bladeOfGrudge,
        strike,
        defend,
        strike,
        defend,
        bladeOfGrudge,
        strike,
        defend,
      ];

      CombatState playScript() {
        var state = start(
          deck: deck,
          seed: 99,
          enemies: [attacker(hp: 60, damage: 4)],
        );

        for (var turn = 0; turn < 4; turn++) {
          // 매 턴 첫 번째 합법 카드를 계속 낸다. 결정론 확인이 목적이므로
          // 전략은 필요 없고, 재현 가능한 규칙이기만 하면 된다.
          while (!state.isOver) {
            final playable = legalActions(state).whereType<PlayCard>();
            if (playable.isEmpty) break;
            state = applyAction(state, playable.first).state;
          }
          if (state.isOver) break;
          state = applyAction(state, const EndTurn()).state;
        }
        return state;
      }

      final a = playScript();
      final b = playScript();

      expect(a.hp, b.hp);
      expect(a.karma, b.karma);
      expect(a.turn, b.turn);
      expect(a.enemies[0].hp, b.enemies[0].hp);
      expect(a.rng, b.rng, reason: '난수기 상태까지 일치해야 재생이 성립한다');
      expect(
        a.hand.map((c) => c.id).toList(),
        b.hand.map((c) => c.id).toList(),
      );
    });
  });

  group('합법 액션', () {
    test('기력으로 낼 수 없는 카드는 목록에 없다', () {
      final expensive = const CardDef(
        id: 'card_expensive',
        name: '비싼카드',
        type: CardType.attack,
        cost: 9,
        effects: [DamageEffect(value: 99)],
      );

      final state = start(deck: deckOf(expensive, 10), enemies: [dummy()]);

      expect(legalActions(state).whereType<PlayCard>(), isEmpty);
      expect(legalActions(state).whereType<EndTurn>().length, 1);
    });

    test('대상 카드는 살아 있는 적마다 하나씩 나온다', () {
      final state = start(
        deck: deckOf(strike, 10),
        enemies: [dummy(), dummy(), Enemy(
          id: 'dead',
          name: '시체',
          hp: 0,
          maxHp: 10,
          pattern: const [EnemyDefend(0)],
        )],
      );

      final plays = legalActions(state).whereType<PlayCard>().toList();
      expect(plays.length, 5 * 2, reason: '손패 5장 × 살아 있는 적 2');
      expect(plays.every((p) => p.targetIndex != 2), isTrue);
    });

    test('전투가 끝나면 합법 액션이 없다', () {
      var state = start(deck: deckOf(strike, 10), enemies: [dummy(hp: 6)]);
      state = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, strike), targetIndex: 0),
      ).state;

      expect(state.outcome, CombatOutcome.victory);
      expect(legalActions(state), isEmpty);
      expect(
        () => applyAction(state, const EndTurn()),
        throwsA(isA<IllegalActionError>()),
      );
    });
  });

  group('전투 종료', () {
    test('적을 모두 쓰러뜨리면 승리한다', () {
      var state = start(
        deck: deckOf(strike, 10),
        enemies: [dummy(hp: 6), dummy(hp: 6)],
      );

      state = applyAction(state, const PlayCard(handIndex: 0, targetIndex: 0)).state;
      expect(state.outcome, isNull, reason: '아직 한 마리 남았다');

      final result = applyAction(
        state,
        const PlayCard(handIndex: 0, targetIndex: 1),
      );

      expect(result.state.outcome, CombatOutcome.victory);
      expect(
        result.events.whereType<CombatEnded>().single.outcome,
        CombatOutcome.victory,
      );
      expect(result.events.whereType<EnemyDied>().single.index, 1);
    });

    test('체력이 0이 되면 패배한다', () {
      var state = start(
        deck: deckOf(strike, 12),
        enemies: [attacker(hp: 200, damage: 30)],
        hp: 50,
      );

      state = applyAction(state, const EndTurn()).state;
      expect(state.hp, 20);

      state = applyAction(state, const EndTurn()).state;
      expect(state.hp, 0);
      expect(state.outcome, CombatOutcome.defeat);
    });
  });

  group('상태 효과 — §3.4', () {
    test('취약은 받는 피해를 1.5배로 만든다', () {
      final state = start(
        deck: deckOf(strike, 10),
        enemies: [
          Enemy(
            id: 'e',
            name: '허수아비',
            hp: 50,
            maxHp: 50,
            pattern: const [EnemyDefend(0)],
            statuses: const {StatusId.vulnerable: 2},
          ),
        ],
      );

      final result = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, strike), targetIndex: 0),
      );

      expect(result.state.enemies[0].hp, 41, reason: 'floor(6 * 1.5) = 9');
    });

    test('취약은 턴마다 1씩 빠진다', () {
      var state = start(
        deck: deckOf(strike, 12),
        enemies: [
          Enemy(
            id: 'e',
            name: '허수아비',
            hp: 50,
            maxHp: 50,
            pattern: const [EnemyDefend(0)],
            statuses: const {StatusId.vulnerable: 2},
          ),
        ],
      );

      state = applyAction(state, const EndTurn()).state;
      expect(state.enemies[0].statuses[StatusId.vulnerable], 1);

      state = applyAction(state, const EndTurn()).state;
      expect(
        state.enemies[0].statuses.containsKey(StatusId.vulnerable),
        isFalse,
        reason: '스택이 0이면 항목 자체를 지운다 — 아이콘 12칸이 한계다(§3.4)',
      );
    });

    test('적이 거는 약화는 플레이어의 피해를 깎는다', () {
      var state = start(
        deck: deckOf(strike, 12),
        enemies: [
          Enemy(
            id: 'e',
            name: '탁한 것',
            hp: 50,
            maxHp: 50,
            pattern: const [EnemyInflict(StatusId.weak, 2)],
          ),
        ],
      );

      state = applyAction(state, const EndTurn()).state;
      expect(state.statuses[StatusId.weak], 2);

      final result = applyAction(
        state,
        PlayCard(handIndex: handIndexOf(state, strike), targetIndex: 0),
      );

      expect(result.state.enemies[0].hp, 46, reason: 'floor(6 * 0.75) = 4');
    });
  });

  group('미리보기 — 화면이 규칙을 다시 계산하지 않게 한다', () {
    test('업이 쌓이면 카드에 적히는 피해도 함께 오른다', () {
      final low = start(deck: deckOf(bladeOfGrudge, 10), enemies: [dummy()]);
      final high = start(
        deck: deckOf(bladeOfGrudge, 10),
        enemies: [dummy()],
        karma: 70,
      );

      expect(previewDamage(low, bladeOfGrudge), 6);
      expect(previewDamage(high, bladeOfGrudge), 13, reason: '6 + floor(70 * 0.1)');
    });

    test('미리보기와 실제로 들어가는 피해가 같다', () {
      // 이 둘이 갈라지면 플레이어는 카드에 적힌 숫자와 다른 게임을 하게 된다.
      final state = start(
        deck: deckOf(bladeOfGrudge, 10),
        enemies: [
          Enemy(
            id: 'e',
            name: '허수아비',
            hp: 60,
            maxHp: 60,
            pattern: const [EnemyDefend(0)],
            statuses: const {StatusId.vulnerable: 1},
          ),
        ],
        karma: 40,
      );

      final index = handIndexOf(state, bladeOfGrudge);
      final preview = previewDamage(state, bladeOfGrudge, targetIndex: 0)!;
      final result = applyAction(
        state,
        PlayCard(handIndex: index, targetIndex: 0),
      );

      expect(result.state.enemies[0].hp, 60 - preview);
    });

    test('피해가 없는 카드는 null을 준다', () {
      final state = start(deck: deckOf(defend, 10));
      expect(previewDamage(state, defend), isNull);
      expect(previewBlock(state, defend), 5);
      expect(previewBlock(state, strike), isNull);
    });

    test('적의 예고 피해는 약화를 반영한다', () {
      final state = start(
        deck: deckOf(strike, 10),
        enemies: [attacker(damage: 8)],
      );
      expect(previewEnemyDamage(state, 0), 8);

      final weakened = state.copyWith(
        enemies: [
          state.enemies[0].copyWith(
            statuses: const {StatusId.weak: 1},
          ),
        ],
      );
      expect(previewEnemyDamage(weakened, 0), 6, reason: 'floor(8 * 0.75)');
    });

    test('공격이 아닌 예고에는 피해 숫자가 없다', () {
      final state = start(deck: deckOf(strike, 10), enemies: [dummy()]);
      expect(previewEnemyDamage(state, 0), isNull);
    });
  });

  group('튜닝 값', () {
    test('원한 환산을 바꾸면 피해가 따라 바뀐다', () {
      // §8.2의 시뮬레이터가 상수를 흔들 수 있어야 한다는 것의 최소 확인.
      const generous = CombatTuning(karmaPerGrudgeTick: 10);

      final state = CombatState(
        turn: 1,
        hp: 80,
        maxHp: 80,
        energy: 3,
        block: 0,
        karma: 50,
        hand: const [],
        drawPile: deckOf(strike, 5),
        discardPile: const [],
        enemies: [
          Enemy(
            id: 'e',
            name: '허수아비',
            hp: 50,
            maxHp: 50,
            pattern: const [EnemyDefend(0)],
            statuses: const {StatusId.grudge: 1},
          ),
        ],
        rng: start(deck: deckOf(strike, 5)).rng,
      );

      expect(applyAction(state, const EndTurn()).state.enemies[0].hp, 47);
      expect(
        applyAction(state, const EndTurn(), tuning: generous).state.enemies[0].hp,
        45,
        reason: '20점당 1 → 10점당 1이 되면 3이 5가 된다',
      );
    });
  });
}
