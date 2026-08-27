import 'package:flutter_test/flutter_test.dart';
import 'package:siwangjeon/data/m1_relics.dart';

void main() {
  test('M1 유물은 15개의 고유 id와 서로 다른 발동-효과 조합을 제공한다', () {
    const expectedIds = <String>{
      'relic_karma_ledger',
      'relic_pure_mirror',
      'relic_dead_lantern',
      'relic_confession_basin',
      'relic_judges_shield',
      'relic_turbid_brazier',
      'relic_sinner_seal',
      'relic_innocent_silk',
      'relic_bloody_brush',
      'relic_karmic_abacus',
      'relic_grudge_urn',
      'relic_yamas_comb',
      'relic_soul_phial',
      'relic_guardian_beads',
      'relic_black_absolution',
    };

    expect(m1Relics, hasLength(15));
    expect(m1Relics.map((relic) => relic.id).toSet(), expectedIds);
    expect(
      m1Relics
          .map((relic) => (relic.trigger, relic.effect.runtimeType))
          .toSet(),
      hasLength(15),
    );
  });
}
