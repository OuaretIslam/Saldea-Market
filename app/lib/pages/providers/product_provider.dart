import 'dart:io';
import 'package:app/services/product_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';

class ProductProvider with ChangeNotifier {
  final _service = ProductService();
  List<Product> _items = [];
  bool _loading = false;

  List<Product> get products => _items;
  bool get isLoading => _loading;

  Future<void> fetchProducts() async {
  final vendeurId = FirebaseAuth.instance.currentUser!.uid;
  _loading = true;
  notifyListeners();

  _items = await _service.fetchByVendeurId(vendeurId); // Nouvelle méthode

  _loading = false;
  notifyListeners();
}

  Future<void> addProduct(Product p, List<File> images) async {
    await _service.add(p, images);
    await fetchProducts();
  }

  Future<void> updateProduct(Product p, List<File> images, List<String> existingImages) async {
    await _service.update(p, images);
    await fetchProducts();
  }

  Future<void> deleteProduct(Product p) async {
    // Appelle delete(Product) défini dans ProductService
    await _service.delete(p);
    // On retire l’élément de la liste locale
    _items.removeWhere((e) => e.id == p.id);
    notifyListeners();
  }
}