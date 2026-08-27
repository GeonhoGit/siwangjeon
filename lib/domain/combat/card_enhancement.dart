/// 카드 강화 변환 (기획서 §3.5).
///
/// 강화는 카드 정의를 바꾸지 않고 런 덱의 한 인스턴스에만 적용한다. 그래서 같은
/// 「타격」 두 장 중 한 장만 강화해도 보상·상점의 원본 콘텐츠에는 `+`가 새지
/// 않고, 저장 로그는 인스턴스 id 하나만 기록하면 된다.
library;

import '../effect/card_effect.dart';
import '../model/card.dart';
import 'tuning.dart';

/// [card]의 강화본을 만든다. 호출자는 한 번 강화된 인스턴스를 다시 이 함수에
/// 넘기지 않아야 하며, 그 합법성은 런 엔진의 `EnhanceWildCampCard` 후보가 맡는다.
CardDef enhancedCard(
  CardDef card, {
  CardEnhancementTuning tuning = CardEnhancementTuning.m1,
}) => CardDef(
  id: card.id,
  name: '${card.name}+',
  type: card.type,
  rarity: card.rarity,
  cost: card.cost,
  karma: card.karma,
  targeted: card.targeted,
  effects: [for (final effect in card.effects) _enhancedEffect(effect, tuning)],
);

CardEffect _enhancedEffect(CardEffect effect, CardEnhancementTuning tuning) =>
    switch (effect) {
      DamageEffect(:final value, :final scaleWith, :final scale) =>
        DamageEffect(
          value: value + tuning.damageBonus,
          scaleWith: scaleWith,
          scale: scale,
        ),
      BlockEffect(:final value) => BlockEffect(value + tuning.blockBonus),
      SpendBlockEffect() => effect,
      ApplyStatusEffect(:final status, :final stacks, :final target) =>
        ApplyStatusEffect(
          status: status,
          stacks: stacks + tuning.statusBonus,
          target: target,
        ),
      // 정화 카드의 강화는 업을 더 씻되 체력·기력 대가는 그대로 둔다. 대가까지
      // 줄이면 §3.3의 "정화에는 반드시 대가"라는 거래가 강화 한 번으로 사라진다.
      ChangeKarmaEffect(:final amount) when amount < 0 => ChangeKarmaEffect(
        amount - tuning.cleanseBonus,
      ),
      ChangeKarmaEffect() ||
      DrawCardsEffect() ||
      GainEnergyEffect() ||
      LoseHpEffect() => effect,
    };
