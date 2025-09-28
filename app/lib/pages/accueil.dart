import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'categorie.dart';
import 'identifie.dart';
import 'offer.dart';
import 'panier.dart';
import 'profile.dart';
import 'productDetails.dart';
import 'AccNotif.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _bottomNavIndex = 0;
  late final PageController _pageController =
      PageController(initialPage: carouselImages.length * 100);

  static const List<String> carouselImages = [
    'https://images.pexels.com/photos/5650026/pexels-photo-5650026.jpeg?auto=compress&cs=tinysrgb&w=600',
    'https://images.pexels.com/photos/8891159/pexels-photo-8891159.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
    'https://images.pexels.com/photos/2536965/pexels-photo-2536965.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
  ];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

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

  void _onBottomNavTapped(int index) {
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesPage()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OfferPage()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PanierPage()));
    } else if (index == 4) {
      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const IdentifieScreen()));
      }
    } else {
      setState(() => _bottomNavIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Saldae Market',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => showSearch(context: context, delegate: CustomSearchDelegate()),
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
          },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageCarousel(),
              _buildCarouselIndicators(),
              const SizedBox(height: 20),
              _buildCategorySection(context),
              const SizedBox(height: 20),
              _buildFeaturedProducts(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildImageCarousel() {
    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: _pageController,
        itemBuilder: (context, index) {
          final actualIndex = index % carouselImages.length;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              image: DecorationImage(
                image: NetworkImage(carouselImages[actualIndex]),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
        onPageChanged: (index) =>
            setState(() => _currentCarouselIndex = index % carouselImages.length),
      ),
    );
  }

  Widget _buildCarouselIndicators() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(carouselImages.length, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentCarouselIndex == index ? Colors.blue : Colors.grey,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context) {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('categorie')
        .where('parentId', isNull: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Aucune catégorie trouvée'),
        );
      }

      final categories = snapshot.data!.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Category(
          id: doc.id,
          name: data['nom'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
        );
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Catégories',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubCategoriesPage(category: category),
                      ),
                    );
                  },
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: CachedGsImage(gsUrl: category.imageUrl),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          category.name,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

  Widget _buildFeaturedProducts() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Produits en vedette',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 16),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('produits').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Erreur de chargement'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Aucun produit trouvé'));

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.65,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final name = data['name'] as String? ?? 'Sans nom';
              final rawPrice = data['price'];
              final price = rawPrice is num ? rawPrice.toDouble() : double.tryParse(rawPrice?.toString() ?? '0') ?? 0.0;
              final promoField = data['promotion'];
              // Determine promotion
              String promoText;
              double discountedPrice;
              if (promoField is num) {
                promoText = '${promoField.toString()}%';
                discountedPrice = price * (1 - promoField / 100);
              } else if (promoField is String && promoField.endsWith('%')) {
                final pct = double.tryParse(promoField.replaceAll('%', '')) ?? 0;
                promoText = promoField;
                discountedPrice = price * (1 - pct / 100);
              } else {
                promoText = '';
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
                      productDoc: docs[index],
                      imageUrls: (imageUrls ?? []).cast<String>(),
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
                      // Image + promo badge
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                              errorWidget: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 40)),
                            ),
                          ),
                          if (promoText.isNotEmpty)
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                                child: Text('-$promoText', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                        ],
                      ),

                      // Details + ratings + price
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            FutureBuilder<Map<String, dynamic>>(
                              future: _getProductRatings(docs[index].id),
                              builder: (ctx, snapRating) {
                                if (!snapRating.hasData) return const SizedBox.shrink();
                                final avg = snapRating.data!['average'] as double;
                                final count = snapRating.data!['count'] as int;
                                return Row(
                                  children: [
                                    ...List.generate(5, (i) {
                                      if (i < avg.floor()) return Icon(Icons.star_rounded, size: 16, color: Colors.amber[600]);
                                      if (i < avg) return Icon(Icons.star_half_rounded, size: 16, color: Colors.amber[600]);
                                      return Icon(Icons.star_outline_rounded, size: 16, color: Colors.amber[600]);
                                    }),
                                    const SizedBox(width: 4),
                                    Text('($count)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),

                            // Original & discounted price
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (promoText.isNotEmpty)
                                      Text('${price.toStringAsFixed(2)}DA',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          decoration: TextDecoration.lineThrough,
                                          color: Colors.grey,
                                        )),
                                    Text('${discountedPrice.toStringAsFixed(2)}DA',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                  ],
                                ),
                                Container(
                                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                                  child: IconButton(
                                    icon: const Icon(Icons.add_shopping_cart, size: 20),
                                    onPressed: () { 
                                      
                                    },
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
    ],
  );
}


  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _bottomNavIndex,
      onTap: _onBottomNavTapped,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Catégories'),
        BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: 'Offres'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Panier'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Compte'),
      ],
    );
  }
}

class CustomSearchDelegate extends SearchDelegate {
  @override
  Widget buildResults(BuildContext context) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const Center(
        child: Text('Entrez un terme de recherche.'),
      );
    }

    // Normalize the query to lowercase
    final lowerQuery = trimmed.toLowerCase();

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('produits')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .get(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(child: Text('Erreur : ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Client-side filter by lowercase comparison
        final docs = (snap.data?.docs ?? []).where((doc) {
          final name = (doc.data()['name'] as String? ?? '');
          return name.toLowerCase().contains(lowerQuery);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('Aucun produit trouvé.'));
        }

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
            final data = docs[i].data();
            final name = data['name'] as String? ?? 'Sans nom';
            final priceValue = (data['price'] as num?)?.toDouble() ?? 0.0;
            final price = '${priceValue.toStringAsFixed(2)} DA';
            final imageUrls = data['imageUrls'] as List<dynamic>?;
            final imageUrl = (imageUrls?.isNotEmpty ?? false)
                ? imageUrls!.first as String
                : 'https://via.placeholder.com/150';
            final promo = data['promotion'] as String?;

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailsPage(
                    productDoc: docs[i],
                    imageUrls: (imageUrls as List).cast<String>(),
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
                                "-$promo%",
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
                          Text(
                            price,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.add_shopping_cart, size: 20),
                                onPressed: () {},
                              ),
                            ),
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
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
      ];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));

  @override
  Widget buildSuggestions(BuildContext context) => const SizedBox.shrink();
}


