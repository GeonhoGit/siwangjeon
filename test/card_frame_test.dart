import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/ui/card_frame.dart';

const _attackCard = CardDef(
  id: 'frame_attack',
  name: '원한의 칼날',
  type: CardType.attack,
  cost: 1,
  karma: 2,
  effects: [DamageEffect(value: 6)],
);

const _skillCard = CardDef(
  id: 'frame_skill',
  name: '철벽',
  type: CardType.skill,
  cost: 1,
  targeted: false,
  effects: [BlockEffect(5)],
);

const _powerCard = CardDef(
  id: 'frame_power',
  name: '불굴',
  type: CardType.power,
  rarity: CardRarity.siwang,
  cost: 2,
  targeted: false,
  effects: [BlockEffect(2)],
);

Future<String?> _noCardArt(AssetBundle assetBundle, String cardId) async =>
    null;

Future<String?> _virtualCardArt(AssetBundle assetBundle, String cardId) async =>
    'assets/card_art/$cardId.webp';

Widget _frameHarness({
  required double width,
  required CardDef card,
  CardArtResolver artResolver = _noCardArt,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: CardFrame(
            card: card,
            effectLabels: const ['피해 6', '업 +2', '원한 1'],
            additionalTypeLabels: const ['광역'],
            artResolver: artResolver,
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('카드 유형·시왕 희귀도 색은 카드 프레젠테이션에서 한 번만 정한다', () {
    expect(
      cardFramePresentation(_attackCard).typeColor,
      const Color(0xFFB2332B),
    );
    expect(
      cardFramePresentation(_skillCard).typeColor,
      const Color(0xFF2E6B8A),
    );
    expect(
      cardFramePresentation(_powerCard).typeColor,
      const Color(0xFF3F7A46),
    );
    expect(
      cardFramePresentation(_powerCard).frameColor,
      const Color(0xFFD6A84A),
      reason: '시왕은 유형 색을 지우지 않고 금색 테두리로만 강조한다.',
    );
  });

  testWidgets('96dp 손패 프레임은 비용·이름·효과 두 줄만 보인다', (tester) async {
    await tester.pumpWidget(_frameHarness(width: 96, card: _attackCard));

    expect(
      find.byKey(const ValueKey('card-frame-compact-frame_attack')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('card-cost-frame_attack')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('card-name-frame_attack')),
      findsOneWidget,
    );
    expect(find.text('피해 6 · 업 +2'), findsOneWidget);
    expect(find.text('원한 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('card-type-ribbon-frame_attack')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('card-art-frame_attack')), findsNothing);
    expect(find.byKey(const ValueKey('card-rules-frame_attack')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('144dp를 넘는 아트 없는 프레임은 유형과 규칙 전문만 보인다', (tester) async {
    await tester.pumpWidget(_frameHarness(width: 145, card: _attackCard));

    expect(
      find.byKey(const ValueKey('card-frame-full-frame_attack')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('card-cost-frame_attack')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('card-name-frame_attack')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('card-type-ribbon-frame_attack')),
      findsOneWidget,
    );
    expect(find.text('공격'), findsOneWidget);
    expect(find.text('광역'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-art-frame_attack')), findsNothing);
    expect(
      find.byKey(const ValueKey('card-rules-frame_attack')),
      findsOneWidget,
    );
    expect(find.text('피해 6'), findsOneWidget);
    expect(find.text('업 +2'), findsOneWidget);
    expect(find.text('원한 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('아트 asset이 있으면 2.15:1 슬롯을 넣어 전체 프레임을 키운다', (tester) async {
    await tester.pumpWidget(_frameHarness(width: 248, card: _attackCard));
    await tester.pump();
    final artlessHeight = tester
        .getSize(find.byKey(const ValueKey('card-frame-frame_attack')))
        .height;

    await tester.pumpWidget(
      _frameHarness(
        width: 248,
        card: _attackCard,
        artResolver: _virtualCardArt,
      ),
    );
    await tester.pump();

    final art = tester.widget<AspectRatio>(
      find.byKey(const ValueKey('card-art-frame_attack')),
    );
    final artHeight = tester
        .getSize(find.byKey(const ValueKey('card-frame-frame_attack')))
        .height;
    expect(art.aspectRatio, cardArtAspectRatio);
    expect(artHeight - artlessHeight, greaterThan(100));
    expect(tester.takeException(), isNull);
  });
}
