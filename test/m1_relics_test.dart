import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/m1_relics.dart';

void main() {
  test('M1 유물은 15개의 고유 id와 서로 다른 발동-효과 조합을 제공한다', () {
    expect(m1Relics, hasLength(15));
    expect(m1Relics.map((relic) => relic.id).toSet(), hasLength(15));
    expect(
      m1Relics
          .map((relic) => (relic.trigger, relic.effect.runtimeType))
          .toSet(),
      hasLength(15),
    );
  });
}
