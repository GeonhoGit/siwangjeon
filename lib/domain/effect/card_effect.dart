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
