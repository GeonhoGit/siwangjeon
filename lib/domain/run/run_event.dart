/// 런 사건의 버전 고정 콘텐츠 모델 (§2.1, §3.3, §7.4).
///
/// 사건의 이름·선택지·업 축 의미는 data 레이어에서 주입한다. domain은 선택지가
/// 어떤 상태 변화를 뜻하는지만 [RunEventEffect]와 [RunEventDelta]로 해석하므로,
/// 콘텐츠를 JSON으로 옮겨도 재생 규칙은 이 레이어에 남는다.
library;

/// 사건 하나. id는 저장하지 않지만 노드별 reward 시드로 같은 사건을 다시 뽑는
/// 콘텐츠 식별자이므로 배포 버전 안에서는 고정한다.
class RunEventDef {
  RunEventDef({
    required this.id,
    required this.name,
    required List<RunEventChoice> choices,
  }) : choices = List.unmodifiable(choices) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', '사건 id는 비어 있을 수 없다');
    }
    if (choices.length < 2) {
      throw ArgumentError.value(choices, 'choices', '사건에는 선택지가 둘 이상 있어야 한다');
    }
    if (choices.map((choice) => choice.id).toSet().length != choices.length) {
      throw ArgumentError.value(choices, 'choices', '사건 선택지 id는 고유해야 한다');
    }
  }

  final String id;
  final String name;
  final List<RunEventChoice> choices;
}

/// 사건에서 기록 가능한 선택지. [effect]의 실제 수치는 [RunTuning]에 있다.
class RunEventChoice {
  const RunEventChoice({
    required this.id,
    required this.label,
    required this.effect,
  });

  final String id;
  final String label;
  final RunEventEffect effect;
}

/// 데이터 콘텐츠가 참조하는 사건 결과의 종류.
///
/// 이름마다 결과를 따로 두어 데이터가 수치를 들지 않고도 각 사건의 의도를
/// 드러낸다. 값은 [RunTuning.eventDeltaFor] 한곳에서만 조정한다.
enum RunEventEffect {
  acceptBribe,
  returnBribe,
  consumeOffering,
  shareOffering,
  takeSmugglerCoin,
  payFerryman,
  falsifyLedger,
  confessLedger,
  burnAncestralAshes,
  tendAncestralAshes,
  stealWidowCandle,
  lightWidowCandle,
  drinkOblivion,
  refuseOblivion,
  takeWardenFavor,
  endureWardenTrial,
}

/// 사건 선택지가 런 전역 자원에 만드는 변화. 음수 hp는 사망을 허용하지 않고,
/// [RunTuning]을 해석하는 엔진이 비용을 낼 수 있을 때만 선택지로 낸다.
class RunEventDelta {
  const RunEventDelta({this.hp = 0, this.karma = 0, this.money = 0});

  final int hp;
  final int karma;
  final int money;
}
