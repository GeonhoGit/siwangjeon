import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/m1_relics.dart';
import 'package:siwangjeon/domain/combat/relic_preview.dart';

void main() {
  test('15종 유물의 발동 시점과 효과 문장은 domain이 빠짐없이 만든다', () {
    expect(m1Relics, hasLength(15));

    for (final relic in m1Relics) {
      final preview = previewRelic(relic);
      expect(preview.triggerLabel, isNotEmpty, reason: relic.id);
      expect(preview.effectLabel, isNotEmpty, reason: relic.id);
    }
  });

  test('혼백 약병 설명은 적 처치 회복임을 구분한다', () {
    final preview = previewRelic(
      m1Relics.singleWhere((relic) => relic.id == 'relic_soul_phial'),
    );

    expect(preview.triggerLabel, '적 처치');
    expect(preview.effectLabel, '체력 +2');
  });
}
