/// 테스트가 앱과 같은 JSON 카드 정의를 읽는 공용 손잡이다.
library;

import 'dart:io';

import 'package:siwangjeon/data/card_content_loader.dart';
import 'package:siwangjeon/data/m0_content.dart';
import 'package:siwangjeon/domain/model/card.dart';
import 'package:siwangjeon/domain/run/run_content.dart';

/// Flutter asset bundle을 거치지 않고 저장소의 원본 JSON을 같은 decoder에 전달한다.
final List<CardDef> m1Cards = const CardContentLoader().decode(
  File(m1CardsAssetPath).readAsStringSync(),
);

/// 기존 이름별 테스트 도구가 수치를 복제하지 않고 id로 카드 정의를 찾는다.
CardDef cardById(String id) => m1Cards.singleWhere((card) => card.id == id);

final CardDef strike = cardById('card_strike');
final CardDef bladeOfGrudge = cardById('card_blade_of_grudge');
final CardDef sinfulSlash = cardById('card_sinful_slash');
final CardDef venomVerdict = cardById('card_venom_verdict');
final CardDef inquisitionBrand = cardById('card_inquisition_brand');
final CardDef twinVerdict = cardById('card_twin_verdict');
final CardDef suppressingCut = cardById('card_suppressing_cut');
final CardDef cleanCut = cardById('card_clean_cut');
final CardDef defend = cardById('card_defend');
final CardDef ironGuard = cardById('card_iron_guard');
final CardDef steadyBreath = cardById('card_steady_breath');
final CardDef recoveredEnergy = cardById('card_recovered_energy');
final CardDef guardianSigil = cardById('card_guardian_sigil');
final CardDef greedyBarrier = cardById('card_greedy_barrier');
final CardDef weakeningGlance = cardById('card_weakening_glance');
final CardDef hellfireMomentum = cardById('card_hellfire_momentum');
final CardDef ironVow = cardById('card_iron_vow');
final CardDef clingingOath = cardById('card_clinging_oath');
final CardDef confession = cardById('card_confession');
final CardDef greatPurification = cardById('card_great_purification');
final CardDef fastingVow = cardById('card_fasting_vow');
final CardDef thinVeil = cardById('card_thin_veil');
final CardDef shatteredWard = cardById('card_shattered_ward');

final RunContent m1TestContent = m1RunContentFromCards(m1Cards);

List<CardDef> get starterDeck => m1TestContent.deck;
List<CardDef> get cardRewardPool => m1TestContent.cardRewardPool;
