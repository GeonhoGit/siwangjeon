/// 카드 JSON 로더 (기획서 §7.3).
///
/// 카드가 20장을 넘긴 M1부터 앱은 이 경계에서 asset을 읽고, domain에는 완성된
/// 불변 [CardDef]만 주입한다. domain은 Flutter asset API를 알지 못한다.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/combat/tuning.dart';
import '../domain/effect/card_effect.dart';
import '../domain/model/card.dart';
import '../domain/model/status.dart';
import '../domain/run/run_content.dart';
import 'm0_content.dart';

const m1CardsAssetPath = 'assets/data/cards.json';

class CardContentLoader {
  const CardContentLoader({this.assetPath = m1CardsAssetPath});

  final String assetPath;

  Future<List<CardDef>> load() async {
    final source = await rootBundle.loadString(assetPath);
    return decode(source);
  }

  /// 테스트와 콘텐츠 검증은 asset I/O 없이 같은 변환을 직접 쓴다.
  List<CardDef> decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List<Object?>) {
      throw const FormatException('카드 JSON 최상위는 배열이어야 한다');
    }
    final cards = [for (final raw in decoded) _card(_map(raw, '카드'))];
    if (cards.map((card) => card.id).toSet().length != cards.length) {
      throw const FormatException('카드 JSON의 id는 고유해야 한다');
    }
    return List.unmodifiable(cards);
  }

  CardDef _card(Map<String, Object?> map) {
    if (!map.containsKey('upgrade')) {
      throw const FormatException('카드 JSON에는 upgrade를 명시해야 한다');
    }

    return CardDef(
      id: _string(map, 'id'),
      name: _string(map, 'name'),
      type: _cardType(_string(map, 'type')),
      rarity: map['rarity'] == null
          ? CardRarity.common
          : _rarity(_string(map, 'rarity')),
      cost: _int(map, 'cost'),
      karma: map['karma'] == null ? 0 : _int(map, 'karma'),
      targeted: map['targeted'] is bool ? map['targeted']! as bool : true,
      effects: [
        for (final raw in _list(map, 'effects')) _effect(_map(raw, '카드 효과')),
      ],
      upgrade: _upgrade(map['upgrade']),
    );
  }

  CardUpgrade? _upgrade(Object? value) {
    if (value == null) return null;
    final map = _map(value, '카드 강화');
    return CardUpgrade(
      effects: [
        for (final raw in _list(map, 'effects')) _effect(_map(raw, '카드 강화 효과')),
      ],
    );
  }

  CardEffect _effect(Map<String, Object?> map) {
    final op = _string(map, 'op');
    return switch (op) {
      'damage' => DamageEffect(
        value: _tunedInt(map, 'value'),
        scaleWith: map['scaleWith'] == null ? null : _string(map, 'scaleWith'),
        scale: map['scale'] == null ? 0 : _double(map, 'scale'),
      ),
      'block' => BlockEffect(_tunedInt(map, 'value')),
      'spendBlock' => SpendBlockEffect(_tunedInt(map, 'amount')),
      'applyStatus' => ApplyStatusEffect(
        status: _status(_string(map, 'status')),
        stacks: _tunedInt(map, 'stacks'),
        target: map['target'] == null
            ? EffectTarget.enemy
            : _target(_string(map, 'target')),
      ),
      'changeKarma' => ChangeKarmaEffect(
        _tunedInt(map, 'amount') * (map['negative'] == true ? -1 : 1),
      ),
      'draw' => DrawCardsEffect(_tunedInt(map, 'count')),
      'gainEnergy' => GainEnergyEffect(_tunedInt(map, 'amount')),
      'loseHp' => LoseHpEffect(_tunedInt(map, 'amount')),
      _ => throw FormatException('알 수 없는 카드 효과: $op'),
    };
  }
}

/// 앱 시작 때 카드 정의를 로드한 뒤 런 콘텐츠로 조립한다.
Future<RunContent> loadM1RunContent() async =>
    m1RunContentFromCards(await const CardContentLoader().load());

Map<String, Object?> _map(Object? value, String label) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw FormatException('$label은 객체여야 한다');
}

List<Object?> _list(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is List<Object?>) return value;
  if (value is List) return value.cast<Object?>();
  throw FormatException('$key는 배열이어야 한다');
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw FormatException('$key는 문자열이어야 한다');
}

int _int(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) return value;
  throw FormatException('$key는 정수여야 한다');
}

double _double(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is num) return value.toDouble();
  throw FormatException('$key는 숫자여야 한다');
}

int _tunedInt(Map<String, Object?> map, String key) {
  final direct = map[key];
  if (direct is int) return direct;
  final tuningKey = map['${key}Tuning'];
  if (tuningKey is! String) {
    throw FormatException('$key 또는 ${key}Tuning이 필요하다');
  }
  return switch (tuningKey) {
    'fastingCleanse' => PurificationCardTuning.fastingCleanse,
    'fastingWeak' => PurificationCardTuning.fastingWeak,
    'veilCleanse' => PurificationCardTuning.veilCleanse,
    'veilVulnerable' => PurificationCardTuning.veilVulnerable,
    'shatteredWardCleanse' => PurificationCardTuning.shatteredWardCleanse,
    'shatteredWardBlockCost' => PurificationCardTuning.shatteredWardBlockCost,
    _ => throw FormatException('알 수 없는 카드 튜닝 값: $tuningKey'),
  };
}

CardType _cardType(String source) => switch (source) {
  'attack' => CardType.attack,
  'skill' => CardType.skill,
  'power' => CardType.power,
  'curse' => CardType.curse,
  'status' => CardType.status,
  _ => throw FormatException('알 수 없는 카드 종류: $source'),
};

CardRarity _rarity(String source) => switch (source) {
  'common' => CardRarity.common,
  'uncommon' => CardRarity.uncommon,
  'rare' => CardRarity.rare,
  'siwang' => CardRarity.siwang,
  _ => throw FormatException('알 수 없는 카드 희귀도: $source'),
};

StatusId _status(String source) {
  for (final status in StatusId.values) {
    if (status.name == source) return status;
  }
  throw FormatException('알 수 없는 상태: $source');
}

EffectTarget _target(String source) => switch (source) {
  'self' => EffectTarget.self,
  'enemy' => EffectTarget.enemy,
  _ => throw FormatException('알 수 없는 효과 대상: $source'),
};
