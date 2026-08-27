import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/domain/model/enemy.dart';
import 'package:siwangjeon/domain/model/status.dart';
import 'package:siwangjeon/ui/labels.dart';

import 'support/m1_card_test_content.dart';

void main() {
  group('적 예고 표기', () {
    test('2회 공격은 회당 피해 뒤에 횟수를 붙인다', () {
      expect(intentLabel(const EnemyAttack(4, times: 2), damage: 4), '공격 4 ×2');
    });

    test('1회 공격은 회당 피해만 표시한다', () {
      expect(intentLabel(const EnemyAttack(4), damage: 4), '공격 4');
    });

    test('공격이 아닌 예고는 기존 표기를 유지한다', () {
      expect(intentLabel(const EnemyDefend(5)), '방어 5');
      expect(intentLabel(const EnemyInflict(StatusId.vulnerable, 2)), '취약 2');
    });
  });

  test('겹친 손패에 남는 이름 앞 두 글자는 M1의 23종을 모두 구분한다', () {
    final labels = m1Cards.map(handCardLabel).toList();

    expect(labels, hasLength(23));
    expect(labels.toSet(), hasLength(23));
    expect(handCardLabel(defend), '수비');
    expect(handCardLabel(guardianSigil), '수호');
  });
}
