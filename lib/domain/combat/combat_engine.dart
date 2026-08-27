/// 전투 엔진 (기획서 §7.2).
///
/// 계약은 단 하나다 — **순수 함수**여야 한다.
///
/// ```
/// (CombatState, CombatAction) → (CombatState, List<GameEvent>)
/// ```
///
/// 이 계약이 지켜지는 동안에만 다음이 가능하다.
/// - UI 없이 유닛 테스트 수천 개를 돌린다
/// - 밸런스 시뮬레이터가 CLI에서 10만 런을 자동 플레이한다 (§8.2)
/// - 애니메이션은 반환된 이벤트 목록을 재생만 한다
///
/// 그래서 이 파일에는 난수·시계·파일 접근·전역 상태가 들어가면 안 된다.
/// 난수가 필요하면 [CombatState]가 들고 있는 명시적 RNG 스트림에서 뽑는다 (§7.4).
library;

import '../effect/card_effect.dart';
import '../model/card.dart';
import '../model/combat_action.dart';
import '../model/combat_state.dart';
import '../model/enemy.dart';
import '../model/game_event.dart';
import '../model/relic.dart';
import '../model/status.dart';
import '../rng/rng.dart';
import 'tuning.dart';

/// 엔진 1회 적용의 결과.
class CombatResult {
  const CombatResult(this.state, this.events);

  final CombatState state;
  final List<GameEvent> events;
}

/// 규칙상 불가능한 액션이 들어왔다.
///
/// 이것은 플레이어의 실수가 아니라 **호출자의 버그**다. UI는 [legalActions]가
/// 돌려준 것만 보여야 하고, 액션 로그에는 합법적인 액션만 쌓여야 한다.
/// 불법 액션이 로그에 섞이면 §7.4의 재생 복구가 그 지점에서 무너진다.
/// 그래서 조용히 무시하지 않고 던진다.
class IllegalActionError extends Error {
  IllegalActionError(this.message);

  final String message;

  @override
  String toString() => 'IllegalActionError: $message';
}

/// 전투를 시작한다.
///
/// [karma]를 받는 이유는 업이 전투가 아니라 **런** 단위 자원이기 때문이다(§3.2).
/// 이전 전투에서 쌓은 업을 그대로 들고 들어온다.
CombatResult beginCombat({
  required int seed,
  required int hp,
  required int maxHp,
  required List<CardDef> deck,
  required List<Enemy> enemies,
  int karma = 0,
  List<RelicDef> relics = const [],
  CombatTuning tuning = CombatTuning.m0,
}) {
  final (drawPile, rng) = Rng.forStream(seed, RngStream.combat).shuffled(deck);

  final start = CombatState(
    turn: 1,
    hp: hp,
    maxHp: maxHp,
    energy: tuning.energyPerTurn,
    block: 0,
    karma: karma.clamp(0, tuning.maxKarma),
    hand: const [],
    drawPile: drawPile,
    discardPile: const [],
    enemies: enemies,
    rng: rng,
    relics: relics,
  );

  final sim = _Sim(start, tuning);
  sim.trigger(RelicTrigger.combatStarted);
  sim.events.add(TurnStarted(sim.turn));
  sim.trigger(RelicTrigger.turnStarted);
  sim.draw(tuning.handSize - sim.hand.length);

  return sim.finish();
}

/// 액션 하나를 적용해 다음 상태와 그 과정에서 일어난 이벤트를 돌려준다.
CombatResult applyAction(
  CombatState state,
  CombatAction action, {
  CombatTuning tuning = CombatTuning.m0,
}) {
  if (state.isOver) {
    throw IllegalActionError('이미 끝난 전투에 액션을 적용할 수 없다');
  }

  final sim = _Sim(state, tuning);

  switch (action) {
    case PlayCard():
      sim.playCard(action);
    case EndTurn():
      sim.endTurn();
  }

  return sim.finish();
}

