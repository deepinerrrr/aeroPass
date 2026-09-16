import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:get/get.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../../data/models/question_model.dart';
import 'ai_chat_controller.dart';

class AiChatDialog {
  static void show(Question question) {
    final controller = Get.put(AiChatController());

    Get.bottomSheet(
      FutureBuilder(
        future: controller.initQuestion(question),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Container(
              height: 200,
              decoration: BoxDecoration(
                color: Get.theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          return const _AiChatPanelView();
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
    );
  }

  static void dismiss() {
    final controller = Get.find<AiChatController>();
    controller.stopGeneration();
    Get.back();
    Get.delete<AiChatController>();
  }
}

class _AiChatPanelView extends StatefulWidget {
  const _AiChatPanelView();

  @override
  State<_AiChatPanelView> createState() => _AiChatPanelViewState();
}

class _AiChatPanelViewState extends State<_AiChatPanelView> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _textController;
  late final DraggableScrollableController _dragController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _dragController = DraggableScrollableController();
    final controller = Get.find<AiChatController>();
    ever(controller.inputText, (value) {
      _textController.text = value;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: value.length),
      );
    });
    ever(controller.messages, (_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _dragController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AiChatController>();
    return DraggableScrollableSheet(
      controller: _dragController,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Get.theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(controller),
              Expanded(child: _buildMessageList(controller)),
              _buildInputBar(controller),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(AiChatController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Text(
                  'AI 答疑助手',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Obx(() => _buildModelSwitcher(controller)),
              ],
            ),
          ),
          Obx(() {
            final hasMessages = controller.messages.where((m) => m.role != 'system').isNotEmpty;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasMessages)
                  IconButton(
                    onPressed: () => _showClearConfirm(controller),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      minimumSize: const Size(32, 32),
                    ),
                    tooltip: '清空会话',
                  ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: AiChatDialog.dismiss,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModelSwitcher(AiChatController controller) {
    final isGenerating = controller.isGenerating.value;
    final currentModel = controller.currentModel.value;

    return GestureDetector(
      onTap: isGenerating
          ? null
          : () {
              final newModel = currentModel == 'qwen' ? 'deepseek' : 'qwen';
              controller.switchModel(newModel);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: currentModel == 'deepseek'
              ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
              : Get.theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: currentModel == 'deepseek'
                ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
                : Get.theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentModel == 'deepseek' ? Icons.auto_awesome_rounded : Icons.psychology_rounded,
              size: 12,
              color: currentModel == 'deepseek'
                  ? const Color(0xFF4F46E5)
                  : Get.theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              controller.currentModelName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: currentModel == 'deepseek'
                    ? const Color(0xFF4F46E5)
                    : Get.theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.swap_horiz_rounded,
              size: 12,
              color: currentModel == 'deepseek'
                  ? const Color(0xFF4F46E5).withValues(alpha: 0.6)
                  : Get.theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirm(AiChatController controller) {
    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('清空会话'),
        content: const Text('确定要清空当前题目的问答记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.clearHistory();
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(AiChatController controller) {
    return Obx(() {
      final displayMessages = controller.messages.where((m) => m.role != 'system').toList();

      if (displayMessages.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology_rounded, size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('正在分析题目...', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: displayMessages.length,
        itemBuilder: (context, index) {
          final message = displayMessages[index];
          return _buildMessageBubble(message, controller);
        },
      );
    });
  }

  Widget _buildMessageBubble(ChatMessage message, AiChatController controller) {
    final isUser = message.role == 'user';
    final isStreaming = message.isStreaming;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? Get.theme.colorScheme.primary
                    : Get.theme.cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: Colors.grey.shade200),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.5),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectionArea(
                          child: GptMarkdown(
                            message.content,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: Get.theme.textTheme.bodyLarge!.color,
                            ),
                            // 同时支持 $...$、$$...$$ 与 \(...\)、\[...\] 定界符
                            useDollarSignsForLatex: true,
                            latexBuilder: (context, tex, style, inline) => Math.tex(
                              tex,
                              mathStyle: inline ? MathStyle.text : MathStyle.display,
                              textStyle: style,
                              // 流式输出中公式不完整时先原样展示，避免报错
                              onErrorFallback: (err) => Text(tex, style: style),
                            ),
                          ),
                        ),
                        if (isStreaming) ...[
                          const SizedBox(height: 6),
                          _buildStreamingIndicator(),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Get.theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '生成中...',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildInputBar(AiChatController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Obx(() {
        final isGenerating = controller.isGenerating.value;
        return Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 80),
                child: TextField(
                  controller: _textController,
                  onChanged: (value) => controller.inputText.value = value,
                  enabled: !isGenerating,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => controller.sendMessage(),
                  decoration: InputDecoration(
                    hintText: isGenerating ? 'AI正在回答...' : '输入追问...',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: isGenerating
                        ? Colors.grey.shade50
                        : Get.theme.scaffoldBackgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Get.theme.colorScheme.primary, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isGenerating)
              IconButton(
                onPressed: controller.stopGeneration,
                icon: const Icon(Icons.stop_circle_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  minimumSize: const Size(40, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              )
            else
              IconButton(
                onPressed: controller.sendMessage,
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Get.theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(40, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
          ],
        );
      }),
    );
  }
}
