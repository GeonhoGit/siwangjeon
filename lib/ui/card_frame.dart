/// 카드 프레임의 표시 규칙.
///
/// 전투/보상/상점 화면은 여기서 받은 프레임에 도메인이 계산한 수치와 문구만
/// 배치한다. 이 파일은 카드 효과나 피해·방어를 다시 계산하지 않는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, AssetManifest;

import '../domain/model/card.dart';

/// 손패의 96dp 폭에는 규칙 전문과 그림을 함께 넣을 수 없다.
///
/// 144dp는 손패 폭의 1.5배로, 이보다 좁으면 12sp 규칙문을 두 줄 이상 읽을
/// 공간이 없다. 그래서 이 경계 아래에서는 비용·이름·효과 두 줄만 남기고,
/// 보상/상점/덱 목록처럼 그 이상을 쓸 수 있는 곳에서만 전체 프레임을 쓴다.
const cardFrameCompactMaximumWidth = 144.0;

/// 카드 유형과 희귀도에서 얻는 모든 카드용 색과 문구의 단일 진입점이다.
///
/// 저주와 상태의 실제 콘텐츠가 추가될 때도 이 enum 값을 표시할 수만 있게 두며,
/// UI 전용 유형을 새로 만들지는 않는다. 콘텐츠가 추가되면 이 매핑을 재사용한다.
@immutable
class CardFramePresentation {
  const CardFramePresentation({
    required this.typeLabel,
    required this.typeColor,
    required this.frameColor,
  });

  final String typeLabel;
  final Color typeColor;
  final Color frameColor;
}

CardFramePresentation cardFramePresentation(CardDef card) {
  final type = switch (card.type) {
    CardType.attack => const CardFramePresentation(
      typeLabel: '공격',
      typeColor: Color(0xFFB2332B),
      frameColor: Color(0xFFB2332B),
    ),
    CardType.skill => const CardFramePresentation(
      typeLabel: '기술',
      typeColor: Color(0xFF2E6B8A),
      frameColor: Color(0xFF2E6B8A),
    ),
    CardType.power => const CardFramePresentation(
      typeLabel: '힘(지속)',
      typeColor: Color(0xFF3F7A46),
      frameColor: Color(0xFF3F7A46),
    ),
    CardType.curse => const CardFramePresentation(
      typeLabel: '저주',
      typeColor: Color(0xFF6B3A82),
      frameColor: Color(0xFF6B3A82),
    ),
    CardType.status => const CardFramePresentation(
      typeLabel: '상태',
      typeColor: Color(0xFF626A73),
      frameColor: Color(0xFF626A73),
    ),
  };

  return card.rarity == CardRarity.siwang
      ? CardFramePresentation(
          typeLabel: type.typeLabel,
          typeColor: _CardFrameColors.siwangGold,
          frameColor: _CardFrameColors.siwangGold,
        )
      : type;
}

/// [CardFrame]의 아트 asset을 찾는 유일한 진입점이다.
typedef CardArtResolver =
    Future<String?> Function(AssetBundle assetBundle, String cardId);

const _cardArtDirectory = 'assets/card_art';
const _cardArtExtensions = ['webp', 'png', 'jpg', 'jpeg'];
// 이름 띠와 하단 규칙 상자를 제외한 오른쪽 아트 칸의 비율이다. 이 값이면
// 248dp 프레임이 규칙 상자를 포함해 목업의 약 3:4.4 비율이 된다.
const cardArtAspectRatio = 0.75;

/// 카드 id에 맞는 포함된 아트 asset을 찾는다.
///
/// `assets/card_art/<card id>.(webp|png|jpg|jpeg)`라는 파일명 계약만 지키면
/// pubspec의 디렉터리 선언 아래 파일을 자동으로 찾는다. 따라서 LoRA 결과물을
/// 추가해도 카드 모델이나 이 목록을 고칠 필요가 없다.
Future<String?> cardArtAssetFor(AssetBundle assetBundle, String cardId) async {
  final manifest = await AssetManifest.loadFromAssetBundle(assetBundle);
  final assets = manifest.listAssets();
  for (final extension in _cardArtExtensions) {
    final asset = '$_cardArtDirectory/$cardId.$extension';
    if (assets.contains(asset)) return asset;
  }
  return null;
}

