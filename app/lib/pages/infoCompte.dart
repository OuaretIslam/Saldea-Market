// lib/pages/infoCompte.dart

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class InfoMComptePage extends StatefulWidget {
  const InfoMComptePage({Key? key}) : super(key: key);

  @override
  _InfoMComptePageState createState() => _InfoMComptePageState();
}

class _InfoMComptePageState extends State<InfoMComptePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final _picker = ImagePicker();

  // données utilisateur
  User? _user;
  String _username = '';
  String _email = '';
  String _phone = '';
  String _pictureUrl = '';
  File? _localImage;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    _user = FirebaseAuth.instance.currentUser;
    if (_user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();
    final data = doc.data() ?? {};

    setState(() {
      _username   = data['username'] as String?  ?? '';
      _email      = data['email']    as String?  ?? _user!.email ?? '';
      _phone      = data['phone']    as String?  ?? '';
      // ATTENTION : dans Firestore vous aviez 'pic' et non 'picture'
      _pictureUrl = data['pic']      as String?  ?? '';
      _loading    = false;
    });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() => _localImage = File(picked.path));
    }
  }

  /// Demande le mot de passe actuel pour la ré-authentification.
  Future<String?> _askForPassword() async {
    final ctrl = TextEditingController();
    String? pwd;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmation nécessaire'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Mot de passe actuel',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              pwd = ctrl.text.trim();
              Navigator.pop(context);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    return pwd;
  }

  Future<void> _saveChanges() async {
    if (_user == null) return;
    setState(() => _saving = true);

    // Valider le format du numéro de téléphone (format réel : chiffres, longueur 7-15, optionnel +)
    final phoneTrim = _phone.trim();
    final phoneRegExp = RegExp(r'^\+[0-9]{11,12}$');
    if (phoneTrim.isNotEmpty && !phoneRegExp.hasMatch(phoneTrim)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de téléphone non valide')),
      );
      setState(() => _saving = false);
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid);
    final Map<String, dynamic> updates = {
      'username': _username.trim(),
      'phone':    phoneTrim,
    };

    // --- 1) Email : réauthentification + updateEmail + Firestore
    if (_email.trim() != _user!.email) {
      final pwd = await _askForPassword();
      if (pwd == null || pwd.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annulé : mot de passe requis')),
        );
        setState(() => _saving = false);
        return;
      }
      try {
        // Réauthentification
        final cred = EmailAuthProvider.credential(
          email: _user!.email!,
          password: pwd,
        );
        await _user!.reauthenticateWithCredential(cred);
        // Mise à jour dans FirebaseAuth
        await _user!.updateEmail(_email.trim());
        updates['email'] = _email.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email mis à jour')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur mise à jour email : \$e')),
        );
        setState(() => _saving = false);
        return;
      }
    }

    // --- 2) Photo : upload et mise à jour du champ 'pic'
    if (_localImage != null) {
      final ref = FirebaseStorage.instance
          .ref('user_pictures/${_user!.uid}.jpg');
      try {
        final task = ref.putFile(_localImage!);
        final snap = await task.whenComplete(() => null);
        final newUrl = await snap.ref.getDownloadURL();
        updates['pic'] = newUrl;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload image : \$e')),
        );
        // on continue malgré l'erreur
      }
    }

    // --- 3) Enregistrement final dans Firestore
    try {
      await docRef.update(updates);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informations enregistrées')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur BDD : \$e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _editField({
    required String title,
    required String currentValue,
    required ValueChanged<String> onChanged,
    required TextInputType inputType,
  }) async {
    final ctrl = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: inputType,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              onChanged(ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    const primaryColor = Colors.blue;
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(value.isNotEmpty ? value : 'Non renseigné'),
          trailing: const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blue;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Infos du compte',
              style: TextStyle(color: Colors.white)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Infos du compte',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          ScaleTransition(
            scale: CurvedAnimation(
                parent: _animationController, curve: Curves.easeInOut),
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _localImage != null
                    ? FileImage(_localImage!)
                    : (_pictureUrl.isNotEmpty
                        ? NetworkImage(_pictureUrl)
                        : null) as ImageProvider<Object>?,
                backgroundColor: Colors.grey.shade300,
                child: (_localImage == null && _pictureUrl.isEmpty)
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildOption(
            icon: Icons.person,
            title: "Nom d'utilisateur",
            value: _username,
            onTap: () => _editField(
              title: "Nom d'utilisateur",
              currentValue: _username,
              inputType: TextInputType.text,
              onChanged: (v) => setState(() => _username = v),
            ),
          ),
          _buildOption(
            icon: Icons.email,
            title: 'Email',
            value: _email,
            onTap: () => _editField(
              title: 'Email',
              currentValue: _email,
              inputType: TextInputType.emailAddress,
              onChanged: (v) => setState(() => _email = v),
            ),
          ),
          _buildOption(
            icon: Icons.phone,
            title: 'Téléphone',
            value: _phone,
            onTap: () => _editField(
              title: 'Téléphone',
              currentValue: _phone,
              inputType: TextInputType.phone,
              onChanged: (v) => setState(() => _phone = v),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Enregistrer', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}