/// 지금 상태에서 규칙상 가능한 모든 액션.
///
/// UI의 버튼 활성화와 §8.2 시뮬레이터의 수 선택이 같은 함수를 쓰게 하려는 것이다.
/// 두 곳이 각자 판단하면 반드시 어긋나고, 그때 시뮬레이터가 낸 밸런스 수치는
/// 실제 플레이와 다른 게임의 것이 된다.
List<CombatAction> legalActions(CombatState state) {
  if (state.isOver) return const [];

  final actions = <CombatAction>[const EndTurn()];

  for (var i = 0; i < state.hand.length; i++) {
    final card = state.hand[i];
    if (card.cost > state.energy) continue;

    if (card.targeted) {
      for (var t = 0; t < state.enemies.length; t++) {
        if (state.enemies[t].isAlive) {
          actions.add(PlayCard(handIndex: i, targetIndex: t));
        }
      }
    } else {
      actions.add(PlayCard(handIndex: i));
    }
  }

  return actions;
}

/// 카드가 지금 이 대상에게 넣을 피해량. 피해 효과가 없으면 null.
///
/// 화면이 직접 계산하지 않게 하려고 엔진이 내준다. 기세·약화·취약과 업 비례가
/// 전부 걸린 **최종 수치**여야 하고, 그러려면 §3.4의 규칙을 알아야 한다.
/// UI가 그 규칙의 사본을 갖는 순간 둘은 반드시 어긋나고, 플레이어는
/// 카드에 적힌 숫자와 실제로 들어간 숫자가 다른 게임을 하게 된다.
///
/// §8.1의 1번 질문에 답하려면 이 값이 특히 정확해야 한다. 업이 쌓일수록
/// 「원한의 칼날」이 세지는 것이 **보이지 않으면** 업은 고민이 아니라
/// 그냥 숨은 수치가 된다.
int? previewDamage(
  CombatState state,
  CardDef card, {
  int? targetIndex,
  CombatTuning tuning = CombatTuning.m0,
}) {
  final sim = _Sim(state, tuning);
  return sim.previewCardDamage(card, targetIndex);
}

/// 전투 상태가 없을 때 카드 정의만으로 알 수 있는 기본 피해량.
///
/// 보상 화면은 아직 전투를 시작하지 않아 기세·약화·취약과 현재 업을 적용할
/// 근거가 없다. 그 화면은 이 값을 "상태와 업 보정 전 기본 수치"로 명시해
/// 보여 주고, 실제 전투에서는 반드시 [previewDamage]의 최종 수치를 쓴다.
/// 이렇게 두 표시의 적용 범위를 엔진에서 정해 UI가 피해 규칙을 복제하지 않는다.
int? previewBaseDamage(CardDef card) {
  var total = 0;
  var found = false;

  for (final effect in card.effects) {
    if (effect is! DamageEffect) continue;
    found = true;
    total += effect.value;
  }

  return found ? total : null;
}

/// 카드가 지금 줄 방어도. 방어 효과가 없으면 null.
int? previewBlock(
  CombatState state,
  CardDef card, {
  CombatTuning tuning = CombatTuning.m0,
}) {
  final sim = _Sim(state, tuning);
  return sim.previewCardBlock(card);
}

/// 전투 상태가 없을 때 카드 정의만으로 알 수 있는 기본 방어도.
///
/// 보상에서는 [previewBaseDamage]와 같은 이유로 굳음 보정을 적용하지 않는다.
/// 현재 전투의 실제 방어도 표시는 [previewBlock]만 사용한다.
int? previewBaseBlock(CardDef card) {
  var total = 0;
  var found = false;

  for (final effect in card.effects) {
    if (effect is! BlockEffect) continue;
    found = true;
    total += effect.value;
  }

  return found ? total : null;
}

