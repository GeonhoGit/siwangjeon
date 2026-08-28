import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siwangjeon/app/app.dart';
import 'package:siwangjeon/app/run_controller.dart';
import 'package:siwangjeon/data/m1_events.dart';
import 'package:siwangjeon/data/m1_relics.dart';
import 'package:siwangjeon/domain/combat/relic_preview.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/combat_action.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/model/relic.dart';
import 'package:siwangjeon/domain/model/status.dart';
import 'package:siwangjeon/domain/run/run_action.dart';
import 'package:siwangjeon/domain/run/run_content.dart';
import 'package:siwangjeon/domain/run/run_engine.dart';
import 'package:siwangjeon/domain/run/run_event.dart';
import 'package:siwangjeon/domain/run/run_map.dart';
import 'package:siwangjeon/domain/run/run_node_type.dart';
import 'package:siwangjeon/domain/run/run_state.dart';
import 'package:siwangjeon/domain/run/run_tuning.dart';
import 'package:siwangjeon/ui/combat_screen.dart';
import 'package:siwangjeon/ui/relic_inventory.dart';
import 'package:siwangjeon/ui/run_screen.dart';

import 'support/m1_card_test_content.dart'
    show cleanCut, greatPurification, ironGuard, m1TestContent, steadyBreath;

class _TestDevice {
  const _TestDevice({
    required this.name,
    required this.physicalSize,
    required this.devicePixelRatio,
  });

  final String name;
  final Size physicalSize;
  final double devicePixelRatio;
}

const _pixel8 = _TestDevice(
  name: 'Pixel 8',
  physicalSize: Size(1080, 2400),
  devicePixelRatio: 2.625,
);

const _galaxyS25Ultra = _TestDevice(
  name: 'Galaxy S25 Ultra',
  physicalSize: Size(1080, 2340),
  devicePixelRatio: 2.8125,
);

const _boundaryDevices = [_pixel8, _galaxyS25Ultra];
const _mapSeeds = [0, 1, 7, 53, 20260826, 20260827, 987654321];

const _finisher = CardDef(
  id: 'ui_finisher',
  name: '판결의 일격',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 999)],
);

const _rewardA = CardDef(
  id: 'ui_reward_a',
  name: '원한의 칼날',
  type: CardType.attack,
  cost: 1,
  karma: 3,
  effects: [
    DamageEffect(value: 6),
    ApplyStatusEffect(status: StatusId.grudge, stacks: 1),
  ],
);

const _rewardB = CardDef(
  id: 'ui_reward_b',
  name: '고해',
  type: CardType.skill,
  cost: 1,
  targeted: false,
  effects: [BlockEffect(2), LoseHpEffect(5), ChangeKarmaEffect(-8)],
);

const _rewardC = CardDef(
  id: 'ui_reward_c',
  name: '집착의 맹세',
  type: CardType.power,
  cost: 2,
  targeted: false,
  effects: [
    BlockEffect(2),
    ApplyStatusEffect(
      status: StatusId.strength,
      stacks: 1,
      target: EffectTarget.self,
    ),
    ApplyStatusEffect(
      status: StatusId.dexterity,
      stacks: 1,
      target: EffectTarget.self,
    ),
  ],
);

const _rewardCards = [_rewardA, _rewardB, _rewardC];
final _nonCombatCardPool = [
  _rewardA,
  _rewardB,
  _rewardC,
  ironGuard,
  cleanCut,
  steadyBreath,
  greatPurification,
];

const _eventIronGuard = CardDef(
  id: 'card_iron_guard',
  name: '사건 철갑 수비',
  type: CardType.skill,
  cost: 1,
  targeted: false,
  effects: [BlockEffect(4)],
);

class _StaticRunController extends RunController {
  _StaticRunController(this._session);

  final RunSession _session;

  @override
  RunSession build() => _session;
}

Future<void> _pumpRun(
  WidgetTester tester, {
  required int seed,
  _TestDevice device = _pixel8,
  double textScale = 1.0,
  RunContent? content,
  RunState? initialState,
}) async {
  tester.view.physicalSize = device.physicalSize;
  tester.view.devicePixelRatio = device.devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runSeedFactoryProvider.overrideWithValue(() => seed),
        runContentProvider.overrideWithValue(content ?? m1TestContent),
        if (initialState != null)
          runInitialStateProvider.overrideWithValue(initialState),
      ],
      child: const SiwangjeonApp(),
    ),
  );
  await tester.pump();
}

Future<void> _pumpReward(
  WidgetTester tester, {
  required _TestDevice device,
  required double textScale,
}) async {
  tester.view.physicalSize = device.physicalSize;
  tester.view.devicePixelRatio = device.devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runControllerProvider.overrideWith(
          () => _StaticRunController(_rewardSession()),
        ),
      ],
      child: const SiwangjeonApp(),
    ),
  );
  await tester.pump();
}

Future<void> _pumpStaticRun(
  WidgetTester tester, {
  required RunSession session,
  required _TestDevice device,
  required double textScale,
}) async {
  tester.view.physicalSize = device.physicalSize;
  tester.view.devicePixelRatio = device.devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runControllerProvider.overrideWith(() => _StaticRunController(session)),
      ],
      child: const SiwangjeonApp(),
    ),
  );
  await tester.pump();
}

ProviderContainer _containerFor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(RunScreen)));

Rect _layoutBounds(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

Finder _darkRelicPanelsWithin(Finder ancestor) => find.descendant(
  of: ancestor,
  matching: find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox) return false;
    final decoration = widget.decoration;
    return decoration is BoxDecoration &&
        decoration.color == const Color(0xFF332B31);
  }),
);

