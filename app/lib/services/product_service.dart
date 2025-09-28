import 'dart:io';
import 'package:app/pages/models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('produits');



  // 🔹 Ajout de produit avec enregistrement des images et de l'ID du vendeur
  Future<void> add(Product p, List<File> imageFiles) async {
    final doc = _col.doc();
    List<String> imageUrls = [];

    // Upload des nouvelles images
    for (int i = 0; i < imageFiles.length; i++) {
      final ref = FirebaseStorage.instance.ref('produits/${doc.id}_$i.jpg');
      final upload = await ref.putFile(imageFiles[i]);
      imageUrls.add(await upload.ref.getDownloadURL());
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Utilisateur non connecté");

    final data = p.toMap()
      ..['imageUrls'] = imageUrls
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['vendeurId'] = currentUser.uid; // 🔥 Ajout du vendeurId

    await doc.set(data);
  }

  // 🔹 Mise à jour avec gestion des images
  Future<void> update(Product p, List<File> newImages) async {
    List<String> imageUrls = [];

    if (newImages.isNotEmpty) {
      // Supprimer les anciennes images du Storage
      for (final url in p.imageUrls) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }

      // Uploader les nouvelles images
      for (int i = 0; i < newImages.length; i++) {
        final ref = FirebaseStorage.instance.ref('produits/${p.id}_$i.jpg');
        final upload = await ref.putFile(newImages[i]);
        imageUrls.add(await upload.ref.getDownloadURL());
      }
    } else {
      // Aucune nouvelle image sélectionnée : garder les anciennes
      imageUrls = List.from(p.imageUrls);
    }

    final data = p.toMap()..['imageUrls'] = imageUrls;
    await _col.doc(p.id).update(data);
  }

  // 🔹 Suppression d'un produit (et des images associées)
  Future<void> delete(Product p) async {
    await _col.doc(p.id).delete();
    for (final url in p.imageUrls) {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (_) {}
    }
  }
  Future<List<Product>> fetchByVendeurId(String vendeurId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('produits')
      .where('vendeurId', isEqualTo: vendeurId)
      .get();

  return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
}
}