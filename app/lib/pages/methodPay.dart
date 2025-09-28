import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Auto-formats MM/AA by inserting “/” after two digits.
class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll('/', '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    if (digits.length > 2) {
      digits = digits.substring(0, 2) + '/' + digits.substring(2);
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class MethodesPaiementPage extends StatefulWidget {
  const MethodesPaiementPage({Key? key}) : super(key: key);

  @override
  _MethodesPaiementPageState createState() => _MethodesPaiementPageState();
}

class _MethodesPaiementPageState extends State<MethodesPaiementPage> {
  bool _livraison = false;
  bool _parCarte = false;
  bool _isSaving = false;
  final Color _primaryColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadCurrentMethod();
  }

  Future<void> _loadCurrentMethod() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final method = doc.data()?['paymentMethod'] as String? ?? 'livraison';
    setState(() {
      _livraison = method == 'livraison';
      _parCarte = method == 'card';
    });
  }

  void _onLivraisonChanged(bool val) {
    setState(() {
      _livraison = val;
      if (val) _parCarte = false;
    });
  }

  void _onParCarteChanged(bool val) {
    setState(() {
      _parCarte = val;
      if (val) _livraison = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'paymentMethod': _parCarte ? 'card' : 'livraison',
    });
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Méthode de paiement enregistrée')),
    );
  }

  Future<void> _confirmAndDelete(String docId) async {
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer suppression'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mot de passe'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (password == null || password.isEmpty) return;
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe incorrect')),
      );
      return;
    }
    // delete document
    await FirebaseFirestore.instance
        .collection('cartepayment')
        .doc(docId)
        .delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Carte supprimée')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Méthodes de paiement',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: _parCarte
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: FloatingActionButton(
                backgroundColor: _primaryColor,
                child: const Icon(Icons.add, color: Colors.white),
                onPressed: () async {
                  final added = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const AddCardPage()),
                  );
                  if (added == true) setState(() {});
                },
              ),
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Paiement à la livraison'),
                  value: _livraison,
                  onChanged: _onLivraisonChanged,
                  activeColor: _primaryColor,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Payer par carte'),
                  value: _parCarte,
                  onChanged: _onParCarteChanged,
                  activeColor: _primaryColor,
                ),
                if (_parCarte) ...[
                  const SizedBox(height: 16),
                  const Text('Cartes enregistrées :',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('cartepayment')
                        .where('EmailProp',
                            isEqualTo: FirebaseAuth.instance.currentUser!.email)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Text(
                          'Erreur : ${snap.error}',
                          style: const TextStyle(color: Colors.red),
                        );
                      }
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Text('Aucune carte trouvée.');
                      }
                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final num = data['numero'] as String? ?? '';
                          final masked = num.length >= 4
                              ? '**** **** **** ${num.substring(num.length - 4)}'
                              : num;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              leading: SizedBox(
                                width: 40,
                                child: Image.asset(
                                  'assets/images/card_logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              title: Text(masked),
                              subtitle: Text(data['nomProp'] as String? ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmAndDelete(doc.id),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Enregistrer',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddCardPage extends StatefulWidget {
  const AddCardPage({Key? key}) : super(key: key);

  @override
  _AddCardPageState createState() => _AddCardPageState();
}

class _AddCardPageState extends State<AddCardPage> {
  final _formKey = GlobalKey<FormState>();
  final _num = TextEditingController();
  final _nom = TextEditingController();
  final _expiry = TextEditingController();
  final _ccv = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _num.dispose();
    _nom.dispose();
    _expiry.dispose();
    _ccv.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final email = FirebaseAuth.instance.currentUser!.email!;
    await FirebaseFirestore.instance.collection('cartepayment').add({
      'EmailProp': email,
      'numero': _num.text.trim(),
      'nomProp': _nom.text.trim(),
      'MM/AA': _expiry.text.trim(),
      'ccv': int.tryParse(_ccv.text.trim()) ?? 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blue;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          'Ajouter une carte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _num,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Numéro de carte',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => v != null && v.replaceAll(' ', '').length == 16 ? null : '16 chiffres',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nom,
                decoration: const InputDecoration(
                  labelText: 'Nom titulaire',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => v != null && v.isNotEmpty ? null : 'Requis',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _expiry,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                  ExpiryDateFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'MM/AA',
                  hintText: 'MM/AA',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => v != null && RegExp(r'^\d{2}/\d{2}$').hasMatch(v) ? null : 'Format MM/AA',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ccv,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'CCV',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => v != null && v.length == 3 ? null : '3 chiffres',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirmer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