Finder _scrollableFinder() =>
    find.byWidgetPredicate((widget) => widget is Scrollable);

Future<void> _disposeTree(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

RunSession _enhancedShopSession() {
  final map = generateActOneMap(702);
  final node = map.nodes.first;
  const enhancedId = 'enhanced-ui-card';
  final deckCard = RunDeckCard(
    instanceId: enhancedId,
    card: _rewardA,
    isEnhanced: true,
  );
  final progress = RunProgress(
    map: map,
    visitedNodeIds: [node.id],
    hp: 80,
    maxHp: 80,
    karma: 0,
    money: 100,
    deckCards: [
      deckCard,
      RunDeckCard(instanceId: 'plain-ui-card', card: _rewardB),
    ],
    pendingShop: ShopInventory(nodeId: node.id, cards: const [_rewardC]),
  );
  return RunSession(
    state: RunState(
      seed: 702,
      characterId: 'm0',
      actionLog: [MoveToNode(nodeId: node.id)],
    ),
    progress: progress,
    legalActions: [
      RemoveShopCard(nodeId: node.id, cardInstanceId: enhancedId),
      LeaveShop(nodeId: node.id),
    ],
  );
}

Future<void> _moveUntilCombat(WidgetTester tester) async {
  for (var depth = 0; depth < 15; depth++) {
    if (find.byType(CombatScreen).evaluate().isNotEmpty) return;
    final session = _containerFor(tester).read(runControllerProvider);
    final moves = session.legalActions.whereType<MoveToNode>();
    if (moves.isNotEmpty) {
      await tester.tap(find.byKey(ValueKey('run-node-${moves.first.nodeId}')));
    } else if (find
        .byKey(const ValueKey('shop-screen'))
        .evaluate()
        .isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('shop-leave')));
    } else if (find
        .byKey(const ValueKey('wild-camp-screen'))
        .evaluate()
        .isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('wild-camp-rest')));
    } else if (find
        .byKey(const ValueKey('event-screen'))
        .evaluate()
        .isNotEmpty) {
      final action = session.legalActions.whereType<ChooseEventOption>().first;
      await tester.tap(find.byKey(ValueKey('event-choice-${action.choiceId}')));
    } else {
      fail('지도와 비전투 선택 화면 밖에서 전투를 기다렸다');
    }
    await tester.pump();
  }
  fail('전투 노드에 도달하지 못했다');
}