/// 적이 예고한 공격이 지금 플레이어에게 넣을 1회 피해량.
///
/// §3.1은 다음 행동을 항상 미리 보여 주라고 요구한다. 그런데 보여 준 숫자가
/// 약화·취약을 반영하지 않은 기본값이면, 플레이어는 그 예고를 근거로
/// 방어를 계산할 수 없다. 예고의 값어치는 정확도에서 나온다.
int? previewEnemyDamage(
  CombatState state,
  int enemyIndex, {
  CombatTuning tuning = CombatTuning.m0,
}) {
  final enemy = state.enemies[enemyIndex];
  final move = enemy.intent;
  if (move is! EnemyAttack) return null;

  final sim = _Sim(state, tuning);
  return sim.incomingDamage(move.damage, enemy.statuses);
}

/// 엔진 내부의 가변 작업대.
///
/// 불변 상태를 한 단계씩 `copyWith`로 넘기면 전투 한 턴에 수십 개의 중간
/// 인스턴스가 생기고, 코드가 규칙이 아니라 상태 배관으로 뒤덮인다.
/// 대신 여기서만 가변으로 굴리고 [finish]에서 다시 불변으로 봉한다.
/// 이 클래스는 파일 밖으로 나가지 않으므로 순수 함수 계약은 그대로다.
class _Sim {
  _Sim(CombatState s, this.tuning)
    : turn = s.turn,
      hp = s.hp,
      maxHp = s.maxHp,
      energy = s.energy,
      block = s.block,
      karma = s.karma,
      hand = List.of(s.hand),
      drawPile = List.of(s.drawPile),
      discardPile = List.of(s.discardPile),
      activePowers = List.of(s.activePowers),
      enemies = List.of(s.enemies),
      statuses = Map.of(s.statuses),
      rng = s.rng,
      relics = List.of(s.relics),
      outcome = s.outcome;

  final CombatTuning tuning;
  final List<GameEvent> events = [];

  int turn;
  int hp;
  int maxHp;
  int energy;
  int block;
  int karma;
  List<CardDef> hand;
  List<CardDef> drawPile;
  List<CardDef> discardPile;
  List<CardDef> activePowers;
  List<Enemy> enemies;
  Map<StatusId, int> statuses;
  Rng rng;
  List<RelicDef> relics;
  CombatOutcome? outcome;

  KarmaBand get karmaBand => KarmaBand.of(karma);

  CombatResult finish() {
    return CombatResult(
      CombatState(
        turn: turn,
        hp: hp,
        maxHp: maxHp,
        energy: energy,
        block: block,
        karma: karma,
        hand: List.unmodifiable(hand),
        drawPile: List.unmodifiable(drawPile),
        discardPile: List.unmodifiable(discardPile),
        activePowers: List.unmodifiable(activePowers),
        enemies: List.unmodifiable(enemies),
        statuses: Map.unmodifiable(statuses),
        rng: rng,
        relics: List.unmodifiable(relics),
        outcome: outcome,
      ),
      List.unmodifiable(events),
    );
  }

  // ── 액션 ──────────────────────────────────────────────

  void playCard(PlayCard action) {
    if (action.handIndex < 0 || action.handIndex >= hand.length) {
      throw IllegalActionError('손패 ${hand.length}장에 ${action.handIndex}번은 없다');
    }

    final card = hand[action.handIndex];

    if (card.cost > energy) {
      throw IllegalActionError(
        '${card.name}은 기력 ${card.cost}이 필요하나 $energy뿐이다',
      );
    }

    int? target;
    if (card.targeted) {
      target = action.targetIndex;
      if (target == null || target < 0 || target >= enemies.length) {
        throw IllegalActionError('${card.name}은 대상이 필요하다');
      }
      if (!enemies[target].isAlive) {
        throw IllegalActionError('${card.name}의 대상 $target번은 이미 쓰러졌다');
      }
    }

    hand.removeAt(action.handIndex);
    energy -= card.cost;
    events.add(CardPlayed(card));
    _resolveCardEffects(card, target);

    // 힘(power) 카드는 버림더미로 가지 않고 전투 내내 활성 영역에 남는다(§3.5).
    // 활성 영역은 재섞기 경로와 분리되어 있으므로, 덱 구성이 액션 로그 재생
    // 때도 고정되고 같은 힘 카드가 다시 손에 들어오지 않는다.
    if (card.type == CardType.power) {
      activePowers.add(card);
    } else {
      discardPile.add(card);
    }

    _checkOutcome();
  }

