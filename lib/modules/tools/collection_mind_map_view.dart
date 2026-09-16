import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:screenshot/screenshot.dart';

import '../../data/models/question_model.dart';
import 'collection_mind_map_controller.dart';

class CollectionMindMapView extends StatefulWidget {
  const CollectionMindMapView({
    super.key,
    required this.keyword,
    required this.questions,
  });

  final String keyword;
  final List<Question> questions;

  @override
  State<CollectionMindMapView> createState() => _CollectionMindMapViewState();
}

class _CollectionMindMapViewState extends State<CollectionMindMapView> {
  late final CollectionMindMapController _controller;
  final TransformationController _canvasController = TransformationController();
  final ScreenshotController _screenshotController = ScreenshotController();
  Size? _lastViewportSize;
  bool _hasPositionedCanvas = false;
  bool _isSaving = false;

  static const _workspaceSize = Size(3600, 3600);

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      CollectionMindMapController(
        keyword: widget.keyword,
        questions: widget.questions,
      ),
      tag: 'mind-map-${widget.keyword}',
    );
  }

  @override
  void dispose() {
    _canvasController.dispose();
    Get.delete<CollectionMindMapController>(tag: 'mind-map-${widget.keyword}');
    super.dispose();
  }

  void _resetCanvas() {
    final viewport = _lastViewportSize;
    if (viewport == null) return;
    _canvasController.value = _centeredTransform(viewport);
  }

  Matrix4 _centeredTransform(Size viewport) {
    return Matrix4.translationValues(
      (viewport.width - _workspaceSize.width) / 2,
      (viewport.height - _workspaceSize.height) / 2,
      0,
    );
  }

  void _positionCanvasForViewport(Size viewport) {
    if (_hasPositionedCanvas && _lastViewportSize == viewport) return;
    _lastViewportSize = viewport;
    _hasPositionedCanvas = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _canvasController.value = _centeredTransform(viewport);
    });
  }

  Future<void> _saveMindMap() async {
    if (_isSaving || _controller.mindMap.value == null) return;
    setState(() => _isSaving = true);
    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 2,
        delay: const Duration(milliseconds: 80),
      );
      if (imageBytes == null) {
        throw StateError('截图生成失败');
      }
      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        quality: 100,
        name: 'collection_mind_map_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (result == null || result['isSuccess'] != true) {
        throw StateError('相册写入失败');
      }
      Get.snackbar(
        '保存成功',
        '完整思维导图已保存到本地相册',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (_) {
      Get.snackbar(
        '保存失败',
        '无法保存思维导图，请检查相册权限后重试',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 题目思维导图'),
        actions: [
          Obx(
            () => IconButton(
              onPressed:
                  _controller.mindMap.value == null ||
                      _controller.isGenerating.value ||
                      _isSaving
                  ? null
                  : _saveMindMap,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              tooltip: '保存完整导图到相册',
            ),
          ),
          IconButton(
            onPressed: _resetCanvas,
            icon: const Icon(Icons.center_focus_strong_rounded),
            tooltip: '复位画布',
          ),
          IconButton(
            onPressed: _controller.generate,
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: '重新生成',
          ),
        ],
      ),
      body: Obx(() {
        if (_controller.isGenerating.value) {
          return _GeneratingView(
            title: widget.keyword,
            questionCount: widget.questions.length,
          );
        }
        final map = _controller.mindMap.value;
        if (map == null) {
          return _ErrorView(
            message: _controller.errorMessage.value,
            onRetry: _controller.generate,
          );
        }
        return Column(
          children: [
            _MapHint(
              title: widget.keyword,
              questionCount: widget.questions.length,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewport = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  _positionCanvasForViewport(viewport);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: InteractiveViewer(
                      transformationController: _canvasController,
                      // The diagram lives in a large workspace rather than a
                      // centered, viewport-sized child. `constrained: false`
                      // lets the viewer retain that world size, so one-finger
                      // drag can pan in every direction instead of stopping
                      // at the old 360px boundary.
                      constrained: false,
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 0.22,
                      maxScale: 4.0,
                      boundaryMargin: EdgeInsets.zero,
                      child: SizedBox(
                        width: _workspaceSize.width,
                        height: _workspaceSize.height,
                        child: Center(
                          child: Screenshot(
                            controller: _screenshotController,
                            child: ColoredBox(
                              color: Theme.of(context).colorScheme.surface,
                              child: Padding(
                                padding: const EdgeInsets.all(48),
                                child: _MindMapCanvas(map: map),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView({required this.title, required this.questionCount});

  final String title;
  final int questionCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 54,
              width: 54,
              child: CircularProgressIndicator(
                color: scheme.primary,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 22),
            Text('AI 正在梳理知识脉络', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '正在分析“$title”中的 $questionCount 道题目',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 58,
              color: Colors.teal.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              message.isEmpty ? '暂时无法生成导图' : message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新生成'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapHint extends StatelessWidget {
  const _MapHint({required this.title, required this.questionCount});

  final String title;
  final int questionCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title · $questionCount 道题目',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('双指缩放', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _MindMapCanvas extends StatelessWidget {
  const _MindMapCanvas({required this.map});

  final CollectionMindMap map;
  static const _canvasWidth = 1160.0;
  static const _rootRect = Rect.fromLTWH(46, 310, 250, 100);
  static const _branchX = 480.0;
  static const _branchWidth = 250.0;
  static const _leafX = 830.0;
  static const _leafWidth = 280.0;
  static const _itemHeight = 72.0;
  static const _gap = 28.0;

  @override
  Widget build(BuildContext context) {
    final layout = _layout();
    return SizedBox(
      width: _canvasWidth,
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MindMapConnectionPainter(
                root: _rootRect.shift(
                  Offset(0, layout.rootTop - _rootRect.top),
                ),
                branches: layout.branches,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Positioned(
            left: _rootRect.left,
            top: layout.rootTop,
            width: _rootRect.width,
            height: _rootRect.height,
            child: _NodeCard(title: map.title, primary: true),
          ),
          for (final branch in layout.branches) ...[
            Positioned(
              left: _branchX,
              top: branch.branchTop,
              width: _branchWidth,
              height: _itemHeight,
              child: _NodeCard(title: branch.branch.title),
            ),
            for (var index = 0; index < branch.leafTops.length; index++)
              Positioned(
                left: _leafX,
                top: branch.leafTops[index],
                width: _leafWidth,
                height: _itemHeight,
                child: _NodeCard(
                  title: branch.branch.children[index],
                  subtle: true,
                ),
              ),
          ],
        ],
      ),
    );
  }

  _MapLayout _layout() {
    var cursor = 70.0;
    final branches = <_BranchLayout>[];
    for (final branch in map.branches) {
      final leafCount = math.max(1, branch.children.length);
      final blockHeight = math.max(
        _itemHeight,
        leafCount * _itemHeight + (leafCount - 1) * _gap,
      );
      final branchTop = cursor + (blockHeight - _itemHeight) / 2;
      final leafTops = List.generate(
        branch.children.length,
        (index) => cursor + index * (_itemHeight + _gap),
      );
      branches.add(
        _BranchLayout(branch: branch, branchTop: branchTop, leafTops: leafTops),
      );
      cursor += blockHeight + 52;
    }
    final height = math.max(720.0, cursor + 70);
    return _MapLayout(
      height: height,
      rootTop: height / 2 - _rootRect.height / 2,
      branches: branches,
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.title,
    this.primary = false,
    this.subtle = false,
  });

  final String title;
  final bool primary;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final color = primary
        ? Theme.of(context).colorScheme.primary
        : subtle
        ? const Color(0xFF17181A)
        : const Color(0xFF23252B);
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(primary ? 16 : 13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        title,
        maxLines: primary ? 2 : 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: primary ? 22 : 15,
          height: 1.2,
          fontWeight: primary || !subtle ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _MindMapConnectionPainter extends CustomPainter {
  const _MindMapConnectionPainter({
    required this.root,
    required this.branches,
    required this.color,
  });

  final Rect root;
  final List<_BranchLayout> branches;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final rootStart = Offset(root.right, root.center.dy);
    for (final branch in branches) {
      final branchEnd = Offset(
        _MindMapCanvas._branchX,
        branch.branchTop + _MindMapCanvas._itemHeight / 2,
      );
      _drawCurve(canvas, paint, rootStart, branchEnd);
      for (final leafTop in branch.leafTops) {
        final leafEnd = Offset(
          _MindMapCanvas._leafX,
          leafTop + _MindMapCanvas._itemHeight / 2,
        );
        _drawCurve(
          canvas,
          paint,
          Offset(
            _MindMapCanvas._branchX + _MindMapCanvas._branchWidth,
            branchEnd.dy,
          ),
          leafEnd,
        );
      }
    }
  }

  void _drawCurve(Canvas canvas, Paint paint, Offset start, Offset end) {
    final midpoint = start.dx + (end.dx - start.dx) * 0.52;
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(midpoint, start.dy, midpoint, end.dy, end.dx, end.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MindMapConnectionPainter oldDelegate) =>
      oldDelegate.root != root ||
      oldDelegate.branches != branches ||
      oldDelegate.color != color;
}

class _MapLayout {
  const _MapLayout({
    required this.height,
    required this.rootTop,
    required this.branches,
  });

  final double height;
  final double rootTop;
  final List<_BranchLayout> branches;
}

class _BranchLayout {
  const _BranchLayout({
    required this.branch,
    required this.branchTop,
    required this.leafTops,
  });

  final MindMapBranch branch;
  final double branchTop;
  final List<double> leafTops;
}
