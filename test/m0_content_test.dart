import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/domain/combat/tuning.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/status.dart';

import 'support/m1_card_test_content.dart';

void main() {
  group('M1 카드 콘텐츠', () {
    test('23장은 중복 id 없이 분류별 장수를 만족한다', () {
      final ids = m1Cards.map((card) => card.id).toSet();
      final purifications = m1Cards.where(_isPurification).toList();

      expect(m1Cards, hasLength(23));
      expect(ids, hasLength(23));
      expect(
        m1Cards.where((card) => card.type == CardType.attack),
        hasLength(8),
      );
      expect(
        m1Cards.where((card) => card.type == CardType.power),
        hasLength(3),
      );
      expect(purifications, hasLength(5));
      expect(
        m1Cards.where(
          (card) => card.type == CardType.skill && !_isPurification(card),
        ),
        hasLength(7),
      );
    });

    test('카드 상태는 구현된 여섯 종 안에만 있다', () {
      const supported = {
        StatusId.strength,
        StatusId.dexterity,
        StatusId.vulnerable,
        StatusId.weak,
        StatusId.poison,
        StatusId.grudge,
      };
      final statuses = m1Cards
          .expand((card) => card.effects)
          .whereType<ApplyStatusEffect>()
          .map((effect) => effect.status);

      expect(statuses, everyElement(isIn(supported)));
    });

    test('업 부과 7장과 서로 다른 대가의 정화 5장을 함께 둔다', () {
      final purifications = m1Cards.where(_isPurification).toList();

      expect(m1Cards.where((card) => card.karma > 0), hasLength(7));
      for (final card in purifications) {
        final hasHpCost = card.effects.whereType<LoseHpEffect>().isNotEmpty;
        final spendsWholeTurn = card.cost >= CombatTuning.m0.energyPerTurn;
        final losesTempo = card.effects.whereType<ApplyStatusEffect>().any(
          (effect) =>
              effect.target == EffectTarget.self &&
              (effect.status == StatusId.weak ||
                  effect.status == StatusId.vulnerable),
        );
        final spendsBlock = card.effects
            .whereType<SpendBlockEffect>()
            .isNotEmpty;

        expect(
          hasHpCost || spendsWholeTurn || losesTempo || spendsBlock,
          isTrue,
          reason: card.id,
        );
      }
    });

    test('시작 덱 8장과 카드 보상 풀이 M0 카드 전체를 나눈다', () {
      final starterIds = starterDeck.map((card) => card.id).toSet();
      final rewardIds = cardRewardPool.map((card) => card.id).toSet();

      expect(starterDeck, hasLength(8));
      expect(starterDeck.where((card) => card.karma > 0), hasLength(3));
      expect(starterDeck.where(_isPurification), hasLength(1));
      expect(starterIds.intersection(rewardIds), isEmpty);
      expect(
        starterIds.union(rewardIds),
        m1Cards.map((card) => card.id).toSet(),
      );
    });

    test('새 정화 3종은 보상·상점 풀에서 서로 다른 대가를 낸다', () {
      for (final card in [fastingVow, thinVeil, shatteredWard]) {
        expect(cardRewardPool, contains(card), reason: card.id);
      }

      expect(
        fastingVow.effects.whereType<ApplyStatusEffect>().single.status,
        StatusId.weak,
      );
      expect(
        thinVeil.effects.whereType<ApplyStatusEffect>().single.status,
        StatusId.vulnerable,
      );
      expect(
        shatteredWard.effects.whereType<SpendBlockEffect>().single.amount,
        greaterThan(0),
      );
    });
  });
}

bool _isPurification(CardDef card) => card.effects
    .whereType<ChangeKarmaEffect>()
    .any((effect) => effect.amount < 0);
