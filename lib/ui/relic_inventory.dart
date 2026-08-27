/// 지도와 전투가 공통으로 쓰는 보유 유물 진입점.
///
/// 1막은 보스를 제외한 14개 깊이가 모두 정예가 될 수 있으므로, 보유 목록을
/// 화면에 펼쳐 놓지 않는다. 고정 48dp 버튼은 어느 개수에서도 자리를 차지하지
/// 않고, 세부 목록은 스크롤 가능한 시트에 둔다.
library;

import 'package:flutter/material.dart';

import '../domain/combat/relic_preview.dart';
import '../domain/model/relic.dart';

class RelicInventoryButton extends StatelessWidget {
  const RelicInventoryButton({super.key, required this.relics});

  final List<RelicDef> relics;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '보유 유물 ${relics.length}개 보기',
      onPressed: () => _showRelicInventory(context, relics),
      icon: _RelicCountIcon(count: relics.length),
    );
  }
}

class _RelicCountIcon extends StatelessWidget {
  const _RelicCountIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Align(
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFC9A227),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _showRelicInventory(BuildContext context, List<RelicDef> relics) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.75,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '보유 유물 ${relics.length}개',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: relics.isEmpty
                      ? const Center(child: Text('보유 유물이 없습니다'))
                      : ListView.separated(
                          key: const ValueKey('relic-inventory-list'),
                          itemCount: relics.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) => DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF332B31),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: RelicSummary(
                                key: ValueKey(
                                  'owned-relic-$index-${relics[index].id}',
                                ),
                                relic: relics[index],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

class RelicSummary extends StatelessWidget {
  const RelicSummary({super.key, required this.relic});

  final RelicDef relic;

  @override
  Widget build(BuildContext context) {
    final preview = previewRelic(relic);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(relic.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('발동: ${preview.triggerLabel}'),
        const SizedBox(height: 4),
        Text(preview.effectLabel),
      ],
    );
  }
}
