import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/domain/combat/card_enhancement.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/status.dart';

import 'support/m1_card_test_content.dart';

void main() {
  group('카드별 JSON 강화', () {
    test('모든 카드의 강화본은 해당 카드 upgrade 효과를 그대로 쓴다', () {
      for (final card in m1Cards) {
        final enhanced = enhancedCard(card);

        expect(enhanced.name, '${card.name}+');
        expect(enhanced.cost, card.cost);
        expect(enhanced.karma, card.karma);
        expect(enhanced.effects, same(card.upgrade!.effects), reason: card.id);
      }
    });

    test('효과 종류가 다른 upgrade도 카드별 정의대로 적용한다', () {
      const testCard = CardDef(
        id: 'test_card_specific_upgrade',
        name: '카드별 강화 확인',
        type: CardType.attack,
        cost: 1,
        effects: [DamageEffect(value: 1)],
        upgrade: CardUpgrade(effects: [DrawCardsEffect(2)]),
      );

      final enhanced = enhancedCard(testCard);

      expect(enhanced.effects.single, isA<DrawCardsEffect>());
      expect((enhanced.effects.single as DrawCardsEffect).count, 2);
    });

    test('정화 강화는 대가를 유지하고 정화량만 늘린다', () {
      final purifications = m1Cards.where(_isPurification);

      for (final card in purifications) {
        final enhanced = enhancedCard(card);
        final baseCleanse = _cleanseAmount(card);
        final enhancedCleanse = _cleanseAmount(enhanced);

        expect(enhanced.cost, card.cost, reason: card.id);
        expect(
          _costSignatures(enhanced),
          _costSignatures(card),
          reason: card.id,
        );
        expect(
          enhancedCleanse,
          lessThan(baseCleanse),
          reason: '${card.id}: 정화량만 증가해야 한다',
        );
      }
    });
  });
}

bool _isPurification(CardDef card) => card.effects
    .whereType<ChangeKarmaEffect>()
    .any((effect) => effect.amount < 0);

int _cleanseAmount(CardDef card) => card.effects
    .whereType<ChangeKarmaEffect>()
    .singleWhere((effect) => effect.amount < 0)
    .amount;

List<String> _costSignatures(CardDef card) {
  final costs = <String>[];
  for (final effect in card.effects) {
    switch (effect) {
      case LoseHpEffect(:final amount):
        costs.add('hp:$amount');
      case SpendBlockEffect(:final amount):
        costs.add('block:$amount');
      case ApplyStatusEffect(
            :final status,
            :final stacks,
            target: EffectTarget.self,
          )
          when status == StatusId.weak || status == StatusId.vulnerable:
        costs.add('status:${status.name}:$stacks');
      default:
        break;
    }
  }
  return costs;
}