void main() {
  testWidgets('15깊이 지도와 노드 종류 범례를 그린다', (tester) async {
    await _pumpRun(tester, seed: 20260827);

    try {
      final session = _containerFor(tester).read(runControllerProvider);
      final map = session.progress.map;

      expect({for (final node in map.nodes) node.depth}, hasLength(15));
      for (final node in map.nodes) {
        expect(find.byKey(ValueKey('run-node-${node.id}')), findsOneWidget);
      }
      for (final symbol in ['전', '정', '상', '야', '사', '왕']) {
        expect(find.text(symbol), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('지도 행은 가운데 정렬되고 직선 간선은 화면 좌표에서도 교차하지 않는다', (tester) async {
    tester.view.physicalSize = _pixel8.physicalSize;
    tester.view.devicePixelRatio = _pixel8.devicePixelRatio;
    addTearDown(tester.view.reset);

    try {
      for (final seed in _mapSeeds) {
        final map = generateActOneMap(seed);
        await tester.pumpWidget(
          MaterialApp(
            home: RunMapScreen(session: _mapSession(map), onMove: (_) {}),
          ),
        );
        await tester.pump();

        final centers = <int, Offset>{
          for (final node in map.nodes)
            node.id: _layoutBounds(
              tester,
              find.byKey(ValueKey('run-node-${node.id}')),
            ).center,
        };
        final mapViewport = _layoutBounds(
          tester,
          find.byKey(const ValueKey('run-map-scroll')),
        );
        _expectCenteredRows(map, centers, mapViewport.center.dx, seed);
        _expectNonCrossingEdgesInPixels(map, centers, seed);
        expect(tester.takeException(), isNull);
      }
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('legalRunActions가 준 노드만 이동에 반응한다', (tester) async {
    await _pumpRun(tester, seed: 20260828);

    try {
      final container = _containerFor(tester);
      final before = container.read(runControllerProvider);
      final legal = before.legalActions.whereType<MoveToNode>().single;
      final illegal = before.progress.map.nodes.firstWhere(
        (node) => node.id != legal.nodeId,
      );

      await tester.tap(find.byKey(ValueKey('run-node-${illegal.id}')));
      await tester.pump();
      expect(container.read(runControllerProvider).state.actionLog, isEmpty);

      await tester.tap(find.byKey(ValueKey('run-node-${legal.nodeId}')));
      await tester.pump();
      expect(
        container.read(runControllerProvider).state.actionLog,
        hasLength(1),
      );
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('현재 위치를 자동으로 스크롤 영역 안에 둔다', (tester) async {
    tester.view.physicalSize = _galaxyS25Ultra.physicalSize;
    tester.view.devicePixelRatio = _galaxyS25Ultra.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: RunMapScreen(session: _deepMapSession(), onMove: (_) {}),
      ),
    );
    await tester.pump();

    try {
      const currentNodeId = 10;
      final currentBounds = _layoutBounds(
        tester,
        find.byKey(ValueKey('run-node-$currentNodeId')),
      );
      final viewport = _layoutBounds(
        tester,
        find.byKey(const ValueKey('run-map-scroll')),
      );

      expect(currentBounds.top, greaterThanOrEqualTo(viewport.top));
      expect(currentBounds.bottom, lessThanOrEqualTo(viewport.bottom));
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('전투 승리 뒤 보상을 고르면 다음 전투 덱에 카드가 들어간다', (tester) async {
    await _pumpRun(tester, seed: 20260829, content: _victoryContent());

    try {
      await _moveUntilCombat(tester);
      expect(find.byType(CombatScreen), findsOneWidget);

      for (final enemyName in ['테스트 적 0', '테스트 적 1', '테스트 적 2']) {
        await tester.tap(find.byKey(const ValueKey('hand-card-0')));
        await tester.pump();
        await tester.tap(find.text(enemyName));
        await tester.pump();
      }

      final container = _containerFor(tester);
      final reward = container
          .read(runControllerProvider)
          .progress
          .pendingCardReward!;
      final chosen = reward.cards.first;
      expect(reward.cards, hasLength(3));
      expect(find.text('전투 승리'), findsOneWidget);
      expect(find.textContaining('노잣돈'), findsOneWidget);
      expect(find.text('피해 6'), findsOneWidget);
      expect(find.text('업 +3'), findsOneWidget);
      expect(find.text('원한 1'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('reward-card-${chosen.id}')));
      await tester.pump();
      expect(find.byType(RunMapScreen), findsOneWidget);
      expect(
        container
            .read(runControllerProvider)
            .progress
            .deck
            .map((card) => card.id),
        contains(chosen.id),
      );

      await _moveUntilCombat(tester);
      final combat = container.read(runControllerProvider).progress.combat!;
      final nextCombatCards = [
        ...combat.hand,
        ...combat.drawPile,
        ...combat.discardPile,
        ...combat.activePowers,
      ];
      expect(nextCombatCards.map((card) => card.id), contains(chosen.id));
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('정예 승리 뒤 유물 효과와 시점을 보고 고르면 지도로 돌아간다', (tester) async {
    final content = _eliteVictoryContent();
    final state = _wonEliteRunState(seed: 20260831, content: content);
    await _pumpRun(
      tester,
      seed: 20260831,
      content: content,
      initialState: state,
    );

    try {
      final container = _containerFor(tester);
      final reward = container
          .read(runControllerProvider)
          .progress
          .pendingRelicReward!;
      final chosen = reward.relics.first;
      final preview = previewRelic(chosen);

      expect(find.byKey(const ValueKey('relic-reward-screen')), findsOneWidget);
      expect(reward.relics, hasLength(3));
      expect(find.text('정예 승리 보상 · 업 +${reward.karmaGained}'), findsOneWidget);
      expect(find.byKey(ValueKey('reward-relic-${chosen.id}')), findsOneWidget);
      expect(find.text('발동: ${preview.triggerLabel}'), findsOneWidget);
      expect(find.text(preview.effectLabel), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('reward-relic-${chosen.id}')));
      await tester.pump();

      expect(find.byType(RunMapScreen), findsOneWidget);
      expect(
        container
            .read(runControllerProvider)
            .progress
            .relics
            .map((relic) => relic.id),
        contains(chosen.id),
      );

      await tester.tap(find.byKey(const ValueKey('map-relic-inventory')));
      await tester.pumpAndSettle();
      expect(find.text(chosen.name), findsOneWidget);
      expect(find.text('발동: ${preview.triggerLabel}'), findsOneWidget);
      expect(find.text(preview.effectLabel), findsOneWidget);
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('승리 화면은 보유 유물이 아닌 victoryRelics를 RelicSummary에 주입한다', (
    tester,
  ) async {
    final granted = m1Relics.first;
    final previouslyOwned = m1Relics[1];
    await _pumpStaticRun(
      tester,
      device: _galaxyS25Ultra,
      textScale: 1.3,
      session: _victorySession(
        relics: [previouslyOwned],
        victoryRelics: [granted],
      ),
    );

    try {
      expect(find.byKey(const ValueKey('victory-relics')), findsOneWidget);
      expect(
        find.byKey(ValueKey('victory-relic-${granted.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('victory-relic-${previouslyOwned.id}')),
        findsNothing,
      );
      expect(find.byType(RelicSummary), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await _disposeTree(tester);
    }

    await _pumpStaticRun(
      tester,
      device: _galaxyS25Ultra,
      textScale: 1.3,
      session: _victorySession(),
    );

    try {
      expect(find.byKey(const ValueKey('victory-relics')), findsNothing);
      expect(find.byType(RelicSummary), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('유물 보상은 버튼 표면을 쓰고 보유 목록만 어두운 패널을 그린다', (tester) async {
    final rewardSession = _relicRewardSession();
    await _pumpStaticRun(
      tester,
      session: rewardSession,
      device: _galaxyS25Ultra,
      textScale: 1.0,
    );

    try {
      for (final relic in rewardSession.progress.pendingRelicReward!.relics) {
        expect(
          _darkRelicPanelsWithin(
            find.byKey(ValueKey('reward-relic-${relic.id}')),
          ),
          findsNothing,
          reason: '유물 보상은 FilledButton의 표면과 전경색을 사용해야 한다.',
        );
      }
    } finally {
      await _disposeTree(tester);
    }

    await _pumpStaticRun(
      tester,
      session: _relicInventorySession(),
      device: _galaxyS25Ultra,
      textScale: 1.0,
    );

    try {
      await tester.tap(find.byKey(const ValueKey('map-relic-inventory')));
      await tester.pumpAndSettle();

      expect(
        _darkRelicPanelsWithin(
          find.byKey(const ValueKey('relic-inventory-list')),
        ),
        findsAtLeastNWidgets(1),
        reason: '보유 유물 목록은 어두운 패널 위에 내용을 표시해야 한다.',
      );
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('유물 보상과 14개 보유 목록은 경계 기기와 글꼴 배율에서 넘치지 않는다', (tester) async {
    for (final device in _boundaryDevices) {
      for (final textScale in [1.0, 1.3]) {
        final rewardSession = _relicRewardSession();
        await _pumpStaticRun(
          tester,
          session: rewardSession,
          device: device,
          textScale: textScale,
        );
        try {
          for (final relic
              in rewardSession.progress.pendingRelicReward!.relics) {
            _expectMinimumTapTargets(
              tester,
              find.byKey(ValueKey('reward-relic-${relic.id}')),
            );
          }
          expect(tester.takeException(), isNull, reason: device.name);
        } finally {
          await _disposeTree(tester);
        }

        await _pumpStaticRun(
          tester,
          session: _relicInventorySession(),
          device: device,
          textScale: textScale,
        );
        try {
          _expectMinimumTapTargets(
            tester,
            find.byKey(const ValueKey('map-relic-inventory')),
          );
          await tester.tap(find.byKey(const ValueKey('map-relic-inventory')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('relic-inventory-list')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull, reason: device.name);
        } finally {
          await _disposeTree(tester);
        }
      }
    }
  });

  testWidgets('보상 전체 카드 프레임은 경계 기기와 글꼴 배율에서 넘치지 않는다', (tester) async {
    for (final device in _boundaryDevices) {
      for (final textScale in [1.0, 1.3]) {
        await _pumpReward(tester, device: device, textScale: textScale);

        try {
          final viewport = _layoutBounds(tester, find.byType(ListView));
          final firstCard = _layoutBounds(
            tester,
            find.byKey(const ValueKey('reward-card-ui_reward_a')),
          );
          expect(
            firstCard.height,
            greaterThanOrEqualTo(48),
            reason: device.name,
          );
          expect(firstCard.top, greaterThanOrEqualTo(viewport.top));
          expect(firstCard.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(
            find.byKey(const ValueKey('card-frame-full-ui_reward_a')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('card-type-ribbon-ui_reward_a')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('card-art-ui_reward_a')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('card-rules-ui_reward_a')),
            findsOneWidget,
          );

          final firstRule = _layoutBounds(
            tester,
            find.byKey(const ValueKey('reward-card-effect-ui_reward_a-0')),
          );
          final secondRule = _layoutBounds(
            tester,
            find.byKey(const ValueKey('reward-card-effect-ui_reward_a-1')),
          );
          expect(secondRule.top, greaterThanOrEqualTo(firstRule.bottom));

          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('reward-card-ui_reward_c')),
            200,
          );
          expect(
            find.byKey(const ValueKey('card-rules-ui_reward_c')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await _disposeTree(tester);
        }
      }
    }
  });

  testWidgets('두 경계 기기와 글꼴 배율에서 48dp 노드와 3슬롯 행이 넘치지 않는다', (tester) async {
    for (final device in _boundaryDevices) {
      for (final textScale in [1.0, 1.3]) {
        await _pumpRun(
          tester,
          seed: 20260830,
          device: device,
          textScale: textScale,
        );

        try {
          final map = _containerFor(
            tester,
          ).read(runControllerProvider).progress.map;
          final mapViewport = _layoutBounds(
            tester,
            find.byKey(const ValueKey('run-map-scroll')),
          );
          final threeSlotNodes = _nodesAtThreeSlotDepth(map);
          expect(threeSlotNodes, hasLength(3), reason: device.name);
          for (final node in map.nodes) {
            final bounds = _layoutBounds(
              tester,
              find.byKey(ValueKey('run-node-${node.id}')),
            );
            expect(bounds.width, greaterThanOrEqualTo(48), reason: device.name);
            expect(
              bounds.height,
              greaterThanOrEqualTo(48),
              reason: device.name,
            );
          }
          for (final node in threeSlotNodes) {
            final bounds = _layoutBounds(
              tester,
              find.byKey(ValueKey('run-node-${node.id}')),
            );
            expect(bounds.left, greaterThanOrEqualTo(mapViewport.left));
            expect(bounds.right, lessThanOrEqualTo(mapViewport.right));
          }
          expect(tester.takeException(), isNull);
        } finally {
          await _disposeTree(tester);
        }
      }
    }
  });

  testWidgets('상점은 상품 효과를 보이고 거래와 나가기를 순서대로 기록한다', (tester) async {
    final seed = _seedForFirstNode(RunNodeType.shop);
    final content = _nonCombatContent(startingMoney: 100);
    await _pumpRun(
      tester,
      seed: seed,
      content: content,
      initialState: _enteredFirstNode(seed),
    );

    try {
      final container = _containerFor(tester);
      final before = container.read(runControllerProvider);
      final card = before.progress.pendingShop!.cards.first;

      expect(find.byKey(const ValueKey('shop-screen')), findsOneWidget);
      expect(
        find.byKey(ValueKey('shop-card-effect-${card.id}-0')),
        findsOneWidget,
      );
      expect(find.text('피해 6'), findsOneWidget);
      expect(find.text('업 +3'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('shop-card-${card.id}')));
      await tester.pump();

      expect(
        container.read(runControllerProvider).progress.money,
        100 - RunTuning.m1.shopCardPrice,
      );
      expect(find.byKey(const ValueKey('shop-screen')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('shop-leave')),
        300,
        scrollable: _scrollableFinder(),
      );
      await tester.tap(find.byKey(const ValueKey('shop-leave')));
      await tester.pump();
      expect(find.byType(RunMapScreen), findsOneWidget);
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('상점은 legalRunActions에 없는 구매와 제거에 반응하지 않는다', (tester) async {
    final seed = _seedForFirstNode(RunNodeType.shop);
    await _pumpRun(
      tester,
      seed: seed,
      content: _nonCombatContent(),
      initialState: _enteredFirstNode(seed),
    );

    try {
      final container = _containerFor(tester);
      final before = container.read(runControllerProvider);
      final shopCard = before.progress.pendingShop!.cards.first;
      final deckCard = before.progress.deckCards.first;

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(ValueKey('shop-card-${shopCard.id}')),
            )
            .onPressed,
        isNull,
      );
      await tester.drag(
        find.byKey(const ValueKey('shop-card-list')),
        const Offset(0, -700),
      );
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(ValueKey('shop-remove-${deckCard.instanceId}')),
            )
            .onPressed,
        isNull,
      );
      expect(container.read(runControllerProvider).state, same(before.state));
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('상점 제거는 같은 이름 카드 중 누른 인스턴스만 지운다', (tester) async {
    final seed = _seedForFirstNode(RunNodeType.shop);
    await _pumpRun(
      tester,
      seed: seed,
      content: _nonCombatContent(
        startingMoney: RunTuning.m1.shopRemoveCardPrice,
        deck: const [_rewardA, _rewardA],
      ),
      initialState: _enteredFirstNode(seed),
    );

    try {
      final container = _containerFor(tester);
      final before = container.read(runControllerProvider);
      final removed = before.progress.deckCards.first;
      final retained = before.progress.deckCards.last;

      await tester.drag(
        find.byKey(const ValueKey('shop-card-list')),
        const Offset(0, -700),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(ValueKey('shop-remove-${removed.instanceId}')),
      );
      await tester.pump();

      final after = container.read(runControllerProvider).progress;
      expect(after.deckCards, hasLength(1));
      expect(after.deckCards.single.instanceId, retained.instanceId);
      expect(
        (container.read(runControllerProvider).state.actionLog.last
                as RemoveShopCard)
            .cardInstanceId,
        removed.instanceId,
      );
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('야장의 휴식과 참회는 각각 화면 선택으로 끝난다', (tester) async {
    final route = _eventThenWildCampRoute();
    final wardenEvent = m1Events.singleWhere(
      (event) => event.id == 'event_wardens_favor',
    );
    await _pumpRun(
      tester,
      seed: route.seed,
      content: _nonCombatContent(events: [wardenEvent]),
    );

    try {
      final container = _containerFor(tester);
      final firstNodeId = container
          .read(runControllerProvider)
          .progress
          .map
          .nodes
          .first
          .id;
      await tester.tap(find.byKey(ValueKey('run-node-$firstNodeId')));
      await tester.pump();
      expect(find.byKey(const ValueKey('event-screen')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('event-choice-trial')));
      await tester.pump();
      expect(container.read(runControllerProvider).progress.hp, 68);

      await tester.tap(
        find.byKey(ValueKey('run-node-${route.wildCampNodeId}')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('wild-camp-screen')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('wild-camp-rest')));
      await tester.pump();
      expect(container.read(runControllerProvider).progress.hp, 80);
      expect(find.byType(RunMapScreen), findsOneWidget);
    } finally {
      await _disposeTree(tester);
    }

    final wildSeed = _seedForFirstNode(RunNodeType.wildCamp);
    await _pumpRun(
      tester,
      seed: wildSeed,
      content: _nonCombatContent(
        startingKarma: RunTuning.m1.wildCampRepentKarmaCleanse,
        startingMoney: RunTuning.m1.wildCampRepentMoneyCost,
      ),
      initialState: _enteredFirstNode(wildSeed),
    );

    try {
      final container = _containerFor(tester);
      await tester.tap(find.byKey(const ValueKey('wild-camp-repent')));
      await tester.pump();

      expect(container.read(runControllerProvider).progress.karma, 0);
      expect(container.read(runControllerProvider).progress.money, 0);
      expect(find.byType(RunMapScreen), findsOneWidget);
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('야장의 강화는 대상 카드만 + 이름과 효과로 바꾸고 상점 목록에도 남긴다', (tester) async {
    final seed = _seedForFirstNode(RunNodeType.wildCamp);
    final initialState = _enteredFirstNode(seed);
    await _pumpRun(
      tester,
      seed: seed,
      content: _nonCombatContent(),
      initialState: initialState,
    );

    try {
      final container = _containerFor(tester);
      expect(find.byKey(const ValueKey('wild-camp-enhance')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wild-camp-enhance')));
      await tester.pump();

      const enhancedId = 'start:0:ui_reward_a';
      expect(
        find.byKey(const ValueKey('wild-camp-enhance-screen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('wild-camp-enhance-$enhancedId')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('wild-camp-enhance-$enhancedId')),
      );
      await tester.pump();

      final enhanced = container
          .read(runControllerProvider)
          .progress
          .deckCards
          .singleWhere((card) => card.instanceId == enhancedId);
      expect(enhanced.isEnhanced, isTrue);
      expect(enhanced.card.name, '${_rewardA.name}+');
      expect(find.byType(RunMapScreen), findsOneWidget);
    } finally {
      await _disposeTree(tester);
    }

    await _pumpStaticRun(
      tester,
      session: _enhancedShopSession(),
      device: _pixel8,
      textScale: 1.3,
    );
    try {
      expect(find.textContaining('${_rewardA.name}+'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shop-remove-enhanced-ui-card')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('사건은 legalRunActions가 낸 선택지만 보이고 지옥의 장부 분기를 숨긴다', (tester) async {
    final seed = _seedForFirstNode(RunNodeType.event);
    final ledger = m1Events.singleWhere(
      (event) => event.id == 'event_hell_ledger',
    );

    await _pumpRun(
      tester,
      seed: seed,
      content: _nonCombatContent(startingMoney: 100, events: [ledger]),
      initialState: _enteredFirstNode(seed),
    );

    try {
      expect(find.byKey(const ValueKey('event-screen')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('event-choice-falsify')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('event-choice-seal')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-choice-confess')), findsNothing);
      expect(find.text('업 +3 · 노잣돈 +35'), findsOneWidget);
      expect(find.text('변화 없음'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('event-choice-seal')));
      await tester.pump();
      expect(find.byType(RunMapScreen), findsOneWidget);
    } finally {
      await _disposeTree(tester);
    }

    await _pumpRun(
      tester,
      seed: seed,
      content: _nonCombatContent(
        startingKarma: 50,
        startingMoney: 100,
        events: [ledger],
      ),
      initialState: _enteredFirstNode(seed),
    );

    try {
      expect(find.byKey(const ValueKey('event-choice-falsify')), findsNothing);
      expect(
        find.byKey(const ValueKey('event-choice-confess')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('event-choice-seal')), findsOneWidget);
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('사건의 카드 획득 선택지는 카드 이름과 효과를 함께 보인다', (tester) async {
    final seed = _seedForFirstNode(RunNodeType.event);
    final offering = m1Events.singleWhere(
      (event) => event.id == 'event_hungry_ghost_offering',
    );

    await _pumpRun(
      tester,
      seed: seed,
      content: _nonCombatContent(
        events: [offering],
        cardRewardPool: const [_rewardA, _rewardB, _rewardC, _eventIronGuard],
      ),
      initialState: _enteredFirstNode(seed),
    );

    try {
      expect(find.text('카드 획득 사건 철갑 수비'), findsOneWidget);
      expect(find.text('방어 4'), findsOneWidget);
    } finally {
      await _disposeTree(tester);
    }
  });

  testWidgets('세 갈래·카드 획득 사건과 긴 상점 덱은 경계 기기와 글자 배율에서 넘치지 않는다', (tester) async {
    final shopSeed = _seedForFirstNode(RunNodeType.shop);
    final wildSeed = _seedForFirstNode(RunNodeType.wildCamp);
    final eventSeed = _seedForFirstNode(RunNodeType.event);
    final cup = m1Events.singleWhere(
      (event) => event.id == 'event_cup_of_oblivion',
    );
    final offering = m1Events.singleWhere(
      (event) => event.id == 'event_hungry_ghost_offering',
    );

    for (final device in _boundaryDevices) {
      for (final textScale in [1.0, 1.3]) {
        await _pumpRun(
          tester,
          seed: shopSeed,
          device: device,
          textScale: textScale,
          content: _nonCombatContent(
            startingMoney: 100,
            deck: List<CardDef>.filled(16, _rewardA),
          ),
          initialState: _enteredFirstNode(shopSeed),
        );
        try {
          final shop = _containerFor(
            tester,
          ).read(runControllerProvider).progress.pendingShop!;
          final deckCard = _containerFor(
            tester,
          ).read(runControllerProvider).progress.deckCards.first;
          _expectMinimumTapTargets(
            tester,
            find.byKey(ValueKey('shop-card-${shop.cards.first.id}')),
          );
          await tester.drag(
            find.byKey(const ValueKey('shop-card-list')),
            const Offset(0, -700),
          );
          await tester.pump();
          _expectMinimumTapTargets(
            tester,
            find.byKey(ValueKey('shop-remove-${deckCard.instanceId}')),
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('shop-leave')),
            300,
            scrollable: _scrollableFinder(),
          );
          _expectMinimumTapTargets(
            tester,
            find.byKey(const ValueKey('shop-leave')),
          );
          expect(tester.takeException(), isNull, reason: device.name);
        } finally {
          await _disposeTree(tester);
        }

        await _pumpRun(
          tester,
          seed: wildSeed,
          device: device,
          textScale: textScale,
          content: _nonCombatContent(
            startingKarma: RunTuning.m1.wildCampRepentKarmaCleanse,
            startingMoney: RunTuning.m1.wildCampRepentMoneyCost,
          ),
          initialState: _enteredFirstNode(wildSeed),
        );
        try {
          _expectMinimumTapTargets(
            tester,
            find.byKey(const ValueKey('wild-camp-rest')),
          );
          _expectMinimumTapTargets(
            tester,
            find.byKey(const ValueKey('wild-camp-repent')),
          );
          _expectMinimumTapTargets(
            tester,
            find.byKey(const ValueKey('wild-camp-enhance')),
          );
          expect(tester.takeException(), isNull, reason: device.name);
        } finally {
          await _disposeTree(tester);
        }

        await _pumpRun(
          tester,
          seed: eventSeed,
          device: device,
          textScale: textScale,
          content: _nonCombatContent(startingKarma: 5, events: [cup]),
          initialState: _enteredFirstNode(eventSeed),
        );
        try {
          final visibleChoices = find.byWidgetPredicate(
            (widget) =>
                widget is FilledButton &&
                widget.key is ValueKey<String> &&
                (widget.key as ValueKey<String>).value.startsWith(
                  'event-choice-',
                ),
          );
          expect(visibleChoices, findsNWidgets(3));
          _expectMinimumTapTargets(tester, visibleChoices);
          expect(tester.takeException(), isNull, reason: device.name);
        } finally {
          await _disposeTree(tester);
        }

        await _pumpRun(
          tester,
          seed: eventSeed,
          device: device,
          textScale: textScale,
          content: _nonCombatContent(events: [offering]),
          initialState: _enteredFirstNode(eventSeed),
        );
        try {
          _expectMinimumTapTargets(
            tester,
            find.byKey(const ValueKey('event-choice-share')),
          );
          expect(tester.takeException(), isNull, reason: device.name);
        } finally {
          await _disposeTree(tester);
        }
      }
    }
  });
}

List<RunNode> _nodesAtThreeSlotDepth(RunMap map) {
  for (final node in map.nodes) {
    final nodes = map.nodes.where((candidate) => candidate.depth == node.depth);
    if (nodes.length == 3) return nodes.toList();
  }
  return const [];
}

RunSession _deepMapSession() {
  final map = RunMap(
    nodes: [
      for (var depth = 0; depth < 15; depth++)
        RunNode(
          id: depth,
          depth: depth,
          type: RunNodeType.event,
          nextNodeIds: depth == 14 ? const [] : [depth + 1],
        ),
    ],
  );
  return RunSession(
    state: const RunState(seed: 1, characterId: 'm0', actionLog: []),
    progress: RunProgress(
      map: map,
      visitedNodeIds: [for (var id = 0; id <= 10; id++) id],
      hp: 80,
      maxHp: 80,
      karma: 0,
      money: 0,
      deck: const [],
    ),
    legalActions: const [],
  );
}

RunSession _mapSession(RunMap map) {
  return RunSession(
    state: const RunState(seed: 1, characterId: 'm0', actionLog: []),
    progress: RunProgress(
      map: map,
      visitedNodeIds: const [],
      hp: 80,
      maxHp: 80,
      karma: 0,
      money: 0,
      deck: const [],
    ),
    legalActions: const [],
  );
}

RunSession _rewardSession() {
  const nodeId = 0;
  return RunSession(
    state: const RunState(seed: 1, characterId: 'm0', actionLog: []),
    progress: RunProgress(
      map: RunMap(
        nodes: [
          RunNode(
            id: nodeId,
            depth: 0,
            type: RunNodeType.combat,
            nextNodeIds: const [],
          ),
        ],
      ),
      visitedNodeIds: const [nodeId],
      hp: 80,
      maxHp: 80,
      karma: 0,
      money: 15,
      deck: const [],
      pendingCardReward: CardReward(nodeId: nodeId, cards: _rewardCards),
    ),
    legalActions: [
      for (final card in _rewardCards)
        ChooseCardReward(nodeId: nodeId, cardId: card.id),
    ],
  );
}

RunSession _relicRewardSession() {
  const nodeId = 0;
  final relics = m1Relics.take(3).toList();
  return RunSession(
    state: const RunState(seed: 1, characterId: 'm0', actionLog: []),
    progress: RunProgress(
      map: RunMap(
        nodes: [
          RunNode(
            id: nodeId,
            depth: 0,
            type: RunNodeType.elite,
            nextNodeIds: const [],
          ),
        ],
      ),
      visitedNodeIds: const [nodeId],
      hp: 80,
      maxHp: 80,
      karma: 3,
      money: 0,
      deck: const [],
      pendingRelicReward: RelicReward(
        nodeId: nodeId,
        relics: relics,
        karmaGained: 3,
      ),
    ),
    legalActions: [
      for (final relic in relics)
        ChooseRelicReward(nodeId: nodeId, relicId: relic.id),
    ],
  );
}

RunSession _relicInventorySession() => RunSession(
  state: const RunState(seed: 1, characterId: 'm0', actionLog: []),
  progress: RunProgress(
    map: RunMap(
      nodes: [
        RunNode(
          id: 0,
          depth: 0,
          type: RunNodeType.combat,
          nextNodeIds: const [],
        ),
      ],
    ),
    visitedNodeIds: const [0],
    hp: 80,
    maxHp: 80,
    karma: 0,
    money: 0,
    deck: const [],
    relics: m1Relics.take(14).toList(),
  ),
  legalActions: const [],
);

RunSession _victorySession({
  List<RelicDef> relics = const [],
  List<RelicDef> victoryRelics = const [],
}) => RunSession(
  state: const RunState(seed: 1, characterId: 'm0', actionLog: []),
  progress: RunProgress(
    map: RunMap(
      nodes: [
        RunNode(id: 0, depth: 0, type: RunNodeType.boss, nextNodeIds: const []),
      ],
    ),
    visitedNodeIds: const [],
    hp: 80,
    maxHp: 80,
    karma: 80,
    money: 0,
    deck: const [],
    relics: relics,
    victoryRelics: victoryRelics,
    outcome: RunOutcome.victory,
  ),
  legalActions: const [],
);

void _expectCenteredRows(
  RunMap map,
  Map<int, Offset> centers,
  double mapCenterX,
  int seed,
) {
  final nodesByDepth = <int, List<RunNode>>{};
  for (final node in map.nodes) {
    nodesByDepth.putIfAbsent(node.depth, () => []).add(node);
  }

  for (final entry in nodesByDepth.entries) {
    final nodes = [...entry.value]
      ..sort((left, right) => left.id.compareTo(right.id));
    final firstCenterX = centers[nodes.first.id]!.dx;
    final lastCenterX = centers[nodes.last.id]!.dx;
    expect(
      (firstCenterX + lastCenterX) / 2,
      closeTo(mapCenterX, 0.001),
      reason: 'seed $seed depth ${entry.key}',
    );
  }
}

void _expectNonCrossingEdgesInPixels(
  RunMap map,
  Map<int, Offset> centers,
  int seed,
) {
  final nodesByDepth = <int, List<RunNode>>{};
  for (final node in map.nodes) {
    nodesByDepth.putIfAbsent(node.depth, () => []).add(node);
  }

  final lastDepth = nodesByDepth.keys.reduce(
    (current, depth) => current > depth ? current : depth,
  );
  for (var depth = 0; depth < lastDepth; depth++) {
    final nodes = [...nodesByDepth[depth]!]
      ..sort((left, right) => left.id.compareTo(right.id));
    for (var leftSlot = 0; leftSlot < nodes.length; leftSlot++) {
      final left = nodes[leftSlot];
      for (
        var rightSlot = leftSlot + 1;
        rightSlot < nodes.length;
        rightSlot++
      ) {
        final right = nodes[rightSlot];
        expect(
          centers[left.id]!.dx,
          lessThan(centers[right.id]!.dx),
          reason: 'seed $seed depth $depth source slots',
        );
        for (final leftTargetId in left.nextNodeIds) {
          for (final rightTargetId in right.nextNodeIds) {
            expect(
              centers[leftTargetId]!.dx,
              lessThanOrEqualTo(centers[rightTargetId]!.dx),
              reason:
                  'seed $seed depth $depth '
                  '${left.id}->$leftTargetId vs '
                  '${right.id}->$rightTargetId',
            );
          }
        }
      }
    }
  }
}

RunContent _nonCombatContent({
  int startingMoney = 0,
  int startingKarma = 0,
  List<CardDef>? deck,
  List<RunEventDef>? events,
  List<CardDef>? cardRewardPool,
}) => RunContent(
  maxHp: 80,
  deck: deck ?? const [_rewardA, _rewardA],
  encounterPool: [
    Enemy(
      id: 'non_combat_enemy',
      name: '검증용 적',
      hp: 1,
      maxHp: 1,
      pattern: const [EnemyDefend(0)],
    ),
  ],
  startingMoney: startingMoney,
  startingKarma: startingKarma,
  cardRewardPool: cardRewardPool ?? _nonCombatCardPool,
  shopCardPool: cardRewardPool ?? _rewardCards,
  events: events ?? m1Events,
);

int _seedForFirstNode(RunNodeType type) {
  for (var seed = 0; seed < 10000; seed++) {
    if (generateActOneMap(seed).nodes.first.type == type) return seed;
  }
  throw StateError('첫 노드가 $type인 시드를 찾지 못했다');
}

RunState _enteredFirstNode(int seed) {
  final firstNode = generateActOneMap(seed).nodes.first;
  return RunState(
    seed: seed,
    characterId: 'm0',
    actionLog: [MoveToNode(nodeId: firstNode.id)],
  );
}

({int seed, int wildCampNodeId}) _eventThenWildCampRoute() {
  for (var seed = 0; seed < 10000; seed++) {
    final map = generateActOneMap(seed);
    final firstNode = map.nodes.first;
    if (firstNode.type != RunNodeType.event) continue;
    for (final nodeId in firstNode.nextNodeIds) {
      if (map.nodeById(nodeId).type == RunNodeType.wildCamp) {
        return (seed: seed, wildCampNodeId: nodeId);
      }
    }
  }
  throw StateError('사건 뒤 야장 경로를 찾지 못했다');
}

void _expectMinimumTapTargets(WidgetTester tester, Finder finder) {
  for (var index = 0; index < finder.evaluate().length; index++) {
    final bounds = _layoutBounds(tester, finder.at(index));
    expect(bounds.width, greaterThanOrEqualTo(48));
    expect(bounds.height, greaterThanOrEqualTo(48));
  }
}

RunContent _victoryContent() => RunContent(
  maxHp: 80,
  deck: List<CardDef>.filled(8, _finisher),
  encounterPool: [
    for (var index = 0; index < 3; index++)
      Enemy(
        id: 'ui_enemy_$index',
        name: '테스트 적 $index',
        hp: 1,
        maxHp: 1,
        pattern: const [EnemyDefend(0)],
      ),
  ],
  cardRewardPool: _rewardCards,
  events: m1Events,
);

RunContent _eliteVictoryContent() => RunContent(
  maxHp: 80,
  deck: List<CardDef>.filled(64, _finisher),
  encounterPool: [
    for (var index = 0; index < 3; index++)
      Enemy(
        id: 'elite_ui_enemy_$index',
        name: '정예 테스트 적 $index',
        hp: 1,
        maxHp: 1,
        pattern: const [EnemyDefend(0)],
      ),
  ],
  cardRewardPool: _rewardCards,
  relicRewardPool: m1Relics,
  events: m1Events,
);

RunState _wonEliteRunState({required int seed, required RunContent content}) {
  var state = startRun(seed: seed, characterId: 'm0');
  while (true) {
    final progress = replayRun(state, content: content);
    if (progress.currentNode?.type == RunNodeType.elite &&
        !progress.isInCombat) {
      return state;
    }

    final legal = legalRunActions(state, content: content);
    if (progress.pendingCardReward != null) {
      state = applyRunAction(
        state,
        legal.whereType<ChooseCardReward>().first,
        content: content,
      );
    } else if (progress.isInCombat) {
      state = applyRunAction(
        state,
        legal.whereType<CombatNodeLog>().firstWhere(
          (action) => action.actions.last is PlayCard,
        ),
        content: content,
      );
    } else {
      state = applyRunAction(
        state,
        legal.whereType<MoveToNode>().first,
        content: content,
      );
    }
  }
}
