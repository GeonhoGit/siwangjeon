/// 런 재생에 필요한 버전 고정 콘텐츠 (§7.3, §7.4).
///
/// 저장 파일에는 콘텐츠 사본을 넣지 않는다. 저장 대상은 계속
/// `{seed, characterId, actionLog}`뿐이고, 이 값은 해당 버전의 콘텐츠 로더가
/// 재생할 때 주입한다. 그래서 `domain/`은 `data/`를 알지 않으면서도 전투
/// 결과를 런 진행 상태로 복원할 수 있다.
library;

import '../model/card.dart';
import '../model/enemy.dart';

class RunContent {
  RunContent({
    required this.maxHp,
    required List<CardDef> deck,
    required List<Enemy> encounterPool,
    this.startingKarma = 0,
  }) : deck = List.unmodifiable(deck),
       encounterPool = List.unmodifiable(encounterPool) {
    if (maxHp <= 0) {
      throw ArgumentError.value(maxHp, 'maxHp', '시작 체력은 양수여야 한다');
    }
    if (startingKarma < 0) {
      throw ArgumentError.value(
        startingKarma,
        'startingKarma',
        '시작 업은 음수일 수 없다',
      );
    }
    if (deck.isEmpty) {
      throw ArgumentError.value(deck, 'deck', '런 시작 덱은 비어 있을 수 없다');
    }
    if (encounterPool.isEmpty) {
      throw ArgumentError.value(
        encounterPool,
        'encounterPool',
        '적 구성용 M0 적 풀이 비어 있을 수 없다',
      );
    }
  }

  /// 런 전체에서 이어지는 혼의 최대치와 초기치.
  final int maxHp;

  final int startingKarma;

  /// 보상이 생기기 전까지는 이 시작 덱이 그대로 런의 덱이다.
  final List<CardDef> deck;

  /// 노드 진입 때 `RngStream.encounter`로 뽑을 M0 적 원형.
  final List<Enemy> encounterPool;
}
