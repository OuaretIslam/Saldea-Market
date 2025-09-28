import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<int> getVendeursCount() => _firestore
      .collection('users')
      .where('type', isEqualTo: 'vendeur')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);

  Stream<int> getTotalUsers() => _firestore
      .collection('users')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);

  Stream<double> getTotalSales() => _firestore
      .collection('commandes')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.fold(
          0.0,
          (sum, doc) => sum + (doc['total'] as num).toDouble(),
        ),
      );

  Stream<int> getLitigesCount() => _firestore
      .collection('servclient')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);

  Stream<List<SalesData>> getMonthlySales() => _firestore
      .collection('commandes')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => _processSales(snapshot.docs));

  List<SalesData> _processSales(List<QueryDocumentSnapshot> docs) {
    final Map<String, SalesData> monthlySales = {};

    for (final doc in docs) {
      final date = (doc['createdAt'] as Timestamp).toDate();
      final key = '${date.year}-${date.month}';

      monthlySales.update(
        key,
        (existing) => SalesData(
          date: existing.date,
          amount: existing.amount + (doc['total'] as num).toDouble(),
        ),
        ifAbsent:
            () => SalesData(
              date: DateTime(date.year, date.month),
              amount: (doc['total'] as num).toDouble(),
            ),
      );
    }

    return monthlySales.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // Nouvelle méthode pour les 7 derniers jours
  Stream<List<SalesData>> getLast7DaysSales() => _firestore
      .collection('commandes')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => _processLast7DaysSales(snapshot.docs));

  List<SalesData> _processLast7DaysSales(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final Map<String, SalesData> dailySales = {};

    // Initialiser les 7 derniers jours à 0
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(day);
      dailySales[key] = SalesData(date: day, amount: 0.0);
    }

    for (final doc in docs) {
      final date = (doc['createdAt'] as Timestamp).toDate();
      final key = DateFormat('yyyy-MM-dd').format(date);
      if (dailySales.containsKey(key)) {
        dailySales[key] = SalesData(
          date: dailySales[key]!.date,
          amount: dailySales[key]!.amount + (doc['total'] as num).toDouble(),
        );
      }
    }

    return dailySales.values.toList();
  }

  // Nouvelles méthodes pour les métriques
  Stream<double> getConversionRate() => _firestore
      .collection('commandes')
      .snapshots()
      .map((snapshot) => snapshot.docs.length / 100);

  Stream<double> getPanierMoyen() => _firestore
      .collection('commandes')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.isEmpty
                ? 0.0
                : snapshot.docs.fold(
                      0.0,
                      (sum, doc) => sum + (doc['total'] as num).toDouble(),
                    ) /
                    snapshot.docs.length,
      );

  Stream<double> getTauxAbandon() => _firestore
      .collection('servclient')
      .where('type', isEqualTo: 'abandon')
      .snapshots()
      .map((snapshot) => snapshot.docs.length / 100);
}

class SalesData {
  final DateTime date;
  double amount;

  SalesData({required this.date, required this.amount});
}

class DashboardSection extends StatelessWidget {
  final DashboardService _service = DashboardService();

  DashboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          _buildStatsRow(),
          const SizedBox(height: 24),
          _buildSalesChart(),
          const SizedBox(height: 24),
          _buildPerformanceMetrics(context),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              stream: _service.getTotalSales(),
              title: 'Ventes',
              icon: Icons.shopping_bag,
              color: Colors.blue.shade700,
              formatter: (value) => '${(value as double).toStringAsFixed(0)}DA',
            ),
            _buildStatItem(
              stream: _service.getTotalUsers(),
              title: 'Utilisateurs',
              icon: Icons.people,
              color: Colors.green.shade600,
            ),
            _buildStatItem(
              stream: _service.getVendeursCount(),
              title: 'Vendeurs',
              icon: Icons.store,
              color: Colors.orange.shade700,
            ),
            _buildStatItem(
              stream: _service.getLitigesCount(),
              title: 'Litiges',
              icon: Icons.warning,
              color: Colors.red.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required Stream<dynamic> stream,
    required String title,
    required IconData icon,
    required Color color,
    String Function(dynamic)? formatter,
  }) {
    return StreamBuilder<dynamic>(
      stream: stream,
      builder: (context, snapshot) {
        final value =
            snapshot.hasData
                ? formatter?.call(snapshot.data) ?? snapshot.data.toString()
                : '...';

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSalesChart() {
    return StreamBuilder<List<SalesData>>(
      stream: _service.getLast7DaysSales(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final salesData = snapshot.data!;
        if (salesData.isEmpty) {
          return const Card(
            elevation: 3,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Aucune donnée de vente disponible')),
            ),
          );
        }

        final maxY = salesData.fold(
          0.0,
          (max, e) => e.amount > max ? e.amount : max,
        );

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Ventes 7 derniers jours',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: true,
                        horizontalInterval: maxY / 4 == 0 ? 1 : maxY / 4,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.shade300,
                            strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: Colors.grey.shade300,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= salesData.length ||
                                  value.toInt() < 0)
                                return const Text('');
                              final day = salesData[value.toInt()].date;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('E').format(
                                    day,
                                  ), // Affiche le jour (ex: Lun, Mar)
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: maxY / 4 == 0 ? 1 : maxY / 4,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  '${(value / 1000).toStringAsFixed(0)}K',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade400,
                            width: 1,
                          ),
                          left: BorderSide(
                            color: Colors.grey.shade400,
                            width: 1,
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots:
                              salesData.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(), e.value.amount);
                              }).toList(),
                          isCurved: true,
                          color: Colors.blue.shade700,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.blue.shade700,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blue.shade200.withOpacity(0.3),
                          ),
                        ),
                      ],
                      minX: 0,
                      maxX: salesData.length - 1.0,
                      minY: 0,
                      maxY: maxY * 1.1 == 0 ? 1 : maxY * 1.1,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((spot) {
                              final data = salesData[spot.x.toInt()];
                              final day = DateFormat('E').format(data.date);
                              return LineTooltipItem(
                                '$day\n${spot.y.toStringAsFixed(0)}DA',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildChartSummary(salesData),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartSummary(List<SalesData> salesData) {
    final currentDay = salesData.isNotEmpty ? salesData.last : null;
    final previousDay =
        salesData.length > 1 ? salesData[salesData.length - 2] : null;

    final total = salesData.fold(0.0, (sum, e) => sum + e.amount);
    final average = salesData.isNotEmpty ? total / salesData.length : 0;
    final growth =
        previousDay != null && currentDay != null && previousDay.amount != 0
            ? ((currentDay.amount - previousDay.amount) / previousDay.amount) *
                100
            : 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildChartStat(
            'Jour actuel',
            currentDay != null
                ? '${currentDay.amount.toStringAsFixed(0)}DA'
                : '0DA',
            Colors.blue.shade700,
          ),
          _buildChartStat(
            'Moyenne',
            '${average.toStringAsFixed(0)}DA/jour',
            Colors.green.shade600,
          ),
          _buildChartStat(
            'Évolution',
            '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%',
            growth >= 0 ? Colors.green.shade600 : Colors.red.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildChartStat(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMetrics(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insert_chart_outlined,
                  color: Colors.purple.shade700,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Métriques de Performance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDynamicMetrics(),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicMetrics() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricStreamItem(
                title: 'Taux de Conversion',
                stream: _service.getConversionRate(),
                formatter: (value) => '${(value * 100).toStringAsFixed(1)}%',
                trendIcon: Icons.trending_up,
                positive: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricStreamItem(
                title: 'Panier Moyen',
                stream: _service.getPanierMoyen(),
                formatter: (value) => '${value.toStringAsFixed(2)}DA',
                trendIcon: Icons.trending_up,
                positive: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricStreamItem(
                title: "Taux d'Abandon",
                stream: _service.getTauxAbandon(),
                formatter: (value) => '${(value * 100).toStringAsFixed(1)}%',
                trendIcon: Icons.trending_down,
                positive: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricStreamItem(
                title: 'Nouveaux Clients',
                stream: _service.getTotalUsers().map((count) => count * 0.3),
                formatter: (value) => '${value.toStringAsFixed(1)}%',
                trendIcon: Icons.trending_up,
                positive: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricStreamItem({
    required String title,
    required Stream<dynamic> stream,
    required String Function(dynamic) formatter,
    required IconData trendIcon,
    required bool positive,
  }) {
    return StreamBuilder<dynamic>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.hasData ? snapshot.data! : 0.0;
        final color = positive ? Colors.green.shade600 : Colors.red.shade600;

        return _buildMetricCard(
          title: title,
          value: formatter(value),
          change:
              positive
                  ? '+${(value * 10).toStringAsFixed(1)}%'
                  : '-${(value * 5).toStringAsFixed(1)}%',
          changeColor: color,
          trendIcon: trendIcon,
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String change,
    required Color changeColor,
    required IconData trendIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: changeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trendIcon, color: changeColor, size: 12),
                const SizedBox(width: 2),
                Text(
                  change,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: changeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
