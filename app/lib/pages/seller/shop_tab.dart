import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/services.dart';

class ShopTab extends StatefulWidget {
  const ShopTab({super.key});

  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(); // Nouveau champ pour téléphone
  
  File? _imageFile;
  String? _imageUrl;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _hasChanges = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  // Ajout d'un contrôleur de focus pour gérer le focus entre les champs
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadShopData();
    
    // Initialisation de l'animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    // Écouter les changements dans les champs pour détecter les modifications
    _nameController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_isInitialLoading && !_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
      _animationController.forward();
    }
  }

  Future<void> _loadShopData() async {
    setState(() => _isInitialLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isInitialLoading = false);
        return;
      }
      
      final query = await FirebaseFirestore.instance
          .collection('magasins')
          .where('vendeurId', isEqualTo: user.uid)
          .limit(1)
          .get();
          
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        setState(() {
          _nameController.text = data['nom'] ?? '';
          _addressController.text = data['adresse'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['telephone'] ?? '';
          _imageUrl = data['image'] ?? '';
        });
      }
    } catch (e) {
      _showErrorSnackBar("Erreur lors du chargement des données: $e");
    } finally {
      setState(() {
        _isInitialLoading = false;
        _hasChanges = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sélectionner une image',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      context,
                      Icons.camera_alt,
                      'Appareil photo',
                      ImageSource.camera,
                    ),
                    _buildImageSourceOption(
                      context,
                      Icons.photo_library,
                      'Galerie',
                      ImageSource.gallery,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (source == null) return;

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
      );
      
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
          _hasChanges = true;
        });
        _animationController.forward();
      }
    } catch (e) {
      _showErrorSnackBar("Erreur lors de la sélection de l'image: $e");
    }
  }

  Widget _buildImageSourceOption(
    BuildContext context,
    IconData icon,
    String label,
    ImageSource source,
  ) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(source),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadImage(File image) async {
    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });
      
      final fileName = 'magasins/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      
      // Afficher la progression du téléchargement
      final uploadTask = ref.putFile(image);
      
      uploadTask.snapshotEvents.listen((event) {
        setState(() {
          _uploadProgress = event.bytesTransferred / event.totalBytes;
        });
      });
      
      await uploadTask;
      
      setState(() {
        _isUploading = false;
      });
      
      return await ref.getDownloadURL();
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showErrorSnackBar("Erreur lors du téléchargement de l'image: $e");
      return null;
    }
  }

  Future<void> _saveShopData() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      String? imageUrl = _imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
        if (imageUrl == null) {
          setState(() => _isLoading = false);
          return;
        }
      }
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar("Vous devez être connecté pour effectuer cette action");
        setState(() => _isLoading = false);
        return;
      }
      
      final query = await FirebaseFirestore.instance
          .collection('magasins')
          .where('vendeurId', isEqualTo: user.uid)
          .limit(1)
          .get();
          
      final shopData = {
        'nom': _nameController.text,
        'adresse': _addressController.text,
        'description': _descriptionController.text,
        'email': _emailController.text,
        'telephone': _phoneController.text,
        'image': imageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (query.docs.isNotEmpty) {
        // Mettre à jour le document existant
        await query.docs.first.reference.update(shopData);
      } else {
        // Créer un nouveau document
        shopData['createdAt'] = FieldValue.serverTimestamp();
        shopData['vendeurId'] = user.uid;
        await FirebaseFirestore.instance.collection('magasins').add(shopData);
      }
      
      setState(() {
        _hasChanges = false;
      });
      _animationController.reverse();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text("Magasin enregistré avec succès"),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      _showErrorSnackBar("Erreur lors de l'enregistrement: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges) {
      return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Modifications non enregistrées'),
          content: const Text(
            'Vous avez des modifications non enregistrées. Voulez-vous vraiment quitter sans sauvegarder?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ANNULER'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('QUITTER'),
            ),
          ],
        ),
      ) ?? false;
    }
    return true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _addressFocus.dispose();
    _descriptionFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Chargement des informations...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paramètres de la boutique',
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Personnalisez les informations de votre boutique',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            GestureDetector(
                              onTap: _isLoading ? null : _pickImage,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                  image: _imageFile != null
                                      ? DecorationImage(
                                          image: FileImage(_imageFile!),
                                          fit: BoxFit.cover,
                                        )
                                      : (_imageUrl != null && _imageUrl!.isNotEmpty)
                                          ? DecorationImage(
                                              image: NetworkImage(_imageUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : const DecorationImage(
                                              image: AssetImage('assets/images/default_shop.png'),
                                              fit: BoxFit.cover,
                                            ),
                                ),
                              ),
                            ),
                            if (_isUploading)
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: _uploadProgress,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            if (!_isUploading)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          nextFocus: _addressFocus,
                          label: 'Nom de la boutique',
                          icon: Icons.store,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Le nom de la boutique est requis'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _addressController,
                          focusNode: _addressFocus,
                          nextFocus: _descriptionFocus,
                          label: 'Adresse de la boutique',
                          icon: Icons.location_on,
                          validator: (value) => value == null || value.isEmpty
                              ? 'L\'adresse est requise'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _descriptionController,
                          focusNode: _descriptionFocus,
                          nextFocus: _emailFocus,
                          label: 'Description',
                          icon: Icons.description,
                          maxLines: 3,
                          helperText: 'Décrivez votre boutique en quelques mots',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          nextFocus: _phoneFocus,
                          label: 'Email de contact',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'L\'email est requis';
                            }
                            if (!EmailValidator.validate(value)) {
                              return 'Veuillez entrer un email valide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          focusNode: _phoneFocus,
                          label: 'Téléphone (optionnel)',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          helperText: 'Numéro de téléphone pour les clients',
                        ),
                        const SizedBox(height: 32),
                        AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, -10 * _animation.value),
                              child: Opacity(
                                opacity: _hasChanges ? 1.0 : 0.0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.amber.shade800,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Vous avez des modifications non enregistrées',
                                          style: TextStyle(
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Voici la partie qui cause probablement le débordement
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Utiliser LayoutBuilder pour s'adapter à la largeur disponible
                            return Column(
                              children: [
                                if (_hasChanges)
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton(
                                      onPressed: _isLoading ? null : () {
                                        _loadShopData();
                                      },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Annuler'),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: (_isLoading || (!_hasChanges && _imageFile == null))
                                         ? null
                                         : _saveShopData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      disabledBackgroundColor: Colors.grey.shade300,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.save),
                                              const SizedBox(width: 8),
                                              // Utiliser FittedBox pour éviter le débordement du texte
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    _hasChanges
                                                         ? 'Enregistrer les modifications'
                                                         : 'Aucune modification',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.help_outline, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Conseils pour votre boutique',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTipItem(
                          icon: Icons.image,
                          title: 'Ajoutez une belle image',
                          description: 'Une image de qualité attire plus de clients.',
                        ),
                        const SizedBox(height: 12),
                        _buildTipItem(
                          icon: Icons.description,
                          title: 'Description détaillée',
                          description: 'Décrivez clairement ce que votre boutique propose.',
                        ),
                        const SizedBox(height: 12),
                        _buildTipItem(
                          icon: Icons.contact_phone,
                          title: 'Coordonnées complètes',
                          description: 'Facilitez le contact pour vos clients potentiels.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      enabled: !_isLoading,
      onFieldSubmitted: (_) {
        if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        }
      },
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        prefixIcon: Icon(icon, color: Colors.blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
