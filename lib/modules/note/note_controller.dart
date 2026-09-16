import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/note_model.dart';
import '../../data/database/database_helper.dart';

class NoteController extends GetxController {
  final DatabaseHelper _db = DatabaseHelper();

  final currentNote = Rxn<Note>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final textContent = ''.obs;

  final strokes = <HandwritingStroke>[].obs;
  final currentColor = Colors.black.obs;
  final currentStrokeWidth = 3.0.obs;

  String? _currentQuestionId;

  final List<Color> availableColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];

  final List<double> availableStrokeWidths = [2.0, 4.0, 6.0, 8.0];

  @override
  void onClose() {
    if (_currentQuestionId != null && textContent.value.isNotEmpty) {
      saveNote();
    }
    super.onClose();
  }

  Future<void> loadNote(String questionId) async {
    _currentQuestionId = questionId;
    isLoading.value = true;
    textContent.value = '';

    try {
      final note = await _db.getNote(questionId);
      currentNote.value = note;
      if (note != null) {
        textContent.value = note.content;
        if (note.handwritingData != null && note.handwritingData!.isNotEmpty) {
          try {
            final handwritingData = HandwritingData.fromJson(note.handwritingData!);
            strokes.value = handwritingData.strokes;
          } catch (_) {
            strokes.clear();
          }
        } else {
          strokes.clear();
        }
      } else {
        strokes.clear();
      }
    } catch (e) {
      Get.snackbar('错误', '加载笔记失败: $e');
    }

    isLoading.value = false;
  }

  void updateText(String value) {
    textContent.value = value;
  }

  void addStroke(List<StrokePoint> points) {
    if (points.isEmpty) return;
    strokes.add(HandwritingStroke(
      points: points,
      color: '#${currentColor.value.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      strokeWidth: currentStrokeWidth.value,
    ));
  }

  void undo() {
    if (strokes.isNotEmpty) {
      strokes.removeLast();
    }
  }

  void clearStrokes() {
    strokes.clear();
  }

  void setColor(Color color) {
    currentColor.value = color;
  }

  void setStrokeWidth(double width) {
    currentStrokeWidth.value = width;
  }

  Future<void> saveNote() async {
    if (_currentQuestionId == null) return;

    isSaving.value = true;
    try {
      final now = DateTime.now().toIso8601String();
      final noteType = _calculateNoteType();

      String? handwritingData;
      if (strokes.isNotEmpty) {
        final data = HandwritingData(
          strokes: strokes.toList(),
          canvasWidth: 300,
          canvasHeight: 400,
        );
        handwritingData = data.toJson();
      }

      await _db.saveNote(Note(
        id: currentNote.value?.id,
        questionId: _currentQuestionId!,
        content: textContent.value,
        handwritingData: handwritingData,
        noteType: noteType,
        createdAt: currentNote.value?.createdAt ?? now,
        updatedAt: now,
      ));

      final updated = await _db.getNote(_currentQuestionId!);
      currentNote.value = updated;
    } catch (e) {
      Get.snackbar('错误', '保存笔记失败: $e');
    }

    isSaving.value = false;
  }

  Future<void> deleteNote() async {
    if (_currentQuestionId == null) return;

    try {
      await _db.deleteNote(_currentQuestionId!);
      currentNote.value = null;
      textContent.value = '';
      strokes.clear();
    } catch (e) {
      Get.snackbar('错误', '删除笔记失败: $e');
    }
  }

  int _calculateNoteType() {
    final hasText = textContent.value.trim().isNotEmpty;
    final hasStrokes = strokes.isNotEmpty;

    if (hasText && hasStrokes) return 2;
    if (hasStrokes) return 1;
    return 0;
  }
}
