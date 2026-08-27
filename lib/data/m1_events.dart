/// M1 사건 8종 (§2.1, §3.3).
///
/// 문구·선택의 의미·카드 보상은 data에, 실제 수치는 `RunTuning.eventDeltaFor`에
/// 둔다. 업 구간의 숫자도 tuning에 남겨, 콘텐츠가 문구를 바꾸다가 밸런스를
/// 바꾸지 않게 한다.
library;

import '../domain/run/run_event.dart';

final List<RunEventDef> m1Events = List.unmodifiable([
  /// 업을 자본으로 바꿀지 빈손으로 지나갈지 묻는다. 청정한 기록 자체를 보상으로
  /// 만들지 않아, 모든 사건이 정화 거래로 수렴하지 않게 한다.
  RunEventDef(
    id: 'event_judges_bribe',
    name: '판관의 뇌물',
    choices: const [
      RunEventChoice(
        id: 'accept',
        label: '봉투를 받는다',
        effect: RunEventEffect.acceptBribe,
      ),
      RunEventChoice(
        id: 'return',
        label: '빈손으로 돌려준다',
        effect: RunEventEffect.returnBribe,
      ),
    ],
  ),

  /// 지금 체력을 회복해 업을 올릴지, 회복을 포기하고 업 없는 방어 카드를 덱에
  /// 심을지 묻는다. 업 축에서 즉시 생존과 장기적인 청정 운용을 맞바꾼다.
  RunEventDef(
    id: 'event_hungry_ghost_offering',
    name: '아귀의 공양',
    choices: const [
      RunEventChoice(
        id: 'consume',
        label: '혼자 먹는다',
        effect: RunEventEffect.consumeOffering,
      ),
      RunEventChoice(
        id: 'share',
        label: '나누고 수호를 배운다',
        effect: RunEventEffect.shareOffering,
        gainedCardId: 'card_iron_guard',
      ),
    ],
  ),

  /// 불법 현금, 돈을 내는 깨끗한 카드, 아무 거래도 하지 않기의 3지선다다.
  /// 업 축에서는 당장의 자본·덱의 안정성·현상 유지를 서로 다른 답으로 둔다.
  RunEventDef(
    id: 'event_river_smuggler',
    name: '삼도천의 밀수꾼',
    choices: const [
      RunEventChoice(
        id: 'smuggle',
        label: '밀수품을 받는다',
        effect: RunEventEffect.takeSmugglerCoin,
      ),
      RunEventChoice(
        id: 'fare',
        label: '정가를 내고 정결한 검을 산다',
        effect: RunEventEffect.payFerryman,
        gainedCardId: 'card_clean_cut',
      ),
      RunEventChoice(
        id: 'leave',
        label: '거래를 지나친다',
        effect: RunEventEffect.turnAwaySmuggler,
      ),
    ],
  ),

  /// 현재 업이 낮을 때는 기록을 더럽혀 자본을 만들 유혹이, 높을 때는 돈을 내고
  /// 기록을 고칠 기회가 열린다. 업은 나중 비용뿐 아니라 지금의 선택지를 바꾼다.
  RunEventDef(
    id: 'event_hell_ledger',
    name: '지옥의 장부',
    choices: const [
      RunEventChoice(
        id: 'falsify',
        label: '아직 깨끗한 장부를 위조한다',
        effect: RunEventEffect.falsifyLedger,
        availableKarmaBands: {KarmaBand.pure, KarmaBand.ordinary},
      ),
      RunEventChoice(
        id: 'confess',
        label: '쌓인 기록을 돈으로 고친다',
        effect: RunEventEffect.confessLedger,
        availableKarmaBands: {KarmaBand.turbid, KarmaBand.wicked},
      ),
      RunEventChoice(
        id: 'seal',
        label: '장부를 덮는다',
        effect: RunEventEffect.sealLedger,
      ),
    ],
  ),

  /// 몸을 회복해 다음 심판을 버틸지, 노잣돈을 써 업을 덜어 낼지 묻는다. 같은
  /// 정화라도 덱이나 현금이 아닌 체력 여유를 얼마나 남길지 판단하게 한다.
  RunEventDef(
    id: 'event_ancestral_ashes',
    name: '조상의 재',
    choices: const [
      RunEventChoice(
        id: 'burn',
        label: '재를 태워 몸을 덥힌다',
        effect: RunEventEffect.burnAncestralAshes,
      ),
      RunEventChoice(
        id: 'tend',
        label: '제사를 지내 업을 던다',
        effect: RunEventEffect.tendAncestralAshes,
      ),
    ],
  ),

  /// 돈만 챙길지, 체력·업·덱을 한꺼번에 투자할지 묻는다. 업 축에서 현금의
  /// 즉시성보다 이후 전투의 청정 방어 기반을 살지 결정하게 한다.
  RunEventDef(
    id: 'event_widows_candle',
    name: '과부의 등불',
    choices: const [
      RunEventChoice(
        id: 'steal',
        label: '촛농을 팔아 노잣돈을 챙긴다',
        effect: RunEventEffect.stealWidowCandle,
      ),
      RunEventChoice(
        id: 'light',
        label: '밤을 지켜 호흡을 배운다',
        effect: RunEventEffect.lightWidowCandle,
        gainedCardId: 'card_steady_breath',
      ),
    ],
  ),

  /// 대가 없는 세 갈래의 호의다. 회복에는 업이 붙고, 정화와 현금은 각각 한
  /// 자원만 주므로 현재 업 구간에서 가장 급한 축을 고르게 한다.
  RunEventDef(
    id: 'event_cup_of_oblivion',
    name: '망각의 잔',
    choices: const [
      RunEventChoice(
        id: 'drink',
        label: '잔을 비운다',
        effect: RunEventEffect.drinkOblivion,
      ),
      RunEventChoice(
        id: 'refuse',
        label: '기억을 지킨다',
        effect: RunEventEffect.refuseOblivion,
      ),
      RunEventChoice(
        id: 'sell',
        label: '잔을 팔아 노잣돈을 만든다',
        effect: RunEventEffect.sellOblivion,
      ),
    ],
  ),

  /// 새 정화 카드와 업을 함께 받아 이후 덱을 바꿀지, 현재 덱을 건드리지 않고
  /// 체력으로 시련을 넘길지 묻는다. 업은 강한 정화 수단을 앞당기는 입장권이다.
  RunEventDef(
    id: 'event_wardens_favor',
    name: '옥졸의 호의',
    choices: const [
      RunEventChoice(
        id: 'favor',
        label: '호의를 받아 대정화를 익힌다',
        effect: RunEventEffect.takeWardenFavor,
        gainedCardId: 'card_great_purification',
      ),
      RunEventChoice(
        id: 'trial',
        label: '지금의 덱으로 시련을 견딘다',
        effect: RunEventEffect.endureWardenTrial,
      ),
    ],
  ),
]);
