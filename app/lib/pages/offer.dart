import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'categorie.dart';
import 'identifie.dart';
import 'panier.dart';
import 'accueil.dart';
import 'profile.dart';
import 'productDetails.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OfferPage extends StatefulWidget {
  const OfferPage({Key? key}) : super(key: key);

  @override
  _OfferPageState createState() => _OfferPageState();
}

class _OfferPageState extends State<OfferPage> {
  int _bottomNavIndex = 2;

  Future<Map<String, dynamic>> _getProductRatings(String productId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('produits')
        .doc(productId)
        .collection('ratings')
        .get();

    if (snapshot.docs.isEmpty) return {'average': 0.0, 'count': 0};

    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['rating'] as num).toDouble();
    }
    return {
      'average': total / snapshot.docs.length,
      'count': snapshot.docs.length,
    };
  }

  // BottomNavigationBar tap handler.
  void _onBottomNavTapped(int index) {
    setState(() {
      _bottomNavIndex = index;
    });
    if (index == 0) {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => const HomePage()));
    } else if (index == 1) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const CategoriesPage()));
    } else if (index == 3) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const PanierPage()));
    } else if (index == 4) {
      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const IdentifieScreen()),
        );
      }
    } else {
      setState(() => _bottomNavIndex = index);
    }
    // Index 2 is the current page (Offers).
  }

  @override
  Widget build(BuildContext context) {
    // Query products that have a non-null promotion field
    final query = FirebaseFirestore.instance
        .collection('produits')
        .where('promotion', isNull: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Offres',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      // Display offer products in a grid.
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final docs = snap.data!.docs;
          
          if (docs.isEmpty) {
            return const Center(child: Text('Aucune promotion disponible'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data();
              final name = data['name'] as String? ?? 'Sans nom';
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
              final promotion = data['promotion'];
              
              // Handle promotion whether it's a number or string
              String promoText;
              double discountedPrice;
              
              if (promotion is num) {
                // If promotion is a number (like 5 for 5%)
                promoText = '${promotion.toString()}%';
                discountedPrice = price * (1 - (promotion / 100));
              } else if (promotion is String) {
                // If promotion is already a string (like "5%")
                promoText = promotion;
                // Extract number from string for calculation
                final percentValue = double.tryParse(promotion.replaceAll('%', '')) ?? 0;
                discountedPrice = price * (1 - (percentValue / 100));
              } else {
                // Fallback
                promoText = '0%';
                discountedPrice = price;
              }
              
              final imageUrls = data['imageUrls'] as List<dynamic>?;
              final imageUrl = (imageUrls?.isNotEmpty ?? false)
                  ? imageUrls!.first as String
                  : 'https://via.placeholder.com/150';

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsPage(
                      productDoc: docs[i],
                      imageUrls: (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
                    ),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, size: 40),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '-$promoText',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<Map<String, dynamic>>(
                              future: _getProductRatings(docs[i].id),
                              builder: (context, snapshot) {
                                final rating = snapshot.hasData ? snapshot.data!['average'] : 0.0;
                                final count = snapshot.hasData ? snapshot.data!['count'] : 0;
                                
                                return Row(
                                  children: [
                                    ...List.generate(5, (index) => Icon(
                                      index < rating.floor()
                                          ? Icons.star_rounded
                                          : (index < rating ? Icons.star_half_rounded : Icons.star_outline_rounded),
                                      color: Colors.amber[600],
                                      size: 16,
                                    )),
                                    const SizedBox(width: 4),
                                    Text(
                                      '($count)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600]),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${price.toStringAsFixed(2)}DA',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${discountedPrice.toStringAsFixed(2)}DA',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.add_shopping_cart, size: 20),
                                    onPressed: () {/* Add to cart logic */},
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
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.category), label: 'Catégories'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_offer), label: 'Offres'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'Panier'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Compte'),
        ],
      ),
    );
  }
}