import 'package:flutter/material.dart';
import 'package:app/services/auth_services.dart'; // Vérifiez que le chemin d'importation correspond à votre projet

class CmpdCmpd extends StatefulWidget {
  const CmpdCmpd({super.key});

  @override
  _CmpdCmpdState createState() => _CmpdCmpdState();
}

class _CmpdCmpdState extends State<CmpdCmpd> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  late AnimationController _animationController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Animation pour l'apparition de la page
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Méthode pour changer le mot de passe en utilisant l'ancien mot de passe
  Future<void> _changePassword() async {
    if (_formKey.currentState!.validate()) {
      if (_newPasswordController.text.trim() != _confirmPasswordController.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La confirmation ne correspond pas au nouveau mot de passe')),
        );
        return;
      }

      // Récupération de l'email de l'utilisateur courant
      final String? userEmail = authService.value.currentUser?.email;
      if (userEmail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucun utilisateur connecté.")),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });
      try {
        await authService.value.resetPasswordFromCurrentPassword(
          currentPassword: _currentPasswordController.text.trim(),
          newPassword: _newPasswordController.text.trim(),
          email: userEmail,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour avec succès')),
        );
        Navigator.pop(context);
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $error')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blue;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Changer le Mot de Passe',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Champ pour l'ancien mot de passe
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Ancien mot de passe',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez saisir l\'ancien mot de passe';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Champ pour le nouveau mot de passe
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez saisir le nouveau mot de passe';
                    }
                    if (value.length < 6) {
                      return 'Le mot de passe doit contenir au moins 6 caractères';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Champ pour confirmer le nouveau mot de passe
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez confirmer le nouveau mot de passe';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Bouton de validation
                Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _changePassword,
                          child: const Text(
                            'Mettre à jour le mot de passe',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold ,color: Colors.white),
                          ),
                        ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
