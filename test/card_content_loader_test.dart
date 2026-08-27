import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/card_content_loader.dart';
import 'package:siwangjeon/data/m0_content.dart';
import 'package:siwangjeon/domain/combat/tuning.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';

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
