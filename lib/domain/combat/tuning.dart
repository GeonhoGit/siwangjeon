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

import '../model/karma_band.dart';

/// §3.3의 업 구간 경계는 전투 유물과 런 심판이 함께 소비한다.
const defaultKarmaBandThresholds = KarmaBandThresholds(
  cleanKarmaMax: 19,
  ordinaryKarmaMax: 49,
  turbidKarmaMax: 79,
);

class CombatTuning {
  const CombatTuning({
    this.energyPerTurn = 3,
    this.handSize = 5,
    this.maxHandSize = 6,
    this.maxKarma = 100,
    this.vulnerableMultiplier = 1.5,
    this.weakMultiplier = 0.75,
    this.karmaPerGrudgeTick = 20,
    this.karmaPerRelicStrength = 25,
    this.pureRelicDexterity = 1,
    this.openingRelicDrawCount = 1,
    this.openingRelicCleanse = 3,
    this.pureRelicTurnBlock = 6,
    this.ordinaryRelicTurnBlock = 4,
    this.turbidRelicTurnBlock = 2,
    this.turbidRelicEnergy = 1,
    this.karmaCardBonusDamage = 3,
    this.cleanCardBlock = 2,
    this.unblockedDamageVulnerable = 1,
    this.unblockedDamageKarma = 1,
    this.karmaPerRelicBurst = 20,
    this.turnEndRelicCleanse = 1,
    this.enemyDeathRelicHeal = 2,
    this.enemyDeathRelicBlock = 5,
    this.turbidRelicDamageReduction = 1,
    this.enemyPhaseTwoThresholdPercent = 50,
    this.karmaBandThresholds = defaultKarmaBandThresholds,
  }) : assert(enemyPhaseTwoThresholdPercent > 0),
       assert(enemyPhaseTwoThresholdPercent < 100);

  /// §3.2 — 매 턴 회복되는 기력(氣). 기획서가 정한 값이다.
  final int energyPerTurn;

  /// §3.1 — 턴 시작 시 손패를 채우는 목표 장수.
  final int handSize;

  /// 손패가 가질 수 있는 최대 장수.
  ///
  /// §3.1은 턴 시작 목표인 5장만 정하고 상한은 정하지 않는다. 세로 화면의
  /// 부채꼴은 장수가 늘수록 카드 간격이 줄어 읽기 어려워지므로, 효과 드로우로
  /// 허용할 여유는 한 장(6장)만 둔다. Pixel 8 기준 1.0×·1.3× 폰트 배율에서
  /// 이 장수의 카드와 턴 종료 버튼이 모두 하단 상호작용 영역 안에 남는지
  /// 위젯 테스트로 고정한다.
  final int maxHandSize;

  /// §3.3 — 업 상한.
  final int maxKarma;

  /// 전투 유물이 참조하는 업 구간. 런 심판과 같은 값을 주입한다.
  final KarmaBandThresholds karmaBandThresholds;

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

  final int karmaPerRelicStrength;
  final int pureRelicDexterity;
  final int openingRelicDrawCount;
  final int openingRelicCleanse;
  final int pureRelicTurnBlock;
  final int ordinaryRelicTurnBlock;
  final int turbidRelicTurnBlock;
  final int turbidRelicEnergy;
  final int karmaCardBonusDamage;
  final int cleanCardBlock;
  final int unblockedDamageVulnerable;
  final int unblockedDamageKarma;
  final int karmaPerRelicBurst;
  final int turnEndRelicCleanse;
  final int enemyDeathRelicHeal;
  final int enemyDeathRelicBlock;
  final int turbidRelicDamageReduction;

  /// 페이즈 적이 2페이즈로 넘어가는 최대 체력 비율. 전이는 체력만 보고
  /// 결정하므로 난수 스트림을 소모하지 않는다.
  final int enemyPhaseTwoThresholdPercent;

  static const CombatTuning m0 = CombatTuning();
}

/// M1 정화 카드의 정화량과 대가. §3.3은 정화에 대가만 요구할 뿐 수치를 정하지
/// 않았으므로, 모두 **M2의 10만 런 시뮬레이터 조율 전 임시값**이다. 콘텐츠에는
/// 카드가 업 축에서 하는 일만 남기고, 이 수치는 여기 한 곳에서 바꾼다.
abstract final class PurificationCardTuning {
  static const fastingCleanse = 7;
  static const fastingWeak = 2;
  static const veilCleanse = 8;
  static const veilVulnerable = 2;
  static const shatteredWardCleanse = 10;
  static const shatteredWardBlockCost = 8;
}