  void endTurn() {
    events.add(TurnEnded(turn));

    _tickGrudge();
    if (outcome != null) return;
    trigger(RelicTrigger.turnEnded);
    if (outcome != null) return;

    // §3.1 — 남은 손패 버림.
    discardPile.addAll(hand);
    hand = [];

    _decayPlayerStatuses();

    _enemyTurn();
    if (outcome != null) return;

    _startPlayerTurn();
  }

  // ── 턴 진행 ────────────────────────────────────────────

  /// 원한(怨恨) — 업에 비례한 피해가 플레이어 턴 끝에 터진다 (§3.4).
  ///
  /// 이 상태만 전투 안에서 업을 페널티가 아니라 **무기**로 쓴다.
  /// §3.3이 업의 대가를 심판까지 미뤄 두었기 때문에, 업을 쌓는 선택이
  /// 전투 중에는 순수한 이득으로만 보이는 문제가 있다.
  /// 원한은 그 이득을 전투 안에서 한 번 체감하게 만드는 장치다.
  void _tickGrudge() {
    final perTick = tuning.karmaPerGrudgeTick;
    final scale = (karma + perTick - 1) ~/ perTick;
    if (scale <= 0) return;

    for (var i = 0; i < enemies.length; i++) {
      if (!enemies[i].isAlive) continue;
      final stacks = enemies[i].statuses[StatusId.grudge] ?? 0;
      if (stacks <= 0) continue;

      _damageEnemy(i, stacks * scale, mitigate: false);
    }

    _checkOutcome();
  }

  void _enemyTurn() {
    for (var i = 0; i < enemies.length; i++) {
      if (!enemies[i].isAlive) continue;

      // 적 턴 시작 — 중독이 먼저 돈다.
      _tickEnemyPoison(i);
      if (outcome != null) return;
      if (!enemies[i].isAlive) continue;

      // 적의 방어도도 자기 턴이 시작될 때 사라진다.
      enemies[i] = enemies[i].copyWith(block: 0);

      _executeMove(i, enemies[i].intent);
      if (outcome != null) return;

      enemies[i] = enemies[i].copyWith(
        patternIndex: enemies[i].patternIndex + 1,
      );
      _decayEnemyStatuses(i);
    }
  }

  void _executeMove(int index, EnemyMove move) {
    switch (move) {
      case EnemyAttack():
        for (var n = 0; n < move.times; n++) {
          if (outcome != null) return;
          _damagePlayer(move.damage, attacker: enemies[index].statuses);
        }

      case EnemyDefend():
        enemies[index] = enemies[index].copyWith(
          block: enemies[index].block + move.block,
        );
        events.add(BlockGained(targetIndex: index, amount: move.block));

      case EnemyInflict():
        // 적 입장의 `enemy`는 플레이어를 가리킨다.
        if (move.target == EffectTarget.enemy) {
          _addStatusToPlayer(move.status, move.stacks);
        } else {
          _addStatusToEnemy(index, move.status, move.stacks);
        }
    }
  }

