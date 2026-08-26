/// M1 사건 8종 (§2.1, §3.3).
///
/// 문구와 선택의 의미는 data에, 실제 수치는 `RunTuning.eventDeltaFor`에 둔다.
/// 그래서 사건이 업 축에서 어떤 거래인지 콘텐츠만 읽어도 드러나고, 밸런스
/// 시뮬레이션은 텍스트를 건드리지 않고 수치만 바꿀 수 있다.
library;

import '../domain/run/run_event.dart';

final List<RunEventDef> m1Events = List.unmodifiable([
  /// 업을 노잣돈으로 바꾸는 가장 직접적인 타락과, 체력으로 갚는 정화의 저울이다.
  RunEventDef(
    id: 'event_judges_bribe',
    name: '판관의 뇌물',
    choices: const [
      RunEventChoice(
        id: 'accept',
        label: '뇌물을 받는다',
        effect: RunEventEffect.acceptBribe,
      ),
      RunEventChoice(
        id: 'return',
        label: '돌려주고 매를 맞는다',
        effect: RunEventEffect.returnBribe,
      ),
    ],
  ),

  /// 남의 공양을 빼앗아 체력을 얻으면 업이 쌓이고, 나누면 체력으로 업을 씻는다.
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
        label: '나누어 준다',
        effect: RunEventEffect.shareOffering,
      ),
    ],
  ),

  /// 밀수는 노잣돈과 업을 함께 늘리고, 정당한 뱃삯은 돈으로 업을 정화한다.
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
        label: '정당한 뱃삯을 낸다',
        effect: RunEventEffect.payFerryman,
      ),
    ],
  ),

  /// 장부를 고치면 즉시 돈을 얻지만 업이 남고, 자백은 체력 대가로 그 업을 씻는다.
  RunEventDef(
    id: 'event_hell_ledger',
    name: '지옥의 장부',
    choices: const [
      RunEventChoice(
        id: 'falsify',
        label: '죄목을 지운다',
        effect: RunEventEffect.falsifyLedger,
      ),
      RunEventChoice(
        id: 'confess',
        label: '죄를 고한다',
        effect: RunEventEffect.confessLedger,
      ),
    ],
  ),

  /// 조상의 재를 태우면 회복과 업을 맞바꾸며, 제사를 지내면 돈을 내고 업을 씻는다.
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
        label: '제단을 돌본다',
        effect: RunEventEffect.tendAncestralAshes,
      ),
    ],
  ),

  /// 과부의 촛불을 훔치면 돈과 업을 얻고, 대신 켜 두면 체력으로 업을 정화한다.
  RunEventDef(
    id: 'event_widows_candle',
    name: '과부의 등불',
    choices: const [
      RunEventChoice(
        id: 'steal',
        label: '촛농을 훔긴다',
        effect: RunEventEffect.stealWidowCandle,
      ),
      RunEventChoice(
        id: 'light',
        label: '등불을 지킨다',
        effect: RunEventEffect.lightWidowCandle,
      ),
    ],
  ),

  /// 망각주는 회복을 업으로 선불 결제하고, 거절은 고통을 감수해 업을 씻는 선택이다.
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
        label: '고통을 기억한다',
        effect: RunEventEffect.refuseOblivion,
      ),
    ],
  ),

  /// 옥졸의 편의를 받으면 돈과 업이 늘고, 시련을 버티면 체력으로 업을 정화한다.
  RunEventDef(
    id: 'event_wardens_favor',
    name: '옥졸의 호의',
    choices: const [
      RunEventChoice(
        id: 'favor',
        label: '호의를 받는다',
        effect: RunEventEffect.takeWardenFavor,
      ),
      RunEventChoice(
        id: 'trial',
        label: '시련을 견딘다',
        effect: RunEventEffect.endureWardenTrial,
      ),
    ],
  ),
]);
