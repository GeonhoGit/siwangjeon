import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/m0_content.dart';
import 'package:siwangjeon/domain/combat/combat_engine.dart';
import 'package:siwangjeon/domain/combat/tuning.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/status.dart';

void main() {
  group('M0 카드 콘텐츠', () {
    test('20장은 중복 id 없이 분류별 장수를 만족한다', () {
      final ids = m0Cards.map((card) => card.id).toSet();
      final purifications = m0Cards.where(_isPurification).toList();

      expect(m0Cards, hasLength(20));
      expect(ids, hasLength(20));
      expect(
        m0Cards.where((card) => card.type == CardType.attack),
        hasLength(8),
      );
      expect(
        m0Cards.where((card) => card.type == CardType.power),
        hasLength(3),
      );
      expect(purifications, hasLength(2));
      expect(
        m0Cards.where(
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
      final statuses = m0Cards
          .expand((card) => card.effects)
          .whereType<ApplyStatusEffect>()
          .map((effect) => effect.status);

      expect(statuses, everyElement(isIn(supported)));
    });

    test('업 부과 7장과 대가 있는 정화 2장을 함께 둔다', () {
      final purifications = m0Cards.where(_isPurification).toList();

      expect(m0Cards.where((card) => card.karma > 0), hasLength(7));
      for (final card in purifications) {
        final hasHpCost = card.effects.whereType<LoseHpEffect>().isNotEmpty;
        final spendsWholeTurn = card.cost >= CombatTuning.m0.energyPerTurn;

        expect(hasHpCost || spendsWholeTurn, isTrue, reason: card.id);
      }
    });

    test('시작 덱에서는 고정 시드의 한 전투에 업 카드와 정화 카드가 함께 손에 잡힌다', () {
      final hands = [
        for (final seed in const [7, 19, 53, 20260826])
          beginCombat(
            seed: seed,
            hp: startingHp,
            maxHp: startingHp,
            deck: starterDeck,
            enemies: defaultEncounter(),
          ).state.hand,
      ];

      expect(
        starterDeck.map((card) => card.id).toSet(),
        m0Cards.map((card) => card.id).toSet(),
      );
      expect(
        hands.any(
          (hand) =>
              hand.any((card) => card.karma > 0) && hand.any(_isPurification),
        ),
        isTrue,
      );
    });
  });
}

bool _isPurification(CardDef card) => card.effects
    .whereType<ChangeKarmaEffect>()
    .any((effect) => effect.amount < 0);