  void _startPlayerTurn() {
    turn++;
    events.add(TurnStarted(turn));

    // 방어도(魄)는 여기서 사라진다.
    //
    // §3.1의 의사코드는 "턴 종료: 남은 손패 버림, 방어도 소멸"을 적 턴보다
    // 위에 적어 두었지만, 그대로 구현하면 적이 때리기 전에 방어도가 없어져
    // 「수비」 같은 방어 카드가 아무것도 하지 않는다. 방어 카드가 존재하는 한
    // 그 순서가 의도일 수 없으므로, "그 턴에 쌓은 방어도가 적 턴을 막아 내고
    // 다음 내 턴이 열릴 때 사라진다"로 읽었다.
    //
    // 적의 방어도도 같은 규칙이다 — 각자 자기 턴이 시작될 때 사라진다.
    block = 0;

    energy = tuning.energyPerTurn;

    trigger(RelicTrigger.turnStarted);

    _tickPlayerPoison();
    if (outcome != null) return;

    draw(tuning.handSize - hand.length);
  }

  // ── 효과 인터프리터 ──────────────────────────────────────

  void _applyEffect(CardEffect effect, int? target) {
    switch (effect) {
      case DamageEffect():
        var value = effect.value.toDouble();
        if (effect.scaleWith == 'karma') {
          value += karma * effect.scale;
        }
        if (target != null) {
          _damageEnemy(target, value.floor());
        }

      case BlockEffect():
        final gained = effect.value + (statuses[StatusId.dexterity] ?? 0);
        block += gained;
        events.add(
          BlockGained(targetIndex: CombatState.playerIndex, amount: gained),
        );

      case ChangeKarmaEffect():
        _changeKarma(effect.amount);

      case DrawCardsEffect():
        // 턴 시작 드로우와 반드시 같은 경로를 쓴다. 여기서만 전투 RNG를
        // 다음 상태로 넘기므로, 카드 드로우도 §7.4의 재생성을 지킨다.
        draw(effect.count);

      case GainEnergyEffect():
        energy += effect.amount;
        if (effect.amount != 0) events.add(EnergyGained(effect.amount));

      case LoseHpEffect():
        _loseHp(effect.amount);

      case ApplyStatusEffect():
        if (effect.target == EffectTarget.self) {
          _addStatusToPlayer(effect.status, effect.stacks);
        } else if (target != null) {
          _addStatusToEnemy(target, effect.status, effect.stacks);
        }
    }
  }

  void _resolveCardEffects(CardDef card, int? target) {
    for (final effect in card.effects) {
      _applyEffect(effect, target);
    }

    // 업은 효과가 해결된 뒤에 붙는다. 업 비례 카드가 자기 비용으로 피해를
    // 키우지 않게 하는 기존 전투 순서를 유물 훅도 그대로 따른다.
    if (card.karma != 0) _changeKarma(card.karma);
    trigger(RelicTrigger.cardPlayed, card: card, target: target);
  }

