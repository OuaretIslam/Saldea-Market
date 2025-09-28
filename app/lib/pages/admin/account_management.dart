// ignore_for_file: unused_local_variable
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AccountManagement extends StatelessWidget {
  const AccountManagement({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
          'Gestion des Comptes',
          style: TextStyle(color: Colors.white), // Texte blanc
        ),
          bottom: const TabBar(
            unselectedLabelColor: Colors.white,
            tabs: [
              Tab(text: 'Vendeurs', icon: Icon(Icons.store, size: 20)),
              Tab(text: 'Utilisateurs', icon: Icon(Icons.person, size: 20)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _VendorsListView(),
            _UsersList(),
          ],
        ),
      ),
    );
  }
}

class _VendorsListView extends StatefulWidget {
  const _VendorsListView({Key? key}) : super(key: key);

  @override
  State<_VendorsListView> createState() => _VendorsListViewState();
}

class _VendorsListViewState extends State<_VendorsListView> {
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Info card inchangée
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Approuver/supprimer des vendeurs : Vérifier leur légalité (ex. : documents d\'entreprise).',
                  style: TextStyle(fontSize: 14, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _usersCollection.where('type', whereIn: ['vendeur', 'vendeur_en_attente', 'vendeur_suspendu']).snapshots(),
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Aucun vendeur trouvé.'));
              }

              final vendorDocs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: vendorDocs.length,
                itemBuilder: (BuildContext context, int index) {
                  final vendorData = vendorDocs[index].data() as Map<String, dynamic>;
                  final vendorId = vendorDocs[index].id;

                  final String username = vendorData['username'] ?? 'Nom inconnu';
                  final String email = vendorData['email'] ?? 'Email inconnu';
                  final String phone = vendorData['phone'] ?? 'Non renseigné';
                  final String type = vendorData['type'] ?? '';
                  final bool isVendorEnAttente = type == 'vendeur_en_attente';
                  final bool isVendorSuspendu = type == 'vendeur_suspendu';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      onTap: () => _showVendorDetails(context, vendorData, vendorId),
                      leading: CircleAvatar(
                        backgroundColor: isVendorSuspendu 
                            ? Colors.red.shade100
                            : isVendorEnAttente 
                                ? Colors.orange.shade100 
                                : Colors.green.shade100,
                        backgroundImage: vendorData['pic'] != null && vendorData['pic'].toString().isNotEmpty
                            ? NetworkImage(vendorData['pic'])
                            : null,
                        child: vendorData['pic'] == null || vendorData['pic'].toString().isEmpty
                            ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?')
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(username)),
                          if (isVendorEnAttente)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'En attente',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          if (isVendorSuspendu)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Suspendu',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email),
                          Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                      trailing: isVendorEnAttente
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green),
                                  onPressed: () {
                                    _showApprovalDialog(context, vendorId, username);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.block, color: Colors.red),
                                  onPressed: () {
                                    _showBlockDialog(context, vendorId, username);
                                  },
                                ),
                              ],
                            )
                          : isVendorSuspendu
                              ? IconButton(
                                  icon: const Icon(Icons.restore, color: Colors.blue),
                                  onPressed: () {
                                    _showRestoreDialog(context, vendorId, username);
                                  },
                                )
                              : IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () {
                                    _showVendorOptions(context, vendorId, username);
                                  },
                                ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSuspendDialog(BuildContext context, String vendorId, String vendorName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspendre le vendeur'),
        content: Text('Voulez-vous vraiment suspendre $vendorName ? Il ne pourra plus se connecter jusqu\'à sa réactivation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              _usersCollection.doc(vendorId).update({
                'type': 'vendeur_suspendu'
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$vendorName a été suspendu'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Suspendre', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, String vendorId, String vendorName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réactiver le vendeur'),
        content: Text('Voulez-vous vraiment réactiver $vendorName ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () {
              _usersCollection.doc(vendorId).update({
                'type': 'vendeur'
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$vendorName a été réactivé'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Réactiver', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVendorOptions(BuildContext context, String vendorId, String vendorName) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text('Suspendre le vendeur'),
            onTap: () {
              Navigator.pop(context);
              _showSuspendDialog(context, vendorId, vendorName);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Supprimer le vendeur'),
            onTap: () {
              Navigator.pop(context);
              _showDeleteDialog(context, vendorId, vendorName);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String vendorId, String vendorName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le vendeur'),
        content: Text('Voulez-vous vraiment supprimer définitivement $vendorName ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              _usersCollection.doc(vendorId).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$vendorName supprimé définitivement'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVendorDetails(BuildContext context, Map<String, dynamic> vendorData, String vendorId) {
    final String username = vendorData['username'] ?? 'Nom inconnu';
    final String email = vendorData['email'] ?? 'Email inconnu';
    final String phone = vendorData['phone'] ?? 'Téléphone inconnu';
    final bool certificatApproved = vendorData['certificatApproved'] ?? false;
    final String certificatUrl = vendorData['certificatUrl'] ?? '';
    final String address = vendorData['address'] ?? 'Adresse inconnue';
    final String type = vendorData['type'] ?? '';
    final bool isVendorEnAttente = type == 'vendeur_en_attente';
    final bool isVendorSuspendu = type == 'vendeur_suspendu';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Container(
            padding: const EdgeInsets.all(24),
            height: MediaQuery.of(context).size.height * 0.8,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Détails du Vendeur',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: vendorData['pic'] != null && vendorData['pic'].toString().isNotEmpty
                            ? NetworkImage(vendorData['pic'])
                            : null,
                          child: vendorData['pic'] == null || vendorData['pic'].toString().isEmpty
                            ? Text(
                                username.isNotEmpty ? username[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              )
                            : null,
                        ),
                        if (isVendorEnAttente)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Text(
                              'En attente',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (isVendorSuspendu)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Text(
                              'Suspendu',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      username,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Informations générales
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informations générales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailItem(
                          icon: Icons.home,
                          label: 'Adresse',
                          value: address,
                        ),
                        _DetailItem(
                          icon: Icons.phone,
                          label: 'Téléphone',
                          value: phone,
                        ),
                        _DetailItem(
                          icon: Icons.date_range,
                          label: 'Date d\'inscription',
                          value: vendorData['createdAt'] != null
                            ? DateFormat('dd/MM/yyyy').format(
                                (vendorData['createdAt'] as Timestamp).toDate())
                            : 'Date inconnue',
                        ),
                        _DetailItem(
                          icon: Icons.verified_user,
                          label: 'Statut',
                          value: isVendorEnAttente ? 'En attente' : 
                                isVendorSuspendu ? 'Suspendu' : 'Approuvé',
                          color: isVendorEnAttente ? Colors.orange : 
                                isVendorSuspendu ? Colors.red : Colors.green,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Certificat d'entreprise
                  Text(
                    'Certificat d\'entreprise',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (certificatUrl.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GestureDetector(
                          onTap: () {
                            // Agrandir l'image du certificat
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return Dialog(
                                  insetPadding: const EdgeInsets.all(20),
                                  child: Container(
                                    width: double.infinity,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AppBar(
                                          title: const Text('Certificat'),
                                          centerTitle: true,
                                          leading: IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                        ),
                                        Flexible(
                                          child: InteractiveViewer(
                                            panEnabled: true,
                                            boundaryMargin: const EdgeInsets.all(20),
                                            minScale: 0.5,
                                            maxScale: 4,
                                            child: Image.network(
                                              certificatUrl,
                                              fit: BoxFit.contain,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded / 
                                                          loadingProgress.expectedTotalBytes!
                                                        : null,
                                                  ),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return Center(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.error, color: Colors.red, size: 48),
                                                      const SizedBox(height: 8),
                                                      Text('Erreur de chargement de l\'image'),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Image.network(
                            certificatUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / 
                                        loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error, color: Colors.red, size: 48),
                                    const SizedBox(height: 8),
                                    Text('Erreur de chargement de l\'image'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade200,
                      ),
                      child: const Center(
                        child: Text('Aucun certificat disponible'),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Boutons d'action
                  if (isVendorEnAttente)
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
                            onPressed: () {
                              Navigator.pop(context);
                              _showBlockDialog(context, vendorId, username);
                            },
                            child: const Text(
                              'Refuser',
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
                              backgroundColor: Colors.green,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showApprovalDialog(context, vendorId, username);
                            },
                            child: const Text(
                              'Approuver',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                  if (isVendorSuspendu)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.green,
                        minimumSize: Size(double.infinity, 50),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showRestoreDialog(context, vendorId, username);
                      },
                      child: const Text(
                        'Réactiver le vendeur',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showApprovalDialog(BuildContext context, String vendorId, String vendorName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approuver le vendeur'),
        content: Text('Voulez-vous vraiment approuver $vendorName ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () {
              // Mettre à jour le statut du vendeur dans Firestore
              _usersCollection.doc(vendorId).update({
                'certificatApproved': true,
                'type': 'vendeur' // Changement de type de vendeur_en_attente à vendeur
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$vendorName approuvé avec succès'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context, String vendorId, String vendorName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser le vendeur'),
        content: Text('Voulez-vous vraiment refuser $vendorName ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              // Option 1: Supprimer le vendeur
              // _usersCollection.doc(vendorId).delete();
              
              // Option 2: Marquer comme refusé
              _usersCollection.doc(vendorId).update({
                'certificatApproved': false,
                'type': 'vendeur_refusé' // Marquer comme refusé
              });
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$vendorName refusé'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _UsersList extends StatelessWidget {
  const _UsersList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildInfoCard(),
        const Expanded(
          child: _UsersListView(),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.red.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Suspendre des utilisateurs : En cas de comportement abusif (spam, fraudes).',
              style: TextStyle(fontSize: 14, color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersListView extends StatefulWidget {
  const _UsersListView({Key? key}) : super(key: key);

  @override
  State<_UsersListView> createState() => _UsersListViewState();
}

class _UsersListViewState extends State<_UsersListView> {
  final CollectionReference _usersCollection = 
    FirebaseFirestore.instance.collection('users');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersCollection.where('type', arrayContains: 'client').snapshots(), // Utilisation de arrayContains
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucun utilisateur trouvé.'));
        }

        final userDocs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: userDocs.length,
          itemBuilder: (BuildContext context, int index) {
            final userData = userDocs[index].data() as Map<String, dynamic>;
            final userId = userDocs[index].id;

            final String username = userData['username'] ?? 'Nom inconnu';
            final String email = userData['email'] ?? 'Email inconnu';
            final bool isActive = userData['isActive'] ?? true;
            final bool hasWarning = userData['hasWarning'] ?? false;
            final String address = userData['address'] ?? 'Adresse inconnue';
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                onTap: () => _showUserDetails(context, userData, userId),
                leading: CircleAvatar(
                  backgroundColor: hasWarning 
                    ? Colors.orange.shade100 
                    : Colors.green.shade100,
                  backgroundImage: userData['pic'] != null && userData['pic'].toString().isNotEmpty
                    ? NetworkImage(userData['pic'])
                    : null,
                  child: userData['pic'] == null || userData['pic'].toString().isEmpty
                    ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?')
                    : null,
                ),
                title: Text(username),
                subtitle: Text(email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isActive,
                        onChanged: (bool newValue) {
                          _usersCollection.doc(userId).update({'isActive': newValue});
                        },
                        activeColor: Colors.blue,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        hasWarning ? Icons.warning : Icons.verified_user,
                        color: hasWarning ? Colors.orange : Colors.green,
                      ),
                      onPressed: () {
                        _toggleUserWarning(userId, hasWarning);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> userData, String userId) {
    final String username = userData['username'] ?? 'Nom inconnu';
    final String email = userData['email'] ?? 'Email inconnu';
    final String address = userData['address'] ?? 'Adresse inconnue';
    bool isActive = userData['isActive'] ?? true;
    bool hasWarning = userData['hasWarning'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Détails Utilisateur',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: userData['pic'] != null && userData['pic'].toString().isNotEmpty
                      ? NetworkImage(userData['pic'])
                      : null,
                    child: userData['pic'] == null || userData['pic'].toString().isEmpty
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        )
                      : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    username,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    email,
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _DetailItem(
                  icon: Icons.home,
                  label: 'Adresse',
                  value: address,
                ),
                _DetailItem(
                  icon: Icons.phone,
                  label: 'Téléphone',
                  value: userData['phone'] ?? 'Non renseigné',
                ),
                _DetailItem(
                  icon: Icons.date_range,
                  label: 'Date d\'inscription',
                  value: userData['createdAt'] != null
                    ? DateFormat('dd/MM/yyyy').format(
                        (userData['createdAt'] as Timestamp).toDate())
                    : 'Date inconnue',
                ),
                _DetailItem(
                  icon: Icons.verified_user,
                  label: 'Statut',
                  value: isActive ? 'Actif' : 'Suspendu',
                  color: isActive ? Colors.green : Colors.red,
                ),
                _DetailItem(
                  icon: Icons.warning,
                  label: 'Avertissement',
                  value: hasWarning ? 'Oui' : 'Non',
                  color: hasWarning ? Colors.orange : Colors.green,
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
                          side: BorderSide(
                            color: hasWarning ? Colors.orange : Colors.grey),
                        ),
                        onPressed: () {
                          _toggleUserWarning(userId, hasWarning);
                          setState(() {
                            hasWarning = !hasWarning;
                          });
                        },
                        child: Text(
                          hasWarning ? 'Retirer avertissement' : 'Donner avertissement',
                          style: TextStyle(
                            color: hasWarning ? Colors.orange : Colors.grey,
                          ),
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
                          _usersCollection.doc(userId).update({
                            'isActive': !isActive,
                          });
                          setState(() {
                            isActive = !isActive;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isActive 
                                ? 'Utilisateur réactivé' 
                                : 'Utilisateur suspendu'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          isActive ? 'Suspendre' : 'Activer',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleUserWarning(String userId, bool currentWarningStatus) {
    _usersCollection.doc(userId).update({
      'hasWarning': !currentWarningStatus,
    });
  }
}
