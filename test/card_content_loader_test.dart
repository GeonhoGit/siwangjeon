import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/card_content_loader.dart';
import 'package:siwangjeon/data/m0_content.dart';
import 'package:siwangjeon/domain/combat/tuning.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M1 카드 JSON 로더', () {
    test('asset의 23장을 읽어 런의 보상·상점 풀까지 같은 카드로 조립한다', () async {
      final cards = await const CardContentLoader().load();
      final content = m1RunContentFromCards(cards);

      expect(cards, hasLength(23));
      expect(
        cards.map((card) => card.id).toSet(),
        m0Cards.map((card) => card.id).toSet(),
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

    test('효과 수치가 없거나 알 수 없는 튜닝 키는 거부한다', () {
      const loader = CardContentLoader();

      expect(
        () => loader.decode(
          '[{"id":"bad","name":"오류","type":"skill","cost":0,"effects":[{"op":"block"}]}]',
        ),
        throwsFormatException,
      );
      expect(
        () => loader.decode(
          '[{"id":"bad","name":"오류","type":"skill","cost":0,"effects":[{"op":"block","valueTuning":"unknown"}]}]',
        ),
        throwsFormatException,
      );
    });
  });
}