  /// 유물 선언을 실제 전투 규칙으로 바꾸는 유일한 곳.
  void trigger(RelicTrigger trigger, {CardDef? card, int? target}) {
    for (final relic in relics) {
      if (relic.trigger != trigger) continue;

      switch (relic.effect) {
        case KarmaScaledStrengthEffect():
          final stacks = karma ~/ tuning.karmaPerRelicStrength;
          if (stacks > 0) _addStatusToPlayer(StatusId.strength, stacks);

        case PureDexterityEffect():
          if (karmaBand == KarmaBand.pure) {
            _addStatusToPlayer(StatusId.dexterity, tuning.pureRelicDexterity);
          }

        case OpeningDrawEffect():
          draw(tuning.openingRelicDrawCount);

        case OpeningCleanseEffect():
          _changeKarma(-tuning.openingRelicCleanse);

        case KarmaBandBlockEffect():
          final gained = switch (karmaBand) {
            KarmaBand.pure => tuning.pureRelicTurnBlock,
            KarmaBand.ordinary => tuning.ordinaryRelicTurnBlock,
            KarmaBand.turbid => tuning.turbidRelicTurnBlock,
            KarmaBand.wicked => 0,
          };
          if (gained > 0) {
            block += gained;
            events.add(
              BlockGained(targetIndex: CombatState.playerIndex, amount: gained),
            );
          }

        case TurbidEnergyEffect():
          if (_isTurbidOrWicked) {
            energy += tuning.turbidRelicEnergy;
            events.add(EnergyGained(tuning.turbidRelicEnergy));
          }

        case KarmaCardBonusDamageEffect():
          if (card != null && card.karma > 0 && target != null) {
            _damageEnemy(target, tuning.karmaCardBonusDamage);
          }

        case CleanCardBlockEffect():
          if (card != null && card.karma == 0) {
            block += tuning.cleanCardBlock;
            events.add(
              BlockGained(
                targetIndex: CombatState.playerIndex,
                amount: tuning.cleanCardBlock,
              ),
            );
          }

        case UnblockedDamageVulnerableEffect():
          if (target != null) {
            _addStatusToEnemy(
              target,
              StatusId.vulnerable,
              tuning.unblockedDamageVulnerable,
            );
          }

        case UnblockedDamageKarmaEffect():
          _changeKarma(tuning.unblockedDamageKarma);

        case KarmaBurstEffect():
          final damage = karma ~/ tuning.karmaPerRelicBurst;
          if (damage > 0) {
            for (var i = 0; i < enemies.length; i++) {
              if (enemies[i].isAlive) _damageEnemy(i, damage);
            }
          }

        case TurnEndCleanseEffect():
          _changeKarma(-tuning.turnEndRelicCleanse);

        case EnemyDeathHealEffect():
          hp = (hp + tuning.enemyDeathRelicHeal).clamp(0, maxHp);

        case EnemyDeathBlockEffect():
          block += tuning.enemyDeathRelicBlock;
          events.add(
            BlockGained(
              targetIndex: CombatState.playerIndex,
              amount: tuning.enemyDeathRelicBlock,
            ),
          );

        case TurbidDamageReductionEffect():
        // [incomingDamage]에서 방어도 전에 공통으로 해석한다.
      }
    }
  }

  bool get _isTurbidOrWicked =>
      karmaBand == KarmaBand.turbid || karmaBand == KarmaBand.wicked;

  int? previewCardDamage(CardDef card, int? target) {
    if (target != null &&
        (target < 0 || target >= enemies.length || !enemies[target].isAlive)) {
      return null;
    }

    // 대상을 고르기 전 카드 표시는 대상 상태를 모른다는 기존 계약을 지킨다.
    // 다만 피해 계산 자체는 실제 카드 해석 경로를 그대로 지나게 한다.
    final resolvedTarget = target ?? enemies.length;
    if (target == null) {
      enemies.add(
        Enemy(
          id: 'preview_target',
          name: '미리보기 대상',
          hp: 1000000000,
          maxHp: 1000000000,
          pattern: const [EnemyDefend(0)],
        ),
      );
    }

    final eventCount = events.length;
    _resolveCardEffects(card, resolvedTarget);
    final damage = events
        .skip(eventCount)
        .whereType<DamageDealt>()
        .where((event) => event.targetIndex == resolvedTarget)
        .fold(0, (total, event) => total + event.amount + event.blocked);
    return damage == 0 && !card.effects.any((effect) => effect is DamageEffect)
        ? null
        : damage;
  }

  int? previewCardBlock(CardDef card) {
    final before = block;
    final eventCount = events.length;
    _resolveCardEffects(card, null);
    final gained = events
        .skip(eventCount)
        .whereType<BlockGained>()
        .where((event) => event.targetIndex == CombatState.playerIndex)
        .fold(0, (total, event) => total + event.amount);
    if (gained == 0 && block == before) return null;
    return block - before;
  }

  // ── 피해 ──────────────────────────────────────────────

  /// 기세·약화·취약을 반영한 최종 피해량.
  int _attackDamage(
    int base,
    Map<StatusId, int> attacker,
    Map<StatusId, int> defender,
  ) {
    var value = (base + (attacker[StatusId.strength] ?? 0)).toDouble();

    if ((attacker[StatusId.weak] ?? 0) > 0) {
      value = (value * tuning.weakMultiplier).floorToDouble();
    }
    if ((defender[StatusId.vulnerable] ?? 0) > 0) {
      value = (value * tuning.vulnerableMultiplier).floorToDouble();
    }

    final result = value.floor();
    return result < 0 ? 0 : result;
  }

