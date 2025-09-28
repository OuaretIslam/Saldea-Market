import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> with AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _topCustomers = [];
  List<Map<String, dynamic>> _weeklySales = [];
  List<Map<String, dynamic>> _monthlySales = [];
  
  // Pagination
  final int _pageSize = 5;
  // ignore: unused_field
  int _productsPage = 0;
  // ignore: unused_field
  int _customersPage = 0;
  bool _hasMoreProducts = true;
  bool _hasMoreCustomers = true;
  
  // Filtres de date
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Pour la mise en cache
  final String _cacheKeyPrefix = 'stats_cache_';
  final Duration _cacheDuration = const Duration(hours: 1);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _fetchData();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;
      
      final cacheKey = '$_cacheKeyPrefix${user.uid}';
      final cachedDataString = prefs.getString(cacheKey);
      
      if (cachedDataString != null) {
        final cachedData = json.decode(cachedDataString) as Map<String, dynamic>;
        final cacheTimestamp = DateTime.fromMillisecondsSinceEpoch(cachedData['timestamp'] as int);
        
        // Vérifier si le cache est encore valide
        if (DateTime.now().difference(cacheTimestamp) < _cacheDuration) {
          setState(() {
            _topProducts = List<Map<String, dynamic>>.from(cachedData['topProducts'] ?? []);
            _topCustomers = List<Map<String, dynamic>>.from(cachedData['topCustomers'] ?? []);
            _weeklySales = List<Map<String, dynamic>>.from(cachedData['weeklySales'] ?? []);
            _monthlySales = List<Map<String, dynamic>>.from(cachedData['monthlySales'] ?? []);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Erreur silencieuse - on va quand même charger les données fraîches
      debugPrint('Erreur lors du chargement du cache: $e');
    }
  }

  Future<void> _saveDataToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      if (user == null) return;
      
      final cacheKey = '$_cacheKeyPrefix${user.uid}';
      final dataToCache = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'topProducts': _topProducts,
        'topCustomers': _topCustomers,
        'weeklySales': _weeklySales,
        'monthlySales': _monthlySales,
      };
      
      await prefs.setString(cacheKey, json.encode(dataToCache));
    } catch (e) {
      debugPrint('Erreur lors de la mise en cache des données: $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Vous devez être connecté pour voir vos statistiques';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez être connecté pour voir vos statistiques')),
        );
        return;
      }
      
      final String vendeurId = user.uid;
      
      // Récupérer tous les produits du vendeur connecté
      final QuerySnapshot produitsSnapshot = await _firestore
          .collection('produits')
          .where('vendeurId', isEqualTo: vendeurId)
          .get();
      
      // Créer une liste des IDs de produits appartenant à ce vendeur
      final List<String> vendeurProductIds = produitsSnapshot.docs
          .map((doc) => doc.id)
          .toList();
      
      // Si le vendeur n'a pas de produits, on arrête là
      if (vendeurProductIds.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Récupérer les commandes avec pagination et filtres de date
      final startTimestamp = Timestamp.fromDate(_startDate);
      final endTimestamp = Timestamp.fromDate(_endDate.add(const Duration(days: 1)));
      
      final QuerySnapshot commandesSnapshot = await _firestore
          .collection('commandes')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThan: endTimestamp)
          .orderBy('createdAt', descending: true)
          .limit(100) // Limiter à 100 commandes les plus récentes dans la plage de dates
          .get();
      
      // Analyser les données pour les produits les plus vendus
      Map<String, int> productCount = {};
      Map<String, int> customerProductCount = {};
      Map<String, String> productNames = {};
      
      // Pour les ventes hebdomadaires (7 derniers jours)
      Map<String, double> dailySales = {};
      
      // Pour les ventes mensuelles (30 derniers jours)
      Map<String, double> monthlySales = {};
      
      // Initialiser les jours de la semaine
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('dd/MM').format(date);
        dailySales[dateStr] = 0;
      }
      
      // Initialiser les jours du mois
      for (int i = 29; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('dd/MM').format(date);
        monthlySales[dateStr] = 0;
      }
      
      for (var doc in commandesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final products = List<Map<String, dynamic>>.from(data['products'] ?? []);
        final userId = data['userId'] as String? ?? '';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        // Filtrer pour ne garder que les produits de ce vendeur dans cette commande
        final vendeurProducts = products.where((product) {
          final productId = product['productId'] as String;
          return vendeurProductIds.contains(productId);
        }).toList();
        
        // Si aucun produit de ce vendeur dans cette commande, passer à la suivante
        if (vendeurProducts.isEmpty) continue;
        
        // Calculer le total des ventes pour ce vendeur dans cette commande
        double commandeTotal = 0;
        for (var product in vendeurProducts) {
          commandeTotal += (product['totalPrice'] as num? ?? 0).toDouble();
        }
        
        // Vérifier si la commande est dans les 7 derniers jours
        if (now.difference(createdAt).inDays <= 7) {
          final dateStr = DateFormat('dd/MM').format(createdAt);
          dailySales[dateStr] = (dailySales[dateStr] ?? 0) + commandeTotal;
        }
        
        // Vérifier si la commande est dans les 30 derniers jours
        if (now.difference(createdAt).inDays <= 30) {
          final dateStr = DateFormat('dd/MM').format(createdAt);
          monthlySales[dateStr] = (monthlySales[dateStr] ?? 0) + commandeTotal;
        }
        
        // Compter les produits
        for (var product in vendeurProducts) {
          final productId = product['productId'] as String;
          final productName = product['name'] as String;
          final quantity = product['quantity'] as int? ?? 1;
          
          productNames[productId] = productName;
          productCount[productId] = (productCount[productId] ?? 0) + quantity;
          
          // Compter les produits par client
          customerProductCount[userId] = (customerProductCount[userId] ?? 0) + quantity;
        }
      }
      
      // Préparer les données pour les produits les plus vendus
      List<Map<String, dynamic>> allTopProducts = productCount.entries
          .map((e) => {
                'id': e.key,
                'name': productNames[e.key] ?? 'Inconnu',
                'count': e.value,
              })
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      // Préparer les données pour les clients les plus actifs
      List<Map<String, dynamic>> allTopCustomers = customerProductCount.entries
          .map((e) => {
                'id': e.key,
                'count': e.value,
              })
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      // Pagination des produits
      _hasMoreProducts = allTopProducts.length > _pageSize;
      _topProducts = allTopProducts.take(_pageSize).toList();
      
      // Pagination des clients
      _hasMoreCustomers = allTopCustomers.length > _pageSize;
      _topCustomers = allTopCustomers.take(_pageSize).toList();
      
      // Préparer les données pour les ventes hebdomadaires
      _weeklySales = dailySales.entries
          .map((e) => {
                'day': e.key,
                'amount': e.value,
              })
          .toList();
      
      // Préparer les données pour les ventes mensuelles
      _monthlySales = monthlySales.entries
          .map((e) => {
                'day': e.key,
                'amount': e.value,
              })
          .toList();
      
      // Sauvegarder les données dans le cache
      _saveDataToCache();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors de la récupération des données: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Erreur lors de la récupération des données: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $_errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMoreProducts() async {
    setState(() {
      _productsPage++;
    });
    
    try {
      // Simuler le chargement de plus de produits
      // Dans une vraie application, vous feriez une nouvelle requête à Firestore
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Ici, nous simulons simplement l'ajout de plus de produits
      // Dans une vraie application, vous récupéreriez la page suivante de produits
      setState(() {
        _hasMoreProducts = false; // Pour cet exemple, on suppose qu'il n'y a plus de produits
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement de plus de produits: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement de plus de produits: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMoreCustomers() async {
    setState(() {
      _customersPage++;
    });
    
    try {
      // Simuler le chargement de plus de clients
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _hasMoreCustomers = false; // Pour cet exemple, on suppose qu'il n'y a plus de clients
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement de plus de clients: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement de plus de clients: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked.start != _startDate || picked?.end != _endDate) {
      setState(() {
        _startDate = picked!.start;
        _endDate = picked.end;
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),

          const SizedBox(height: 20),
          _buildDateFilter(),
          const SizedBox(height: 20),
          _buildWeeklySalesCard(),
          const SizedBox(height: 20),
          _buildMonthlySalesCard(),
          const SizedBox(height: 20),
          _buildTopProductsCard(),
          const SizedBox(height: 20),
          _buildTopCustomersCard(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Statistiques de vente',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            if (_isLoading)
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 8),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _fetchData,
              tooltip: 'Actualiser les données',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateFilter() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtrer par date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Du ${DateFormat('dd/MM/yyyy').format(_startDate)} au ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showDateRangePicker,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Changer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySalesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ventes Hebdomadaires',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _calculateTotalSales(_weeklySales),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _hasError
                    ? Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 200,
                        child: _buildWeeklySalesChart(),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySalesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ventes Mensuelles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _calculateTotalSales(_monthlySales),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _hasError
                    ? Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 200,
                        child: _buildMonthlySalesChart(),
                      ),
          ],
        ),
      ),
    );
  }

  String _calculateTotalSales(List<Map<String, dynamic>> salesData) {
    double total = 0;
    for (var sale in salesData) {
      total += sale['amount'] as double;
    }
    return '${total.toStringAsFixed(2)}€';
  }

  Widget _buildTopProductsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Produits les plus vendus',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? Center(
                        child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 250,
                            child: _buildTopProductsList(),
                          ),
                          if (_hasMoreProducts)
                            TextButton(
                              onPressed: _loadMoreProducts,
                              child: const Text('Voir plus'),
                            ),
                        ],
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCustomersCard() {
  return Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Ajoutez ceci pour que la colonne s'adapte à son contenu
        children: [
          const Text(
            'Clients les plus actifs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
                  ? Center(
                      child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min, // Ajoutez ceci pour que la colonne s'adapte à son contenu
                      children: [
                        // Supprimez le SizedBox avec hauteur fixe et laissez le contenu déterminer la hauteur
                        _buildTopCustomersList(),
                        if (_hasMoreCustomers)
                          TextButton(
                            onPressed: _loadMoreCustomers,
                            child: const Text('Voir plus'),
                          ),
                      ],
                    ),
        ],
      ),
    ),
  );
}



  Widget _buildWeeklySalesChart() {
    if (_weeklySales.isEmpty || _weeklySales.every((sale) => (sale['amount'] as double) == 0)) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucune vente cette semaine',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _weeklySales.map((e) => e['amount'] as double).reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueAccent,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${_weeklySales[groupIndex]['day']}: ${rod.toY.toStringAsFixed(2)}€',
                const TextStyle(color: Colors.white),
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
                if (value < 0 || value >= _weeklySales.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _weeklySales[value.toInt()]['day'].toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}€',
                  style: const TextStyle(fontSize: 10),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          _weeklySales.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: _weeklySales[index]['amount'] as double,
                color: Colors.blue,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlySalesChart() {
    if (_monthlySales.isEmpty || _monthlySales.every((sale) => (sale['amount'] as double) == 0)) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucune vente ce mois-ci',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Regrouper les données par semaine pour éviter un graphique trop chargé
    List<Map<String, dynamic>> weeklyGroupedData = [];
    double currentWeekTotal = 0;
    String currentWeekLabel = '';
    
    for (int i = 0; i < _monthlySales.length; i++) {
      if (i % 7 == 0) {
        if (i > 0) {
          weeklyGroupedData.add({
            'day': currentWeekLabel,
            'amount': currentWeekTotal,
          });
        }
        currentWeekTotal = _monthlySales[i]['amount'] as double;
        currentWeekLabel = 'S${(i ~/ 7) + 1}';
      } else {
        currentWeekTotal += _monthlySales[i]['amount'] as double;
      }
    }
    
    // Ajouter la dernière semaine
    if (currentWeekLabel.isNotEmpty) {
      weeklyGroupedData.add({
        'day': currentWeekLabel,
        'amount': currentWeekTotal,
      });
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: weeklyGroupedData.isEmpty 
            ? 10 
            : weeklyGroupedData.map((e) => e['amount'] as double).reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.green.shade700,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${weeklyGroupedData[groupIndex]['day']}: ${rod.toY.toStringAsFixed(2)}€',
                const TextStyle(color: Colors.white),
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
                if (value < 0 || value >= weeklyGroupedData.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    weeklyGroupedData[value.toInt()]['day'].toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}€',
                  style: const TextStyle(fontSize: 10),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          weeklyGroupedData.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: weeklyGroupedData[index]['amount'] as double,
                color: Colors.green,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopProductsList() {
  if (_topProducts.isEmpty) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucun produit vendu',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  return ListView.builder(
    itemCount: _topProducts.length,
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    itemBuilder: (context, index) {
      final product = _topProducts[index];
      return Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            product['name'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          // Suppression de la ligne affichant l'ID du produit
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${product['count']} vendu(s)',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          leading: CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text('${index + 1}'),
          ),
          onTap: () {
            // Naviguer vers la page détaillée du produit
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Détails du produit ${product['name']}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      );
    },
  );
}

Widget _buildTopCustomersList() {
  if (_topCustomers.isEmpty) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucun client actif',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
  return ListView.builder(
    itemCount: _topCustomers.length,
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    itemBuilder: (context, index) {
      final customer = _topCustomers[index];
            
      return FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('users').doc(customer['id']).get(),
        builder: (context, snapshot) {
          String clientName = 'Client inconnu';
          String clientEmail = '';
                    
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              title: Text('Chargement...'),
              subtitle: Text(''),
            );
          }
                    
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            if (userData != null) {
              // Changed from 'name' to 'username'
              final username = userData['username'] as String?;
              final email = userData['email'] as String?;
              if (username != null && username.isNotEmpty) {
                clientName = username;
              }
              if (email != null && email.isNotEmpty) {
                clientEmail = email;
              }
            }
          }
                    
          return Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                clientName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(clientEmail.isEmpty ? 'Email non disponible' : clientEmail),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${customer['count']} article(s)',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              leading: CircleAvatar(
                backgroundColor: Colors.green,
                child: Text('${index + 1}'),
              ),
              onTap: () {
                // Naviguer vers la page détaillée du client
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Détails du client $clientName'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}}