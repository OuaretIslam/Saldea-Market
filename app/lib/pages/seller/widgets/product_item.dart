import 'package:flutter/material.dart';
import 'dart:io';

class ProductItem extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const ProductItem({
    super.key,
    required this.product,
    required this.onDelete,
    required this.onEdit,
  });

  Widget _buildProductImage() {
    // 0. Vérifier imageUrls (nouveau champ)
   final urls = (product['imageUrls'] as List<dynamic>?)?.cast<String>();
  if (urls != null && urls.isNotEmpty) {
    final firstUrl = urls.first;
    if (firstUrl.startsWith('http')) {
      return Image.network(
        firstUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else {
      // chemin local
      try {
        return Image.file(
          File(firstUrl),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        );
      } catch (e) {
        debugPrint('Erreur chargement imageUrls locale: $e');
        return _buildPlaceholder();
      }
    }
  }

    // 1. Champ legacy imageFile (File direct)
    if (product['imageFile'] != null && product['imageFile'] is File) {
      return Image.file(
        product['imageFile'] as File,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
      );
    }

    // 2. Ancien champ unique 'image'
    final img = product['image'] as String?;
    if (img != null && img.isNotEmpty) {
      if (img.startsWith('http')) {
        return Image.network(
          img,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } else {
        try {
          return Image.file(
            File(img),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          );
        } catch (e) {
          debugPrint('Erreur chargement image locale: $e');
          return _buildPlaceholder();
        }
      }
    }

    // 3. Pas d'image -> placeholder
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[200],
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildProductImage(),
        ),
        title: Text(
          product['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('€${product['price']}'),
            Text('${product['stock']} en stock'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}