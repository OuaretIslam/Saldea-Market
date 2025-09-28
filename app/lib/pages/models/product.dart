import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final String description;
  final int stock;
  final List<String> imageUrls;
  final List<String> colors;
  final double? promotion;
  final Timestamp createdAt;
  final String categoryId;
  final String subCategoryId;
  final String vendeurId; // ✅ ajouté

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.stock,
    required this.imageUrls,
    required this.colors,
    required this.promotion,
    required this.createdAt,
    required this.categoryId,
    required this.subCategoryId,
    required this.vendeurId, // ✅ ajouté
  });

  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Product(
      id: doc.id,
      name: data['name'] as String,
      price: (data['price'] as num).toDouble(),
      description: data['description'] as String? ?? '',
      stock: data['stock'] as int? ?? 0,
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'] as List)
          : data['image'] != null
              ? [data['image'] as String]
              : <String>[],
      colors: data['colors'] != null
          ? List<String>.from(data['colors'] as List)
          : <String>[],
      promotion: data['promotion'] != null
          ? (data['promotion'] as num).toDouble()
          : null,
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
      categoryId: data['categoryId'] as String? ?? '',
      subCategoryId: data['subCategoryId'] as String? ?? '',
      vendeurId: data['vendeurId'] as String? ?? '', // ✅ ajouté
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'description': description,
      'stock': stock,
      'imageUrls': imageUrls,
      'colors': colors,
      'promotion': promotion,
      'createdAt': createdAt,
      'categoryId': categoryId,
      'subCategoryId': subCategoryId,
      'vendeurId': vendeurId, // ✅ ajouté
    };
  }
}