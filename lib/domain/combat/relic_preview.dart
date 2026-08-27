/// 유물 보상과 보유 목록에 쓰는, 규칙 기반 설명.
///
/// 효과와 발동 시점을 사람이 읽는 문장으로 바꾸는 것도 유물 규칙의 일부다.
/// 그래서 이 파일은 sealed 유물 효과와 [CombatTuning]을 해석하고, UI는 반환된
/// 문자열을 배치만 한다. 새 효과나 시점이 추가되면 여기의 exhaustive switch도
/// 함께 갱신되어 화면 설명이 엔진과 갈라지지 않는다.
library;

import '../model/relic.dart';
import 'tuning.dart';

class RelicPreview {
  const RelicPreview({required this.triggerLabel, required this.effectLabel});

  final String triggerLabel;
  final String effectLabel;
}

RelicPreview previewRelic(
  RelicDef relic, {
  CombatTuning tuning = CombatTuning.m0,
}) => RelicPreview(
  triggerLabel: _triggerLabel(relic.trigger),
  effectLabel: _effectLabel(relic.effect, tuning),
);

String _triggerLabel(RelicTrigger trigger) => switch (trigger) {
  RelicTrigger.combatStarted => '전투 시작',
  RelicTrigger.turnStarted => '내 턴 시작',
  RelicTrigger.cardPlayed => '카드 사용 후',
  RelicTrigger.turnEnded => '턴 종료',
  RelicTrigger.enemyDied => '적 처치',
  RelicTrigger.playerDamageDealt => '방어도를 뚫는 피해를 줌',
  RelicTrigger.playerDamageTaken => '피해를 받을 때',
};

String _effectLabel(
  RelicEffect effect,
  CombatTuning tuning,
) => switch (effect) {
  KarmaScaledStrengthEffect() => '업 ${tuning.karmaPerRelicStrength}마다 기세 +1',
  PureDexterityEffect() => '청정이면 굳음 +${tuning.pureRelicDexterity}',
  OpeningDrawEffect() => '카드 ${tuning.openingRelicDrawCount}장 뽑기',
  OpeningCleanseEffect() => '업 -${tuning.openingRelicCleanse}',
  KarmaBandBlockEffect() =>
    '청정/보통/탁함: 방어 +${tuning.pureRelicTurnBlock}/'
        '${tuning.ordinaryRelicTurnBlock}/${tuning.turbidRelicTurnBlock}',
  TurbidEnergyEffect() => '탁함 또는 악업이면 기력 +${tuning.turbidRelicEnergy}',
  KarmaCardBonusDamageEffect() => '업 카드면 피해 +${tuning.karmaCardBonusDamage}',
  CleanCardBlockEffect() => '업 없는 카드면 방어 +${tuning.cleanCardBlock}',
  UnblockedDamageVulnerableEffect() =>
    '적에게 취약 +${tuning.unblockedDamageVulnerable}',
  UnblockedDamageKarmaEffect() => '업 +${tuning.unblockedDamageKarma}',
  KarmaBurstEffect() => '업 ${tuning.karmaPerRelicBurst}마다 모든 적에게 피해 1',
  TurnEndCleanseEffect() => '업 -${tuning.turnEndRelicCleanse}',
  EnemyDeathHealEffect() => '체력 +${tuning.enemyDeathRelicHeal}',
  EnemyDeathBlockEffect() => '방어 +${tuning.enemyDeathRelicBlock}',
  TurbidDamageReductionEffect() =>
    '탁함 또는 악업이면 받는 피해 -${tuning.turbidRelicDamageReduction}',
};