  void _damageEnemy(int index, int base, {bool mitigate = true}) {
    final enemy = enemies[index];
    if (!enemy.isAlive) return;

    final amount = mitigate
        ? _attackDamage(base, statuses, enemy.statuses)
        : base;

    final blocked = amount < enemy.block ? amount : enemy.block;
    final through = amount - blocked;

    enemies[index] = enemy.copyWith(
      block: enemy.block - blocked,
      hp: enemy.hp - through < 0 ? 0 : enemy.hp - through,
    );

    events.add(
      DamageDealt(targetIndex: index, amount: through, blocked: blocked),
    );

    if (!enemies[index].isAlive) {
      events.add(EnemyDied(index));
      trigger(RelicTrigger.enemyDied);
    }
    if (through > 0) {
      trigger(RelicTrigger.playerDamageDealt, target: index);
    }
  }

  void _damagePlayer(int base, {Map<StatusId, int>? attacker}) {
    final amount = attacker == null ? base : incomingDamage(base, attacker);

    final blocked = amount < block ? amount : block;
    final through = amount - blocked;

    block -= blocked;
    hp -= through;
    if (hp < 0) hp = 0;

    events.add(
      DamageDealt(
        targetIndex: CombatState.playerIndex,
        amount: through,
        blocked: blocked,
      ),
    );

    _checkOutcome();
  }

  /// 적의 공격 피해와 예고가 함께 쓰는, 방어도 전 최종 피해량.
  int incomingDamage(int base, Map<StatusId, int> attacker) {
    var amount = _attackDamage(base, attacker, statuses);
    for (final relic in relics) {
      if (relic.trigger != RelicTrigger.playerDamageTaken) continue;
      switch (relic.effect) {
        case TurbidDamageReductionEffect():
          if (_isTurbidOrWicked) {
            amount -= tuning.turbidRelicDamageReduction;
          }
        case KarmaScaledStrengthEffect() ||
            PureDexterityEffect() ||
            OpeningDrawEffect() ||
            OpeningCleanseEffect() ||
            KarmaBandBlockEffect() ||
            TurbidEnergyEffect() ||
            KarmaCardBonusDamageEffect() ||
            CleanCardBlockEffect() ||
            UnblockedDamageVulnerableEffect() ||
            UnblockedDamageKarmaEffect() ||
            KarmaBurstEffect() ||
            TurnEndCleanseEffect() ||
            EnemyDeathHealEffect() ||
            EnemyDeathBlockEffect():
          throw StateError('유물 발동 시점이 효과와 다르다');
      }
    }
    return amount < 0 ? 0 : amount;
  }

  /// 방어도를 피해 가는 체력 대가. 정화의 비용은 공격 피해가 아니다.
  void _loseHp(int amount) {
    if (amount <= 0) return;

    final lost = amount < hp ? amount : hp;
    hp -= lost;
    events.add(
      DamageDealt(
        targetIndex: CombatState.playerIndex,
        amount: lost,
        blocked: 0,
      ),
    );
    _checkOutcome();
  }

  void _changeKarma(int amount) {
    if (amount == 0) return;

    final before = karma;
    karma = (karma + amount).clamp(0, tuning.maxKarma);
    final changed = karma - before;
    if (changed != 0) events.add(KarmaGained(changed));
  }

  // ── 상태 효과 ──────────────────────────────────────────

  void _addStatusToPlayer(StatusId id, int stacks) {
    if (stacks == 0) return;
    statuses = _bump(statuses, id, stacks);
    events.add(
      StatusApplied(
        targetIndex: CombatState.playerIndex,
        status: id,
        stacks: stacks,
      ),
    );
  }

