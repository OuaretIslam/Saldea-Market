import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoriqueCommandePage extends StatefulWidget {
  const HistoriqueCommandePage({Key? key}) : super(key: key);

  @override
  _HistoriqueCommandePageState createState() => _HistoriqueCommandePageState();
}

class _HistoriqueCommandePageState extends State<HistoriqueCommandePage> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blue;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'historique des commandes',
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
                  .where('status', isEqualTo: 'livré')
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
                          Icons.history,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune commande livrée',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vos commandes livrées apparaîtront ici',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final orderDate = (data['createdAt'] as Timestamp).toDate();
                    final orderItems = (data['products'] as List?)?.length ?? 0;
                    final totalPrice = (data['total'] as num?)?.toDouble() ?? 0.0;
                    final isOpen = doc.id == _expandedId;
                    
                    // Récupérer les dates de statut
                    DateTime? deliveryDate;
                    if (data['statusDates'] != null && data['statusDates'] is Map) {
                      final statusDates = data['statusDates'] as Map;
                      if (statusDates['livré'] is Timestamp) {
                        deliveryDate = (statusDates['livré'] as Timestamp).toDate();
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
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
                                _expandedId = isOpen ? null : doc.id;
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
                                      // Date de commande
                                      Text(
                                        'Commandé le : ${_formatDate(orderDate)}',
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
                                  
                                  if (deliveryDate != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Livré le : ${_formatDate(deliveryDate)}',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Badge de statut livré
                                  _buildStatusBadge(),
                                  
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

                          // Détails de la commande
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: isOpen
                                ? _buildOrderDetails(data)
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

  // Badge de statut livré
  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.green,
          ),
          SizedBox(width: 8),
          Text(
            'Livré',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Détails de la commande
  Widget _buildOrderDetails(Map<String, dynamic> data) {
    final products = data['products'] as List? ?? [];
    final paymentMethod = data['paymentMethod'] as String? ?? 'Non spécifié';
    final userId = data['userId'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
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
            'Détails de la commande',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Liste des produits
          const Text(
            'Articles',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 8),
          
          ...List.generate(products.length, (i) {
            final product = products[i] as Map<String, dynamic>? ?? {};
            final productName = product['name'] as String? ?? 'Produit';
            final quantity = product['quantity'] as int? ?? 1;
            final unitPrice = product['unitPrice'] as num? ?? 0.0;
            final totalPrice = product['totalPrice'] as num? ?? (unitPrice * quantity);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$productName × $quantity',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${unitPrice.toStringAsFixed(2)} DA / unité',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${totalPrice.toStringAsFixed(2)} DA',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          
          const Divider(height: 24),
          
          // Adresse de livraison
          const Text(
            'Adresse de livraison',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Fetch address from users collection
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              
              if (snapshot.hasError) {
                return Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red));
              }
              
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Text('Adresse non disponible');
              }
              
              final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              
              // Handle address as string instead of map
              if (userData['address'] is String) {
                return Text(
                  userData['address'] as String? ?? 'Adresse non disponible',
                  style: const TextStyle(fontSize: 14),
                );
              } 
              // Try to handle as map if possible (for backward compatibility)
              else if (userData['address'] is Map) {
                try {
                  final address = userData['address'] as Map<String, dynamic>? ?? {};
                  return Text(
                    '${address['name'] ?? ''}\n'
                    '${address['street'] ?? ''}\n'
                    '${address['city'] ?? ''}, ${address['postalCode'] ?? ''}\n'
                    '${address['phone'] ?? ''}',
                    style: const TextStyle(fontSize: 14),
                  );
                } catch (e) {
                  return Text(
                    'Erreur de format d\'adresse: $e',
                    style: const TextStyle(fontSize: 14, color: Colors.red),
                  );
                }
              } 
              // Fallback for any other case
              else {
                return const Text(
                  'Format d\'adresse non reconnu',
                  style: TextStyle(fontSize: 14),
                );
              }
            },
          ),
          
          const Divider(height: 24),
          
          // Méthode de paiement
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Méthode de paiement',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                paymentMethod,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Formater une date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${_formatTime(date)}';
  }
  
  // Formater l'heure
  String _formatTime(DateTime date) {
    String hours = date.hour.toString().padLeft(2, '0');
    String minutes = date.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}