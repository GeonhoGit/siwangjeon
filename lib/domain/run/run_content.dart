/// 런 재생에 필요한 버전 고정 콘텐츠 (§7.3, §7.4).
///
/// 저장 파일에는 콘텐츠 사본을 넣지 않는다. 저장 대상은 계속
/// `{seed, characterId, actionLog}`뿐이고, 이 값은 해당 버전의 콘텐츠 로더가
/// 재생할 때 주입한다. 그래서 `domain/`은 `data/`를 알지 않으면서도 전투
/// 결과를 런 진행 상태로 복원할 수 있다.
library;

import '../model/card.dart';
import '../model/boss.dart';
import '../model/enemy.dart';
import '../model/relic.dart';
import 'run_event.dart';

class RunContent {
  RunContent({
    required this.maxHp,
    required List<CardDef> deck,
    required List<Enemy> encounterPool,
    List<BossDef> bossPool = const [],
    this.startingKarma = 0,
    this.startingMoney = 0,
    required List<CardDef> cardRewardPool,
    List<CardDef>? shopCardPool,
    List<RunEventDef> events = const [],
    List<RelicDef> relicRewardPool = const [],
  }) : deck = List.unmodifiable(deck),
       encounterPool = List.unmodifiable(encounterPool),
       bossPool = List.unmodifiable(bossPool),
       cardRewardPool = List.unmodifiable(cardRewardPool),
       shopCardPool = List.unmodifiable(shopCardPool ?? cardRewardPool),
       events = List.unmodifiable(events),
       relicRewardPool = List.unmodifiable(relicRewardPool) {
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
    if (startingMoney < 0) {
      throw ArgumentError.value(
        startingMoney,
        'startingMoney',
        '시작 노잣돈은 음수일 수 없다',
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
    if (this.bossPool.map((boss) => boss.enemy.id).toSet().length !=
        this.bossPool.length) {
      throw ArgumentError.value(bossPool, 'bossPool', '시왕 id는 고유해야 한다');
    }
    if (cardRewardPool.isEmpty) {
      throw ArgumentError.value(
        cardRewardPool,
        'cardRewardPool',
        '카드 보상 풀은 비어 있을 수 없다',
      );
    }
    if (cardRewardPool.map((card) => card.id).toSet().length !=
        cardRewardPool.length) {
      throw ArgumentError.value(
        cardRewardPool,
        'cardRewardPool',
        '카드 보상 풀의 id는 고유해야 한다',
      );
    }
    if (this.shopCardPool.isEmpty) {
      throw ArgumentError.value(
        shopCardPool,
        'shopCardPool',
        '상점 카드 풀은 비어 있을 수 없다',
      );
    }
    if (this.shopCardPool.map((card) => card.id).toSet().length !=
        this.shopCardPool.length) {
      throw ArgumentError.value(
        shopCardPool,
        'shopCardPool',
        '상점 카드 풀의 id는 고유해야 한다',
      );
    }
    if (this.events.map((event) => event.id).toSet().length !=
        this.events.length) {
      throw ArgumentError.value(events, 'events', '사건 id는 고유해야 한다');
    }
    if (this.relicRewardPool.map((relic) => relic.id).toSet().length !=
        this.relicRewardPool.length) {
      throw ArgumentError.value(
        relicRewardPool,
        'relicRewardPool',
        '유물 보상 풀의 id는 고유해야 한다',
      );
    }
  }

  /// 런 전체에서 이어지는 혼의 최대치와 초기치.
  final int maxHp;

  final int startingKarma;

  /// 상점이 생기기 전에도 런에 이어지는 노잣돈의 초기값.
  final int startingMoney;

  /// 보상이 생기기 전까지는 이 시작 덱이 그대로 런의 덱이다.
  final List<CardDef> deck;

  /// 노드 진입 때 `RngStream.encounter`로 뽑을 M0 적 원형.
  final List<Enemy> encounterPool;

  /// 시왕 심판 전용 콘텐츠. 빈 기본값은 보스에 도달하지 않는 기존 전투 단위
  /// 테스트와의 호환을 위한 것이며, 실제 보스 노드 진입은 엔진이 거부한다.
  final List<BossDef> bossPool;

  /// 전투 승리 뒤 `RngStream.reward`로 뽑을 카드 정의.
  ///
  /// 콘텐츠 id로 선택을 기록하므로 같은 id를 두 번 넣지 않는다. 덱에는 같은
  /// 카드가 여러 장 들어갈 수 있지만, 풀의 중복은 선택 액션을 모호하게 만든다.
  final List<CardDef> cardRewardPool;

  /// 상점 상품을 뽑는 카드 정의. 별도 풀을 주입하지 않으면 M1-3의 카드 보상
  /// 풀을 그대로 쓴다. 상점 전용 카드는 콘텐츠가 늘어날 때만 이 경계에서 분리한다.
  final List<CardDef> shopCardPool;

  /// 노드별 reward 시드로 뽑는 사건 정의. 기존 전투 전용 테스트는 사건 노드를
  /// 만들지 않으므로 빈 기본값을 허용하되, 실제 사건 노드 진입은 엔진이 거부한다.
  final List<RunEventDef> events;

  final List<RelicDef> relicRewardPool;
}
