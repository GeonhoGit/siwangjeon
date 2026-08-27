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
import 'package:siwangjeon/data/m1_relics.dart';
import 'package:siwangjeon/domain/combat/combat_engine.dart';
import 'package:siwangjeon/domain/combat/tuning.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/game_event.dart';
import 'package:siwangjeon/ui/combat_screen.dart';
import 'package:siwangjeon/ui/labels.dart';

class TestDevice {
  const TestDevice({
    required this.name,
    required this.physicalSize,
    required this.devicePixelRatio,
  });

  final String name;
  final Size physicalSize;
  final double devicePixelRatio;
}

/// 이슈 #1을 재현한 Pixel 8의 실제 물리 해상도와 밀도.
///
/// 1080 / 2.625와 2400 / 2.625가 각각 논리 411×914에 해당한다.
const _pixel8 = TestDevice(
  name: 'Pixel 8',
  physicalSize: Size(1080, 2400),
  devicePixelRatio: 2.625,
);

/// Galaxy S25 Ultra (SM-S938N)의 실제 물리 해상도와 density 450.
///
/// 450 / 160 = 2.8125이므로 논리 크기는 384×832다. 이 기기는 Pixel 8보다
/// 27dp 좁고 82dp 짧아, 겹친 손패의 왼쪽 식별 띠를 검증하는 기준으로 쓴다.
const _galaxyS25Ultra = TestDevice(
  name: 'Galaxy S25 Ultra',
  physicalSize: Size(1080, 2340),
  devicePixelRatio: 2.8125,
);

const _boundaryDevices = [_pixel8, _galaxyS25Ultra];

Future<void> pumpCombat(
  WidgetTester tester, {
  double textScale = 1.0,
  int? seed,
  CombatController Function()? controller,
  TestDevice device = _pixel8,
}) async {
  tester.view.physicalSize = device.physicalSize;
  tester.view.devicePixelRatio = device.devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final overrides = [
    if (seed != null) combatSeedFactoryProvider.overrideWithValue(() => seed),
    if (controller != null) combatControllerProvider.overrideWith(controller),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const SiwangjeonApp(home: CombatScreen()),
    ),
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

class _RelicCombatController extends CombatController {
  @override
  CombatSession build() {
    final result = beginCombat(
      seed: 7,
      hp: startingHp,
      maxHp: startingHp,
      deck: starterDeck,
      enemies: defaultEncounter(),
      relics: m1Relics.take(14).toList(),
    );

    return CombatSession(
      seed: 7,
      state: result.state,
      lastEvents: result.events,
      actionLog: const [],
    );
  }
}

class _HealingEventCombatController extends CombatController {
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
      state: result.state,
      lastEvents: const [HpGained(2)],
      actionLog: const [],
    );
  }
}

Rect paintBounds(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(box.getTransformTo(null), box.paintBounds);
}

Rect textPrefixPaintBounds(WidgetTester tester, Finder finder, int endOffset) {
  expect(finder, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: endOffset),
  );
  expect(boxes, isNotEmpty);

  var prefixBounds = Rect.fromLTRB(
    boxes.first.left,
    boxes.first.top,
    boxes.first.right,
    boxes.first.bottom,
  );
  for (final box in boxes.skip(1)) {
    prefixBounds = prefixBounds.expandToInclude(
      Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
    );
  }
  return MatrixUtils.transformRect(
    paragraph.getTransformTo(null),
    prefixBounds,
  );
}

