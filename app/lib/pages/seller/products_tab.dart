import 'package:app/pages/seller/product_form.dart';
import 'package:app/pages/seller/widgets/product_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  bool isLoading = true;
  int _currentPage = 0; // 0: catégories, 1: sous-catégories, 2: produits

  String? selectedCategoryId;
  String? selectedCategoryName;
  String? selectedSubCategoryId;
  String? selectedSubCategoryName;

  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> subCategories = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      isLoading = true;
    });

    await _loadCategories();
    await _loadProducts();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('categorie')
              .where('parentId', isNull: true)
              .get();

      setState(() {
        categories =
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      });
    } catch (e) {
      print('Erreur lors du chargement des catégories: $e');
    }
  }

  Future<void> _loadSubCategories(String categoryId) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('categorie')
              .where('parentId', isEqualTo: categoryId)
              .get();

      setState(() {
        subCategories =
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      });
    } catch (e) {
      print('Erreur lors du chargement des sous-catégories: $e');
    }
  }

  Future<void> _loadProducts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await context.read<ProductProvider>().fetchProducts();
    }
  }

  void _showForm([Product? product]) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            child: ProductForm(
              initialProduct: product,
              onSave: (prod, newImages, existingImages) async {
                if (prod.id.isEmpty) {
                  await context.read<ProductProvider>().addProduct(
                    prod,
                    newImages,
                  );
                } else {
                  await context.read<ProductProvider>().updateProduct(
                    prod,
                    newImages,
                    existingImages,
                  );
                }
                Navigator.of(context).pop();
                _loadProducts();
              },
            ),
          ),
    );
  }

  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer ce produit ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  await context.read<ProductProvider>().deleteProduct(product);
                  Navigator.of(context).pop();
                  _loadProducts();
                },
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _selectCategory(Map<String, dynamic> category) async {
    setState(() {
      selectedCategoryId = category['id'];
      selectedCategoryName = category['nom'];
      isLoading = true;
    });

    await _loadSubCategories(category['id']);

    setState(() {
      _currentPage = 1; // Aller à la page des sous-catégories
      isLoading = false;
    });
  }

  void _selectSubCategory(Map<String, dynamic> subCategory) {
    setState(() {
      selectedSubCategoryId = subCategory['id'];
      selectedSubCategoryName = subCategory['nom'];
      _currentPage = 2; // Aller à la page des produits
    });
  }

  void _goBack() {
    setState(() {
      if (_currentPage == 2) {
        _currentPage = 1; // Retour aux sous-catégories
        selectedSubCategoryId = null;
        selectedSubCategoryName = null;
      } else if (_currentPage == 1) {
        _currentPage = 0; // Retour aux catégories
        selectedCategoryId = null;
        selectedCategoryName = null;
        subCategories = [];
      }
    });
  }

  // Fonction pour obtenir l'image appropriée pour une catégorie
  Widget _getCategoryImage(Map<String, dynamic> category) {
    String categoryName = category['nom']?.toString().toLowerCase() ?? '';

    // Correspondance des noms de catégories principales
    if (categoryName.contains('electronique') ||
        categoryName.contains('électronique')) {
      return Image.asset('assets/images/Electronique.jfif', fit: BoxFit.cover);
    } else if (categoryName.contains('vetement') ||
        categoryName.contains('vêtement')) {
      return Image.asset('assets/images/vetements.jfif', fit: BoxFit.cover);
    } else if (categoryName.contains('beaute') ||
        categoryName.contains('beauté')) {
      return Image.asset('assets/images/beaute.jfif', fit: BoxFit.cover);
    } else if (categoryName.contains('accessoire') ||
        categoryName.contains('acessoire')) {
      return Image.asset('assets/images/acessoires.jfif', fit: BoxFit.cover);
    } else if (categoryName.contains('Maison') ||
        categoryName.contains('maison')) {
      return Image.asset('assets/images/Maison.jfif', fit: BoxFit.cover);
    } else if (categoryName.contains('Sport') ||
        categoryName.contains('sport')) {
      return Image.asset('assets/images/photo.jfif', fit: BoxFit.cover);
    } else if (categoryName.contains('Fifa') || categoryName.contains('fifa')) {
      return Image.asset('assets/images/Fifaplay.jfif', fit: BoxFit.cover);
    }
    // Utiliser l'image URL si disponible
    else if (category['imageUrl'] != null) {
      return Image.network(
        category['imageUrl'],
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) =>
                const Icon(Icons.category, size: 40),
      );
    }
    // Utiliser une icône par défaut
    else {
      return const Icon(Icons.category, size: 40);
    }
  }

  // Widget pour afficher une carte de catégorie
  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return GestureDetector(
      onTap: () => _selectCategory(category),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          width:
              MediaQuery.of(context).size.width / 2 -
              24, // 2 cartes par ligne avec marge
          height: 120,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _getCategoryImage(category),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                category['nom'] ?? 'Sans nom',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fonction pour obtenir l'image appropriée pour une sous-catégorie
  Widget _getSubCategoryImage(Map<String, dynamic> subCategory) {
    String subCategoryName = subCategory['nom']?.toString().toLowerCase() ?? '';

    // Correspondance des noms de sous-catégories
    if (subCategoryName.contains('ordinateur')) {
      return Image.asset('assets/images/ordinateur.jfif', fit: BoxFit.cover);
    }
    if (subCategoryName.contains('salon')) {
      return Image.asset('assets/images/salon.jfif', fit: BoxFit.cover);
    } else if (subCategoryName.contains('smartphone') ||
        subCategoryName.contains('téléphone') ||
        subCategoryName.contains('telephone') ||
        subCategoryName.contains('phone')) {
      return Image.asset('assets/images/phone.jfif', fit: BoxFit.cover);
    } else if (subCategoryName.contains('tv') ||
        subCategoryName.contains('son') ||
        subCategoryName.contains('télévision') ||
        subCategoryName.contains('television')) {
      return Image.asset('assets/images/tv.jfif', fit: BoxFit.cover);
    } else if (subCategoryName.contains('femme')) {
      return Image.asset('assets/images/vetfemme.jfif', fit: BoxFit.cover);
    } else if (subCategoryName.contains('homme')) {
      return Image.asset('assets/images/vethomme.jpg', fit: BoxFit.cover);
    } else if (subCategoryName.contains('enfant')) {
      return Image.asset('assets/images/enfant.jfif', fit: BoxFit.cover);
    }
    // Vérifier si la sous-catégorie appartient à une catégorie principale
    else {
      // Récupérer la catégorie parente
      String? parentId = subCategory['parentId'];
      if (parentId != null) {
        // Chercher la catégorie parente dans la liste des catégories
        var parentCategory = categories.firstWhere(
          (cat) => cat['id'] == parentId,
          orElse: () => <String, dynamic>{},
        );

        if (parentCategory.isNotEmpty) {
          String parentName =
              parentCategory['nom']?.toString().toLowerCase() ?? '';

          // Utiliser l'image de la catégorie parente si pertinent
          if (parentName.contains('electronique') ||
              parentName.contains('électronique')) {
            return Image.asset(
              'assets/images/Electronique.jfif',
              fit: BoxFit.cover,
            );
          } else if (parentName.contains('vetement') ||
              parentName.contains('vêtement')) {
            return Image.asset(
              'assets/images/vetements.jfif',
              fit: BoxFit.cover,
            );
          } else if (parentName.contains('beaute') ||
              parentName.contains('beauté')) {
            return Image.asset('assets/images/beaute.jfif', fit: BoxFit.cover);
          } else if (parentName.contains('accessoire') ||
              parentName.contains('acessoire')) {
            return Image.asset(
              'assets/images/acessoires.jfif',
              fit: BoxFit.cover,
            );
          } else if (parentName.contains('Maison') ||
              parentName.contains('acessoire')) {
            return Image.asset('assets/images/Maison.jfif', fit: BoxFit.cover);
          }
        }
      }

      // Utiliser l'image URL si disponible
      if (subCategory['imageUrl'] != null) {
        return Image.network(
          subCategory['imageUrl'],
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) =>
                  const Icon(Icons.category_outlined, size: 40),
        );
      }

      // Utiliser une icône par défaut
      return const Icon(Icons.category_outlined, size: 40);
    }
  }

  // Widget pour afficher une carte de sous-catégorie
  Widget _buildSubCategoryCard(Map<String, dynamic> subCategory) {
    return GestureDetector(
      onTap: () => _selectSubCategory(subCategory),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          width:
              MediaQuery.of(context).size.width / 2 -
              24, // 2 cartes par ligne avec marge
          height: 120,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _getSubCategoryImage(subCategory),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subCategory['nom'] ?? 'Sans nom',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Page des catégories
  Widget _buildCategoriesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Catégories',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Expanded(
          child:
              categories.isEmpty
                  ? const Center(child: Text('Aucune catégorie disponible'))
                  : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      return _buildCategoryCard(categories[index]);
                    },
                  ),
        ),
      ],
    );
  }

  // Page des sous-catégories
  Widget _buildSubCategoriesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedCategoryName ?? 'Sous-catégories',
                  style: Theme.of(context).textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              subCategories.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Aucune sous-catégorie disponible'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Passer directement aux produits de cette catégorie
                            setState(() {
                              selectedSubCategoryId = null;
                              _currentPage = 2;
                            });
                          },
                          child: const Text(
                            'Voir tous les produits de cette catégorie',
                          ),
                        ),
                      ],
                    ),
                  )
                  : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: subCategories.length,
                    itemBuilder: (context, index) {
                      return _buildSubCategoryCard(subCategories[index]);
                    },
                  ),
        ),
      ],
    );
  }

  // Page des produits
  Widget _buildProductsPage() {
    final provider = context.watch<ProductProvider>();
    List<Product> filteredProducts = provider.products;

    if (selectedSubCategoryId != null) {
      filteredProducts =
          filteredProducts
              .where((p) => p.subCategoryId == selectedSubCategoryId)
              .toList();
    } else if (selectedCategoryId != null) {
      filteredProducts =
          filteredProducts
              .where((p) => p.categoryId == selectedCategoryId)
              .toList();
    }

    String title =
        selectedSubCategoryName ?? selectedCategoryName ?? 'Produits';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              filteredProducts.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Aucun produit trouvé",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        
                      ],
                    ),
                  )
                  : Stack(
                    children: [
                      ListView.builder(
                        itemCount: filteredProducts.length,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemBuilder: (context, i) {
                          final product = filteredProducts[i];
                          return ProductItem(
                            product: product.toMap(),
                            onEdit: () => _showForm(product),
                            onDelete: () => _confirmDelete(product),
                          );
                        },
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton(
                          onPressed: () => _showForm(),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();

    if (isLoading || provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Afficher la page appropriée en fonction de _currentPage
    switch (_currentPage) {
      case 0:
        return _buildCategoriesPage();
      case 1:
        return _buildSubCategoriesPage();
      case 2:
        return _buildProductsPage();
      default:
        return _buildCategoriesPage();
    }
  }
}
