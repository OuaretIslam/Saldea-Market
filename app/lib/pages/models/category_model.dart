class Category {
  final String id;
  final String nom;
  final String? parentId;

  Category({required this.id, required this.nom, this.parentId});

  factory Category.fromFirestore(Map<String, dynamic> data, String id) {
    return Category(
      id: id,
      nom: data['nom'] ?? '',
      parentId: data['parentId'],
    );
  }
}
