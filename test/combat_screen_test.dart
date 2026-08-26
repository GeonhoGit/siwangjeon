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
import 'package:siwangjeon/ui/combat_screen.dart';

/// 화면이 세로 휴대폰 크기에서 검사되도록 고정한다.
///
/// §8.1의 2번 질문이 "세로 화면에서 답답하지 않은가"이므로, 테스트가
/// 데스크톱 크기에서 통과해 버리면 정작 물어야 할 조건을 비켜 간다.
/// 갤럭시 A 계열에 가까운 논리 해상도를 쓴다(§7.5의 저사양 기준).
const _phone = Size(393, 851);

Future<void> pumpCombat(WidgetTester tester) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const ProviderScope(child: SiwangjeonApp()));
  await tester.pump();
}

/// 화면에는 1초짜리 반복 타이머(경과 시간)가 있다. 트리를 비워 dispose를
/// 태우지 않으면 테스트가 "타이머가 남아 있다"로 실패한다.
Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
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

    expect(container.read(combatControllerProvider).state.block, greaterThan(0));

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
