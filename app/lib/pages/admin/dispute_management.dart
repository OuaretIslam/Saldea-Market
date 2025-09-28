import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class DisputeManagement extends StatelessWidget {
  const DisputeManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const Text(
                'Gestion des Litiges',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 10),
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('commandes')
                        .limit(1)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Tooltip(
                      message: 'Erreur de connexion à Firebase',
                      child: Icon(Icons.error_outline, color: Colors.red),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Tooltip(
                      message: 'Connexion en cours...',
                      child: Icon(Icons.sync, color: Colors.orange),
                    );
                  }
                  return const Tooltip(
                    message: 'Connecté à Firebase',
                    child: Icon(Icons.check_circle, color: Colors.green),
                  );
                },
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.white,
            tabs: [
              Tab(text: 'Commandes', icon: Icon(Icons.shopping_cart)),
              Tab(text: 'Litiges', icon: Icon(Icons.gavel)),
              Tab(text: 'Notifications', icon: Icon(Icons.notifications)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_OrdersList(), _DisputesList(), _NotificationsView()],
        ),
      ),
    );
  }
}

class _OrdersList extends StatefulWidget {
  const _OrdersList();

  @override
  State<_OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<_OrdersList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('commandes')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Chargement des commandes...'),
                    ],
                  ),
                );
              }

              final orders = snapshot.data?.docs ?? [];

              if (orders.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Aucune commande trouvée',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Filtrer les commandes si une recherche est en cours
              final filteredOrders =
                  _searchQuery.isEmpty
                      ? orders
                      : orders.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final orderId = doc.id.toLowerCase();
                        final userId =
                            data['userId']?.toString().toLowerCase() ?? '';
                        final searchLower = _searchQuery.toLowerCase();
                        return orderId.contains(searchLower) ||
                            userId.contains(searchLower);
                      }).toList();

              return ListView.builder(
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order =
                      filteredOrders[index].data() as Map<String, dynamic>;
                  final orderId = filteredOrders[index].id;
                  final createdAt = order['createdAt'] as Timestamp?;
                  final status = order['status'] ?? 'en attente';
                  final total = order['total']?.toString() ?? '0';
                  final paymentMethod =
                      order['paymentMethod'] ?? 'Non spécifié';
                  final promoCode = order['promoCode'] ?? '';
                  final userId = order['userId'] ?? '';

                  // Récupérer les produits
                  final productsList =
                      (order['products'] as List<dynamic>?)?.map((product) {
                        return {
                          'name': product['name'] ?? 'Produit inconnu',
                          'quantity': product['quantity'] ?? 0,
                          'totalPrice': product['totalPrice'] ?? 0,
                          'unitPrice': product['unitPrice'] ?? 0,
                        };
                      }).toList() ??
                      [];

                  return _OrderCard(
                    orderId: orderId,
                    createdAt: createdAt?.toDate() ?? DateTime.now(),
                    status: status,
                    total: total,
                    paymentMethod: paymentMethod,
                    promoCode: promoCode,
                    userId: userId,
                    products: productsList,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final DateTime createdAt;
  final String status;
  final String total;
  final String paymentMethod;
  final String promoCode;
  final String userId;
  final List<Map<String, dynamic>> products;

  const _OrderCard({
    required this.orderId,
    required this.createdAt,
    required this.status,
    required this.total,
    required this.paymentMethod,
    required this.promoCode,
    required this.userId,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        {
          'en attente': Colors.orange,
          'en préparation': Colors.blue,
          'en cours de livraison': Colors.orange,
          'livrée': Colors.green,
          'annulée': Colors.red,
        }[status.toLowerCase()] ??
        Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: EdgeInsets.zero,
        leading: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
            Icon(
              Icons.shopping_bag,
              color:
                  status.toLowerCase() == 'en cours de livraison'
                      ? Colors.orange
                      : statusColor,
              size: 24,
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Commande #${orderId.length > 8 ? orderId.substring(0, 8) + '...' : orderId}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color:
                    status.toLowerCase() == 'en cours de livraison'
                        ? Colors.orange.withOpacity(0.15)
                        : statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ID: ${userId.length > 10 ? userId.substring(0, 10) + '...' : userId}',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy à HH:mm').format(createdAt),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.payment, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(paymentMethod, style: const TextStyle(fontSize: 13)),
                  const Spacer(),
                  Text(
                    '$total DA',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Produits commandés',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              child: Row(
                                children: const [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Produit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Qté',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Prix unit.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: products.length,
                              separatorBuilder:
                                  (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final product = products[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '${product['name']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text('${product['quantity']}'),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${product['unitPrice']} DA',
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${product['totalPrice']} DA',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Récapitulatif
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (promoCode.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Code promo:',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    promoCode,
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '$total DA',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Boutons d'action
                if (status == 'en attente' || status == 'en préparation')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.local_shipping),
                              label: const Text('En cours de livraison'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('commandes')
                                    .doc(orderId)
                                    .update({'status': 'en cours de livraison'})
                                    .then((_) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Commande en cours de livraison',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    })
                                    .catchError((error) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Erreur: $error'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Livrée'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('commandes')
                                    .doc(orderId)
                                    .update({'status': 'livrée'})
                                    .then((_) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Commande marquée comme livrée',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    })
                                    .catchError((error) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Erreur: $error'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (status == 'en cours de livraison')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Livrée'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('commandes')
                              .doc(orderId)
                              .update({'status': 'livrée'})
                              .then((_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Commande marquée comme livrée',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              })
                              .catchError((error) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erreur: $error'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              });
                        },
                      ),
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

class _DisputesList extends StatefulWidget {
  const _DisputesList();

  @override
  State<_DisputesList> createState() => _DisputesListState();
}

class _DisputesListState extends State<_DisputesList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _rejectDispute(String disputeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('servclient')
          .doc(disputeId)
          .update({
            'status': 'rejeté',
            'rejectedAt': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Litige marqué comme rejeté'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du rejet: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resolveDispute(String disputeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('servclient')
          .doc(disputeId)
          .update({
            'status': 'résolu',
            'resolvedAt': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Litige marqué comme résolu'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la résolution: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('servclient')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Chargement des litiges...'),
                    ],
                  ),
                );
              }

              final disputes = snapshot.data?.docs ?? [];

              if (disputes.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gavel_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Aucun litige trouvé',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Filtrer les litiges si une recherche est en cours
              final filteredDisputes =
                  _searchQuery.isEmpty
                      ? disputes
                      : disputes.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final report =
                            data['rapport']?.toString().toLowerCase() ?? '';
                        final username =
                            data['username']?.toString().toLowerCase() ?? '';
                        final searchLower = _searchQuery.toLowerCase();
                        return report.contains(searchLower) ||
                            username.contains(searchLower);
                      }).toList();

              return ListView.builder(
                itemCount: filteredDisputes.length,
                itemBuilder: (context, index) {
                  final dispute =
                      filteredDisputes[index].data() as Map<String, dynamic>;
                  return _DisputeCard(
                    disputeId: filteredDisputes[index].id,
                    report: dispute['rapport'] ?? 'Aucun rapport',
                    username: dispute['username'] ?? 'Utilisateur inconnu',
                    createdAt:
                        (dispute['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
                    status: dispute['status'] as String? ?? 'nouveau',
                    onReject: () => _rejectDispute(filteredDisputes[index].id),
                    onResolve:
                        () => _resolveDispute(filteredDisputes[index].id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final String disputeId;
  final String report;
  final String username;
  final DateTime createdAt;
  final String status;
  final VoidCallback onReject;
  final VoidCallback onResolve;

  const _DisputeCard({
    required this.disputeId,
    required this.report,
    required this.username,
    required this.createdAt,
    required this.status,
    required this.onReject,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        {
          'nouveau': Colors.orange,
          'en cours': Colors.blue,
          'résolu': Colors.green,
          'rejeté': Colors.red,
        }[status.toLowerCase()] ??
        Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _showDisputeDetails(context),
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.gavel, color: Colors.blue),
        ),
        title: Text(
          report.length > 50 ? '${report.substring(0, 50)}...' : report,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Utilisateur: $username'),
            Text(DateFormat('dd MMM yyyy à HH:mm').format(createdAt)),
          ],
        ),
        trailing: Chip(
          label: Text(status),
          backgroundColor: statusColor.withOpacity(0.1),
          labelStyle: TextStyle(color: statusColor),
        ),
      ),
    );
  }

  void _showDisputeDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Détails du Litige',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _DetailItem(
                          icon: Icons.person,
                          label: 'Utilisateur',
                          value: username,
                        ),
                        _DetailItem(
                          icon: Icons.date_range,
                          label: 'Date',
                          value: DateFormat(
                            'dd MMM yyyy à HH:mm',
                          ).format(createdAt),
                        ),
                        _DetailItem(
                          icon: Icons.info_outline,
                          label: 'Statut',
                          value: status,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Rapport:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            report,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (status != 'résolu' && status != 'rejeté')
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check),
                                  label: const Text('Résoudre'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder:
                                          (context) => AlertDialog(
                                            title: const Text(
                                              'Confirmer la résolution',
                                            ),
                                            content: const Text(
                                              'Voulez-vous marquer ce litige comme résolu ?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(context),
                                                child: const Text('Annuler'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  onResolve();
                                                  Navigator.pop(
                                                    context,
                                                  ); // Fermer la boîte de dialogue
                                                  Navigator.pop(
                                                    context,
                                                  ); // Fermer la vue détaillée
                                                },
                                                child: const Text(
                                                  'Résoudre',
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.close),
                                  label: const Text('Rejeter'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder:
                                          (context) => AlertDialog(
                                            title: const Text(
                                              'Confirmer le rejet',
                                            ),
                                            content: const Text(
                                              'Voulez-vous marquer ce litige comme rejeté ?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(context),
                                                child: const Text('Annuler'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  onReject();
                                                  Navigator.pop(
                                                    context,
                                                  ); // Fermer la boîte de dialogue
                                                  Navigator.pop(
                                                    context,
                                                  ); // Fermer la vue détaillée
                                                },
                                                child: const Text(
                                                  'Rejeter',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView();

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendNotification(bool toAll) async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un message'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final usersSnapshot =
          await FirebaseFirestore.instance
              .collection(toAll ? 'users' : 'vendeurs')
              .get();

      for (var doc in usersSnapshot.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'message': _messageController.text,
          'timestamp': FieldValue.serverTimestamp(),
          'type': toAll ? 'all' : 'vendeurs',
          'username': doc.data()['username'] ?? 'Utilisateur inconnu',
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            toAll
                ? 'Notification envoyée à ${usersSnapshot.docs.length} utilisateurs'
                : 'Notification envoyée à ${usersSnapshot.docs.length} vendeurs',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _messageController.clear();
    } catch (e) {
      print('Erreur lors de l\'envoi des notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Envoyer une notification',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Écrivez votre message ici...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.store),
                            label: const Text('Envoyer aux vendeurs'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed:
                                _isLoading
                                    ? null
                                    : () => _sendNotification(false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.people),
                            label: const Text('Envoyer à tous'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed:
                                _isLoading
                                    ? null
                                    : () => _sendNotification(true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Notifications récentes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Une erreur est survenue'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final notifications = snapshot.data?.docs ?? [];

              // Grouper les notifications par type et date
              final Map<String, List<Map<String, dynamic>>> grouped = {};
              for (var doc in notifications) {
                final notif = doc.data() as Map<String, dynamic>;
                final type = notif['type'] ?? 'all';
                if (!grouped.containsKey(type)) grouped[type] = [];
                grouped[type]!.add({...notif, 'id': doc.id});
              }

              if (grouped.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Aucune notification',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children:
                    grouped.entries.map((entry) {
                      final type = entry.key;
                      final notifs = entry.value;
                      final icon = type == 'all' ? Icons.people : Icons.store;
                      final color = type == 'all' ? Colors.green : Colors.blue;
                      final title =
                          type == 'all'
                              ? 'Notifications générales'
                              : 'Notifications vendeurs';
                      final lastNotif = notifs.first;
                      final date =
                          lastNotif['timestamp'] is Timestamp
                              ? DateFormat('dd/MM/yyyy').format(
                                (lastNotif['timestamp'] as Timestamp).toDate(),
                              )
                              : '';
                      final count = notifs.length;
                      final lastMsg = lastNotif['message'] ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: color.withOpacity(0.15)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(icon, color: color, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          date,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$count notification${count > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              if (lastMsg.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    lastMsg,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
