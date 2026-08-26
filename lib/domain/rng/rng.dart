/// 결정론적 난수 (기획서 §7.4).
///
/// `dart:math`의 [Random]을 쓰지 않는 이유는 그것이 **가변**이기 때문이다.
/// 전투 상태가 불변인데 그 안에 가변 난수원이 있으면, 같은 상태에 같은 액션을
/// 두 번 적용했을 때 결과가 달라진다. 그러면 §7.4의 "시드 + 액션 로그 재생"이
/// 성립하지 않는다.
///
/// 그래서 여기서는 상태 전이를 값으로 드러낸다.
/// `(뽑은 값, 다음 난수기)`를 함께 반환하고, 호출자가 다음 난수기를 들고 간다.
///
/// 알고리즘은 xorshift32다. 암호학적 품질은 필요 없고, 필요한 것은
/// **모든 기기에서 같은 시드가 같은 수열을 낸다**는 보장뿐이다.
/// 32비트로 마스킹해 두면 64비트 정수를 쓰는 네이티브와
/// 배정밀도 실수를 쓰는 웹에서 결과가 갈라지지 않는다.
library;

/// 난수 스트림 구분 (§7.4).
///
/// 하나의 스트림을 공유하면 보상 롤 한 번이 어긋났을 때 이후 전투까지 전부
/// 밀린다. 용도별로 분리해 두면 그런 연쇄가 생기지 않는다.
enum RngStream {
  /// 카드·유물 보상 롤.
  reward,

  /// 노드 맵 생성과 적 배치.
  encounter,

  /// 전투 내부 (드로우, 적 행동 선택).
  combat,
}

/// 불변 난수기. 값 하나를 뽑을 때마다 새 인스턴스가 나온다.
class Rng {
  const Rng._(this.state);

  /// 런 시드에서 스트림별 난수기를 파생시킨다.
  factory Rng.forStream(int seed, RngStream stream) {
    var s = (seed ^ (_goldenRatio * (stream.index + 1))) & _mask;
    // xorshift는 상태 0에서 영원히 0을 뱉는다. 시드가 하필 그 값이면 비켜간다.
    if (s == 0) s = 0x1D2B3C4D;

    // 초기 몇 개는 시드 비트 패턴이 그대로 비친다. 버리고 시작한다.
    var rng = Rng._(s);
    for (var i = 0; i < 8; i++) {
      rng = rng._advance().$2;
    }
    return rng;
  }

  /// 내부 상태. 저장 파일에 그대로 넣을 수 있도록 공개해 둔다.
  final int state;

  static const int _mask = 0xFFFFFFFF;
  static const int _goldenRatio = 0x9E3779B9;

  /// 2^32. `nextInt`의 거부 표집에서 수열의 주기 크기로 쓴다.
  static const int _range = 0x100000000;

  (int, Rng) _advance() {
    var x = state;
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    return (x, Rng._(x));
  }

  /// `[0, bound)` 범위의 정수를 균등하게 뽑는다.
  ///
  /// 단순히 `raw % bound`를 쓰면 2^32가 bound로 나누어떨어지지 않을 때
  /// 작은 값이 미세하게 더 자주 나온다. 카드 드로우처럼 수만 번 반복되는
  /// 곳에서는 그 편향이 밸런스 데이터에 그대로 실린다 (§8.2).
  (int, Rng) nextInt(int bound) {
    assert(bound > 0, 'bound는 양수여야 한다');

    final limit = _range - (_range % bound);
    var rng = this;
    while (true) {
      final (raw, next) = rng._advance();
      rng = next;
      if (raw < limit) return (raw % bound, rng);
    }
  }

  /// Fisher-Yates. 원본을 건드리지 않고 새 리스트를 만든다.
  (List<T>, Rng) shuffled<T>(List<T> items) {
    final result = List<T>.of(items);
    var rng = this;

    for (var i = result.length - 1; i > 0; i--) {
      final (j, next) = rng.nextInt(i + 1);
      rng = next;
      final tmp = result[i];
      result[i] = result[j];
      result[j] = tmp;
    }

    return (result, rng);
  }

  @override
  bool operator ==(Object other) => other is Rng && other.state == state;

  @override
  int get hashCode => state.hashCode;

  @override
  String toString() => 'Rng(0x${state.toRadixString(16)})';
}
