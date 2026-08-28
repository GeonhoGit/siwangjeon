/// 카드 프레임의 표시 규칙.
///
/// 전투/보상/상점 화면은 여기서 받은 프레임에 엔진이 계산한 수치와 문구만
/// 넘긴다. 이 파일은 카드 효과나 피해·방어를 다시 계산하지 않는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, AssetManifest;

import '../domain/model/card.dart';

/// 손패의 96dp 폭에서는 규칙 전문과 그림을 함께 넣을 수 없다.
///
/// 144dp는 손패 폭의 1.5배로, 이보다 좁으면 12sp 규칙문을 두 줄 이상 읽을
/// 공간이 없다. 그래서 이 경계 아래에서는 비용·이름·효과 두 줄만 남기고,
/// 보상/상점/덱 목록처럼 그 이상을 쓸 수 있는 곳에서만 전체 프레임을 쓴다.
const cardFrameCompactMaximumWidth = 144.0;

/// 카드 유형과 희귀도에서 얻는 모든 카드용 색과 문구의 단일 진입점이다.
///
/// 저주·상태의 실제 콘텐츠는 아직 없지만 [CardType]에는 이미 두 값이 있다.
/// 여기서는 그 enum 값을 표시할 수만 있게 두며, UI 전용 유형을 새로 만들지는
/// 않는다. 콘텐츠가 추가될 때 이 매핑을 재사용한다.
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
      typeLabel: '지속',
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
          typeColor: type.typeColor,
          frameColor: _CardFrameColors.siwangGold,
        )
      : type;
}

/// [CardFrame]이 아트 asset을 찾는 유일한 진입점이다.
typedef CardArtResolver =
    Future<String?> Function(AssetBundle assetBundle, String cardId);

const _cardArtDirectory = 'assets/card_art';
const _cardArtExtensions = ['webp', 'png', 'jpg', 'jpeg'];
const cardArtAspectRatio = 2.15;

/// 카드 id에 맞는 포함된 아트 asset을 찾는다.
///
/// `assets/card_art/<card id>.(webp|png|jpg|jpeg)`라는 파일명 계약만 지키면
/// pubspec의 디렉터리 선언이 새 파일을 함께 묶는다. 따라서 LoRA 결과물을
/// 추가할 때 카드 모델이나 이 목록을 고칠 필요가 없다.
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

  /// 한 카드가 두 분류를 가질 콘텐츠가 생기면 그 문구만 추가한다.
  /// 현재 도메인 모델에는 두 번째 분류 필드가 없으므로 비어 있는 것이 맞다.
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
              presentation: cardFramePresentation(card),
              minimumHeight: minimumHeight,
              selected: selected,
              dimmed: dimmed,
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
              presentation: cardFramePresentation(card),
              minimumHeight: minimumHeight,
              selected: selected,
              dimmed: dimmed,
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
    required this.presentation,
    required this.minimumHeight,
    required this.selected,
    required this.dimmed,
    required this.child,
  });

  final CardDef card;
  final CardFramePresentation presentation;
  final double? minimumHeight;
  final bool selected;
  final bool dimmed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Colors.white : presentation.frameColor;
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
          border: Border.all(color: borderColor, width: selected ? 2.5 : 1.5),
          boxShadow: const [
            BoxShadow(
              color: _CardFrameColors.shadow,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: borderColor.withValues(alpha: 0.52)),
          ),
          child: Padding(padding: const EdgeInsets.all(7), child: child),
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
    final labels = [presentation.typeLabel, ...additionalTypeLabels];
    // 아트가 없는 카드는 그림이 만들던 시각적 여백도 필요 없다. 4dp는 제목·유형·
    // 규칙 상자를 구분하는 최소 간격이고, 세 곳에서 8dp 대신 쓰면 카드당 12dp를
    // 더 돌려준다. 아트가 있으면 목업의 원래 8dp 간격을 유지한다.
    final sectionGap = artAsset == null ? 4.0 : 8.0;

    return Column(
      key: ValueKey('card-frame-full-${card.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CostBadge(card: card, color: presentation.typeColor, diameter: 34),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                key: ValueKey('card-name-${card.id}'),
                card.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _CardFrameColors.title,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: sectionGap),
        Wrap(
          key: ValueKey('card-type-ribbon-${card.id}'),
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final label in labels)
              _TypeRibbon(label: label, color: presentation.typeColor),
          ],
        ),
        if (artAsset case final asset?) ...[
          const SizedBox(height: 8),
          CardArtSlot(
            cardId: card.id,
            color: presentation.typeColor,
            asset: asset,
          ),
        ],
        SizedBox(height: sectionGap),
        _RulesBox(
          card: card,
          labels: effectLabels,
          effectKeyPrefix: effectKeyPrefix,
        ),
        if (footer case final footer?) ...[
          SizedBox(height: sectionGap),
          DefaultTextStyle.merge(
            style: const TextStyle(
              color: _CardFrameColors.title,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            child: Center(child: footer),
          ),
        ],
      ],
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
    return Container(
      key: ValueKey('card-cost-${card.id}'),
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: _CardFrameColors.costBorder, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '${card.cost}',
        style: TextStyle(
          fontSize: diameter >= 30 ? 19 : 12,
          fontWeight: FontWeight.w900,
          color: _CardFrameColors.costText,
        ),
      ),
    );
  }
}

class _TypeRibbon extends StatelessWidget {
  const _TypeRibbon({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
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
      // 2.15:1은 248dp 전체 프레임에서 약 105dp를 쓰는 목업의 가로 아트
      // 비율이다. asset이 없으면 슬롯을 아예 만들지 않아 그 105dp와 여백을
      // 돌려주므로, 세 후보를 한 화면에서 비교할 수 있다.
      aspectRatio: cardArtAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
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
  static const siwangGold = Color(0xFFD6A84A);
  static const title = Color(0xFFFFF3D2);
  static const costBorder = Color(0xFFF9E7A7);
  static const costText = Color(0xFF1D1713);
  static const artShadow = Color(0xFF211C2A);
  static const rulePaper = Color(0xFFF3E3BA);
  static const ruleBorder = Color(0xFFB89A61);
  static const ruleText = Color(0xFF35271E);
}
