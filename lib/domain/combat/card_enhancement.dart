/// 카드 강화 변환 (기획서 §3.5).
///
/// 강화는 카드 정의를 바꾸지 않고 런 덱의 한 인스턴스에만 적용한다. 그래서 같은
/// 「타격」 두 장 중 한 장만 강화해도 보상·상점의 원본 콘텐츠에는 `+`가 새지
/// 않고, 저장 로그는 인스턴스 id 하나만 기록하면 된다.
library;

import '../model/card.dart';

/// [card]의 강화본을 만든다. 호출자는 한 번 강화된 인스턴스를 다시 이 함수에
/// 넘기지 않아야 하며, 그 합법성은 런 엔진의 `EnhanceWildCampCard` 후보가 맡는다.
///
/// 정화 카드의 JSON 강화본은 체력·기력·상태·방어도 대가를 원본과 같게 두고,
/// 정화량만 늘린다. 대가까지 줄이면 §3.3의 "정화에는 반드시 대가" 거래가 강화
/// 한 번으로 사라진다.
CardDef enhancedCard(CardDef card) => CardDef(
  id: card.id,
  name: '${card.name}+',
  type: card.type,
  rarity: card.rarity,
  cost: card.cost,
  karma: card.karma,
  targeted: card.targeted,
  // 강화 정의가 없는 테스트 전용 카드는 원본 효과를 유지한다. 앱 콘텐츠의 모든
  // 카드는 loader 회귀 테스트가 JSON `upgrade` 존재를 강제한다.
  effects: card.upgrade?.effects ?? card.effects,
);
