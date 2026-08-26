import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siwangjeon/app/app.dart';
import 'package:siwangjeon/app/run_controller.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/run/run_action.dart';
import 'package:siwangjeon/domain/run/run_content.dart';
import 'package:siwangjeon/domain/run/run_engine.dart';
import 'package:siwangjeon/domain/run/run_map.dart';
import 'package:siwangjeon/domain/run/run_node_type.dart';
import 'package:siwangjeon/domain/run/run_state.dart';
import 'package:siwangjeon/ui/combat_screen.dart';
import 'package:siwangjeon/ui/run_screen.dart';

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

const _finisher = CardDef(
  id: 'ui_finisher',
  name: '판결의 일격',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 999)],
);

const _rewardA = CardDef(
  id: 'ui_reward_a',
  name: '보상 A',
  type: CardType.attack,
  cost: 0,
  effects: [DamageEffect(value: 1)],
);

const _rewardB = CardDef(
  id: 'ui_reward_b',
  name: '보상 B',
  type: CardType.skill,
  cost: 0,
  effects: [BlockEffect(1)],
);

const _rewardC = CardDef(
  id: 'ui_reward_c',
  name: '보상 C',
  type: CardType.curse,
  cost: 0,
  effects: [DamageEffect(value: 1)],
);

Future<void> _pumpRun(
  WidgetTester tester, {
  required int seed,
  _TestDevice device = _pixel8,
  double textScale = 1.0,
  RunContent? content,
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
        if (content != null) runContentProvider.overrideWithValue(content),
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

Future<void> _disposeTree(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

Future<void> _moveUntilCombat(WidgetTester tester) async {
  for (var depth = 0; depth < 15; depth++) {
    if (find.byType(CombatScreen).evaluate().isNotEmpty) return;
    final session = _containerFor(tester).read(runControllerProvider);
    final move = session.legalActions.whereType<MoveToNode>().first;
    await tester.tap(find.byKey(ValueKey('run-node-${move.nodeId}')));
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

  testWidgets('두 경계 기기와 글꼴 배율에서 48dp 노드가 넘치지 않는다', (tester) async {
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
          expect(tester.takeException(), isNull);
        } finally {
          await _disposeTree(tester);
        }
      }
    }
  });
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
  cardRewardPool: const [_rewardA, _rewardB, _rewardC],
);
