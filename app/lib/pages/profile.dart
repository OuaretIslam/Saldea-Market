// lib/pages/profile.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'accueil.dart';
import 'categorie.dart';
import 'aPropCom.dart';
import 'signin.dart';
import 'offer.dart';
import 'panier.dart';
import 'adrLivrison.dart';
import 'historyCmd.dart';
import 'chngRole.dart';
import 'methodPay.dart';
import 'servClient.dart';
import 'suiviCmd.dart';
import 'package:app/services/auth_services.dart'; // pour signOut

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  int _bottomNavIndex = 4;    // index pour "Compte"
  User? _user;                // FirebaseAuth user

  // données enrichies Firestore
  String _username    = '';
  String _email       = '';
  String _pictureUrl  = '';
  bool   _loadingData = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();

    _user = FirebaseAuth.instance.currentUser;
    _loadProfileData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationController
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Charge username, email et pic depuis Firestore
  Future<void> _loadProfileData() async {
    if (_user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();

    final data = doc.data() ?? {};
    setState(() {
      _username    = data['username'] as String? ?? _user!.displayName ?? '';
      _email       = data['email']    as String? ?? _user!.email ?? '';
      _pictureUrl  = data['pic']      as String? ?? '';
      _loadingData = false;
    });
  }

  /// Rafraîchit à la fois Auth et Firestore
  Future<void> _reloadUser() async {
    await FirebaseAuth.instance.currentUser?.reload();
    _user = FirebaseAuth.instance.currentUser;
    await _loadProfileData();
  }

  void _onBottomNavTapped(int index) {
    setState(() => _bottomNavIndex = index);
    Widget? target;
    switch (index) {
      case 0: target = const HomePage(); break;
      case 1: target = const CategoriesPage(); break;
      case 2: target = const OfferPage(); break;
      case 3: target = const PanierPage(); break;
      case 4: return; // déjà sur profile
    }
    if (target != null) {
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => target!),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await authService.value.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la déconnexion : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blue;
    const accentColor  = Colors.deepOrange;
    final backgroundColor = Colors.grey.shade100;

    // si on attend Firestore
    if (_loadingData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mon Profil'),
          backgroundColor: primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // liste d'options avec callback de reload après modif
    final options = <Map<String,dynamic>>[
      {
        'icon': Icons.person,
        'title': 'À propos du compte',
        'subtitle': 'Voir et modifier vos informations',
        'action': (BuildContext ctx) {
          Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const InfoComptePage()),
          ).then((_) => _reloadUser());
        },
      },
      {
        'icon': Icons.local_shipping,
        'title': 'Suivi de commande',
        'subtitle': 'Consulter le suivi de vos commandes',
        'action': (BuildContext ctx) {
          Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const CommandesAvecSuiviPage()),
          ).then((_) => _reloadUser());
        },
      },
      {
        'icon': Icons.history,
        'title': 'Historique des commandes',
        'subtitle': 'Voir vos commandes précédentes',
        'action': (BuildContext ctx) {
          Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const HistoriqueCommandePage()),
          ).then((_) => _reloadUser());
        },
      },
      {
        'icon': Icons.location_on,
        'title': 'Adresse de livraison',
        'subtitle': 'Gérer vos adresses',
        'action': (BuildContext ctx) {
          Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const AdresseLivraisonPage()),
          ).then((_) => _reloadUser());
        },
      },
      {
        'icon': Icons.payment,
        'title': 'Méthodes de paiement',
        'subtitle': 'Gérer vos moyens de paiement',
        'action': (BuildContext ctx) {
          Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const MethodesPaiementPage()),
          ).then((_) => _reloadUser());
        },
      },
      {
        'icon': Icons.settings,
        'title': 'Changement de role',
        'subtitle': 'Préférences et configurations',
        'action': (BuildContext ctx) {
          Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const ChangementRolePage()),
          ).then((_) => _reloadUser());
        },
      },
      {
        'icon': Icons.support_agent,
        'title': 'Service client',
        'subtitle': 'Assistance et contact',
        'action': (BuildContext ctx) {
          Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const ServClientPage()),
          ).then((_) => _reloadUser());
        },
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mon Profil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        color: backgroundColor,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // HEADER ANIMÉ : avatar / nom / email
              AnimatedBuilder(
                animation: _animationController,
                builder: (ctx, child) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, -0.5),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
                  ));
                  return SlideTransition(position: slide, child: child);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 40, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _pictureUrl.isNotEmpty
                            ? NetworkImage(_pictureUrl)
                            : null,
                        backgroundColor: const Color.fromARGB(255, 28, 183, 14).withOpacity(0.3),
                        child: _pictureUrl.isEmpty
                            ? const Icon(Icons.person,
                                size: 50, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _username.isNotEmpty
                            ? _username
                            : (_user?.displayName ?? 'Nom Utilisateur'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email.isNotEmpty
                            ? _email
                            : (_user?.email ?? 'email@exemple.com'),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // LISTE ANIMÉE D'OPTIONS
              Column(
                children: List.generate(options.length, (i) {
                  final start = 0.3 + i * (0.7 / options.length);
                  final end   = start + (0.7 / options.length);
                  final slideAnim = Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(start, end, curve: Curves.easeOut),
                  ));
                  final opt = options[i];
                  return SlideTransition(
                    position: slideAnim,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(opt['icon'], color: primaryColor, size: 24),
                      ),
                      title: Text(opt['title'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(opt['subtitle'],
                          style: const TextStyle(fontSize: 13)),
                      trailing: const Icon(Icons.keyboard_arrow_right),
                      onTap: () => (opt['action'] as Function)(context),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // BOUTON DE DÉCONNEXION ANIMÉ
              AnimatedBuilder(
                animation: _animationController,
                builder: (ctx, child) {
                  final scale = Tween<double>(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.9, 1.0, curve: Curves.elasticOut),
                    ),
                  );
                  return ScaleTransition(scale: scale, child: child);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(0.8),
                          accentColor
                        ]
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text('Se déconnecter',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      onPressed: _signOut,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.category), label: 'Catégories'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_offer), label: 'Offres'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'Panier'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Compte'),
        ],
      ),
    );
  }
}