Rect layoutBounds(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

void expectHandIsOnScreenAndClearOfEndTurn(WidgetTester tester, int cardCount) {
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
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
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
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

double largestScreenBlankBand(WidgetTester tester) {
  final status = layoutBounds(tester, find.byKey(const ValueKey('status-bar')));
  final hand = layoutBounds(tester, find.byKey(const ValueKey('hand-area')));
  final occupied = [
    for (final enemy in ['enemy_agwi', 'enemy_wongwi', 'enemy_dokgwi'])
      paintBounds(tester, find.byKey(ValueKey('enemy-intent-label-$enemy'))),
    for (final enemy in ['enemy_agwi', 'enemy_wongwi', 'enemy_dokgwi'])
      paintBounds(tester, find.byKey(ValueKey('enemy-body-$enemy'))),
    for (final enemy in ['enemy_agwi', 'enemy_wongwi', 'enemy_dokgwi'])
      paintBounds(tester, find.byKey(ValueKey('enemy-health-$enemy'))),
    layoutBounds(tester, find.byKey(const ValueKey('enemy-threat-summary'))),
    layoutBounds(tester, find.byKey(const ValueKey('event-strip'))),
  ]..sort((left, right) => left.top.compareTo(right.top));

  var occupiedBottom = status.bottom;
  var largestBlank = 0.0;
  for (final region in occupied) {
    final top = math.max(region.top, status.bottom);
    final bottom = math.min(region.bottom, hand.top);
    if (bottom <= occupiedBottom) continue;
    largestBlank = math.max(largestBlank, top - occupiedBottom);
    occupiedBottom = math.max(occupiedBottom, bottom);
  }
  return math.max(largestBlank, hand.top - occupiedBottom);
}

void main() {
  testWidgets('체력 회복 이벤트를 전투 화면이 재생한다', (tester) async {
    await pumpCombat(tester, controller: _HealingEventCombatController.new);

    try {
      expect(find.text('체력 +2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await disposeTree(tester);
    }
  });

  testWidgets('전투에서도 14개 유물 목록을 경계 기기와 글꼴 배율에서 확인한다', (tester) async {
    for (final device in _boundaryDevices) {
      for (final textScale in [1.0, 1.3]) {
        await pumpCombat(
          tester,
          device: device,
          textScale: textScale,
          controller: _RelicCombatController.new,
        );

        try {
          final button = layoutBounds(
            tester,
            find.byKey(const ValueKey('combat-relic-inventory')),
          );
          expect(button.width, greaterThanOrEqualTo(48));
          expect(button.height, greaterThanOrEqualTo(48));

          await tester.tap(
            find.byKey(const ValueKey('combat-relic-inventory')),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(ValueKey('owned-relic-13-${m1Relics[13].id}')),
            240,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('relic-inventory-list')),
              matching: find.byType(Scrollable),
            ),
          );
          expect(tester.takeException(), isNull, reason: device.name);
        } finally {
          await disposeTree(tester);
        }
      }
    }
  });

  test('선택 카드는 손패 팬에서 마지막에 그린다', () {
    expect(
      handFanPaintOrder(
        cardCount: 5,
        selected: 1,
        previousSelected: null,
        selectionProgress: 1,
      ),
      [0, 2, 3, 4, 1],
    );
  });

  test('선택 전환 중에는 새 선택이 직전 선택보다 앞에 그려진다', () {
    expect(
      handFanPaintOrder(
        cardCount: 5,
        selected: 3,
        previousSelected: 1,
        selectionProgress: 0.5,
      ),
      [0, 2, 4, 1, 3],
    );
  });

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

  testWidgets('두 경계 기기에서 상태바와 손패 사이에 96dp를 넘는 빈 띠가 없다', (tester) async {
    for (final device in _boundaryDevices) {
      await pumpCombat(
        tester,
        textScale: device == _galaxyS25Ultra ? 0.9 : 1.0,
        device: device,
      );

      try {
        // 48dp 최소 터치 타겟 두 개보다 큰 빈 띠는 §8.1의 화면 밀도 판단을
        // 흐린다. 적·이벤트·손패의 실제 페인트 경계를 합쳐 화면 전체에서 잰다.
        expect(
          largestScreenBlankBand(tester),
          lessThanOrEqualTo(96),
          reason: '${device.name}의 정보 영역이 비어 있으면 안 된다',
        );
      } finally {
        await disposeTree(tester);
      }
    }
  });

  testWidgets('두 경계 기기의 적 임시 도형은 세로 1.4배를 넘지 않는다', (tester) async {
    for (final device in _boundaryDevices) {
      await pumpCombat(
        tester,
        textScale: device == _galaxyS25Ultra ? 0.9 : 1.0,
        device: device,
      );

      try {
        for (final enemy in ['enemy_agwi', 'enemy_wongwi', 'enemy_dokgwi']) {
          final body = paintBounds(
            tester,
            find.byKey(ValueKey('enemy-body-$enemy')),
          );
          // 레이아웃의 부동소수점 나눗셈 오차만 허용하고 비율 상한은 고정한다.
          expect(body.height / body.width, lessThanOrEqualTo(1.4 + 0.0001));
        }
      } finally {
        await disposeTree(tester);
      }
    }
  });

  testWidgets('두 경계 기기의 1.0×와 1.3×에서 2장과 5장 손패가 넘치지 않는다', (tester) async {
    for (final device in _boundaryDevices) {
      for (final textScale in [1.0, 1.3]) {
        for (final cardCount in [2, 5]) {
          await pumpCombat(
            tester,
            textScale: textScale,
            device: device,
            controller: () => _FixedHandCombatController(
              List.filled(cardCount, bladeOfGrudge),
            ),
          );

          expect(tester.takeException(), isNull);
          expectHandIsOnScreenAndClearOfEndTurn(tester, cardCount);
          expectHandIsInsideFlow(tester, cardCount);
          await disposeTree(tester);
        }
      }
    }
  });

  testWidgets('Galaxy S25 Ultra의 겹친 손패는 모든 카드의 비용과 구별용 이름 앞부분을 남긴다', (
    tester,
  ) async {
    for (var start = 0; start < m0Cards.length; start += 5) {
      final hand = m0Cards.skip(start).take(5).toList();
      await pumpCombat(
        tester,
        textScale: 0.9,
        device: _galaxyS25Ultra,
        controller: () => _FixedHandCombatController(hand),
      );

      try {
        for (var index = 0; index < hand.length - 1; index++) {
          final card = hand[index];
          final cost = paintBounds(
            tester,
            find.byKey(ValueKey('card-cost-${card.id}')),
          );
          final namePrefix = textPrefixPaintBounds(
            tester,
            find.byKey(ValueKey('card-name-${card.id}')),
            handCardLabel(card).length,
          );
          final coveringCard = paintBounds(
            tester,
            find.byKey(ValueKey('hand-card-${index + 1}')),
          );

          // 오른쪽 카드는 뒤에 칠해져 왼쪽 카드의 오른쪽을 덮는다. 식별자는
          // 다음 카드의 시작 전에서 끝나야 선택 전에도 읽힌다.
          expect(cost.right, lessThan(coveringCard.left));
          expect(namePrefix.right, lessThan(coveringCard.left));
        }
        expect(tester.takeException(), isNull);
      } finally {
        await disposeTree(tester);
      }
    }
  });

  testWidgets('긴 첫 어절의 이름도 원문 텍스트 하나로 그린다', (tester) async {
    const card = guardianSigil;
    await pumpCombat(
      tester,
      textScale: 0.9,
      device: _galaxyS25Ultra,
      controller: () => _FixedHandCombatController(const [card]),
    );

    try {
      final name = tester.widget<Text>(
        find.byKey(ValueKey('card-name-${card.id}')),
      );

      expect(name.data, card.name);
    } finally {
      await disposeTree(tester);
    }
  });

  testWidgets('카드 이름은 원문 공백을 보존한 텍스트 하나로 그린다', (tester) async {
    const cards = [
      greedyBarrier,
      recoveredEnergy,
      cleanCut,
      ironGuard,
      confession,
    ];

    for (final card in cards) {
      await pumpCombat(
        tester,
        textScale: 0.9,
        device: _galaxyS25Ultra,
        controller: () => _FixedHandCombatController([card]),
      );

      try {
        final name = find.byKey(ValueKey('card-name-${card.id}'));
        expect(name, findsOneWidget);
        final renderedName = tester.widget<Text>(name).data;

        // 이름을 한 텍스트로 그리면 조사·어미 앞에 새 공백을 넣을 여지가 없다.
        expect(card.name.contains(renderedName!), isTrue);
        expect(renderedName, card.name);
      } finally {
        await disposeTree(tester);
      }
    }
  });

  testWidgets('두 경계 기기에서 손패 상한까지 화면과 하단 상호작용 영역 안에 있다', (tester) async {
    final cardCount = CombatTuning.m0.maxHandSize;

    for (final device in _boundaryDevices) {
      for (final textScale in [1.0, 1.3]) {
        await pumpCombat(
          tester,
          textScale: textScale,
          device: device,
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

  testWidgets('두 경계 기기의 1.0×와 2.0×에서 긴 손패가 화면과 버튼을 침범하지 않는다', (tester) async {
    for (final device in _boundaryDevices) {
      for (final textScale in [2.0, 1.0]) {
        await pumpCombat(
          tester,
          textScale: textScale,
          device: device,
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
    }
  });

  testWidgets('두 경계 기기의 1.0×와 2.0×에서 2장 손패는 겹치지 않는다', (tester) async {
    for (final device in _boundaryDevices) {
      for (final textScale in [2.0, 1.0]) {
        await pumpCombat(
          tester,
          textScale: textScale,
          device: device,
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

  testWidgets('두 경계 기기의 1.0×와 1.3×에서 양끝 선택 손패도 화면 안에 남는다', (tester) async {
    for (final device in _boundaryDevices) {
      for (final textScale in [1.0, 1.3]) {
        for (final selectedIndex in [0, 4]) {
          await pumpCombat(
            tester,
            textScale: textScale,
            device: device,
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
    await pumpCombat(tester, seed: 7);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CombatScreen)),
    );
    final before = container.read(combatControllerProvider).state;

    // 고정 시드의 손패에서 대상이 필요한 공격 카드를 찾는다. 위치는 셔플에
    // 따라 달라질 수 있어도 테스트마다 달라지면 탭-탭 배선을 증명할 수 없다.
    final attackIndex = before.hand.indexWhere((c) => c.targeted);
    expect(attackIndex, isNot(-1), reason: '시작 덱에는 공격 카드가 있다');

    await tester.tap(find.byKey(ValueKey('hand-card-$attackIndex')));
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

    final card = find.byKey(ValueKey('hand-card-$index'));
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(card);
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

  testWidgets('두 경계 기기의 1.0×와 1.3×에서 적 3마리 조우도 손패 경계를 지킨다', (tester) async {
    for (final device in _boundaryDevices) {
      for (final textScale in [1.0, 1.3]) {
        await pumpCombat(
          tester,
          textScale: textScale,
          device: device,
          seed: 20260826,
        );

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
    }
  });
}
