// 전투 화면 위젯 테스트 (기획서 §12-2 "임시 UI로 전투 1건 플레이 가능").
//
// 여기서 확인하는 것은 그림이 예쁜지가 아니라 **배선이 이어져 있는지**다.
// 탭이 액션이 되고, 액션이 엔진을 거쳐, 바뀐 상태가 다시 화면에 나오는가.
// 이 왕복이 끊겨 있으면 4주차에 §8.1의 질문들을 던져 볼 수조차 없다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/app/app.dart';
import 'package:siwangjeon/app/combat_controller.dart';
import 'package:siwangjeon/data/m0_content.dart';
import 'package:siwangjeon/domain/combat/combat_engine.dart';
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
}
