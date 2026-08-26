// 전투 화면 위젯 테스트 (기획서 §12-2 "임시 UI로 전투 1건 플레이 가능").
//
// 여기서 확인하는 것은 그림이 예쁜지가 아니라 **배선이 이어져 있는지**다.
// 탭이 액션이 되고, 액션이 엔진을 거쳐, 바뀐 상태가 다시 화면에 나오는가.
// 이 왕복이 끊겨 있으면 4주차에 §8.1의 질문들을 던져 볼 수조차 없다.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/app/app.dart';
import 'package:siwangjeon/app/combat_controller.dart';
import 'package:siwangjeon/data/m0_content.dart';
import 'package:siwangjeon/domain/combat/combat_engine.dart';
import 'package:siwangjeon/domain/combat/tuning.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/ui/combat_screen.dart';

/// 이슈 #1을 재현한 Pixel 8의 실제 물리 해상도와 밀도.
///
/// 1080 / 2.625와 2400 / 2.625가 각각 논리 411×914에 해당한다.
const _pixel8PhysicalSize = Size(1080, 2400);
const _pixel8DevicePixelRatio = 2.625;

Future<void> pumpCombat(
  WidgetTester tester, {
  double textScale = 1.0,
  int? seed,
  CombatController Function()? controller,
}) async {
  tester.view.physicalSize = _pixel8PhysicalSize;
  tester.view.devicePixelRatio = _pixel8DevicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final overrides = [
    if (seed != null) combatSeedFactoryProvider.overrideWithValue(() => seed),
    if (controller != null) combatControllerProvider.overrideWith(controller),
  ];

  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const SiwangjeonApp()),
  );
  await tester.pump();
}

/// 화면에는 1초짜리 반복 타이머(경과 시간)가 있다. 트리를 비워 dispose를
/// 태우지 않으면 테스트가 "타이머가 남아 있다"로 실패한다.
Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

/// TextScaler와 조상 페인트 변환을 함께 반영한 실제 글자 크기다.
/// FittedBox가 다시 들어와 축소하면 두 번째 항이 1보다 작아져 이 검사가 실패한다.
double paintedFontSize(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  return paragraph.textScaler.scale(text.style!.fontSize!) *
      paragraph.getTransformTo(null).getMaxScaleOnAxis();
}

class _FixedHandCombatController extends CombatController {
  _FixedHandCombatController(this._hand);

  final List<CardDef> _hand;

  @override
  CombatSession build() {
    final result = beginCombat(
      seed: 7,
      hp: startingHp,
      maxHp: startingHp,
      deck: starterDeck,
      enemies: defaultEncounter(),
    );

    return CombatSession(
      seed: 7,
      state: result.state.copyWith(hand: _hand),
      lastEvents: result.events,
      actionLog: const [],
    );
  }
}

class _SameCardDeckCombatController extends CombatController {
  @override
  CombatSession build() {
    final result = beginCombat(
      seed: 7,
      hp: startingHp,
      maxHp: startingHp,
      deck: List.filled(10, defend),
      enemies: defaultEncounter(),
    );

    return CombatSession(
      seed: 7,
      state: result.state,
      lastEvents: result.events,
      actionLog: const [],
    );
  }
}

Rect paintBounds(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(box.getTransformTo(null), box.paintBounds);
}

