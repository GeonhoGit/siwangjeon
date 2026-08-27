import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/app/run_controller.dart';
import 'package:siwangjeon/domain/model/boss.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/run/judgment_preview.dart';
import 'package:siwangjeon/domain/run/run_action.dart';
import 'package:siwangjeon/domain/run/run_engine.dart';
import 'package:siwangjeon/domain/run/run_map.dart';
import 'package:siwangjeon/domain/run/run_node_type.dart';
import 'package:siwangjeon/domain/run/run_state.dart';
import 'package:siwangjeon/ui/run_screen.dart';

class _StaticRunController extends RunController {
  _StaticRunController(this._session);

  final RunSession _session;

  @override
  RunSession build() => _session;
}

void main() {
  testWidgets('전투 전 지도는 도메인 심판 안내를 스크롤 지도 앞에 배치한다', (tester) async {
    final preview = judgmentPreviewFor(
      karma: 80,
      boss: BossDef(
        enemy: const Enemy(
          id: 'ui_yeomra',
          name: '염라대왕',
          hp: 96,
          maxHp: 96,
          pattern: [EnemyDefend(0)],
        ),
        turbidExtraMove: const EnemyDefend(0),
      ),
    );
    final session = _mapSession(judgmentPreview: preview);

    await tester.pumpWidget(
      MaterialApp(
        home: RunMapScreen(session: session, onMove: (_) {}),
      ),
    );
    await tester.pump();

    final notice = find.byKey(const ValueKey('judgment-preview'));
    final map = find.byKey(const ValueKey('run-map-scroll'));
    expect(notice, findsOneWidget);
    expect(map, findsOneWidget);
    expect(
      tester.getBottomLeft(notice).dy,
      lessThan(tester.getTopLeft(map).dy),
    );
    final labels = tester
        .widgetList<Text>(
          find.descendant(of: notice, matching: find.byType(Text)),
        )
        .map((text) => text.data)
        .toList();
    expect(
      labels,
      containsAll([
        preview.title,
        '${preview.bandLabel} · ${preview.effectLabel}',
      ]),
    );
  });

  testWidgets('런 승리는 패배 화면과 다른 종료 구조로 렌더링한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runControllerProvider.overrideWith(
            () => _StaticRunController(_victorySession()),
          ),
        ],
        child: const MaterialApp(home: RunScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('run-ended-victory')), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byKey(const ValueKey('run-map-scroll')), findsNothing);
  });
}

RunSession _mapSession({
  JudgmentPreview? judgmentPreview,
  RunOutcome? outcome,
}) {
  final map = RunMap(
    nodes: [
      RunNode(
        id: 0,
        depth: 0,
        type: RunNodeType.combat,
        nextNodeIds: const [1],
      ),
      RunNode(id: 1, depth: 1, type: RunNodeType.boss, nextNodeIds: const []),
    ],
  );
  return RunSession(
    state: const RunState(seed: 1, characterId: 'm0', actionLog: []),
    progress: RunProgress(
      map: map,
      visitedNodeIds: const [0],
      hp: 80,
      maxHp: 80,
      karma: 80,
      money: 0,
      deck: const [],
      judgmentPreview: judgmentPreview,
      outcome: outcome,
    ),
    legalActions: outcome == null ? const [MoveToNode(nodeId: 1)] : const [],
  );
}

RunSession _victorySession() => _mapSession(outcome: RunOutcome.victory);
