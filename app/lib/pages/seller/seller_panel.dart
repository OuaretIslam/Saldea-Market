import 'dart:io';

import 'package:app/pages/models/product.dart';
import 'package:app/pages/providers/product_provider.dart';
import 'package:app/pages/seller/product_form.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard_tab.dart';
import 'shop_tab.dart';
import 'products_tab.dart';
import 'stats_tab.dart';
import 'package:app/services/auth_services.dart';
import 'package:app/pages/accueil.dart';

class SellerPanel extends StatefulWidget {
  const SellerPanel({super.key});

  @override
  _SellerPanelState createState() => _SellerPanelState();
}

class _SellerPanelState extends State<SellerPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showProductForm([Product? initialProduct]) async {
    await showDialog(
      context: context,
      builder:
          (_) => Dialog(
            child: ProductForm(
              initialProduct: initialProduct,
              onSave: (
                Product prod,
                List<File> newImages,
                List<String> existingImages,
              ) async {
                if (prod.id.isEmpty) {
                  await context.read<ProductProvider>().addProduct(
                    prod,
                    newImages,
                  );
                } else {
                  await context.read<ProductProvider>().updateProduct(
                    prod,
                    newImages,
                    existingImages,
                  );
                }
                Navigator.of(context).pop();
                _tabController.animateTo(2);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      initialProduct == null
                          ? '${prod.name} ajouté avec succès'
                          : '${prod.name} mis à jour avec succès',
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tableau de bord vendeur',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 0, 154, 197),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Déconnexion'),
                      content: const Text(
                        'Êtes-vous sûr de vouloir vous déconnecter ?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Annuler'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final authService = AuthService();
                            await authService.signOut();
                            Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const HomePage()));
                          },
                          child: const Text('Déconnexion'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              41,
                              5,
                              3,
                            ),
                          ),
                        ),
                      ],
                    ),
              );

              if (shouldLogout == true) {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.of(context).pushReplacementNamed('/signin');
              }
            },
          ),
        ],
      ),

      body: TabBarView(
        controller: _tabController,
        children: const [DashboardTab(), ShopTab(), ProductsTab(), StatsTab()],
      ),
      bottomNavigationBar: Material(
        color: const Color.fromARGB(255, 0, 154, 197),
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Tableau de bord'),
            Tab(icon: Icon(Icons.store), text: 'Boutique'),
            Tab(icon: Icon(Icons.shopping_bag), text: 'Produits'),
            Tab(icon: Icon(Icons.assessment), text: 'Statistiques'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductForm(),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
