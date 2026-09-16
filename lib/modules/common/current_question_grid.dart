import 'package:flutter/material.dart';

/// 打开答题卡后，将当前题所在行自动定位到可视区域中部。
class CurrentQuestionGrid extends StatefulWidget {
  const CurrentQuestionGrid({
    super.key,
    required this.controller,
    required this.currentIndex,
    required this.itemCount,
    required this.itemBuilder,
  });

  final ScrollController controller;
  final int currentIndex;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<CurrentQuestionGrid> createState() => _CurrentQuestionGridState();
}

class _CurrentQuestionGridState extends State<CurrentQuestionGrid> {
  static const _crossAxisCount = 6;
  static const _spacing = 10.0;
  static const _aspectRatio = 1.2;
  static const _padding = 20.0;

  String? _lastScheduledTarget;

  void _scheduleCurrentQuestionPosition(double width) {
    if (widget.itemCount == 0 || width <= 0) return;
    final safeIndex = widget.currentIndex.clamp(0, widget.itemCount - 1);
    final targetKey = '$safeIndex/$width/${widget.itemCount}';
    if (_lastScheduledTarget == targetKey) return;
    _lastScheduledTarget = targetKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.controller.hasClients) return;
      final position = widget.controller.position;
      final usableWidth =
          width - _padding * 2 - _spacing * (_crossAxisCount - 1);
      final tileWidth = usableWidth / _crossAxisCount;
      final tileHeight = tileWidth / _aspectRatio;
      final row = safeIndex ~/ _crossAxisCount;
      final rowOffset = _padding + row * (tileHeight + _spacing);
      final centeredOffset =
          rowOffset - (position.viewportDimension - tileHeight) / 2;
      widget.controller.jumpTo(
        centeredOffset.clamp(0.0, position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleCurrentQuestionPosition(constraints.maxWidth);
        return GridView.builder(
          controller: widget.controller,
          padding: const EdgeInsets.all(_padding),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _crossAxisCount,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            childAspectRatio: _aspectRatio,
          ),
          itemCount: widget.itemCount,
          itemBuilder: widget.itemBuilder,
        );
      },
    );
  }
}
