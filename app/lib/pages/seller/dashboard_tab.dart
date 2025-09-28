import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  // États pour les données du tableau de bord
  int todaySales = 0;
  int totalOrders = 0;
  double totalRevenue = 0;
  int totalCustomers = 0;
  List<Map<String, dynamic>> recentActivities = [];
  bool isLoading = true;
  String? currentUserId; // Store the current user ID (vendeur)
  
  // Map pour stocker les produits du vendeur (productId -> product data)
  Map<String, Map<String, dynamic>> vendorProducts = {};

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  // Get the current user ID
  Future<void> _getCurrentUser() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        currentUserId = user.uid;
      });
      await _loadVendorProducts(); // Charger d'abord les produits du vendeur
      _loadDashboardData(); // Puis charger les données du tableau de bord
    } else {
      setState(() {
        isLoading = false;
      });
      debugPrint('Aucun utilisateur connecté');
    }
  }
  
  // Charger tous les produits du vendeur actuel
  Future<void> _loadVendorProducts() async {
    if (currentUserId == null) return;
    
    try {
      final QuerySnapshot productSnapshot = await FirebaseFirestore.instance
          .collection('produits') // Ajustez selon votre collection de produits
          .where('vendeurId', isEqualTo: currentUserId)
          .get();
      
      Map<String, Map<String, dynamic>> products = {};
      for (var doc in productSnapshot.docs) {
        products[doc.id] = doc.data() as Map<String, dynamic>;
      }
      
      vendorProducts = products;
      debugPrint('Produits du vendeur chargés: ${vendorProducts.length}');
    } catch (e) {
      debugPrint('Erreur lors du chargement des produits du vendeur: $e');
    }
  }

  // Fonction pour charger les données du tableau de bord
  Future<void> _loadDashboardData() async {
    if (currentUserId == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    
    try {
      // Récupérer toutes les commandes
      final QuerySnapshot orderSnapshot = await FirebaseFirestore.instance
          .collection('commandes')
          .get();
      
      // Filtrer les commandes qui contiennent des produits du vendeur actuel
      List<QueryDocumentSnapshot> vendorOrders = [];
      Set<String> uniqueCustomers = {};
      
      for (var doc in orderSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        if (data.containsKey('products') && data['products'] is List) {
          List<dynamic> products = data['products'] as List;
          
          // Vérifier si au moins un produit appartient au vendeur actuel
          bool hasVendorProduct = false;
          for (var product in products) {
            if (product is Map && product.containsKey('productId')) {
              String productId = product['productId'] as String;
              
              // Vérifier si ce produit appartient au vendeur actuel
              if (vendorProducts.containsKey(productId)) {
                hasVendorProduct = true;
                
                // Ajouter le client à la liste des clients uniques
                if (data.containsKey('userId') && data['userId'] != null) {
                  uniqueCustomers.add(data['userId'] as String);
                }
                
                break;
              }
            }
          }
          
          if (hasVendorProduct) {
            vendorOrders.add(doc);
          }
        }
      }
      
      // Calculer les statistiques pour les commandes du vendeur
      _calculateStatistics(vendorOrders);
      
      // Récupérer les activités récentes
      _getRecentActivities(vendorOrders);
      
      if (mounted) {
        setState(() {
          totalCustomers = uniqueCustomers.length;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des données: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Calculer les statistiques à partir des commandes
  void _calculateStatistics(List<QueryDocumentSnapshot> vendorOrders) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    
    int todaySalesCount = 0; // Nombre total d'articles vendus aujourd'hui
    double revenue = 0;
    int totalOrdersCount = vendorOrders.length;
    
    for (var doc in vendorOrders) {
      final data = doc.data() as Map<String, dynamic>;
      bool isToday = false;
      
      // Vérifier si la commande est d'aujourd'hui
      if (data.containsKey('createdAt')) {
        var createdAt = data['createdAt'];
        DateTime? orderDate;
        
        try {
          if (createdAt is Timestamp) {
            orderDate = createdAt.toDate();
          } else if (createdAt is String) {
            orderDate = DateTime.parse(createdAt);
          }
          
          if (orderDate != null) {
            DateTime orderDay = DateTime(
              orderDate.year,
              orderDate.month,
              orderDate.day,
            );
            isToday = orderDay.isAtSameMomentAs(today);
          }
        } catch (e) {
          debugPrint('Erreur lors de la conversion de la date: $e');
        }
      }
      
      // Calculer le revenu et compter les articles vendus
      if (data.containsKey('products') && data['products'] is List) {
        List<dynamic> products = data['products'] as List;
        
        for (var product in products) {
          if (product is Map && product.containsKey('productId')) {
            String productId = product['productId'] as String;
            
            // Vérifier si ce produit appartient au vendeur actuel
            if (vendorProducts.containsKey(productId)) {
              // Ajouter le prix total du produit au revenu
              if (product.containsKey('totalPrice')) {
                try {
                  revenue += (product['totalPrice'] as num).toDouble();
                } catch (e) {
                  debugPrint('Erreur lors de la lecture du prix total: $e');
                }
              }
              
              // Compter les articles vendus aujourd'hui
              if (isToday) {
                // Vérifier s'il y a une quantité spécifiée
                if (product.containsKey('quantity') && product['quantity'] != null) {
                  try {
                    todaySalesCount += (product['quantity'] as num).toInt();
                  } catch (e) {
                    // Si la conversion échoue, compter comme 1 article
                    todaySalesCount += 1;
                    debugPrint('Erreur lors de la lecture de la quantité: $e');
                  }
                } else {
                  // Si pas de quantité spécifiée, compter comme 1 article
                  todaySalesCount += 1;
                }
              }
            }
          }
        }
      }
    }
    
    // Mettre à jour les statistiques
    if (mounted) {
      setState(() {
        todaySales = todaySalesCount;
        totalOrders = totalOrdersCount;
        totalRevenue = revenue;
      });
    }
  }

  // Récupérer les activités récentes
  void _getRecentActivities(List<QueryDocumentSnapshot> vendorOrders) {
    try {
      // Trier les commandes par date (du plus récent au plus ancien)
      List<QueryDocumentSnapshot> sortedOrders = List.from(vendorOrders);
      sortedOrders.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        DateTime? aDate;
        DateTime? bDate;
        
        try {
          if (aData.containsKey('createdAt')) {
            var createdAt = aData['createdAt'];
            if (createdAt is Timestamp) {
              aDate = createdAt.toDate();
            } else if (createdAt is String) {
              aDate = DateTime.parse(createdAt);
            }
          }
        } catch (e) {
          // Ignorer l'erreur
        }
        
        try {
          if (bData.containsKey('createdAt')) {
            var createdAt = bData['createdAt'];
            if (createdAt is Timestamp) {
              bDate = createdAt.toDate();
            } else if (createdAt is String) {
              bDate = DateTime.parse(createdAt);
            }
          }
        } catch (e) {
          // Ignorer l'erreur
        }
        
        // Si les dates sont nulles, mettre à la fin
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        
        // Trier par ordre décroissant
        return bDate.compareTo(aDate);
      });
      
      // Prendre les commandes récentes (limité à 10 pour éviter une liste trop longue)
      final recentDocs = sortedOrders.take(10).toList();
      
      // Créer la liste d'activités
      List<Map<String, dynamic>> activities = [];
      
      for (var doc in recentDocs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Déterminer la date
        String timeAgo = 'Récent';
        DateTime? orderDate;
        if (data.containsKey('createdAt')) {
          try {
            var createdAt = data['createdAt'];
            if (createdAt is Timestamp) {
              orderDate = createdAt.toDate();
            } else if (createdAt is String) {
              orderDate = DateTime.parse(createdAt);
            }
            if (orderDate != null) {
              timeAgo = _getTimeAgo(orderDate);
            }
          } catch (e) {
            // Utiliser la valeur par défaut
          }
        }
        
        // Calculer le montant total pour les produits du vendeur actuel
        double amount = 0;
        List<Map<String, dynamic>> vendorProductsList = [];
        
        if (data.containsKey('products') && data['products'] is List) {
          List<dynamic> products = data['products'] as List;
          
          for (var product in products) {
            if (product is Map && product.containsKey('productId')) {
              String productId = product['productId'] as String;
              
              // Vérifier si ce produit appartient au vendeur actuel
              if (this.vendorProducts.containsKey(productId)) {
                // Ajouter le prix total du produit au montant
                double productPrice = 0;
                if (product.containsKey('totalPrice')) {
                  try {
                    productPrice = (product['totalPrice'] as num).toDouble();
                    amount += productPrice;
                  } catch (e) {
                    debugPrint('Erreur lors de la lecture du prix total: $e');
                  }
                }
                
                // Ajouter les détails du produit à la liste
                Map<String, dynamic> productDetails = {
                  'name': product.containsKey('name') ? product['name'] : 'Produit',
                  'price': productPrice,
                  'quantity': product.containsKey('quantity') ? product['quantity'] : 1,
                };
                vendorProductsList.add(productDetails);
              }
            }
          }
        }
        
        // Déterminer les détails des produits pour l'affichage
        String productInfo = 'Commande';
        if (vendorProductsList.isNotEmpty) {
          productInfo = vendorProductsList[0]['name'];
          if (vendorProductsList.length > 1) {
            productInfo += ' + ${vendorProductsList.length - 1} autres';
          }
        }
        
        // Ajouter l'activité avec toutes les informations nécessaires
        activities.add({
          'type': 'Nouvelle commande',
          'details': productInfo,
          'time': timeAgo,
          'amount': amount,
          'status': data.containsKey('status') ? data['status'] : 'en préparation',
          'orderId': doc.id,
          'orderDate': orderDate,
          'products': vendorProductsList,
          'customerInfo': data.containsKey('customerInfo') ? data['customerInfo'] : null,
          'shippingAddress': data.containsKey('shippingAddress') ? data['shippingAddress'] : null,
          'fullOrderData': data,
        });
      }
      
      if (mounted) {
        setState(() {
          recentActivities = activities;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération des activités récentes: $e');
    }
  }

  // Convertir un DateTime en texte "Il y a X minutes/heures/jours"
  String _getTimeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  // Afficher les détails de l'activité
  void _showActivityDetails(Map<String, dynamic> activity) {
    showDialog(
      context: context,
      builder: (context) => ActivityDetailsDialog(activity: activity),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(

      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aperçu de votre boutique',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Statistiques
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              StatCard(
                title: 'Ventes aujourd\'hui',
                value: isLoading ? '...' : todaySales.toString(),
                icon: Icons.shopping_cart,
                color: Colors.green,
              ),
              StatCard(
                title: 'Commandes',
                value: isLoading ? '...' : totalOrders.toString(),
                icon: Icons.receipt,
                color: Colors.blue,
              ),
              StatCard(
                title: 'Revenus',
                value:
                    isLoading
                        ? '...'
                        : '${NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2).format(totalRevenue)}',
                icon: Icons.attach_money,
                color: Colors.orange,
              ),
              StatCard(
                title: 'Clients',
                value: isLoading ? '...' : totalCustomers.toString(),
                icon: Icons.people,
                color: Colors.purple,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Text(
            'Activités récentes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // Liste des activités récentes
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : recentActivities.isEmpty
              ? const Center(child: Text('Aucune activité récente'))
              : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentActivities.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final activity = recentActivities[index];
                  return InkWell(
                    onTap: () => _showActivityDetails(activity),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(
                            activity['status'].toString(),
                          ),
                          child: const Icon(
                            Icons.shopping_bag,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(activity['type'].toString()),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activity['details'].toString()),
                            Text(
                              'Statut: ${activity['status']}',
                              style: TextStyle(
                                color: _getStatusColor(
                                  activity['status'].toString(),
                                ),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              NumberFormat.currency(
                                locale: 'fr_FR',
                                symbol: '€',
                                decimalDigits: 2,
                              ).format(activity['amount']),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              activity['time'].toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  // Obtenir la couleur en fonction du statut de la commande
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en préparation':
        return Colors.orange;
      case 'expédiée':
        return Colors.blue;
      case 'livrée':
        return Colors.green;
      case 'annulée':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }
}

/// Widget StatCard
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget pour afficher les détails d'une activité
class ActivityDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> activity;

  const ActivityDetailsDialog({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    // Formater la date si disponible
    String formattedDate = 'Date inconnue';
    if (activity['orderDate'] != null) {
      formattedDate = DateFormat('dd/MM/yyyy à HH:mm').format(activity['orderDate']);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(activity['status'].toString()),
                  child: const Icon(Icons.shopping_bag, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commande #${activity['orderId'].toString().substring(0, 8)}...',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(activity['status'].toString()).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(activity['status'].toString()),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    activity['status'].toString(),
                    style: TextStyle(
                      color: _getStatusColor(activity['status'].toString()),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            
            // Produits
            const Text(
              'Produits',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            
            // Liste des produits
            if (activity['products'] != null && (activity['products'] as List).isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (activity['products'] as List).length,
                itemBuilder: (context, index) {
                  final product = (activity['products'] as List)[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.inventory_2, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'].toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Quantité: ${product['quantity']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          NumberFormat.currency(
                            locale: 'fr_FR',
                            symbol: '€',
                            decimalDigits: 2,
                          ).format(product['price']),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              const Text('Aucun produit trouvé'),
              
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),
            
            // Informations client
            if (activity['customerInfo'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informations client',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    Icons.person,
                    'Nom',
                    activity['customerInfo']['name'] ?? 'Non spécifié',
                  ),
                  _buildInfoRow(
                    Icons.email,
                    'Email',
                    activity['customerInfo']['email'] ?? 'Non spécifié',
                  ),
                  _buildInfoRow(
                    Icons.phone,
                    'Téléphone',
                    activity['customerInfo']['phone'] ?? 'Non spécifié',
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                ],
              ),
              
            // Adresse de livraison
            if (activity['shippingAddress'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Adresse de livraison',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    Icons.location_on,
                    'Adresse',
                    activity['shippingAddress']['street'] ?? 'Non spécifiée',
                  ),
                  _buildInfoRow(
                    Icons.location_city,
                    'Ville',
                    '${activity['shippingAddress']['postalCode'] ?? ''} ${activity['shippingAddress']['city'] ?? 'Non spécifiée'}',
                  ),
                  _buildInfoRow(
                    Icons.flag,
                    'Pays',
                    activity['shippingAddress']['country'] ?? 'Non spécifié',
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              
            // Total
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    NumberFormat.currency(
                      locale: 'fr_FR',
                      symbol: '€',
                      decimalDigits: 2,
                    ).format(activity['amount']),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Bouton de fermeture
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // Construire une ligne d'information
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Obtenir la couleur en fonction du statut de la commande
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en préparation':
        return Colors.orange;
      case 'expédiée':
        return Colors.blue;
      case 'livrée':
        return Colors.green;
      case 'annulée':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }
}