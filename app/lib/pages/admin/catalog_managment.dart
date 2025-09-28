// ignore_for_file: unused_field, unused_element, unused_local_variable
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class CatalogManagement extends StatefulWidget {
  const CatalogManagement({super.key});

  @override
  State<CatalogManagement> createState() => _CatalogManagementState();
}

class _CatalogManagementState extends State<CatalogManagement> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'Gestion du Catalogue',
            style: TextStyle(color: Colors.white), // Texte blanc
          ),
          bottom: const TabBar(
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.white,
            tabs: [
              Tab(text: 'Produits', icon: Icon(Icons.shopping_bag)),
              Tab(text: 'Catégories', icon: Icon(Icons.category)),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSearchField(),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ProductsList(
                    searchQuery: _searchQuery,
                    filter: _selectedFilter,
                  ),
                  const CategoriesList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Rechercher produits...',
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
                : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }
}

class _ProductsList extends StatefulWidget {
  final String searchQuery;
  final String filter;

  const _ProductsList({required this.searchQuery, required this.filter});

  @override
  State<_ProductsList> createState() => _ProductsListState();
}

class _ProductsListState extends State<_ProductsList> {
  String _currentFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filter;
  }

  @override
  void didUpdateWidget(_ProductsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      setState(() {
        _currentFilter = widget.filter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Section de filtrage avec design moderne
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrer les produits',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _currentFilter,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items:
                            ['Tous', 'En stock', 'En rupture', 'En promotion']
                                .map(
                                  (filter) => DropdownMenuItem(
                                    value: filter,
                                    child: Text(filter),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _currentFilter = value;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          border: InputBorder.none,
                          hintText: 'État du stock',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Liste des produits
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('produits')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = snapshot.data?.docs ?? [];

              // Filtrer les produits en fonction de la recherche et du filtre
              final filteredProducts =
                  products.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] as String? ?? '';
                    final description = data['description'] as String? ?? '';
                    final stock = (data['stock'] as num?)?.toInt() ?? 0;
                    final price = (data['price'] as num?)?.toDouble() ?? 0.0;

                    // Filtre de recherche
                    final matchesSearch =
                        name.toLowerCase().contains(
                          widget.searchQuery.toLowerCase(),
                        ) ||
                        description.toLowerCase().contains(
                          widget.searchQuery.toLowerCase(),
                        );

                    // Filtre d'état du stock
                    bool matchesFilter = true;
                    switch (_currentFilter) {
                      case 'En stock':
                        matchesFilter = stock > 0;
                        break;
                      case 'En rupture':
                        matchesFilter = stock <= 0;
                        break;
                      case 'En promotion':
                        // Vous pouvez ajouter une logique pour les produits en promotion
                        // Par exemple, si vous avez un champ 'isPromo' ou un prix réduit
                        matchesFilter = false; // À adapter selon votre logique
                        break;
                      default: // 'Tous'
                        matchesFilter = true;
                    }

                    return matchesSearch && matchesFilter;
                  }).toList();

              if (filteredProducts.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final doc = filteredProducts[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final name = data['name'] as String? ?? 'Sans nom';
                  final description = data['description'] as String? ?? '';
                  final price = (data['price'] as num?)?.toDouble() ?? 0.0;
                  final stock = (data['stock'] as num?)?.toInt() ?? 0;
                  final imageUrls =
                      (data['image'] as List<dynamic>?)?.cast<String>() ?? [];
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                  return _buildProductItem(
                    context,
                    doc.id,
                    name,
                    description,
                    price,
                    stock,
                    imageUrls.isNotEmpty ? imageUrls[0] : '',
                    createdAt,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductItem(
    BuildContext context,
    String productId,
    String name,
    String description,
    double price,
    int stock,
    String imageUrl,
    DateTime? createdAt,
  ) {
    final bool isInStock = stock > 0;

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('produits')
              .doc(productId)
              .get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Erreur lors de la récupération du produit: ${snapshot.error}');
          return _buildProductItemContent(
            context,
            productId,
            name,
            description,
            price,
            stock,
            '',
            createdAt,
            isInStock,
          );
        }

        if (!snapshot.hasData) {
          return _buildProductItemContent(
            context,
            productId,
            name,
            description,
            price,
            stock,
            '',
            createdAt,
            isInStock,
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final imageUrls =
            (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
        final firstImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : '';

        return _buildProductItemContent(
          context,
          productId,
          name,
          description,
          price,
          stock,
          firstImageUrl,
          createdAt,
          isInStock,
        );
      },
    );
  }

  Widget _buildProductItemContent(
    BuildContext context,
    String productId,
    String name,
    String description,
    double price,
    int stock,
    String imageUrl,
    DateTime? createdAt,
    bool isInStock,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap:
            () => _showProductDetails(
              context,
              productId,
              name,
              description,
              price,
              stock,
              imageUrl,
              createdAt,
            ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image du produit
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    imageUrl.isNotEmpty
                        ? Image.network(
                          imageUrl,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('Erreur de chargement de l\'image: $error');
                            return Container(
                              width: 90,
                              height: 90,
                              color: Colors.grey[300],
                              child: const Icon(Icons.error_outline),
                            );
                          },
                        )
                        : Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
              ),
              const SizedBox(width: 16),
              // Informations produit
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Produit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isInStock ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isInStock ? 'En stock' : 'Rupture',
                          style: TextStyle(
                            fontSize: 12,
                            color: isInStock ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isInStock
                          ? '$stock unités disponibles'
                          : 'Temporairement indisponible',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${price.toStringAsFixed(2)} DA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDetails(
    BuildContext context,
    String productId,
    String name,
    String description,
    double price,
    int stock,
    String imageUrl,
    DateTime? createdAt,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (context, scrollController) => FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('produits')
                          .doc(productId)
                          .get(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Erreur: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    print('Données du produit: $data'); // Log pour déboguer
                    final imageUrls =
                        (data['imageUrls'] as List<dynamic>?)?.cast<String>() ??
                        [];
                    print('URLs des images: $imageUrls'); // Log pour déboguer

                    return SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Carrousel d'images
                          SizedBox(
                            height: 300,
                            child:
                                imageUrls.isEmpty
                                    ? Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 50,
                                        ),
                                      ),
                                    )
                                    : PageView.builder(
                                      itemCount: imageUrls.length,
                                      itemBuilder: (context, index) {
                                        return Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                              imageUrls[index],
                                              fit: BoxFit.cover,
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                print(
                                                  'Erreur de chargement de l\'image: $error',
                                                );
                                                return Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.error_outline,
                                                    size: 50,
                                                  ),
                                                );
                                              },
                                            ),
                                            if (index == 0)
                                              Positioned(
                                                top: 16,
                                                right: 16,
                                                child: InkWell(
                                                  onTap:
                                                      () => Navigator.pop(
                                                        context,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.9),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.close,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                          ),

                          // Détails du produit
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Produit',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            stock > 0
                                                ? Colors.green.withOpacity(0.2)
                                                : Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        stock > 0 ? 'En stock' : 'Rupture',
                                        style: TextStyle(
                                          color:
                                              stock > 0
                                                  ? Colors.green
                                                  : Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Prix: ${price.toStringAsFixed(2)} DA',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                if (createdAt != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ajouté le: ${createdAt.toString().split('.')[0]}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 24),
                                const Text(
                                  'Description',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: Colors.grey.shade700,
                                  ),
                                ),

                                const SizedBox(height: 24),
                                const Text(
                                  'Caractéristiques',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildFeatureItem('Stock', '$stock unités'),
                                _buildFeatureItem(
                                  'Prix',
                                  '${price.toStringAsFixed(2)} DA',
                                ),
                                if (createdAt != null)
                                  _buildFeatureItem(
                                    'Date d\'ajout',
                                    createdAt.toString().split('.')[0],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
    );
  }

  Widget _buildFeatureItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  void _showAdvancedFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Filtres avancés',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Catégories
                        const Text(
                          'Catégories',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                    'Tous',
                                    'Électronique',
                                    'Vêtements',
                                    'Maison',
                                    'Jardin',
                                    'Sport',
                                    'Beauté',
                                  ]
                                  .map(
                                    (cat) =>
                                        _buildFilterChip(cat, cat == 'Tous'),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 24),

                        // Prix
                        const Text(
                          'Fourchette de prix',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RangeSlider(
                          values: const RangeValues(10, 150),
                          min: 0,
                          max: 200,
                          divisions: 20,
                          labels: const RangeLabels('10DA', '150DA'),
                          onChanged: (RangeValues values) {},
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0DA',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            Text(
                              '200DA',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Disponibilité
                        const Text(
                          'Disponibilité',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSwitchOption(
                          'Produits en stock uniquement',
                          true,
                        ),
                        _buildSwitchOption('Articles en promotion', false),
                        _buildSwitchOption('Nouveautés', false),

                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Réinitialiser'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Appliquer'),
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

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {},
      backgroundColor: Colors.grey.shade200,
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade800 : Colors.black87,
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSwitchOption(String title, bool value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Switch(value: value, onChanged: (bool value) {}),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aucun produit trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos critères de recherche',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class CategoriesList extends StatefulWidget {
  const CategoriesList({Key? key}) : super(key: key);

  @override
  State<CategoriesList> createState() => _CategoriesListState();
}

class _CategoriesListState extends State<CategoriesList> {
  // État pour la navigation
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  // Pour stocker temporairement l'image sélectionnée
  File? _selectedImage;
  bool _isUploading = false;
  final _imagePicker = ImagePicker();

  // Référence à Firestore
  final _categoriesRef = FirebaseFirestore.instance.collection('categorie');
  final _storage = FirebaseStorage.instance;
  final _uuid = Uuid();

  void _resetState() {
    if (mounted) {
      setState(() {
        _selectedImage = null;
        _isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _resetState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _selectedCategoryId == null
        ? _buildCategoriesList()
        : _buildSubcategoriesList();
  }

  Widget _buildCategoriesList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Catégories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle Catégorie'),
                onPressed: () => _showAddCategoryDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                _categoriesRef
                    .where('parentId', isNull: true) // Catégories principales
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final documents = snapshot.data?.docs ?? [];
              if (documents.isEmpty) {
                return const Center(child: Text('Aucune catégorie trouvée'));
              }

              return GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children:
                    documents.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildCategoryCard(
                        context,
                        doc.id,
                        data['nom'] as String? ?? 'Sans nom',
                        data['imageUrl'] as String? ?? '',
                      );
                    }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubcategoriesList() {
    if (_selectedCategoryId == null) return Container();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedCategoryId = null;
                    _selectedCategoryName = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                '$_selectedCategoryName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Ajouter', style: TextStyle(fontSize: 14)),
                onPressed: () => _showAddSubcategoryDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                _categoriesRef
                    .where('parentId', isEqualTo: _selectedCategoryId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final documents = snapshot.data?.docs ?? [];
              if (documents.isEmpty) {
                return const Center(
                  child: Text('Aucune sous-catégorie trouvée'),
                );
              }

              return GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children:
                    documents.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildSubcategoryCard(
                        context,
                        doc.id,
                        data['nom'] as String? ?? 'Sans nom',
                        data['imageUrl'] as String? ?? '',
                      );
                    }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String categoryId,
    String categoryName,
    String imageUrl,
  ) {
    return FutureBuilder<int>(
      future: _getSubcategoriesCount(categoryId),
      builder: (context, snapshot) {
        final subcategoriesCount = snapshot.data ?? 0;

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _selectedCategoryId = categoryId;
                _selectedCategoryName = categoryName;
              });
            },
            onLongPress:
                () => _showCategoryOptions(context, categoryId, categoryName),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: ImageWithLoading(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              size: 20,
                              color: Colors.white,
                            ),
                            onPressed:
                                () => _showCategoryOptions(
                                  context,
                                  categoryId,
                                  categoryName,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          categoryName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$subcategoriesCount sous-catégories',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubcategoryCard(
    BuildContext context,
    String subcategoryId,
    String subcategoryName,
    String imageUrl,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Actions pour cliquer sur une sous-catégorie
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sous-catégorie sélectionnée : $subcategoryName'),
            ),
          );
        },
        onLongPress:
            () => _showSubcategoryOptions(
              context,
              subcategoryId,
              subcategoryName,
            ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: ImageWithLoading(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Colors.white,
                        ),
                        onPressed:
                            () => _showSubcategoryOptions(
                              context,
                              subcategoryId,
                              subcategoryName,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    subcategoryName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialogue pour ajouter une nouvelle catégorie
  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    _resetState();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Nouvelle Catégorie'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom de la catégorie',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text('Ajouter une image'),
                              onPressed: () async {
                                final image = await _pickImage();
                                if (image != null) {
                                  setDialogState(() {
                                    _selectedImage = image;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ImagePreviewWidget(
                        selectedImage: _selectedImage,
                        currentImageUrl: null,
                        isUploading: _isUploading,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      _resetState();
                      Navigator.pop(context);
                    },
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed:
                        _isUploading
                            ? null
                            : () async {
                              final categoryName = nameController.text.trim();
                              if (categoryName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Veuillez entrer un nom de catégorie',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                _isUploading = true;
                              });

                              try {
                                String? imageUrl;
                                if (_selectedImage != null) {
                                  imageUrl = await _uploadImage(
                                    _selectedImage!,
                                  );
                                }

                                final newCategoryId = _uuid.v4();
                                await _categoriesRef.doc(newCategoryId).set({
                                  'nom': categoryName,
                                  'imageUrl': imageUrl ?? '',
                                  'parentId': null,
                                  'timestamp': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));

                                _resetState();
                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Catégorie "$categoryName" ajoutée',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() {
                                  _isUploading = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e')),
                                );
                              }
                            },
                    child: const Text('Ajouter'),
                  ),
                ],
              );
            },
          ),
    );
  }

  // Dialogue pour modifier une catégorie existante
  void _showEditCategoryDialog(
    BuildContext context,
    String categoryId,
    String currentName,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );
    _resetState();
    String? currentImageUrl;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              _categoriesRef.doc(categoryId).get().then((doc) {
                if (doc.exists) {
                  final data = doc.data() as Map<String, dynamic>;
                  currentImageUrl = data['imageUrl'] as String?;
                  setDialogState(() {});
                }
              });

              return AlertDialog(
                title: const Text('Modifier Catégorie'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom de la catégorie',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text('Changer l\'image'),
                              onPressed: () async {
                                final image = await _pickImage();
                                if (image != null) {
                                  setDialogState(() {
                                    _selectedImage = image;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ImagePreviewWidget(
                        selectedImage: _selectedImage,
                        currentImageUrl: currentImageUrl,
                        isUploading: _isUploading,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      _resetState();
                      Navigator.pop(context);
                    },
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed:
                        _isUploading
                            ? null
                            : () async {
                              final newName = nameController.text.trim();
                              if (newName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Veuillez entrer un nom de catégorie',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                _isUploading = true;
                              });

                              try {
                                String? imageUrl = currentImageUrl;
                                if (_selectedImage != null) {
                                  imageUrl = await _uploadImage(
                                    _selectedImage!,
                                  );
                                }

                                await _categoriesRef.doc(categoryId).update({
                                  'nom': newName,
                                  if (imageUrl != null) 'imageUrl': imageUrl,
                                });

                                _resetState();
                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Catégorie mise à jour en "$newName"',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() {
                                  _isUploading = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e')),
                                );
                              }
                            },
                    child: const Text('Enregistrer'),
                  ),
                ],
              );
            },
          ),
    );
  }

  // Dialogue pour ajouter une nouvelle sous-catégorie
  void _showAddSubcategoryDialog(BuildContext context) {
    if (_selectedCategoryId == null) return;

    final TextEditingController nameController = TextEditingController();
    _selectedImage = null;
    bool _isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  'Nouvelle sous-catégorie pour $_selectedCategoryName',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom de la sous-catégorie',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text('Ajouter une image'),
                              onPressed: () async {
                                final image = await _pickImage();
                                if (image != null) {
                                  setDialogState(() {
                                    _selectedImage = image;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ImagePreviewWidget(
                        selectedImage: _selectedImage,
                        currentImageUrl: null,
                        isUploading: _isUploading,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        _isSubmitting
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed:
                        _isUploading || _isSubmitting
                            ? null
                            : () async {
                              final subcategoryName =
                                  nameController.text.trim();
                              if (subcategoryName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Veuillez entrer un nom de sous-catégorie',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                _isUploading = true;
                                _isSubmitting = true;
                              });

                              try {
                                String? imageUrl;
                                if (_selectedImage != null) {
                                  imageUrl = await _uploadImage(
                                    _selectedImage!,
                                  );
                                }

                                // Générer un ID unique pour la nouvelle sous-catégorie
                                final newSubcategoryId = _uuid.v4();

                                // Ajouter la sous-catégorie à Firestore
                                await _categoriesRef.doc(newSubcategoryId).set({
                                  'nom': subcategoryName,
                                  'imageUrl': imageUrl ?? '',
                                  'parentId':
                                      _selectedCategoryId, // ID de la catégorie parente
                                  'timestamp': FieldValue.serverTimestamp(),
                                });

                                // Close the dialog first
                                Navigator.of(dialogContext).pop();

                                // Then show the confirmation message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Sous-catégorie "$subcategoryName" ajoutée',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() {
                                  _isUploading = false;
                                  _isSubmitting = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e')),
                                );
                              }
                            },
                    child: const Text('Ajouter'),
                  ),
                ],
              );
            },
          ),
    );
  }

  // Dialogue pour modifier une sous-catégorie existante
  void _showEditSubcategoryDialog(
    BuildContext context,
    String subcategoryId,
    String currentName,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );
    _selectedImage = null;
    String? currentImageUrl;
    bool _isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              // Récupérer les données actuelles de la sous-catégorie
              _categoriesRef.doc(subcategoryId).get().then((doc) {
                if (doc.exists) {
                  final data = doc.data() as Map<String, dynamic>;
                  currentImageUrl = data['imageUrl'] as String?;
                  setDialogState(() {}); // Rafraîchir le dialogue
                }
              });

              return AlertDialog(
                title: const Text('Modifier Sous-catégorie'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom de la sous-catégorie',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text('Changer l\'image'),
                              onPressed: () async {
                                final image = await _pickImage();
                                if (image != null) {
                                  setDialogState(() {
                                    _selectedImage = image;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ImagePreviewWidget(
                        selectedImage: _selectedImage,
                        currentImageUrl: currentImageUrl,
                        isUploading: _isUploading,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        _isSubmitting
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed:
                        _isUploading || _isSubmitting
                            ? null
                            : () async {
                              final newName = nameController.text.trim();
                              if (newName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Veuillez entrer un nom de sous-catégorie',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                _isUploading = true;
                                _isSubmitting = true;
                              });

                              try {
                                String? imageUrl = currentImageUrl;
                                if (_selectedImage != null) {
                                  imageUrl = await _uploadImage(
                                    _selectedImage!,
                                  );
                                }

                                // Mettre à jour la sous-catégorie dans Firestore
                                await _categoriesRef.doc(subcategoryId).update({
                                  'nom': newName,
                                  if (imageUrl != null) 'imageUrl': imageUrl,
                                });

                                // Close the dialog first
                                Navigator.of(dialogContext).pop();

                                // Then show the confirmation message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Sous-catégorie mise à jour en "$newName"',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() {
                                  _isUploading = false;
                                  _isSubmitting = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e')),
                                );
                              }
                            },
                    child: const Text('Enregistrer'),
                  ),
                ],
              );
            },
          ),
    );
  }

  // Menu d'options pour les catégories
  void _showCategoryOptions(
    BuildContext context,
    String categoryId,
    String categoryName,
  ) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('Voir les sous-catégories'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedCategoryId = categoryId;
                      _selectedCategoryName = categoryName;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Modifier'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditCategoryDialog(context, categoryId, categoryName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Supprimer',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteCategory(context, categoryId, categoryName);
                  },
                ),
              ],
            ),
          ),
    );
  }

  // Menu d'options pour les sous-catégories
  void _showSubcategoryOptions(
    BuildContext context,
    String subcategoryId,
    String subcategoryName,
  ) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Modifier'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditSubcategoryDialog(
                      context,
                      subcategoryId,
                      subcategoryName,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Supprimer',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteSubcategory(
                      context,
                      subcategoryId,
                      subcategoryName,
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  // Confirmation de suppression d'une catégorie
  void _confirmDeleteCategory(
    BuildContext context,
    String categoryId,
    String categoryName,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Voulez-vous vraiment supprimer la catégorie "$categoryName" et toutes ses sous-catégories?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(context);

                  try {
                    // Récupérer d'abord toutes les sous-catégories
                    final subcategoriesSnapshot =
                        await _categoriesRef
                            .where('parentId', isEqualTo: categoryId)
                            .get();

                    // Supprimer chaque sous-catégorie
                    final batch = FirebaseFirestore.instance.batch();

                    for (final doc in subcategoriesSnapshot.docs) {
                      batch.delete(doc.reference);
                    }

                    // Supprimer la catégorie principale
                    batch.delete(_categoriesRef.doc(categoryId));

                    // Exécuter le batch
                    await batch.commit();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Catégorie "$categoryName" et ses sous-catégories supprimées',
                        ),
                        action: SnackBarAction(label: 'OK', onPressed: () {}),
                      ),
                    );

                    // Si la catégorie supprimée était sélectionnée, revenir à la liste des catégories
                    if (_selectedCategoryId == categoryId) {
                      setState(() {
                        _selectedCategoryId = null;
                        _selectedCategoryName = null;
                      });
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur lors de la suppression: $e'),
                      ),
                    );
                  }
                },
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }

  // Confirmation de suppression d'une sous-catégorie
  void _confirmDeleteSubcategory(
    BuildContext context,
    String subcategoryId,
    String subcategoryName,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Voulez-vous vraiment supprimer la sous-catégorie "$subcategoryName"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(context);

                  try {
                    await _categoriesRef.doc(subcategoryId).delete();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Sous-catégorie "$subcategoryName" supprimée',
                        ),
                        action: SnackBarAction(label: 'OK', onPressed: () {}),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur lors de la suppression: $e'),
                      ),
                    );
                  }
                },
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }

  // Fonction pour compter les sous-catégories
  Future<int> _getSubcategoriesCount(String categoryId) async {
    final querySnapshot =
        await _categoriesRef
            .where('parentId', isEqualTo: categoryId)
            .count()
            .get();

    return querySnapshot.count ?? 0;
  }

  // Sélection d'une image depuis la galerie
  Future<File?> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint('Erreur lors de la sélection de l\'image: $e');
    }
    return null;
  }

  // Upload d'une image vers Firebase Storage
  Future<String?> _uploadImage(File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imageId = const Uuid().v4();
      final imageRef = storageRef.child('categories/$imageId.jpg');

      // Compresser l'image avant l'upload
      final compressedImage = await _compressImage(imageFile);

      // Upload avec metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'picked-file-path': imageFile.path},
      );

      // Upload avec gestion de progression
      final uploadTask = imageRef.putFile(compressedImage, metadata);

      // Attendre la fin de l'upload
      final snapshot = await uploadTask;

      // Récupérer l'URL de l'image
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Erreur lors de l\'upload de l\'image: $e');
      rethrow;
    }
  }

  // Fonction pour compresser l'image
  Future<File> _compressImage(File file) async {
    // Pour l'instant, retourner le fichier original
    // TODO: Implémenter la compression d'image
    return file;
  }
}

// Widget pour confirmer une action
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;

  const ConfirmDialog({
    Key? key,
    required this.title,
    required this.content,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            onConfirm();
            Navigator.pop(context);
          },
          child: const Text('Supprimer'),
        ),
      ],
    );
  }
}

// Ajouter cette classe pour gérer le chargement des images
class ImageWithLoading extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  const ImageWithLoading({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value:
                loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('Erreur de chargement de l\'image: $error');
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.error_outline, color: Colors.red),
          ),
        );
      },
    );
  }
}

class ImagePreviewWidget extends StatelessWidget {
  final File? selectedImage;
  final String? currentImageUrl;
  final bool isUploading;

  const ImagePreviewWidget({
    Key? key,
    this.selectedImage,
    this.currentImageUrl,
    this.isUploading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Image.file(
              selectedImage!,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            if (isUploading)
              Container(
                height: 100,
                width: double.infinity,
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      );
    } else if (currentImageUrl != null && currentImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          currentImageUrl!,
          height: 100,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