  void _addStatusToEnemy(int index, StatusId id, int stacks) {
    if (stacks == 0 || !enemies[index].isAlive) return;
    enemies[index] = enemies[index].copyWith(
      statuses: _bump(enemies[index].statuses, id, stacks),
    );
    events.add(StatusApplied(targetIndex: index, status: id, stacks: stacks));
  }

  static Map<StatusId, int> _bump(
    Map<StatusId, int> source,
    StatusId id,
    int delta,
  ) {
    final next = Map<StatusId, int>.of(source);
    final value = (next[id] ?? 0) + delta;
    if (value <= 0) {
      next.remove(id);
    } else {
      next[id] = value;
    }
    return next;
  }

  /// 턴마다 1씩 빠지는 상태들. 기세·굳음처럼 지속되는 것은 건드리지 않는다.
  static const _decaying = [StatusId.vulnerable, StatusId.weak];

  void _decayPlayerStatuses() {
    var next = statuses;
    for (final id in _decaying) {
      if ((next[id] ?? 0) > 0) next = _bump(next, id, -1);
    }
    statuses = next;
  }

  void _decayEnemyStatuses(int index) {
    var next = enemies[index].statuses;
    for (final id in _decaying) {
      if ((next[id] ?? 0) > 0) next = _bump(next, id, -1);
    }
    enemies[index] = enemies[index].copyWith(statuses: next);
  }

  void _tickEnemyPoison(int index) {
    final stacks = enemies[index].statuses[StatusId.poison] ?? 0;
    if (stacks <= 0) return;

    // 중독은 방어도를 무시한다.
    _damageEnemy(index, stacks, mitigate: false);
    enemies[index] = enemies[index].copyWith(
      statuses: _bump(enemies[index].statuses, StatusId.poison, -1),
    );
    _checkOutcome();
  }

  void _tickPlayerPoison() {
    final stacks = statuses[StatusId.poison] ?? 0;
    if (stacks <= 0) return;

    hp -= stacks;
    if (hp < 0) hp = 0;
    events.add(
      DamageDealt(
        targetIndex: CombatState.playerIndex,
        amount: stacks,
        blocked: 0,
      ),
    );

    statuses = _bump(statuses, StatusId.poison, -1);
    _checkOutcome();
  }

  // ── 덱 ────────────────────────────────────────────────

  void draw(int count) {
    if (count <= 0) return;

    // 상한에 걸린 카드는 덱에서 꺼내지 않는다. 버리거나 재셔플하면 덱 순서와
    // 전투 RNG 스트림이 바뀌어 §7.4의 액션 로그 재생이 달라질 수 있다.
    final available = tuning.maxHandSize - hand.length;
    if (available <= 0) return;

    final drawn = <CardDef>[];

    for (var i = 0; i < count && i < available; i++) {
      if (drawPile.isEmpty) {
        // 덱이 비면 버림더미를 섞어 되돌린다. 양쪽 다 비었으면 더 못 뽑는다.
        if (discardPile.isEmpty) break;

        final (shuffled, next) = rng.shuffled(discardPile);
        rng = next;
        events.add(DeckReshuffled(discardPile.length));
        drawPile = shuffled;
        discardPile = [];
      }

      drawn.add(drawPile.removeAt(0));
    }

    if (drawn.isEmpty) return;
    hand.addAll(drawn);
    events.add(CardsDrawn(List.unmodifiable(drawn)));
  }

  // ── 종료 판정 ──────────────────────────────────────────

  void _checkOutcome() {
    if (outcome != null) return;

    if (hp <= 0) {
      outcome = CombatOutcome.defeat;
      events.add(const CombatEnded(CombatOutcome.defeat));
      return;
    }

    if (!enemies.any((e) => e.isAlive)) {
      outcome = CombatOutcome.victory;
      events.add(const CombatEnded(CombatOutcome.victory));
    }
  }
}
