import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siwangjeon/app/app.dart';
import 'package:siwangjeon/app/run_controller.dart';
import 'package:siwangjeon/domain/effect/card_effect.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/model/status.dart';
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
      expect(find.text('피해 6 · 업 +3'), findsOneWidget);
      expect(find.text('원한 1'), findsOneWidget);
      expect(find.text('방어 2 · 체력 -5'), findsOneWidget);
      expect(find.text('업 -8'), findsOneWidget);
      expect(find.text('방어 2 · 기세 1'), findsOneWidget);
      expect(find.text('굳음 1'), findsOneWidget);

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

  testWidgets('보상 효과는 경계 기기와 글꼴 배율에서 세 장 모두 보인다', (tester) async {
    for (final device in _boundaryDevices) {
      for (final textScale in [1.0, 1.3]) {
        await _pumpReward(tester, device: device, textScale: textScale);

        try {
          final viewport = _layoutBounds(tester, find.byType(ListView));
          for (final card in _rewardCards) {
            final cardBounds = _layoutBounds(
              tester,
              find.byKey(ValueKey('reward-card-${card.id}')),
            );
            expect(
              cardBounds.height,
              greaterThanOrEqualTo(48),
              reason: device.name,
            );
            expect(cardBounds.top, greaterThanOrEqualTo(viewport.top));
            expect(cardBounds.bottom, lessThanOrEqualTo(viewport.bottom));
          }

          final firstEffectLine = _layoutBounds(
            tester,
            find.byKey(const ValueKey('reward-card-effect-ui_reward_a-0')),
          );
          final secondEffectLine = _layoutBounds(
            tester,
            find.byKey(const ValueKey('reward-card-effect-ui_reward_a-1')),
          );
          expect(
            secondEffectLine.top,
            greaterThanOrEqualTo(firstEffectLine.bottom),
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
);
