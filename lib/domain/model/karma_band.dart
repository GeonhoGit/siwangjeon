/// 업 구간과 그 경계.
///
/// 경계값 자체는 전투 수치와 함께 `combat/tuning.dart`에 둔다. 이 모델은 전투와
/// 런 심판이 같은 설정을 해석하게 하는 의미 단위만 제공한다.
library;

/// 업 구간에 따른 심판 등급 (§3.3).
enum KarmaBand {
  /// 청정 — 보스 체력 감소, 청정 유물 효과.
  pure,

  /// 평범 — 기준값.
  ordinary,

  /// 탁함 — 추가 판결 행동, 탁함 유물 효과.
  turbid,

  /// 악업 — 보스 2페이즈 즉시 진입, 확정 유물.
  wicked,
}

/// 청정·평범·탁함의 마지막 업 수치.
///
/// [forKarma]는 전투 유물과 심판이 공통으로 쓰는 유일한 구간 판정이다.
class KarmaBandThresholds {
  const KarmaBandThresholds({
    required this.cleanKarmaMax,
    required this.ordinaryKarmaMax,
    required this.turbidKarmaMax,
  }) : assert(cleanKarmaMax >= 0),
       assert(ordinaryKarmaMax >= cleanKarmaMax),
       assert(turbidKarmaMax >= ordinaryKarmaMax);

  final int cleanKarmaMax;
  final int ordinaryKarmaMax;
  final int turbidKarmaMax;

  KarmaBand forKarma(int karma) {
    if (karma <= cleanKarmaMax) return KarmaBand.pure;
    if (karma <= ordinaryKarmaMax) return KarmaBand.ordinary;
    if (karma <= turbidKarmaMax) return KarmaBand.turbid;
    return KarmaBand.wicked;
  }
}
