// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PromotionsManagement extends StatefulWidget {
  const PromotionsManagement({super.key});

  @override
  State<PromotionsManagement> createState() => _PromotionsManagementState();
}

class _PromotionsManagementState extends State<PromotionsManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _promotionsCollection = FirebaseFirestore.instance
      .collection('promotions');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [_buildHeader(context), _buildStatsRow(), _buildPromoList()],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestion des Promotions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un code...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton(
                onPressed: () => _showAddPromoDialog(context),
                backgroundColor: Colors.blue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: _promotionsCollection.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allPromoCodes = snapshot.data!.docs;
        final filteredPromoCodes =
            _searchQuery.isEmpty
                ? allPromoCodes
                : allPromoCodes.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final code = (data['code'] as String).toLowerCase();
                  final value = (data['value'] as String).toLowerCase();
                  return code.contains(_searchQuery) ||
                      value.contains(_searchQuery);
                }).toList();

        final activeCodes =
            filteredPromoCodes.where((doc) => doc['isActive'] == true).length;
        final expiredCodes =
            filteredPromoCodes
                .where(
                  (doc) => (doc['expiration'] as Timestamp).toDate().isBefore(
                    DateTime.now(),
                  ),
                )
                .length;
        final totalUsage = filteredPromoCodes.fold(
          0,
          (sum, doc) => sum + (doc['usageCount'] as int),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _StatCard(
                value: filteredPromoCodes.length.toString(),
                label: 'Codes',
                icon: Icons.discount,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _StatCard(
                value: activeCodes.toString(),
                label: 'Actifs',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _StatCard(
                value: expiredCodes.toString(),
                label: 'Expirés',
                icon: Icons.timer_off,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _StatCard(
                value: totalUsage.toString(),
                label: 'Utiliser',
                icon: Icons.shopping_cart,
                color: Colors.blue,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromoList() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          child: StreamBuilder<QuerySnapshot>(
            stream: _promotionsCollection.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Une erreur est survenue: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allPromoCodes = snapshot.data!.docs;
              final filteredPromoCodes =
                  _searchQuery.isEmpty
                      ? allPromoCodes
                      : allPromoCodes.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final code = (data['code'] as String).toLowerCase();
                        final value = (data['value'] as String).toLowerCase();
                        return code.contains(_searchQuery) ||
                            value.contains(_searchQuery);
                      }).toList();

              if (filteredPromoCodes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Aucun code promo trouvé'
                            : 'Aucun résultat pour "$_searchQuery"',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: filteredPromoCodes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final promo = filteredPromoCodes[index];
                  return _PromoCodeTile(
                    promo: PromoCode.fromFirestore(promo),
                    onTap:
                        () => _showPromoDetails(
                          context,
                          PromoCode.fromFirestore(promo),
                        ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddPromoDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    final valueController = TextEditingController();
    final usageLimitController = TextEditingController();
    DateTime? expirationDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nouveau Code Promo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: codeController,
                      decoration: InputDecoration(
                        labelText: 'Code promotionnel',
                        prefixIcon: const Icon(Icons.local_offer),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value!.isEmpty ? 'Veuillez entrer un code' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: valueController,
                      decoration: InputDecoration(
                        labelText: 'Valeur (ex: 20% ou 150DA)',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value!.isEmpty
                                  ? 'Veuillez entrer une valeur'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: usageLimitController,
                      decoration: InputDecoration(
                        labelText: 'Limite d\'utilisation',
                        prefixIcon: const Icon(Icons.timer),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) =>
                              value!.isEmpty
                                  ? 'Veuillez entrer une limite'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 7),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            expirationDate = pickedDate;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date d\'expiration',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              expirationDate != null
                                  ? DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(expirationDate!)
                                  : 'Sélectionner une date',
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.blue,
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              await _promotionsCollection.add({
                                'code': codeController.text,
                                'value': valueController.text,
                                'expiration': Timestamp.fromDate(
                                  expirationDate ??
                                      DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                ),
                                'isActive': true,
                                'usageCount': 0,
                                'usageLimit': int.parse(
                                  usageLimitController.text,
                                ),
                                'createdAt': Timestamp.now(),
                              });

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Code promo créé avec succès!',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur: ${e.toString()}'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Créer le Code',
                          style: TextStyle(color: Colors.white),
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

  void _showPromoDetails(BuildContext context, PromoCode promo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Détails du Code',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          promo.isActive
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.discount,
                      color:
                          promo.isActive &&
                                  !promo.expiration.isBefore(DateTime.now())
                              ? Colors.blue
                              : Colors.grey,
                    ),
                  ),
                  title: Text(
                    promo.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    'Valeur: ${promo.value}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Switch(
                    value: promo.isActive,
                    onChanged: (value) async {
                      try {
                        await _promotionsCollection.doc(promo.id).update({
                          'isActive': value,
                        });
                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur: ${e.toString()}'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    activeColor: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                _DetailItem(
                  icon: Icons.calendar_today,
                  label: 'Expiration',
                  value: DateFormat('dd MMM yyyy').format(promo.expiration),
                  color:
                      promo.expiration.isBefore(DateTime.now())
                          ? Colors.red
                          : null,
                ),
                _DetailItem(
                  icon: Icons.shopping_cart,
                  label: 'Utilisations',
                  value:
                      '${promo.usageCount}${promo.usageLimit != null ? '/${promo.usageLimit}' : ''}',
                ),
                _DetailItem(
                  icon: Icons.date_range,
                  label: 'Créé le',
                  value: DateFormat('dd MMM yyyy').format(promo.createdAt),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () async {
                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Confirmer la suppression'),
                                content: Text(
                                  'Êtes-vous sûr de vouloir supprimer le code ${promo.code} ?',
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirm == true) {
                            try {
                              await _promotionsCollection
                                  .doc(promo.id)
                                  .delete();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Code ${promo.code} supprimé'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur: ${e.toString()}'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Supprimer',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.blue,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditPromoDialog(context, promo);
                        },
                        child: const Text(
                          'Modifier',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  void _showEditPromoDialog(BuildContext context, PromoCode promo) {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController(text: promo.code);
    final valueController = TextEditingController(text: promo.value);
    final usageLimitController = TextEditingController(
      text: promo.usageLimit?.toString() ?? '',
    );
    DateTime? expirationDate = promo.expiration;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modifier le Code Promo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: codeController,
                      decoration: InputDecoration(
                        labelText: 'Code promotionnel',
                        prefixIcon: const Icon(Icons.local_offer),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value!.isEmpty ? 'Veuillez entrer un code' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: valueController,
                      decoration: InputDecoration(
                        labelText: 'Valeur (ex: 20% ou 150DA)',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator:
                          (value) =>
                              value!.isEmpty
                                  ? 'Veuillez entrer une valeur'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: usageLimitController,
                      decoration: InputDecoration(
                        labelText: 'Limite d\'utilisation',
                        prefixIcon: const Icon(Icons.timer),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) =>
                              value!.isEmpty
                                  ? 'Veuillez entrer une limite'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate:
                              expirationDate ??
                              DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            expirationDate = pickedDate;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date d\'expiration',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              expirationDate != null
                                  ? DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(expirationDate!)
                                  : 'Sélectionner une date',
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.blue,
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              await _promotionsCollection.doc(promo.id).update({
                                'code': codeController.text,
                                'value': valueController.text,
                                'expiration': Timestamp.fromDate(
                                  expirationDate ??
                                      DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                ),
                                'usageLimit': int.parse(
                                  usageLimitController.text,
                                ),
                              });

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Code promo modifié avec succès!',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur: ${e.toString()}'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Enregistrer les modifications',
                          style: TextStyle(color: Colors.white),
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
}

class PromoCode {
  final String id;
  final String code;
  final String value;
  final DateTime expiration;
  bool isActive;
  final int? usageLimit;
  int usageCount;
  final DateTime createdAt;

  PromoCode({
    required this.id,
    required this.code,
    required this.value,
    required this.expiration,
    required this.isActive,
    this.usageLimit,
    required this.usageCount,
    required this.createdAt,
  });

  factory PromoCode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromoCode(
      id: doc.id,
      code: data['code'] ?? '',
      value: data['value'] ?? '',
      expiration: (data['expiration'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,
      usageLimit: data['usageLimit'],
      usageCount: data['usageCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoCodeTile extends StatelessWidget {
  final PromoCode promo;
  final VoidCallback onTap;

  const _PromoCodeTile({required this.promo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isExpired = promo.expiration.isBefore(DateTime.now());

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              promo.isActive && !isExpired
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.discount,
          color: promo.isActive && !isExpired ? Colors.blue : Colors.grey,
        ),
      ),
      title: Text(
        promo.code,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isExpired ? Colors.grey : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            promo.value,
            style: TextStyle(color: isExpired ? Colors.grey : null),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 12,
                color: isExpired ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd MMM yyyy').format(promo.expiration),
                style: TextStyle(
                  fontSize: 12,
                  color: isExpired ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text('${promo.usageCount}'),
            backgroundColor: Colors.grey[100],
            labelStyle: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