class CardFrame extends StatelessWidget {
  const CardFrame({
    super.key,
    required this.card,
    required this.effectLabels,
    this.width,
    this.minimumHeight,
    this.selected = false,
    this.dimmed = false,
    this.effectKeyPrefix,
    this.footer,
    this.additionalTypeLabels = const [],
    this.artResolver = cardArtAssetFor,
  });

  final CardDef card;
  final List<String> effectLabels;
  final double? width;
  final double? minimumHeight;
  final bool selected;
  final bool dimmed;
  final String? effectKeyPrefix;
  final Widget? footer;
  final CardArtResolver artResolver;

  /// 카드가 두 분류를 가진 콘텐츠가 생기면 그 문구만 추가로 표시한다.
  /// 현재 모델에는 두 번째 분류 필드가 없으므로 비어 있는 것이 맞다.
  final List<String> additionalTypeLabels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth <= cardFrameCompactMaximumWidth;
          if (compact) {
            return _CardFrameSurface(
              card: card,
              minimumHeight: minimumHeight,
              selected: selected,
              dimmed: dimmed,
              compact: true,
              child: _CompactCardContents(
                card: card,
                effectLabels: effectLabels,
                effectKeyPrefix: effectKeyPrefix,
              ),
            );
          }

          return FutureBuilder<String?>(
            future: artResolver(DefaultAssetBundle.of(context), card.id),
            builder: (context, snapshot) => _CardFrameSurface(
              card: card,
              minimumHeight: minimumHeight,
              selected: selected,
              dimmed: dimmed,
              compact: false,
              child: _FullCardContents(
                card: card,
                effectLabels: effectLabels,
                effectKeyPrefix: effectKeyPrefix,
                footer: footer,
                additionalTypeLabels: additionalTypeLabels,
                artAsset: snapshot.data,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CardFrameSurface extends StatelessWidget {
  const _CardFrameSurface({
    required this.card,
    required this.minimumHeight,
    required this.selected,
    required this.dimmed,
    required this.compact,
    required this.child,
  });

  final CardDef card;
  final double? minimumHeight;
  final bool selected;
  final bool dimmed;
  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Colors.white : _CardFrameColors.gold;
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        key: ValueKey('card-frame-${card.id}'),
        constraints: BoxConstraints(minHeight: minimumHeight ?? 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_CardFrameColors.paperLight, _CardFrameColors.paperDark],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 2.5 : 1.25),
          boxShadow: const [
            BoxShadow(
              color: _CardFrameColors.shadow,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CustomPaint(
            key: ValueKey('card-frame-ornament-${card.id}'),
            foregroundPainter: const _CardFrameOrnamentPainter(),
            child: Padding(
              // 손패는 기존의 읽기 쉬운 가로 이름 레이아웃을 유지한다. 전체
              // 프레임만 아트가 가장자리까지 닿도록 안쪽 패딩을 없앤다.
              padding: compact ? const EdgeInsets.all(7) : EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactCardContents extends StatelessWidget {
  const _CompactCardContents({
    required this.card,
    required this.effectLabels,
    required this.effectKeyPrefix,
  });

  final CardDef card;
  final List<String> effectLabels;
  final String? effectKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final presentation = cardFramePresentation(card);
    final textScaler = MediaQuery.textScalerOf(context);
    final costDiameter = textScaler.scale(20);
    final effectLines = _compactEffectLines(effectLabels);

    return Column(
      key: ValueKey('card-frame-compact-${card.id}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CostBadge(
          card: card,
          color: presentation.typeColor,
          diameter: costDiameter,
        ),
        const SizedBox(height: 5),
        Text(
          key: ValueKey('card-name-${card.id}'),
          card.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < effectLines.length; index++)
          Text(
            key: ValueKey(_effectKey(effectKeyPrefix, index)),
            effectLines[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: presentation.typeColor,
            ),
          ),
      ],
    );
  }
}

// 248dp 전체 카드에서 약 3%인 8dp만 남긴다. 카드 유형을 훑어볼 색 신호는
// 유지하면서, 세로 이름을 담던 빈 36dp 띠의 28dp를 이름·아트·규칙 상자에
// 돌려준다. 96dp 손패는 이 띠를 쓰지 않는 별도 컴팩트 레이아웃이라 그대로 둔다.
const _typeColorStripeWidth = 8.0;
const _artlessIdentityAreaHeight = 46.0;
const _typeMedallionSpace = 22.0;

class _FullCardContents extends StatelessWidget {
  const _FullCardContents({
    required this.card,
    required this.effectLabels,
    required this.effectKeyPrefix,
    required this.footer,
    required this.additionalTypeLabels,
    required this.artAsset,
  });

  final CardDef card;
  final List<String> effectLabels;
  final String? effectKeyPrefix;
  final Widget? footer;
  final List<String> additionalTypeLabels;
  final String? artAsset;

  @override
  Widget build(BuildContext context) {
    final presentation = cardFramePresentation(card);
    return Stack(
      key: ValueKey('card-frame-full-${card.id}'),
      children: [
        // 유형색 띠가 차지하는 폭만 제외하고 아트가 프레임 가장자리까지
        // 닿는다. 아트가 없을 때도 같은 구조를 유지하고 이 칸의 높이만 줄인다.
        Padding(
          padding: const EdgeInsets.only(left: _typeColorStripeWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (artAsset case final asset?)
                CardArtSlot(
                  cardId: card.id,
                  color: presentation.typeColor,
                  asset: asset,
                )
              else
                const SizedBox(height: _artlessIdentityAreaHeight),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _RulesBox(
                  card: card,
                  labels: effectLabels,
                  effectKeyPrefix: effectKeyPrefix,
                ),
              ),
              if (footer case final footer?) ...[
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: _CardFrameColors.title,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  child: Center(child: footer),
                ),
              ],
              const SizedBox(height: _typeMedallionSpace),
            ],
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _typeColorStripeWidth,
          child: _TypeColorStripe(card: card, color: presentation.typeColor),
        ),
        Positioned(
          top: 4,
          left: _typeColorStripeWidth + 4,
          child: _CostBadge(
            card: card,
            color: presentation.typeColor,
            diameter: 36,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: _TypeCornerRibbon(
            card: card,
            label: presentation.typeLabel,
            additionalLabels: additionalTypeLabels,
            color: presentation.typeColor,
          ),
        ),
        Positioned(
          top: 7,
          left: _typeColorStripeWidth + 44,
          right: 44,
          height: 30,
          child: _HorizontalCardName(card: card),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 3,
          child: Center(child: _TypeMedallion(color: presentation.frameColor)),
        ),
      ],
    );
  }
}

class _TypeColorStripe extends StatelessWidget {
  const _TypeColorStripe({required this.card, required this.color});

  final CardDef card;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: ValueKey('card-type-stripe-${card.id}'),
      color: color,
    );
  }
}

class _HorizontalCardName extends StatelessWidget {
  const _HorizontalCardName({required this.card});

  final CardDef card;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: card.name,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _CardFrameColors.paperLight.withValues(alpha: 0.94),
          border: const Border(
            bottom: BorderSide(color: _CardFrameColors.gold, width: 0.8),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                key: ValueKey('card-name-${card.id}'),
                card.name,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  color: _CardFrameColors.title,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CostBadge extends StatelessWidget {
  const _CostBadge({
    required this.card,
    required this.color,
    required this.diameter,
  });

  final CardDef card;
  final Color color;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('card-cost-${card.id}'),
      width: diameter,
      height: diameter * 1.12,
      child: CustomPaint(
        key: ValueKey('card-cost-shield-${card.id}'),
        painter: _ShieldBadgePainter(color),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${card.cost}',
              style: TextStyle(
                fontSize: diameter >= 30 ? 19 : 12,
                fontWeight: FontWeight.w900,
                color: _CardFrameColors.costText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeCornerRibbon extends StatelessWidget {
  const _TypeCornerRibbon({
    required this.card,
    required this.label,
    required this.additionalLabels,
    required this.color,
  });

  final CardDef card;
  final String label;
  final List<String> additionalLabels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('card-type-ribbon-${card.id}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _TypeCornerLabel(label: label, color: color, attached: true),
        for (final additionalLabel in additionalLabels)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _TypeCornerLabel(label: additionalLabel, color: color),
          ),
      ],
    );
  }
}

class _TypeCornerLabel extends StatelessWidget {
  const _TypeCornerLabel({
    required this.label,
    required this.color,
    this.attached = false,
  });

  final String label;
  final Color color;
  final bool attached;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.94),
        borderRadius: attached
            ? const BorderRadius.only(bottomLeft: Radius.circular(7))
            : BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _CardFrameColors.title,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TypeMedallion extends StatelessWidget {
  const _TypeMedallion({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('card-type-medallion'),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: _CardFrameColors.paperDark,
        shape: BoxShape.circle,
        border: Border.all(color: _CardFrameColors.gold, width: 1.25),
      ),
      child: Center(
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class CardArtSlot extends StatelessWidget {
  const CardArtSlot({
    super.key,
    required this.cardId,
    required this.color,
    required this.asset,
  });

  final String cardId;
  final Color color;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      key: ValueKey('card-art-$cardId'),
      // 아트가 있는 카드만 목업 비율의 세로 공간을 사용한다. asset이 없으면
      // 작은 식별 영역으로 줄어 세 후보를 한 화면에서 비교할 수 있다.
      aspectRatio: cardArtAspectRatio,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => DecoratedBox(
          decoration: BoxDecoration(
            color: _CardFrameColors.artShadow,
            border: Border.all(color: color.withValues(alpha: 0.72)),
          ),
        ),
      ),
    );
  }
}

class _RulesBox extends StatelessWidget {
  const _RulesBox({
    required this.card,
    required this.labels,
    required this.effectKeyPrefix,
  });

  final CardDef card;
  final List<String> labels;
  final String? effectKeyPrefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('card-rules-${card.id}'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _CardFrameColors.rulePaper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _CardFrameColors.ruleBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < labels.length; index++)
            Text(
              key: ValueKey(_effectKey(effectKeyPrefix, index)),
              labels[index],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _CardFrameColors.ruleText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _CardFrameOrnamentPainter extends CustomPainter {
  const _CardFrameOrnamentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _CardFrameColors.gold.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final inset = 3.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inset,
          inset,
          size.width - inset * 2,
          size.height - inset * 2,
        ),
        const Radius.circular(6),
      ),
      paint,
    );
    _paintCorner(canvas, const Offset(7, 7), 1, 1, paint);
    _paintCorner(canvas, Offset(size.width - 7, 7), -1, 1, paint);
    _paintCorner(canvas, Offset(7, size.height - 7), 1, -1, paint);
    _paintCorner(
      canvas,
      Offset(size.width - 7, size.height - 7),
      -1,
      -1,
      paint,
    );
  }

  void _paintCorner(
    Canvas canvas,
    Offset origin,
    double horizontal,
    double vertical,
    Paint paint,
  ) {
    canvas.drawCircle(origin, 1.2, paint);
    canvas.drawLine(origin, origin.translate(horizontal * 10, 0), paint);
    canvas.drawLine(origin, origin.translate(0, vertical * 10), paint);
  }

  @override
  bool shouldRepaint(_CardFrameOrnamentPainter oldDelegate) => false;
}

class _ShieldBadgePainter extends CustomPainter {
  const _ShieldBadgePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.18, 0)
      ..quadraticBezierTo(0, 0, 0, size.height * 0.18)
      ..lineTo(0, size.height * 0.73)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, size.height * 0.73)
      ..lineTo(size.width, size.height * 0.18)
      ..quadraticBezierTo(size.width, 0, size.width * 0.82, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = _CardFrameColors.costBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
    );
  }

  @override
  bool shouldRepaint(_ShieldBadgePainter oldDelegate) =>
      oldDelegate.color != color;
}

List<String> _compactEffectLines(List<String> labels) {
  return [
    labels.take(2).join(' · '),
    if (labels.length > 2) labels.skip(2).join(' · '),
  ].where((line) => line.isNotEmpty).toList();
}

String _effectKey(String? prefix, int index) =>
    prefix == null ? 'card-effect-line-$index' : '$prefix-$index';

abstract final class _CardFrameColors {
  static const paperLight = Color(0xFF5A4B44);
  static const paperDark = Color(0xFF241C20);
  static const shadow = Color(0x80000000);
  static const gold = Color(0xFFD6A84A);
  static const siwangGold = gold;
  static const title = Color(0xFFFFF3D2);
  static const costBorder = Color(0xFFF9E7A7);
  static const costText = Color(0xFF1D1713);
  static const artShadow = Color(0xFF211C2A);
  static const rulePaper = Color(0xFFF3E3BA);
  static const ruleBorder = Color(0xFFB89A61);
  static const ruleText = Color(0xFF35271E);
}
