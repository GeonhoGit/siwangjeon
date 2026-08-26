/// 전투 상수 (기획서 §8.2).
///
/// **여기 있는 수치는 전부 M0 임시값이다.** 기획서가 못박은 것은
/// 기력 3(§3.2)과 업 구간 경계(§3.3)뿐이고, 나머지는 전투가 굴러가게
/// 하려고 정한 값이다.
///
/// 한곳에 모아 둔 이유는 M2의 밸런스 시뮬레이터(§8.2)가 이 값들을
/// 흔들어 가며 10만 런을 돌릴 것이기 때문이다. 상수가 엔진 코드에
/// 흩어져 있으면 그 작업이 코드 수정이 되어 버린다.
library;

class CombatTuning {
  const CombatTuning({
    this.energyPerTurn = 3,
    this.handSize = 5,
    this.maxKarma = 100,
    this.vulnerableMultiplier = 1.5,
    this.weakMultiplier = 0.75,
    this.karmaPerGrudgeTick = 20,
  });

  /// §3.2 — 매 턴 회복되는 기력(氣). 기획서가 정한 값이다.
  final int energyPerTurn;

  /// §3.1 — 턴 시작 시 손패를 채우는 목표 장수.
  final int handSize;

  /// §3.3 — 업 상한.
  final int maxKarma;

  /// 취약: 받는 피해 배수.
  final double vulnerableMultiplier;

  /// 약화: 주는 피해 배수.
  final double weakMultiplier;

  /// 원한 1스택이 업 몇 점당 1의 피해로 환산되는가.
  ///
  /// 업 100에서 스택당 5 피해가 된다. §3.3의 "지금 세게 밀어붙이고
  /// 심판에서 값을 치른다"를 전투 안에서도 한 번 맛보게 하려는 값이고,
  /// 이 환산이 너무 후하면 업이 순수한 이득이 되어 §8.1의 1번 질문이
  /// 자동으로 실패한다.
  final int karmaPerGrudgeTick;

  static const CombatTuning m0 = CombatTuning();
}
