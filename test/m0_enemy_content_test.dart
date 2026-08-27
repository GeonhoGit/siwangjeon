import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/m0_content.dart';
import 'package:siwangjeon/domain/combat/combat_engine.dart';
import 'package:siwangjeon/domain/model/combat_action.dart';
import 'package:siwangjeon/domain/model/combat_state.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/model/status.dart';

import 'support/m1_card_test_content.dart';

void main() {
  group('M0 적 콘텐츠', () {
    test('다섯 종은 중복 id 없이 구현된 상태만 예고한다', () {
      const supported = {
        StatusId.strength,
        StatusId.dexterity,
        StatusId.vulnerable,
        StatusId.weak,
        StatusId.poison,
        StatusId.grudge,
      };
      final enemies = [agwi(), wongwi(), dokgwi(), yacha(), nachal()];

      expect(enemies.map((enemy) => enemy.id).toSet(), hasLength(5));
      for (final move in enemies.expand((enemy) => enemy.pattern)) {
        if (move case EnemyInflict(:final status)) {
          expect(supported, contains(status));
        }
      }
    });

    test('기본 조우는 아귀·원귀·독귀 세 마리를 실제로 올린다', () {
      expect(defaultEncounter().map((enemy) => enemy.id), [
        'enemy_agwi',
        'enemy_wongwi',
        'enemy_dokgwi',
      ]);
    });

    test('기존 다섯 적은 페이즈가 없어 예전 순환을 그대로 쓴다', () {
      for (final enemy in [agwi(), wongwi(), dokgwi(), yacha(), nachal()]) {
        expect(enemy.phaseCount, 1, reason: enemy.name);
        expect(enemy.activePattern, enemy.pattern, reason: enemy.name);

        var state = _startAgainst(enemy);
        for (final expected in enemy.pattern) {
          expect(
            state.enemies.single.intent.runtimeType,
            expected.runtimeType,
            reason: enemy.name,
          );
          state = applyAction(state, const EndTurn()).state;
        }
      }
    });

    test('독귀는 중독 뒤 방어, 야차는 기세 뒤 연타, 나찰은 방어 뒤 취약을 예고한다', () {
      var poisonState = _startAgainst(dokgwi());
      expect(poisonState.enemies.single.intent, isA<EnemyInflict>());
      poisonState = applyAction(poisonState, const EndTurn()).state;
      expect(poisonState.statuses[StatusId.poison], 1);
      expect(poisonState.enemies.single.intent, isA<EnemyDefend>());
      poisonState = applyAction(poisonState, const EndTurn()).state;
      expect(poisonState.enemies.single.intent, isA<EnemyAttack>());

      var strengthState = _startAgainst(yacha());
      strengthState = applyAction(strengthState, const EndTurn()).state;
      expect(strengthState.enemies.single.statuses[StatusId.strength], 2);
      expect(previewEnemyDamage(strengthState, 0), 7);
      strengthState = applyAction(strengthState, const EndTurn()).state;
      expect(strengthState.hp, 66, reason: '기세 2가 붙은 7 피해를 두 번 맞는다');
      expect(strengthState.enemies.single.intent, isA<EnemyDefend>());

      var defenseState = _startAgainst(nachal());
      defenseState = applyAction(defenseState, const EndTurn()).state;
      expect(defenseState.enemies.single.block, 10);
      expect(defenseState.enemies.single.intent, isA<EnemyInflict>());
      defenseState = applyAction(defenseState, const EndTurn()).state;
      expect(defenseState.statuses[StatusId.vulnerable], 2);
      expect(defenseState.enemies.single.intent, isA<EnemyAttack>());
    });
  });
}

CombatState _startAgainst(Enemy enemy) => beginCombat(
  seed: 20260826,
  hp: startingHp,
  maxHp: startingHp,
  deck: starterDeck,
  enemies: [enemy],
).state;
