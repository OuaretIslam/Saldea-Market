import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import '../models/product.dart';
import '../models/category_model.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ProductForm extends StatefulWidget {
  final Product? initialProduct;
  final void Function(Product prod, List<File> newImages, List<String> existingImages) onSave;

  const ProductForm({
    Key? key,
    this.initialProduct,
    required this.onSave,
  }) : super(key: key);

  @override
  _ProductFormState createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _promotionController = TextEditingController();
  final _colorController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Category> mainCategories = [];
  List<Category> subCategories = [];
  Category? selectedMainCategory;
  Category? selectedSubCategory;

  List<File> _pickedImages = [];
  List<String> _existingImageUrls = [];
  List<String> _colors = [];
  bool _hasPromotion = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      _loadInitialProduct(widget.initialProduct!);
    }
    fetchMainCategories();
  }

  void _loadInitialProduct(Product p) {
    _nameController.text = p.name;
    _priceController.text = p.price.toString();
    _descriptionController.text = p.description;
    _quantityController.text = p.stock.toString();
    _colors = List.from(p.colors);
    _hasPromotion = p.promotion != null;
    if (_hasPromotion) {
      _promotionController.text = p.promotion!.toString();
    }
    _existingImageUrls = List.from(p.imageUrls);
    selectedMainCategory = Category(id: p.categoryId, nom: '', parentId: null);
    selectedSubCategory = Category(id: p.subCategoryId, nom: '', parentId: p.categoryId);
  }

  Future<void> fetchMainCategories() async {
    final snap = await _firestore.collection('categorie').where('parentId', isNull: true).get();
    setState(() {
      mainCategories = snap.docs.map((d) => Category.fromFirestore(d.data(), d.id)).toList();
      if (selectedMainCategory != null) {
        selectedMainCategory = mainCategories.firstWhereOrNull((c) => c.id == selectedMainCategory!.id);
        if (selectedMainCategory != null) {
          fetchSubCategories(selectedMainCategory!.id);
        }
      }
    });
  }

  Future<void> fetchSubCategories(String parentId) async {
    final snap = await _firestore.collection('categorie').where('parentId', isEqualTo: parentId).get();
    setState(() {
      subCategories = snap.docs.map((d) => Category.fromFirestore(d.data(), d.id)).toList();
      if (selectedSubCategory != null) {
        selectedSubCategory = subCategories.firstWhereOrNull((c) => c.id == selectedSubCategory!.id);
      }
    });
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;
    if (picked.length + _pickedImages.length + _existingImageUrls.length > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 images autorisées.')),
      );
      return;
    }
    setState(() {
      _pickedImages.addAll(picked.map((x) => File(x.path)));
    });
  }

  void _saveProduct() {
    if (!_formKey.currentState!.validate()) return;

    final prod = Product(
      id: widget.initialProduct?.id ?? '',
      name: _nameController.text.trim(),
      price: double.parse(_priceController.text),
      description: _descriptionController.text.trim(),
      stock: int.parse(_quantityController.text),
      imageUrls: _existingImageUrls,
      createdAt: Timestamp.now(),
      categoryId: selectedMainCategory?.id ?? '',
      subCategoryId: selectedSubCategory?.id ?? '',
      colors: _colors,
      promotion: _hasPromotion ? double.tryParse(_promotionController.text) ?? 0 : null,
      vendeurId: FirebaseAuth.instance.currentUser!.uid, // ✅ ID du vendeur actuel
    );

    widget.onSave(prod, _pickedImages, _existingImageUrls);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialProduct == null ? 'Ajouter un produit' : 'Modifier le produit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_nameController, 'Nom'),
              _buildTextField(_priceController, 'Prix', isNumber: true),
              _buildTextField(_descriptionController, 'Description', maxLines: 3),
              _buildTextField(_quantityController, 'Stock', isNumber: true),
              const SizedBox(height: 16),
              _buildDropdown<Category>(
                value: selectedMainCategory,
                items: mainCategories,
                label: 'Catégorie principale',
                onChanged: (cat) {
                  setState(() {
                    selectedMainCategory = cat;
                    selectedSubCategory = null;
                  });
                  if (cat != null) fetchSubCategories(cat.id);
                },
              ),
              _buildDropdown<Category>(
                value: selectedSubCategory,
                items: subCategories,
                label: 'Sous-catégorie',
                onChanged: (cat) => setState(() => selectedSubCategory = cat),
              ),
              const SizedBox(height: 16),
              _buildImagePickerSection(),
              _buildColorField(),
              _buildPromotionField(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveProduct,
                child: Text(widget.initialProduct == null ? 'Ajouter' : 'Mettre à jour'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: isNumber ? TextInputType.number : null,
        maxLines: maxLines,
        validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required String label,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(labelText: label),
      value: value,
      items: items
          .map((e) => DropdownMenuItem<T>(
                value: e,
                child: Text((e as dynamic).nom),
              ))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Requis' : null,
    );
  }

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Images (max 3)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ..._existingImageUrls.map((url) => Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                    GestureDetector(
                      onTap: () => setState(() => _existingImageUrls.remove(url)),
                      child: const Icon(Icons.close, color: Colors.red),
                    ),
                  ],
                )),
            ..._pickedImages.map((file) => Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
                    GestureDetector(
                      onTap: () => setState(() => _pickedImages.remove(file)),
                      child: const Icon(Icons.close, color: Colors.red),
                    ),
                  ],
                )),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Ajouter des images'),
        ),
      ],
    );
  }

  Widget _buildColorField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Couleurs disponibles', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _colorController,
                decoration: const InputDecoration(hintText: 'Ex : rouge'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: () {
                final c = _colorController.text.trim();
                if (c.isNotEmpty && !_colors.contains(c)) {
                  setState(() => _colors.add(c));
                  _colorController.clear();
                }
              },
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          children: _colors
              .map((c) => Chip(
                    label: Text(c),
                    onDeleted: () => setState(() => _colors.remove(c)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPromotionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('En promotion'),
          value: _hasPromotion,
          onChanged: (v) => setState(() => _hasPromotion = v ?? false),
        ),
        if (_hasPromotion)
          TextField(
            controller: _promotionController,
            decoration: const InputDecoration(labelText: 'Valeur (%)'),
            keyboardType: TextInputType.number,
          ),
      ],
    );
  }
}