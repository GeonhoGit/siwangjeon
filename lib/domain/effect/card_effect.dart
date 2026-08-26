/// 카드 효과 (기획서 §7.3).
///
/// 카드는 코드가 아니라 `assets/data/cards.json`으로 정의된다.
/// 이 sealed 계층은 그 JSON의 `effects` 배열을 해석한 결과물이며,
/// 인터프리터([applyAction] 안의 효과 처리부)가 [CardEffect]를 받아
/// 전투 상태에 적용한다.
///
/// sealed로 두는 이유는 switch가 빠짐없이 다뤄졌는지를 컴파일러가
/// 검사하게 하기 위해서다. 효과를 하나 추가하면 인터프리터가
/// 컴파일 에러로 알려 준다.
library;

import '../model/status.dart';

sealed class CardEffect {
  const CardEffect();
}

/// `{"op": "damage", "value": 6, "scaleWith": "karma", "scale": 0.1}`
final class DamageEffect extends CardEffect {
  const DamageEffect({
    required this.value,
    this.scaleWith,
    this.scale = 0,
  });

  final int value;

  /// 피해량을 함께 키우는 자원 이름. 현재는 `karma`만 쓴다.
  final String? scaleWith;

  /// 자원 1당 증가 비율.
  final double scale;
}

/// `{"op": "applyStatus", "status": "grudge", "stacks": 1}`
final class ApplyStatusEffect extends CardEffect {
  const ApplyStatusEffect({
    required this.status,
    required this.stacks,
    this.target = EffectTarget.enemy,
  });

  final StatusId status;
  final int stacks;
  final EffectTarget target;
}

/// 방어(魄)를 부여한다. 턴 종료 시 소멸한다 (§3.2).
final class BlockEffect extends CardEffect {
  const BlockEffect(this.value);

  final int value;
}

/// 업(業)을 즉시 증감한다. 음수는 §3.3의 정화에 쓴다.
///
/// [CardDef.karma]는 강한 카드가 효과 해결 뒤에 내는 고정 업 비용이고,
/// 이 효과는 카드 해결 순서 안에서 의도적으로 업을 바꾸는 결과다. 두 방식을
/// 한 카드에 함께 써서 서로 상쇄하지 않는다.
final class ChangeKarmaEffect extends CardEffect {
  const ChangeKarmaEffect(this.amount);

  final int amount;
}

/// 덱에서 카드를 뽑는다. 덱 소진과 재셔플은 전투의 공통 드로우 규칙을 따른다.
final class DrawCardsEffect extends CardEffect {
  const DrawCardsEffect(this.count) : assert(count >= 0);

  final int count;
}

/// 기력(氣)을 즉시 회복한다. 턴당 기본 기력보다 더 낼 수 있게 할 수 있다.
final class GainEnergyEffect extends CardEffect {
  const GainEnergyEffect(this.amount) : assert(amount >= 0);

  final int amount;
}

/// 정화 같은 카드가 내는 고정 체력 대가다.
///
/// 공격 피해와 달리 방어도·기세·약화·취약을 거치지 않고 체력만 정확히 잃는다.
/// 따라서 [EffectTarget]을 붙여 [DamageEffect]와 공유하면 안 된다.
final class LoseHpEffect extends CardEffect {
  const LoseHpEffect(this.amount) : assert(amount >= 0);

  final int amount;
}
