import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdresseLivraisonPage extends StatefulWidget {
  const AdresseLivraisonPage({Key? key}) : super(key: key);

  @override
  _AdresseLivraisonPageState createState() => _AdresseLivraisonPageState();
}

class _AdresseLivraisonPageState extends State<AdresseLivraisonPage> {
  final TextEditingController _addressController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _addressController.text = doc.data()?['address'] ?? '';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _confirmAndSave() async {
    final pwController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la mise à jour'),
        content: TextField(
          controller: pwController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Mot de passe',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer', style: TextStyle(color: Color.fromARGB(255, 40, 5, 238))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final password = pwController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre mot de passe')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser!;
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'authentification : ${e.message}')),
      );
      return;
    }

    final newAddress = _addressController.text.trim();
    if (newAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'adresse ne peut pas être vide')),
      );
      return;
    }

    setState(() => _isLoading = true);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'address': newAddress});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adresse mise à jour')),
    );
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blue;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Adresse de livraison',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // compact, professional TextField:
                  TextFormField(
                    controller: _addressController,
                    maxLines: 1,
                    decoration: InputDecoration(
                      labelText: 'Adresse de livraison',
                      hintText: '123 Rue Exemple, Ville',
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // original taller button style:
                  ElevatedButton(
                    onPressed: _confirmAndSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size.fromHeight(56), // ← forces 56px height
                    ),
                    child: const Text(
                      'Enregistrer',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
