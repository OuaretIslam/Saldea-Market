import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommandesAvecSuiviPage extends StatefulWidget {
  const CommandesAvecSuiviPage({Key? key}) : super(key: key);

  @override
  _CommandesAvecSuiviPageState createState() => _CommandesAvecSuiviPageState();
}

class _CommandesAvecSuiviPageState extends State<CommandesAvecSuiviPage> with SingleTickerProviderStateMixin {
  String? _expandedId;
  late AnimationController _fadeCtrl;

  // Les statuts possibles avec leurs propriétés
  final List<OrderStatus> _orderStatuses = [
    const OrderStatus(
      code: 'preparation',
      label: 'En préparation',
      icon: Icons.inventory_2,
      color: Colors.orange,
    ),
    const OrderStatus(
      code: 'en cours de livraison',
      label: 'En cours de livraison',
      icon: Icons.local_shipping,
      color: Colors.blue,
    ),
    const OrderStatus(
      code: 'livré',
      label: 'Livré',
      icon: Icons.check_circle,
      color: Colors.green,
    ),
    const OrderStatus(
      code: 'returned',
      label: 'Retourné',
      icon: Icons.assignment_return,
      color: Colors.red,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // Retourne l'index du statut
  int _statusIndex(String statusCode) {
    final idx = _orderStatuses.indexWhere((s) => s.code == statusCode);
    if (idx == -1) return 0;
    return idx.clamp(0, _orderStatuses.length - 1);
  }

  // Trouve le statut par son code
  OrderStatus _getStatusByCode(String code) {
    return _orderStatuses.firstWhere(
      (status) => status.code == code,
      orElse: () => _orderStatuses[0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mes Commandes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: uid == null
          ? const Center(child: Text('Veuillez vous connecter'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('commandes')
                  .where('userId', isEqualTo: uid)
                  //.orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Erreur Firestore : ${snap.error}'));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune commande',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vos commandes apparaîtront ici',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final statusCode = data['status'] as String? ?? 'preparation';
                    final orderDate = (data['createdAt'] as Timestamp).toDate();
                    final orderItems = (data['products'] as List?)?.length ?? 0;
                    final totalPrice = (data['total'] as num?)?.toDouble() ?? 0.0;
                    final isOpen = doc.id == _expandedId;

                    // Récupérer les éventuelles dates de statut
                    final statusDates = <String, DateTime>{};
                    if (data['statusDates'] != null && data['statusDates'] is Map) {
                      (data['statusDates'] as Map).forEach((key, value) {
                        if (value is Timestamp) {
                          statusDates[key as String] = value.toDate();
                        }
                      });
                    }

                    // Si les dates de statut sont manquantes, utiliser la date de création
                    if (statusDates.isEmpty) {
                      statusDates['preparation'] = orderDate;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // En-tête de la commande
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (_expandedId == doc.id) {
                                  _expandedId = null;
                                  _fadeCtrl.reverse();
                                } else {
                                  _expandedId = doc.id;
                                  _fadeCtrl.forward(from: 0);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Numéro de commande
                                      Text(
                                        'Commande #${doc.id.substring(0, 6).toUpperCase()}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      
                                      // Prix
                                      Text(
                                        '${totalPrice.toStringAsFixed(2)} DA',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                                                    
                                  const SizedBox(height: 12),
                                  
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Date
                                      Text(
                                        _formatDate(orderDate),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                      
                                      // Nombre d'articles
                                      Text(
                                        '$orderItems article${orderItems > 1 ? 's' : ''}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Badge de statut
                                  _buildStatusBadge(statusCode),
                                  
                                  const SizedBox(height: 8),
                                  
                                  // Indicateur d'expansion
                                  Icon(
                                    isOpen ? Icons.expand_less : Icons.expand_more,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Détails animés (timeline)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: isOpen
                                ? FadeTransition(
                                    opacity: _fadeCtrl,
                                    child: _buildTimeline(statusCode, statusDates),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  // Badge de statut stylisé
  Widget _buildStatusBadge(String statusCode) {
    final status = _getStatusByCode(statusCode);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.icon,
            size: 16,
            color: status.color,
          ),
          const SizedBox(width: 8),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Construit la timeline horizontale avec statuts
  Widget _buildTimeline(String currentStatus, Map<String, DateTime> statusDates) {
    final activeColor = Colors.blue;
    final inactiveColor = Colors.grey.shade300;
    final currentIndex = _statusIndex(currentStatus);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suivi de commande',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Ligne de progression
          Stack(
            children: [
              // Ligne de base
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: inactiveColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Progression active
              FractionallySizedBox(
                widthFactor: _orderStatuses.isEmpty 
                    ? 0 
                    : currentIndex / (_orderStatuses.length - 1),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Étapes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_orderStatuses.length, (i) {
              final status = _orderStatuses[i];
              final isActive = i <= currentIndex;
              final isCurrent = i == currentIndex;
              
              // Chercher la date correspondante au statut
              final statusDate = statusDates[status.code];
              
              return Column(
                children: [
                  // Indicateur d'étape
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive ? status.color : inactiveColor,
                      shape: BoxShape.circle,
                      border: isCurrent 
                          ? Border.all(color: status.color, width: 3)
                          : null,
                      boxShadow: isActive 
                          ? [
                              BoxShadow(
                                color: status.color.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ] 
                          : null,
                    ),
                    child: Icon(
                      status.icon,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Libellé
                  Text(
                    status.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? status.color : Colors.grey,
                    ),
                  ),
                  
                  // Date (si disponible)
                  if (statusDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _formatShortDate(statusDate),
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive ? status.color : Colors.grey,
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
  
  // Formater une date complète
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${_formatTime(date)}';
  }
  
  // Formater une date courte
  String _formatShortDate(DateTime date) {
    return '${date.day}/${date.month}';
  }
  
  // Formater l'heure
  String _formatTime(DateTime date) {
    String hours = date.hour.toString().padLeft(2, '0');
    String minutes = date.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

// Modèle pour les statuts de commande
class OrderStatus {
  final String code;
  final String label;
  final IconData icon;
  final Color color;
  
  const OrderStatus({
    required this.code,
    required this.label,
    required this.icon,
    required this.color,
  });
}