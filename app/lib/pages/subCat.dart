import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'productDetails.dart';
import 'categorie.dart';

class SubCatPage extends StatelessWidget {
  final Category parent;
  final Category subcategory;

  const SubCatPage({
    Key? key,
    required this.parent,
    required this.subcategory,
  }) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('produits')
        .where('categoryId', isEqualTo: parent.id)
        .where('subCategoryId', isEqualTo: subcategory.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          subcategory.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Aucun produit dans cette sous-catégorie'));

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.65,
            ),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final docData = docs[i].data();
              final name = docData['name'] as String? ?? 'Sans nom';
              final price = (docData['price'] as num?)?.toDouble() ?? 0.0;
              final promo = docData['promotion'] as String?;
              final urls = (docData['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
              final imageUrl = urls.isNotEmpty ? urls.first : 'https://via.placeholder.com/150';

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsPage(
                      productDoc: docs[i],
                      imageUrls: urls,
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
                  )],
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
                          if (promo != null)
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
                                  '-$promo%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
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
                                height: 1.2),
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
                                Text(
                                  '${price.toStringAsFixed(2)}DA',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle),
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
    );
  }
}