import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'accueil.dart';
import 'categorie.dart';
import 'offer.dart';
import 'profile.dart';
import 'identifie.dart';

class PanierPage extends StatefulWidget {
  const PanierPage({Key? key}) : super(key: key);

  @override
  _PanierPageState createState() => _PanierPageState();
}

class _PanierPageState extends State<PanierPage> {
  int _bottomNavIndex = 3;
  final _promoController = TextEditingController();
  double _promoDiscount = 0.0;
  String? _promoMessage;
  String? _appliedPromoCode; // <-- store the code if applied

  User? get _user => FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _cartStream {
    return FirebaseFirestore.instance
        .collection('panier')
        .where('userId', isEqualTo: _user?.uid)
        .snapshots();
  }

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    final query = await FirebaseFirestore.instance
        .collection('promotions')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      setState(() {
        _promoMessage = 'Code invalide';
        _promoDiscount = 0.0;
        _appliedPromoCode = null;
      });
      return;
    }

    final doc = query.docs.first;
    final data = doc.data();

    // check active
    if (data['isActive'] != true) {
      setState(() {
        _promoMessage = 'Ce code n’est pas actif';
        _promoDiscount = 0.0;
        _appliedPromoCode = null;
      });
      return;
    }

    // check expiration
    final expTs = data['expiration'] as Timestamp?;
    if (expTs == null || expTs.toDate().isBefore(DateTime.now())) {
      setState(() {
        _promoMessage = 'Ce code a expiré';
        _promoDiscount = 0.0;
        _appliedPromoCode = null;
      });
      return;
    }

    // check limits
    final usage = (data['usageCount'] as num?)?.toInt() ?? 0;
    final limit = (data['usageLimit'] as num?)?.toInt() ?? 0;
    if (usage >= limit) {
      setState(() {
        _promoMessage = 'Code épuisé';
        _promoDiscount = 0.0;
        _appliedPromoCode = null;
      });
      return;
    }

    // parse percent
    final rawValue = data['value'] as String? ?? '';
    final match = RegExp(r'(\d+)').firstMatch(rawValue);
    if (match == null) {
      setState(() {
        _promoMessage = 'Valeur de promo invalide';
        _promoDiscount = 0.0;
        _appliedPromoCode = null;
      });
      return;
    }
    final percent = double.parse(match.group(1)!);

    setState(() {
      _promoDiscount = percent / 100.0;
      _promoMessage = 'Promo appliquée : ${percent.toInt()}%';
      _appliedPromoCode = code;
    });
  }

  double _calculateSubtotal(List<_CartItem> items) {
    return items.fold(0.0, (sum, item) => sum + item.effectivePrice * item.qty);
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesPage()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OfferPage()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PanierPage()));
    } else if (index == 4) {
      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const IdentifieScreen()));
      }
    } else {
      setState(() => _bottomNavIndex = index);
    }
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panier', style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _cartStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final cartDocs = snap.data?.docs ?? [];
          if (cartDocs.isEmpty) {
            return const Center(child: Text('Votre panier est vide'));
          }
          return FutureBuilder<List<_CartItem>>(
            future: Future.wait(cartDocs.map((doc) async {
              final data = doc.data();
              final productId = data['productId'] as String;
              final prodSnap = await FirebaseFirestore.instance
                  .collection('produits')
                  .doc(productId)
                  .get();
              final prodData = prodSnap.data()!;
              final priceAtPurchase = (data['priceAtPurchase'] as num).toDouble();
              final qty = (data['quantity'] as int);
              final imageUrls = (prodData['imageUrls'] as List?)?.cast<String>() ?? [];
              return _CartItem(
                cartId: doc.id,            // keep the panier document’s ID
                productId: prodSnap.id,    // ← THIS is the real product’s ID
                name: prodData['name'] as String,
                imageUrl: imageUrls.first,
                qty: qty,
                effectivePrice: priceAtPurchase,
              );
            })),
            builder: (ctx, itemsSnap) {
              if (itemsSnap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = itemsSnap.data!;
              final subTotal = _calculateSubtotal(items);
              final discountValue = subTotal * _promoDiscount;
              final total = subTotal - discountValue;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final it = items[i];
                          return ListTile(
                            leading: it.imageUrl.isNotEmpty
                                ? Image.network(it.imageUrl,
                                    width: 50, height: 50, fit: BoxFit.cover)
                                : null,
                            title: Text(it.name),
                            subtitle: Text(
                                'DA${it.effectivePrice.toStringAsFixed(2)} x ${it.qty}'),
                            trailing: Text(
                                'DA${(it.effectivePrice * it.qty).toStringAsFixed(2)}'),
                          );
                        },
                      ),
                    ),

                    // Promo input
                    TextField(
                      controller: _promoController,
                      decoration: InputDecoration(
                        labelText: 'Code promo',
                        suffixIcon: TextButton(
                          onPressed: _applyPromo,
                          child: const Text('Appliquer'),
                        ),
                      ),
                    ),
                    if (_promoMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(_promoMessage!,
                          style: const TextStyle(color: Colors.green)),
                    ],
                    const SizedBox(height: 16),

                    // Summary
                    _buildSummaryRow('Sous-total', subTotal),
                    if (_promoDiscount > 0)
                      _buildSummaryRow('Remise', -discountValue),
                    const Divider(height: 32),
                    _buildSummaryRow('Total', total, isTotal: true),
                    const SizedBox(height: 16),

                    // Checkout button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showCheckoutDialog(context, items),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Acheter',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Catégories'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: 'Offres'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Panier'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Compte'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, double amount,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: isTotal ? 18 : 16,
                  fontWeight:
                      isTotal ? FontWeight.bold : FontWeight.normal)),
          Text('DA${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: isTotal ? 18 : 16,
                  fontWeight:
                      isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context, List<_CartItem> items) {
    final subTotal = _calculateSubtotal(items);
    final discountValue = subTotal * _promoDiscount;
    final total = subTotal - discountValue;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Confirmation d\'achat'),
        content: Text('Total à payer : DA${total.toStringAsFixed(2)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmPurchase(items, total);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPurchase(List<_CartItem> items, double total) async {
    final uid = _user?.uid;
    if (uid == null) return;

    // retrieve payment method
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final payMethod = userDoc.data()?['paymentMethod'] as String? ?? 'livraison';

    if (payMethod == 'card') {
      await _handleCardPayment(uid, items, total);
    } else {
      await _storeOrder(uid, items, total, payMethod);
      _showSuccessAnimation();
    }
  }

  Future<void> _handleCardPayment(
      String uid, List<_CartItem> items, double total) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur non identifié')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('cartepayment')
              .where('EmailProp', isEqualTo: email)
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erreur : ${snap.error}'),
              );
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 200, child: Center(child: CircularProgressIndicator()));
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const SizedBox(
                  height: 200, child: Center(child: Text('Aucune carte trouvée.')));
            }

            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: docs.map((doc) {
                  final data = doc.data();
                  final rawNum = data['numero'] as String? ?? '';
                  final masked = rawNum.length >= 4
                      ? '**** **** **** ${rawNum.substring(rawNum.length - 4)}'
                      : rawNum;
                  final owner = data['nomProp'] as String? ?? '';

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
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
                      subtitle: Text(owner),
                      onTap: () async {
                        Navigator.pop(context);
                        await _storeOrder(
                          uid,
                          items,
                          total,
                          'card',
                          paymentDetail: doc.id,
                        );
                        _showSuccessAnimation();
                      },
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _storeOrder(
  String uid,
  List<_CartItem> items,
  double total,
  String payMethod, {
  String? paymentDetail,
}) async {
  final batch = FirebaseFirestore.instance.batch();
  final orderRef =
      FirebaseFirestore.instance.collection('commandes').doc();

  // On ajoute maintenant productId à chaque item
  final produits = items.map((i) => {
  'productId': i.productId,
  'name':       i.name,
  'quantity':   i.qty,
  'unitPrice':  i.effectivePrice,
  'totalPrice': i.effectivePrice * i.qty,
  }).toList();


  final orderData = {
    'userId': uid,
    'createdAt': FieldValue.serverTimestamp(),
    'paymentMethod': payMethod,
    'paymentDetail': paymentDetail ?? '',
    'total': total,
    'products': produits,
    'promoCode': _appliedPromoCode ?? '',
    'status': 'en préparation',
  };

  batch.set(orderRef, orderData);

  // Mise à jour du promo si nécessaire
  if (_appliedPromoCode != null) {
    final promoQuery = await FirebaseFirestore.instance
        .collection('promotions')
        .where('code', isEqualTo: _appliedPromoCode)
        .limit(1)
        .get();
    if (promoQuery.docs.isNotEmpty) {
      final promoDoc = promoQuery.docs.first;
      final usage = (promoDoc.data()['usageCount'] as num?)?.toInt() ?? 0;
      batch.update(promoDoc.reference, {'usageCount': usage + 1});
    }
  }

  for (var item in items) {
    final productRef = FirebaseFirestore.instance
        .collection('produits')
        .doc(item.productId);
    batch.update(productRef, {'stock': FieldValue.increment(-item.qty)});
  }

  // Vider le panier en batch
  for (var item in items) {
  final cartRef = FirebaseFirestore.instance
      .collection('panier')
      .doc(item.cartId);
  batch.delete(cartRef);
  }


  await batch.commit();
}



  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Achat réussi !',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    });
  }
}

class _CartItem {
  final String cartId;      // ← ID of the “panier” document
  final String productId;   // ← ID of the actual produit document
  final String name;
  final String imageUrl;
  final int qty;
  final double effectivePrice;

  _CartItem({
    required this.cartId,
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.qty,
    required this.effectivePrice,
  });
}

