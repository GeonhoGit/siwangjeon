/// 카드 정의 (기획서 §3.5, §7.3).
///
/// 카드는 코드가 아니라 `assets/data/cards.json`으로 정의된다(§7.3).
/// 이 클래스는 그 JSON 한 항목을 해석한 결과이며, **정의**일 뿐
/// 전투 중 상태를 갖지 않는다. 손패에 같은 카드가 두 장 있어도
/// 같은 인스턴스를 공유해도 안전하다.
library;

import '../effect/card_effect.dart';

/// §3.5의 카드 분류.
enum CardType {
  attack,
  skill,

  /// 힘 — 지속 효과. 사용 시 사라지지 않고 전투 내내 남는다.
  power,

  /// 저주 — 덱을 오염시키는 카드. 1.0 기준 3종(§3.5).
  curse,

  /// 상태 카드 — 전투 중 임시로 덱에 섞여 들어오는 것들.
  status,
}

/// §3.5의 희귀도. 시왕 등급은 캐릭터별 3장뿐이고 런당 1장만 등장한다.
enum CardRarity { common, uncommon, rare, siwang }

class CardDef {
  const CardDef({
    required this.id,
    required this.name,
    required this.type,
    required this.cost,
    required this.effects,
    this.rarity = CardRarity.common,
    this.karma = 0,
    this.targeted = true,
  });

  final String id;
  final String name;
  final CardType type;
  final CardRarity rarity;

  /// 기력(氣) 소모량. 매 턴 3이 회복되므로(§3.2) 사실상 0~3이다.
  final int cost;

  /// 사용 시 누적되는 업(業). §3.3의 "강력한 카드는 업 +1~+5".
  final int karma;

  /// 적을 지정해야 하는 카드인지. 방어 카드처럼 대상이 없으면 false.
  final bool targeted;

  final List<CardEffect> effects;

  @override
  String toString() => 'CardDef($id)';
}
