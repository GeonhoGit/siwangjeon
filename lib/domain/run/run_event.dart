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
    this.gainedCardId,
    this.availableKarmaBands,
  }) : assert(
         gainedCardId == null || gainedCardId != '',
         '사건으로 얻는 카드 id는 비어 있을 수 없다',
       );

  final String id;
  final String label;
  final RunEventEffect effect;

  /// 사건에서 얻는 카드의 콘텐츠 id. 행동 로그에는 카드 목록을 복사하지 않고
  /// [id]만 남긴 뒤, 재생 중 노드와 선택지에서 카드 인스턴스 id를 다시 만든다.
  final String? gainedCardId;

  /// 이 선택지를 제시할 업 구간. `null`은 어느 구간에서도 제시한다는 뜻이며,
  /// 실제 구간 판정과 합법 액션 생성은 `legalRunActions()` 한 곳이 맡는다.
  final Set<KarmaBand>? availableKarmaBands;

  bool isAvailableIn(KarmaBand band) =>
      availableKarmaBands == null || availableKarmaBands!.contains(band);
}

/// §3.3의 업 구간을 숫자 대신 의미로 콘텐츠에 전달한다.
///
/// 0~19/20~49/50~79/80~100의 경계값은 조정 가능한 수치이므로 `RunTuning`에
/// 남기고, 사건 데이터는 어느 상태에서 어떤 질문을 던질지만 고른다.
enum KarmaBand { clean, ordinary, turbid, evil }

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
  turnAwaySmuggler,
  falsifyLedger,
  confessLedger,
  sealLedger,
  burnAncestralAshes,
  tendAncestralAshes,
  stealWidowCandle,
  lightWidowCandle,
  drinkOblivion,
  refuseOblivion,
  sellOblivion,
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
