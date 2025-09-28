// lib/categorie.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'accueil.dart';
import 'identifie.dart';
import 'offer.dart';
import 'panier.dart';
import 'profile.dart';
import 'subCat.dart';  // ← Import your new page

/// Model class for a category or subcategory
class Category {
  final String id;
  final String name;
  final String imageUrl;
  final String? parentId;

  Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.parentId,
  });
}

/// Widget to load & cache an image from a Firebase Storage `gs://` URL
class CachedGsImage extends StatefulWidget {
  final String gsUrl;
  final BoxFit fit;

  const CachedGsImage({
    Key? key,
    required this.gsUrl,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  _CachedGsImageState createState() => _CachedGsImageState();
}

class _CachedGsImageState extends State<CachedGsImage> {
  late final Future<String> _downloadUrlFuture;

  @override
  void initState() {
    super.initState();
    _downloadUrlFuture =
        FirebaseStorage.instance.refFromURL(widget.gsUrl).getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _downloadUrlFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || snap.data == null) {
          return const Center(child: Icon(Icons.broken_image));
        }
        return CachedNetworkImage(
          imageUrl: snap.data!,
          fit: widget.fit,
          placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) => const Center(child: Icon(Icons.error)),
        );
      },
    );
  }
}

/// Displays top-level categories
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({Key? key}) : super(key: key);

  @override
  _CategoriesPageState createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  int _bottomNavIndex = 1;

  void _onBottomNavTapped(int idx) {
    switch (idx) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomePage()));
        return;
      case 2:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const OfferPage()));
        return;
      case 3:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const PanierPage()));
        return;
      case 4:
        if (FirebaseAuth.instance.currentUser != null) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfilePage()));
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const IdentifieScreen()));
        }
        return;
    }
    setState(() => _bottomNavIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categorie')
            .where('parentId', isNull: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aucune catégorie trouvée'));
          }
          final cats = docs.map((d) {
            final m = d.data()! as Map<String, dynamic>;
            return Category(
              id: d.id,
              name: m['nom'] ?? '',
              imageUrl: m['imageUrl'] ?? '',
            );
          }).toList();

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: .8,
            ),
            itemCount: cats.length,
            itemBuilder: (_, i) => CategoryCard(category: cats[i]),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
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
      ),
    );
  }
}

/// Card for a category or subcategory
class CategoryCard extends StatelessWidget {
  final Category category;
  const CategoryCard({Key? key, required this.category}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          // Load subcategories
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubCategoriesPage(category: category),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: CachedGsImage(gsUrl: category.imageUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                category.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays subcategories; tapping one goes to SubCatPage
class SubCategoriesPage extends StatefulWidget {
  final Category category;
  const SubCategoriesPage({Key? key, required this.category})
      : super(key: key);

  @override
  _SubCategoriesPageState createState() => _SubCategoriesPageState();
}

class _SubCategoriesPageState extends State<SubCategoriesPage> {
  int _bottomNavIndex = 1;

  void _onBottomNavTapped(int idx) {
    // same as above (copy-paste navigation)
    switch (idx) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomePage()));
        return;
      case 1:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const CategoriesPage()));
        return;
      case 2:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const OfferPage()));
        return;
      case 3:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const PanierPage()));
        return;
      case 4:
        if (FirebaseAuth.instance.currentUser != null) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfilePage()));
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const IdentifieScreen()));
        }
        return;
    }
    setState(() => _bottomNavIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categorie')
            .where('parentId', isEqualTo: widget.category.id)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aucune sous-catégorie trouvée'));
          }
          final subs = docs.map((d) {
            final m = d.data()! as Map<String, dynamic>;
            return Category(
              id: d.id,
              name: m['nom'] ?? '',
              imageUrl: m['imageUrl'] ?? '',
              parentId: widget.category.id,
            );
          }).toList();

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: .8,
            ),
            itemCount: subs.length,
            itemBuilder: (_, i) {
              final sub = subs[i];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () {
                    // ← NEW: navigate to SubCatPage
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubCatPage(
                          parent: widget.category,
                          subcategory: sub,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                          child: CachedGsImage(gsUrl: sub.imageUrl),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          sub.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Catégories'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: 'Offres'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Panier'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Compte'),
        ],
      ),
    );
  }
}
