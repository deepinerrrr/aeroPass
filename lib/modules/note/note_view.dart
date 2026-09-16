import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'note_controller.dart';
import '../../data/models/note_model.dart';

class NoteView extends StatefulWidget {
  final String questionId;

  const NoteView({super.key, required this.questionId});

  @override
  State<NoteView> createState() => _NoteViewState();
}

class _NoteViewState extends State<NoteView>
    with SingleTickerProviderStateMixin {
  late final NoteController _controller;
  late final TabController _tabController;
  late final TextEditingController _textController;
  final List<StrokePoint> _currentStrokePoints = [];

  @override
  void initState() {
    super.initState();
    _controller = Get.put(NoteController());
    _tabController = TabController(length: 3, vsync: this);
    _textController = TextEditingController();
    _loadNote();
  }

  Future<void> _loadNote() async {
    await _controller.loadNote(widget.questionId);
    _textController.text = _controller.textContent.value;
    _controller.textContent.listen((value) {
      if (_textController.text != value) {
        _textController.text = value;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    Get.delete<NoteController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Get.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('笔记'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(
            () => _controller.isSaving.value
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () async {
                      await _controller.saveNote();
                      Get.back();
                      Get.snackbar(
                        '成功',
                        '笔记已保存',
                        backgroundColor: Colors.green,
                        colorText: Colors.white,
                      );
                    },
                  ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '手写'),
            Tab(text: '打字'),
            Tab(text: '混合'),
          ],
          indicatorColor: Get.theme.colorScheme.primary,
          labelColor: Get.theme.colorScheme.primary,
          unselectedLabelColor: Get.theme.textTheme.bodySmall?.color,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildHandwritingTab(), _buildTypingTab(), _buildMixedTab()],
      ),
    );
  }

  Widget _buildTypingTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Get.theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Get.theme.dividerColor),
              ),
              child: TextField(
                controller: _textController,
                onChanged: _controller.updateText,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: '在此输入笔记内容...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Get.theme.hintColor),
                ),
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Get.theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => Text(
              '字数: ${_controller.textContent.value.length}',
              style: TextStyle(
                fontSize: 12,
                color: Get.theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandwritingTab() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Get.theme.dividerColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onPanStart: (details) {
                  _currentStrokePoints.clear();
                  _currentStrokePoints.add(
                    StrokePoint(
                      x: details.localPosition.dx,
                      y: details.localPosition.dy,
                    ),
                  );
                },
                onPanUpdate: (details) {
                  _currentStrokePoints.add(
                    StrokePoint(
                      x: details.localPosition.dx,
                      y: details.localPosition.dy,
                    ),
                  );
                  setState(() {});
                },
                onPanEnd: (details) {
                  _controller.addStroke(List.from(_currentStrokePoints));
                  _currentStrokePoints.clear();
                },
                child: Obx(
                  () => CustomPaint(
                    painter: HandwritingPainter(
                      strokes: _controller.strokes.toList(),
                      currentStrokePoints: _currentStrokePoints,
                      currentColor: _controller.currentColor.value,
                      currentStrokeWidth: _controller.currentStrokeWidth.value,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildHandwritingToolbar(),
      ],
    );
  }

  Widget _buildMixedTab() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Get.theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Get.theme.dividerColor),
                  ),
                  child: TextField(
                    controller: _textController,
                    onChanged: _controller.updateText,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '在此输入文字笔记...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Get.theme.hintColor),
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Get.theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Get.theme.dividerColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onPanStart: (details) {
                          _currentStrokePoints.clear();
                          _currentStrokePoints.add(
                            StrokePoint(
                              x: details.localPosition.dx,
                              y: details.localPosition.dy,
                            ),
                          );
                        },
                        onPanUpdate: (details) {
                          _currentStrokePoints.add(
                            StrokePoint(
                              x: details.localPosition.dx,
                              y: details.localPosition.dy,
                            ),
                          );
                          setState(() {});
                        },
                        onPanEnd: (details) {
                          _controller.addStroke(
                            List.from(_currentStrokePoints),
                          );
                          _currentStrokePoints.clear();
                        },
                        child: Obx(
                          () => CustomPaint(
                            painter: HandwritingPainter(
                              strokes: _controller.strokes.toList(),
                              currentStrokePoints: _currentStrokePoints,
                              currentColor: _controller.currentColor.value,
                              currentStrokeWidth:
                                  _controller.currentStrokeWidth.value,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildHandwritingToolbar(),
      ],
    );
  }

  Widget _buildHandwritingToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._controller.availableColors.map(
                    (color) => _buildColorButton(color),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 24,
                    color: Get.theme.dividerColor,
                  ),
                  const SizedBox(width: 12),
                  ..._controller.availableStrokeWidths.map(
                    (width) => _buildStrokeWidthButton(width),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildToolButton(
            icon: Icons.undo_rounded,
            onTap: _controller.undo,
            tooltip: '撤销',
          ),
          const SizedBox(width: 8),
          _buildToolButton(
            icon: Icons.cleaning_services_rounded,
            onTap: _controller.clearStrokes,
            tooltip: '清空',
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    return Obx(() {
      final isSelected =
          _controller.currentColor.value.toARGB32() == color.toARGB32();
      return GestureDetector(
        onTap: () => _controller.setColor(color),
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Get.theme.colorScheme.primary
                  : Colors.grey.shade300,
              width: isSelected ? 3 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
      );
    });
  }

  Widget _buildStrokeWidthButton(double width) {
    return Obx(() {
      final isSelected = _controller.currentStrokeWidth.value == width;
      return GestureDetector(
        onTap: () => _controller.setStrokeWidth(width),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Get.theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Get.theme.colorScheme.primary
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Container(
              width: width * 2,
              height: width * 2,
              decoration: BoxDecoration(
                color: isSelected ? Get.theme.colorScheme.primary : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildToolButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Get.theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Get.theme.dividerColor),
        ),
        child: Icon(
          icon,
          size: 20,
          color: Get.theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}

class HandwritingPainter extends CustomPainter {
  final List<HandwritingStroke> strokes;
  final List<StrokePoint> currentStrokePoints;
  final Color currentColor;
  final double currentStrokeWidth;

  HandwritingPainter({
    required this.strokes,
    required this.currentStrokePoints,
    required this.currentColor,
    required this.currentStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    if (currentStrokePoints.isNotEmpty) {
      final paint = Paint()
        ..color = currentColor
        ..strokeWidth = currentStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(currentStrokePoints.first.x, currentStrokePoints.first.y);
      for (int i = 1; i < currentStrokePoints.length; i++) {
        path.lineTo(currentStrokePoints[i].x, currentStrokePoints[i].y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawStroke(Canvas canvas, HandwritingStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = _parseColor(stroke.color)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(stroke.points.first.x, stroke.points.first.y);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].x, stroke.points[i].y);
    }
    canvas.drawPath(path, paint);
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        final hex = colorStr.substring(1);
        return Color(int.parse('FF$hex', radix: 16));
      }
      return Colors.black;
    } catch (_) {
      return Colors.black;
    }
  }

  @override
  bool shouldRepaint(covariant HandwritingPainter oldDelegate) {
    return true;
  }
}
