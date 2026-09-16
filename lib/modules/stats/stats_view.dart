import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'stats_controller.dart';

class StatsView extends StatelessWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StatsController());

    return Scaffold(
      appBar: AppBar(title: const Text('学习统计')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: controller.loadStats,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(controller),
                const SizedBox(height: 16),
                _buildPieChartCard(controller),
                const SizedBox(height: 16),
                _buildBarChartCard(controller),
                const SizedBox(height: 16),
                _buildLineChartCard(controller),
                const SizedBox(height: 16),
                _buildMockExamCard(controller),
                const SizedBox(height: 16),
                _buildDetailCard(controller),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildOverviewCard(StatsController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('学习概览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildStatItem('总题数', '${controller.totalQuestions.value}', Icons.library_books_rounded, Colors.blue)),
                Expanded(child: _buildStatItem('已练习', '${controller.practicedCount.value}', Icons.edit_note_rounded, Colors.indigo)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatItem('正确率', '${controller.correctRate.toStringAsFixed(1)}%', Icons.check_circle_rounded, Colors.green)),
                Expanded(child: _buildStatItem('错题数', '${controller.wrongCount.value}', Icons.error_rounded, Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPieChartCard(StatsController controller) {
    final practiced = controller.practicedCount.value.toDouble();
    final wrong = controller.wrongCount.value.toDouble();
    final mastered = controller.masteredCount.value.toDouble();
    final unpracticed = controller.unpracticedCount.toDouble();
    final correct = practiced - wrong;

    final total = practiced + unpracticed;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('题目分布', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 40),
              const Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('题目分布', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, constraints) {
              final chartSize = constraints.maxWidth * 0.55;
              return Row(
                children: [
                  SizedBox(
                    width: chartSize,
                    height: chartSize,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: chartSize * 0.28,
                        sections: [
                          PieChartSectionData(
                            value: correct > 0 ? correct : 0,
                            color: Colors.green,
                            radius: chartSize * 0.18,
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            title: correct > 0 ? '答对' : '',
                          ),
                          PieChartSectionData(
                            value: wrong > 0 ? wrong : 0,
                            color: Colors.red,
                            radius: chartSize * 0.18,
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            title: wrong > 0 ? '错题' : '',
                          ),
                          PieChartSectionData(
                            value: mastered > 0 ? mastered : 0,
                            color: Colors.blue,
                            radius: chartSize * 0.18,
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            title: mastered > 0 ? '掌握' : '',
                          ),
                          PieChartSectionData(
                            value: unpracticed > 0 ? unpracticed : 0,
                            color: Colors.grey.shade300,
                            radius: chartSize * 0.18,
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                            title: unpracticed > 0 ? '未练' : '',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(Colors.green, '答对', '${correct.toInt()}题'),
                        const SizedBox(height: 8),
                        _buildLegendItem(Colors.red, '错题', '${wrong.toInt()}题'),
                        const SizedBox(height: 8),
                        _buildLegendItem(Colors.blue, '已掌握', '${mastered.toInt()}题'),
                        const SizedBox(height: 8),
                        _buildLegendItem(Colors.grey, '未练习', '${unpracticed.toInt()}题'),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildBarChartCard(StatsController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('学习进度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final labels = ['练习进度', '掌握进度', '正确率'];
                        return BarTooltipItem(
                          '${labels[group.x]}\n${rod.toY.toStringAsFixed(1)}%',
                          const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = ['练习', '掌握', '正确率'];
                          if (value.toInt() < labels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(labels[value.toInt()], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          if (value % 20 == 0) {
                            return Text('${value.toInt()}%', style: const TextStyle(fontSize: 11, color: Colors.grey));
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: controller.progressRate,
                          color: Colors.blue,
                          width: 36,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: controller.masteredRate,
                          color: Colors.green,
                          width: 36,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: controller.correctRate,
                          color: Colors.orange,
                          width: 36,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartCard(StatsController controller) {
    final records = controller.mockExamRecords;
    if (records.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('模拟考试趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 40),
              const Center(child: Text('暂无考试记录', style: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      );
    }

    final reversedRecords = records.reversed.toList();
    final spots = <FlSpot>[];
    for (int i = 0; i < reversedRecords.length; i++) {
      final score = (reversedRecords[i]['score'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), score));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('模拟考试趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < reversedRecords.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('第${idx + 1}次', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            );
                          }
                          return const SizedBox();
                        },
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          if (value % 20 == 0) {
                            return Text('${value.toInt()}', style: const TextStyle(fontSize: 11, color: Colors.grey));
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: Colors.teal,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: Colors.teal,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.teal.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)}分',
                            const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockExamCard(StatsController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.quiz_rounded, color: Colors.teal.shade600, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('模拟考试', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildStatItem('考试次数', '${controller.mockExamCount.value}', Icons.assignment_rounded, Colors.teal)),
                Expanded(child: _buildStatItem('平均分', controller.mockExamAvgScore.toStringAsFixed(1), Icons.trending_up_rounded, Colors.orange)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatItem('最高分', controller.mockExamMaxScore.toStringAsFixed(1), Icons.emoji_events_rounded, Colors.amber)),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(StatsController controller) {
    final unpracticed = controller.unpracticedCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('详细数据', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _buildDetailRow('总题数', '${controller.totalQuestions.value}'),
            _buildDetailRow('已练习', '${controller.practicedCount.value}'),
            _buildDetailRow('未练习', '$unpracticed'),
            _buildDetailRow('答对数', '${controller.correctCount.value}'),
            _buildDetailRow('答错数', '${controller.wrongCount.value}'),
            _buildDetailRow('收藏数', '${controller.favoriteCount.value}'),
            _buildDetailRow('已掌握', '${controller.masteredCount.value}'),
            _buildDetailRow('正确率', '${controller.correctRate.toStringAsFixed(1)}%'),
            _buildDetailRow('模拟考试次数', '${controller.mockExamCount.value}'),
            _buildDetailRow('模拟考试平均分', controller.mockExamAvgScore.toStringAsFixed(1)),
            _buildDetailRow('模拟考试最高分', controller.mockExamMaxScore.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