Rect layoutBounds(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

void expectHandIsOnScreenAndClearOfEndTurn(WidgetTester tester, int cardCount) {
  final screen = _pixel8PhysicalSize / _pixel8DevicePixelRatio;
  final endTurn = paintBounds(tester, find.byKey(const ValueKey('end-turn')));

  for (var index = 0; index < cardCount; index++) {
    final card = paintBounds(tester, find.byKey(ValueKey('hand-card-$index')));
    expect(card.left, greaterThanOrEqualTo(0));
    expect(card.right, lessThanOrEqualTo(screen.width));
    expect(card.top, greaterThanOrEqualTo(0));
    expect(card.bottom, lessThanOrEqualTo(screen.height));
    expect(card.overlaps(endTurn), isFalse);
  }
}

void expectHandIsInsideFlow(WidgetTester tester, int cardCount) {
  final flow = layoutBounds(tester, find.byType(Flow));

  for (var index = 0; index < cardCount; index++) {
    final card = paintBounds(tester, find.byKey(ValueKey('hand-card-$index')));
    expect(card.left, greaterThanOrEqualTo(flow.left));
    expect(card.top, greaterThanOrEqualTo(flow.top));
    expect(card.right, lessThanOrEqualTo(flow.right));
    expect(card.bottom, lessThanOrEqualTo(flow.bottom));
  }
}

void expectFanHasNoTopBlankBand(WidgetTester tester, int cardCount) {
  final flow = layoutBounds(tester, find.byKey(const ValueKey('hand-fan')));
  final topmostCard = [
    for (var index = 0; index < cardCount; index++)
      paintBounds(tester, find.byKey(ValueKey('hand-card-$index'))),
  ].map((card) => card.top).reduce(math.min);

  // 팬 높이는 회전·확대 후 카드가 실제로 차지하는 높이로 정한다. 행렬 변환의
  // 부동소수점 오차만 1dp 허용한다. 이전 구조의 빈 띠는 이 Flow 높이의 약 25%였다.
  expect(topmostCard - flow.top, lessThanOrEqualTo(1));
}

void expectHandIsInLowerSixtyPercent(WidgetTester tester, int cardCount) {
  final screen = _pixel8PhysicalSize / _pixel8DevicePixelRatio;
  final interactionBoundary = screen.height * 0.4;

  for (var index = 0; index < cardCount; index++) {
    final card = paintBounds(tester, find.byKey(ValueKey('hand-card-$index')));
    expect(card.top, greaterThanOrEqualTo(interactionBoundary));
  }
  expect(
    paintBounds(tester, find.byKey(const ValueKey('end-turn'))).top,
    greaterThanOrEqualTo(interactionBoundary),
  );
}

void main() {
  testWidgets('전투 화면이 손패와 적과 턴 종료 버튼을 그린다', (tester) async {
    await pumpCombat(tester);

    expect(find.byType(CombatScreen), findsOneWidget);
    expect(find.text('턴 종료'), findsOneWidget);

    // M0 기본 조우는 적 2종이다.
    expect(find.text('아귀'), findsOneWidget);
    expect(find.text('원귀'), findsOneWidget);

    // §3.1 — 손패 5장.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CombatScreen)),
    );
    expect(container.read(combatControllerProvider).state.hand.length, 5);

    await disposeTree(tester);
  });

  testWidgets('세로 화면에서 넘치지 않는다 (§8.1의 2번 질문)', (tester) async {
    await pumpCombat(tester);

    // 오버플로가 있으면 이 시점에 예외가 잡혀 있다.
    expect(tester.takeException(), isNull);

    await disposeTree(tester);
  });

  testWidgets('예고와 카드 효과 글자는 선택한 배율 그대로 그린다', (tester) async {
    for (final textScale in [1.3, 2.0]) {
      await pumpCombat(
        tester,
        textScale: textScale,
        controller: () => _FixedHandCombatController(const [confession]),
      );

      try {
        expect(
          paintedFontSize(
            tester,
            find.byKey(const ValueKey('enemy-intent-label-enemy_agwi')),
          ),
          closeTo(12 * textScale, 0.01),
        );
        expect(
          paintedFontSize(
            tester,
            find.byKey(const ValueKey('card-effect-line-0')),
          ),
          closeTo(10 * textScale, 0.01),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await disposeTree(tester);
      }
    }
  });

  testWidgets('손패 팬의 위쪽 빈 띠가 남지 않는다', (tester) async {
    await pumpCombat(
      tester,
      controller: () => _FixedHandCombatController(const [
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
      ]),
    );

    expectFanHasNoTopBlankBand(tester, 5);
    await disposeTree(tester);
  });

  testWidgets('서로 다른 높이의 손패도 실제 배치와 팬 높이가 일치한다', (tester) async {
    await pumpCombat(
      tester,
      textScale: 1.3,
      controller: () => _FixedHandCombatController(const [
        defend,
        bladeOfGrudge,
        defend,
        bladeOfGrudge,
        defend,
      ]),
    );

    try {
      final cardHeights = [
        for (var index = 0; index < 5; index++)
          tester
              .renderObject<RenderBox>(find.byKey(ValueKey('hand-card-$index')))
              .size
              .height,
      ];
      expect(cardHeights.toSet().length, greaterThan(1));

      final selected = paintBounds(
        tester,
        find.byKey(const ValueKey('hand-card-1')),
      );
      await tester.tapAt(selected.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      // 높이와 실제 Flow 변환은 같은 카드별 기하값을 소비해야 한다. 한쪽만
      // 바뀌면 높이가 다른 카드 중 가장 높은 카드에서 빈 띠 또는 클리핑이 생긴다.
      expectHandIsInsideFlow(tester, 5);
      expectFanHasNoTopBlankBand(tester, 5);
    } finally {
      await disposeTree(tester);
    }
  });

  testWidgets('손패와 턴 종료는 화면 하단 60%에 있다 (§5.1)', (tester) async {
    await pumpCombat(
      tester,
      controller: () => _FixedHandCombatController(const [
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
      ]),
    );

    expectHandIsInLowerSixtyPercent(tester, 5);
    await disposeTree(tester);
  });

  testWidgets('Pixel 8의 1.0×와 1.3×에서 2장과 5장 손패가 넘치지 않는다', (tester) async {
    for (final textScale in [1.0, 1.3]) {
      for (final cardCount in [2, 5]) {
        await pumpCombat(
          tester,
          textScale: textScale,
          controller: () =>
              _FixedHandCombatController(List.filled(cardCount, bladeOfGrudge)),
        );

        expect(tester.takeException(), isNull);
        expectHandIsOnScreenAndClearOfEndTurn(tester, cardCount);
        expectHandIsInsideFlow(tester, cardCount);
        await disposeTree(tester);
      }
    }
  });

  testWidgets('손패 상한까지도 화면과 하단 상호작용 영역 안에 있다', (tester) async {
    final cardCount = CombatTuning.m0.maxHandSize;

    for (final textScale in [1.0, 1.3]) {
      await pumpCombat(
        tester,
        textScale: textScale,
        controller: () =>
            _FixedHandCombatController(List.filled(cardCount, bladeOfGrudge)),
      );

      try {
        expect(tester.takeException(), isNull);
        expectHandIsOnScreenAndClearOfEndTurn(tester, cardCount);
        expectHandIsInsideFlow(tester, cardCount);
        expectHandIsInLowerSixtyPercent(tester, cardCount);
      } finally {
        await disposeTree(tester);
      }
    }
  });

  testWidgets('주입한 시드가 초기 손패를 결정론적으로 고정한다', (tester) async {
    const seed = 20260826;

    await pumpCombat(tester, seed: seed);
    final firstContainer = ProviderScope.containerOf(
      tester.element(find.byType(CombatScreen)),
    );
    final firstSession = firstContainer.read(combatControllerProvider);
    final firstHand = firstSession.state.hand.map((card) => card.id).toList();

    expect(firstSession.seed, seed);
    await disposeTree(tester);

    await pumpCombat(tester, seed: seed);
    final secondContainer = ProviderScope.containerOf(
      tester.element(find.byType(CombatScreen)),
    );
    final secondSession = secondContainer.read(combatControllerProvider);

    expect(secondSession.seed, seed);
    expect(secondSession.state.hand.map((card) => card.id), firstHand);
    await disposeTree(tester);
  });

  testWidgets('Pixel 8의 1.0×와 2.0×에서 긴 손패가 화면과 버튼을 침범하지 않는다', (tester) async {
    for (final textScale in [2.0, 1.0]) {
      await pumpCombat(
        tester,
        textScale: textScale,
        controller: () => _FixedHandCombatController(const [
          bladeOfGrudge,
          bladeOfGrudge,
          bladeOfGrudge,
          bladeOfGrudge,
          bladeOfGrudge,
        ]),
      );

      expect(tester.takeException(), isNull);
      expectHandIsOnScreenAndClearOfEndTurn(tester, 5);

      await disposeTree(tester);
    }
  });

  testWidgets('Pixel 8의 1.0×와 2.0×에서 2장 손패는 겹치지 않는다', (tester) async {
    for (final textScale in [2.0, 1.0]) {
      await pumpCombat(
        tester,
        textScale: textScale,
        controller: () =>
            _FixedHandCombatController(const [bladeOfGrudge, bladeOfGrudge]),
      );

      expect(tester.takeException(), isNull);
      expectHandIsOnScreenAndClearOfEndTurn(tester, 2);

      final firstCard = paintBounds(
        tester,
        find.byKey(const ValueKey('hand-card-0')),
      );
      final secondCard = paintBounds(
        tester,
        find.byKey(const ValueKey('hand-card-1')),
      );
      expect(firstCard.overlaps(secondCard), isFalse);

      await disposeTree(tester);
    }
  });

  testWidgets('선택한 가운데 손패 카드는 1.12배로 확대된다 (§5.3)', (tester) async {
    await pumpCombat(
      tester,
      controller: () => _FixedHandCombatController(const [
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
      ]),
    );

    try {
      final card = find.byKey(const ValueKey('hand-card-2'));
      final before = paintBounds(tester, card);
      await tester.tapAt(before.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final middle = paintBounds(tester, card);
      expect(middle.width, greaterThan(before.width));
      expect(middle.width, lessThan(before.width * 1.12));

      await tester.pump(const Duration(milliseconds: 60));

      final after = paintBounds(tester, card);
      expect(after.width, closeTo(before.width * 1.12, 0.01));
      expect(after.height, closeTo(before.height * 1.12, 0.01));
    } finally {
      await disposeTree(tester);
    }
  });

  testWidgets('선택한 손패를 취소하면 120ms 동안 축소된다', (tester) async {
    await pumpCombat(
      tester,
      controller: () => _FixedHandCombatController(const [
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
      ]),
    );

    try {
      final card = find.byKey(const ValueKey('hand-card-2'));
      final unselected = paintBounds(tester, card);
      await tester.tapAt(unselected.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final selected = paintBounds(tester, card);
      await tester.tapAt(selected.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final middle = paintBounds(tester, card);
      expect(middle.width, greaterThan(unselected.width));
      expect(middle.width, lessThan(selected.width));
      expect(tester.takeException(), isNull);
      expectHandIsOnScreenAndClearOfEndTurn(tester, 5);
      expectHandIsInsideFlow(tester, 5);

      await tester.pump(const Duration(milliseconds: 60));

      final after = paintBounds(tester, card);
      expect(after.width, closeTo(unselected.width, 0.01));
      expect(after.height, closeTo(unselected.height, 0.01));
      expect(tester.takeException(), isNull);
      expectHandIsOnScreenAndClearOfEndTurn(tester, 5);
      expectHandIsInsideFlow(tester, 5);
    } finally {
      await disposeTree(tester);
    }
  });

  testWidgets('다른 손패를 선택하면 이전 카드가 축소되고 새 카드가 확대된다', (tester) async {
    await pumpCombat(
      tester,
      controller: () => _FixedHandCombatController(const [
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
      ]),
    );

    try {
      final first = find.byKey(const ValueKey('hand-card-2'));
      final second = find.byKey(const ValueKey('hand-card-4'));
      await tester.tapAt(paintBounds(tester, first).center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final firstSelected = paintBounds(tester, first);
      await tester.tapAt(paintBounds(tester, second).center);
      await tester.pump();

      final secondUnselected = paintBounds(tester, second);
      await tester.pump(const Duration(milliseconds: 60));

      final firstMiddle = paintBounds(tester, first);
      final secondMiddle = paintBounds(tester, second);
      expect(firstMiddle.width, greaterThan(firstSelected.width / 1.12));
      expect(firstMiddle.width, lessThan(firstSelected.width));
      expect(secondMiddle.width, greaterThan(secondUnselected.width));
      expect(secondMiddle.width, lessThan(secondUnselected.width * 1.12));
      expect(tester.takeException(), isNull);
      expectHandIsOnScreenAndClearOfEndTurn(tester, 5);
      expectHandIsInsideFlow(tester, 5);

      await tester.pump(const Duration(milliseconds: 60));

      final firstAfter = paintBounds(tester, first);
      final secondAfter = paintBounds(tester, second);
      expect(firstAfter.width, closeTo(firstSelected.width / 1.12, 0.01));
      expect(secondAfter.width, closeTo(secondUnselected.width * 1.12, 0.01));
      expect(tester.takeException(), isNull);
      expectHandIsOnScreenAndClearOfEndTurn(tester, 5);
      expectHandIsInsideFlow(tester, 5);
    } finally {
      await disposeTree(tester);
    }
  });

  testWidgets('카드 사용으로 손패가 줄면 남은 카드가 축소 애니메이션하지 않는다', (tester) async {
    await pumpCombat(
      tester,
      controller: () => _FixedHandCombatController(const [
        defend,
        defend,
        defend,
        defend,
        defend,
      ]),
    );

    try {
      final selected = find.byKey(const ValueKey('hand-card-2'));
      await tester.tapAt(paintBounds(tester, selected).center);
      await tester.pump(const Duration(milliseconds: 120));

      await tester.tapAt(paintBounds(tester, selected).center);
      await tester.pump();
      expect(find.byKey(const ValueKey('hand-card-4')), findsNothing);
      await tester.pump(const Duration(milliseconds: 60));

      final middleWidths = [
        for (var index = 0; index < 4; index++)
          paintBounds(tester, find.byKey(ValueKey('hand-card-$index'))).width,
      ];

      await tester.pump(const Duration(milliseconds: 60));

      for (var index = 0; index < 4; index++) {
        final unselected = paintBounds(
          tester,
          find.byKey(ValueKey('hand-card-$index')),
        );
        expect(middleWidths[index], closeTo(unselected.width, 0.01));
      }
      expect(tester.takeException(), isNull);
    } finally {
      await disposeTree(tester);
    }
  });

  testWidgets('1.3×에서 카드 사용 직후 손패 팬 높이가 정착값으로 유지된다', (tester) async {
    await pumpCombat(
      tester,
      textScale: 1.3,
      controller: () => _FixedHandCombatController(const [
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
        bladeOfGrudge,
      ]),
    );

    try {
      final selected = find.byKey(const ValueKey('hand-card-2'));
      await tester.tapAt(paintBounds(tester, selected).center);
      await tester.pump(const Duration(milliseconds: 120));

      await tester.tap(find.text('아귀'));
      await tester.pump();
      expect(find.byKey(const ValueKey('hand-card-4')), findsNothing);
      final immediateHeight = layoutBounds(
        tester,
        find.byKey(const ValueKey('hand-fan')),
      ).height;

      await tester.pump();
      final settledHeight = layoutBounds(
        tester,
        find.byKey(const ValueKey('hand-fan')),
      ).height;

      // 프레임 경계의 부동소수점 오차만 1dp 허용한다. 현재 회귀는 132dp
      // 대체값으로 돌아가 39.7dp 차이를 낸다.
      expect((immediateHeight - settledHeight).abs(), lessThanOrEqualTo(1));
    } finally {
      await disposeTree(tester);
    }
  });

  testWidgets('같은 내용의 새 손패로 턴 종료하면 이전 선택을 축소하지 않는다', (tester) async {
    await pumpCombat(tester, controller: _SameCardDeckCombatController.new);

    try {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CombatScreen)),
      );
      final beforeHand = container.read(combatControllerProvider).state.hand;
      final unselectedWidths = [
        for (var index = 0; index < 5; index++)
          paintBounds(tester, find.byKey(ValueKey('hand-card-$index'))).width,
      ];
      final selected = find.byKey(const ValueKey('hand-card-2'));
      await tester.tapAt(paintBounds(tester, selected).center);
      await tester.pump(const Duration(milliseconds: 120));

      await tester.tap(find.text('턴 종료'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final afterSession = container.read(combatControllerProvider);
      expect(afterSession.actionLog.length, 1);
      expect(identical(afterSession.state.hand, beforeHand), isFalse);
      for (var index = 0; index < 5; index++) {
        expect(
          identical(afterSession.state.hand[index], beforeHand[index]),
          isTrue,
        );
        final middle = paintBounds(
          tester,
          find.byKey(ValueKey('hand-card-$index')),
        );
        expect(middle.width, closeTo(unselectedWidths[index], 0.01));
      }
      expect(tester.takeException(), isNull);
    } finally {
      await disposeTree(tester);
    }
  });

  testWidgets('Pixel 8의 1.0×와 1.3×에서 양끝 선택 손패도 화면 안에 남는다', (tester) async {
    for (final textScale in [1.0, 1.3]) {
      for (final selectedIndex in [0, 4]) {
        await pumpCombat(
          tester,
          textScale: textScale,
          controller: () => _FixedHandCombatController(const [
            bladeOfGrudge,
            bladeOfGrudge,
            bladeOfGrudge,
            bladeOfGrudge,
            bladeOfGrudge,
          ]),
        );

        try {
          final selected = paintBounds(
            tester,
            find.byKey(ValueKey('hand-card-$selectedIndex')),
          );
          await tester.tapAt(selected.center);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));

          expect(tester.takeException(), isNull);
          expectHandIsOnScreenAndClearOfEndTurn(tester, 5);
          expectHandIsInsideFlow(tester, 5);

          await tester.pump(const Duration(milliseconds: 60));

          expect(tester.takeException(), isNull);
          expectHandIsOnScreenAndClearOfEndTurn(tester, 5);
          expectHandIsInsideFlow(tester, 5);
        } finally {
          await disposeTree(tester);
        }
      }
    }
  });

  testWidgets('선택해도 다른 손패 카드의 중심은 움직이지 않는다', (tester) async {
    for (final cardCount in [2, 5]) {
      final selectedIndex = cardCount ~/ 2;
      await pumpCombat(
        tester,
        controller: () =>
            _FixedHandCombatController(List.filled(cardCount, bladeOfGrudge)),
      );

      try {
        final beforeCenters = [
          for (var index = 0; index < cardCount; index++)
            paintBounds(
              tester,
              find.byKey(ValueKey('hand-card-$index')),
            ).center.dx,
        ];
        final selected = find.byKey(ValueKey('hand-card-$selectedIndex'));
        await tester.tapAt(paintBounds(tester, selected).center);
        await tester.pump();

        for (final elapsed in const [
          Duration(milliseconds: 60),
          Duration(milliseconds: 60),
        ]) {
          await tester.pump(elapsed);

          for (var index = 0; index < cardCount; index++) {
            if (index == selectedIndex) continue;
            final center = paintBounds(
              tester,
              find.byKey(ValueKey('hand-card-$index')),
            ).center.dx;
            expect(center, closeTo(beforeCenters[index], 0.01));
          }
        }
      } finally {
        await disposeTree(tester);
      }
    }
  });

  testWidgets('카드를 탭해 고르고, 적을 탭해 사용한다 (§5.3 탭-탭)', (tester) async {
    await pumpCombat(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CombatScreen)),
    );
    final before = container.read(combatControllerProvider).state;

    // 손패에서 대상이 필요한 공격 카드를 찾는다. 덱이 섞이므로 위치는 매번 다르다.
    final attackIndex = before.hand.indexWhere((c) => c.targeted);
    expect(attackIndex, isNot(-1), reason: '시작 덱에는 공격 카드가 있다');

    final cardName = before.hand[attackIndex].name;
    await tester.tap(find.text(cardName).first);
    await tester.pump(const Duration(milliseconds: 200));

    // 고른 상태에서는 각 적 위에 "그 적이 받을 피해"가 뜬다.
    expect(find.textContaining('−'), findsWidgets);

    await tester.tap(find.text('아귀'));
    await tester.pump();

    final after = container.read(combatControllerProvider).state;
    expect(after.enemies[0].hp, lessThan(before.enemies[0].hp));
    expect(after.energy, before.energy - 1);
    expect(after.hand.length, 4);

    // 액션 로그가 실제로 쌓이는지 본다 — §7.4의 저장 파일이 될 목록이다.
    expect(container.read(combatControllerProvider).actionLog.length, 1);

    await disposeTree(tester);
  });

  testWidgets('대상 없는 카드는 두 번 탭으로 사용된다', (tester) async {
    await pumpCombat(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CombatScreen)),
    );
    final before = container.read(combatControllerProvider).state;

    final index = before.hand.indexWhere((c) => !c.targeted);
    if (index == -1) {
      // 시작 손패에 「수비」가 한 장도 없을 수 있다. 그 경우는 이 테스트의
      // 대상이 아니므로 조용히 지나간다.
      await disposeTree(tester);
      return;
    }

    final name = before.hand[index].name;
    await tester.tap(find.text(name).first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text(name).first);
    await tester.pump();

    expect(
      container.read(combatControllerProvider).state.block,
      greaterThan(0),
    );

    await disposeTree(tester);
  });

  testWidgets('턴 종료를 누르면 턴이 넘어가고 적이 행동한다', (tester) async {
    await pumpCombat(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CombatScreen)),
    );
    final before = container.read(combatControllerProvider).state;

    await tester.tap(find.text('턴 종료'));
    await tester.pump();

    final after = container.read(combatControllerProvider).state;
    expect(after.turn, before.turn + 1);
    expect(after.energy, 3, reason: '§3.1 — 기력 3 회복');
    expect(after.hp, lessThan(before.hp), reason: '아귀의 첫 예고는 공격이다');

    await disposeTree(tester);
  });

  testWidgets('정화·체력 대가·드로우·기력·업을 카드에서 함께 읽을 수 있다', (tester) async {
    await pumpCombat(
      tester,
      textScale: 1.3,
      controller: () => _FixedHandCombatController(const [
        confession,
        greatPurification,
        steadyBreath,
        recoveredEnergy,
        hellfireMomentum,
        clingingOath,
      ]),
    );

    try {
      expect(find.textContaining('업 -8'), findsOneWidget);
      expect(find.textContaining('체력 -5'), findsOneWidget);
      expect(find.textContaining('드로우 1'), findsOneWidget);
      expect(find.textContaining('기력 +1'), findsOneWidget);
      expect(find.textContaining('업 +3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectHandIsOnScreenAndClearOfEndTurn(tester, 6);
      expectHandIsInsideFlow(tester, 6);
      expectHandIsInLowerSixtyPercent(tester, 6);
    } finally {
      await disposeTree(tester);
    }
  });

  testWidgets('적 3마리 조우도 1.0×와 1.3×에서 손패 경계를 지킨다', (tester) async {
    for (final textScale in [1.0, 1.3]) {
      await pumpCombat(tester, textScale: textScale, seed: 20260826);

      try {
        expect(find.text('아귀'), findsOneWidget);
        expect(find.text('원귀'), findsOneWidget);
        expect(find.text('독귀'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectHandIsOnScreenAndClearOfEndTurn(tester, 5);
        expectHandIsInsideFlow(tester, 5);
        expectHandIsInLowerSixtyPercent(tester, 5);
        expectFanHasNoTopBlankBand(tester, 5);
      } finally {
        await disposeTree(tester);
      }
    }
  });
}
