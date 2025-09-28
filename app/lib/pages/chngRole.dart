import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ChangementRolePage extends StatefulWidget {
  const ChangementRolePage({Key? key}) : super(key: key);

  @override
  _ChangementRolePageState createState() => _ChangementRolePageState();
}

class _ChangementRolePageState extends State<ChangementRolePage> {
  final _roles = ['Client', 'Vendeur'];
  String _selectedRole = 'Client';
  XFile? _certificatImage;
  bool _isLoading = false;
  bool _vendeurPending = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyPending();
  }

  Future<void> _checkIfAlreadyPending() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null && data['type'] == 'vendeur_en_attente') {
      setState(() => _vendeurPending = true);
    }
  }

  Future<void> _pickCertificat() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _certificatImage = picked;
      });
    }
  }

  Future<void> _submit() async {
    final uid = _auth.currentUser!.uid;
    final userDoc = _firestore.collection('users').doc(uid);

    if (_selectedRole == 'Vendeur' && _vendeurPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu as déjà soumis une demande. Patiente jusqu’à la réponse de l’admin.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedRole == 'Client') {
        await userDoc.update({'type': 'client'});
      } else {
        if (_certificatImage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez sélectionner une image de certificat.')),
          );
          setState(() => _isLoading = false);
          return;
        }
        final file = File(_certificatImage!.path);
        final ref = _storage.ref().child('travailcertificat/$uid.jpg');
        final uploadTask = ref.putFile(file);
        final snap = await uploadTask;
        final downloadUrl = await snap.ref.getDownloadURL();

        await userDoc.update({
          'type': 'vendeur_en_attente',
          'certificatUrl': downloadUrl,
          'certificatApproved': false,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rôle mis à jour avec succès.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Changement de rôle', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Choisissez un rôle',
                border: OutlineInputBorder(),
              ),
              items: _roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedRole = val!),
            ),
            const SizedBox(height: 24),
            if (_selectedRole == 'Vendeur') ...[
              GestureDetector(
                onTap: _pickCertificat,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _certificatImage == null
                      ? const Center(child: Text('Sélectionnez une image de certificat'))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_certificatImage!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24, width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Enregistrer', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
