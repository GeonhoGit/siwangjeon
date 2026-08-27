import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/card_content_loader.dart';
import 'package:siwangjeon/data/m0_content.dart';
import 'package:siwangjeon/domain/combat/card_enhancement.dart';
import 'package:siwangjeon/domain/combat/tuning.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';

import 'support/m1_card_test_content.dart';

void main() {
  group('M1 카드 JSON 로더', () {
    test('앱과 테스트가 같은 JSON 원문을 같은 decoder로 해석한다', () {
      final source = File(m1CardsAssetPath).readAsStringSync();
      final cards = const CardContentLoader().decode(source);
      final content = m1RunContentFromCards(cards);

      expect(cards, hasLength(23));
      expect(cards.map((card) => card.id), m1Cards.map((card) => card.id));
      expect(
        content.deck.first,
        same(cards.singleWhere((card) => card.id == 'card_strike')),
        reason: '런 조립은 별도 카드 상수가 아니라 로더 결과를 그대로 참조한다',
      );
      expect(
        content.cardRewardPool.map((card) => card.id),
        containsAll([fastingVow.id, thinVeil.id, shatteredWard.id]),
      );

      final fasting = cards.singleWhere((card) => card.id == fastingVow.id);
      expect(
        fasting.effects.whereType<ChangeKarmaEffect>().single.amount,
        -PurificationCardTuning.fastingCleanse,
      );
      final shattered = cards.singleWhere(
        (card) => card.id == shatteredWard.id,
      );
      expect(
        shattered.effects.whereType<SpendBlockEffect>().single.amount,
        PurificationCardTuning.shatteredWardBlockCost,
      );
    });

    test('정화 3종의 원본과 강화본은 각각 정화량 튜닝을 따른다', () {
      final source = File(m1CardsAssetPath).readAsStringSync();
      final rawCards = (jsonDecode(source) as List)
          .map((raw) => (raw as Map).cast<String, Object?>())
          .toList();
      final cards = const CardContentLoader().decode(source);

      const expectedTunings =
          <
            ({
              String id,
              String baseKey,
              int baseAmount,
              String enhancedKey,
              int enhancedAmount,
            })
          >[
            (
              id: 'card_fasting_vow',
              baseKey: 'fastingCleanse',
              baseAmount: PurificationCardTuning.fastingCleanse,
              enhancedKey: 'fastingEnhancedCleanse',
              enhancedAmount: PurificationCardTuning.fastingEnhancedCleanse,
            ),
            (
              id: 'card_thin_veil',
              baseKey: 'veilCleanse',
              baseAmount: PurificationCardTuning.veilCleanse,
              enhancedKey: 'veilEnhancedCleanse',
              enhancedAmount: PurificationCardTuning.veilEnhancedCleanse,
            ),
            (
              id: 'card_shattered_ward',
              baseKey: 'shatteredWardCleanse',
              baseAmount: PurificationCardTuning.shatteredWardCleanse,
              enhancedKey: 'shatteredWardEnhancedCleanse',
              enhancedAmount:
                  PurificationCardTuning.shatteredWardEnhancedCleanse,
            ),
          ];

      for (final expected in expectedTunings) {
        final rawCard = rawCards.singleWhere(
          (card) => card['id'] == expected.id,
        );
        final rawUpgrade = rawCard['upgrade'] as Map<String, Object?>;
        final baseCleanse = _rawCleanseEffect(rawCard['effects']);
        final enhancedCleanse = _rawCleanseEffect(rawUpgrade['effects']);
        final card = cards.singleWhere((card) => card.id == expected.id);

        expect(
          baseCleanse['amountTuning'],
          expected.baseKey,
          reason: expected.id,
        );
        expect(baseCleanse.containsKey('amount'), isFalse, reason: expected.id);
        expect(
          enhancedCleanse['amountTuning'],
          expected.enhancedKey,
          reason: expected.id,
        );
        expect(
          enhancedCleanse.containsKey('amount'),
          isFalse,
          reason: expected.id,
        );
        expect(_cleanseAmount(card), -expected.baseAmount, reason: expected.id);
        expect(
          _cleanseAmount(enhancedCard(card)),
          -expected.enhancedAmount,
          reason: expected.id,
        );
      }
    });

    test('모든 앱 카드가 upgrade를 명시한다', () {
      for (final card in m1Cards) {
        expect(card.upgrade, isNotNull, reason: card.id);
        expect(card.upgrade!.effects, isNotEmpty, reason: card.id);
      }
    });

    test('효과 수치와 upgrade의 누락·알 수 없는 튜닝 키를 거부한다', () {
      const loader = CardContentLoader();

      expect(
        () => loader.decode(
          '[{"id":"bad","name":"오류","type":"skill","cost":0,"effects":[{"op":"block"}],"upgrade":null}]',
        ),
        throwsFormatException,
      );
      expect(
        () => loader.decode(
          '[{"id":"bad","name":"오류","type":"skill","cost":0,"effects":[{"op":"block","valueTuning":"unknown"}],"upgrade":null}]',
        ),
        throwsFormatException,
      );
      expect(
        () => loader.decode(
          '[{"id":"bad","name":"오류","type":"skill","cost":0,"effects":[]}]',
        ),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _rawCleanseEffect(Object? rawEffects) =>
    (rawEffects as List)
        .map((raw) => (raw as Map).cast<String, Object?>())
        .singleWhere(
          (effect) =>
              effect['op'] == 'changeKarma' && effect['negative'] == true,
        );

int _cleanseAmount(CardDef card) => card.effects
    .whereType<ChangeKarmaEffect>()
    .singleWhere((effect) => effect.amount < 0)
    .amount;
