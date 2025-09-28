import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductDetailsPage extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> productDoc;
  final List<String> imageUrls;

  const ProductDetailsPage({
    Key? key,
    required this.productDoc,
    required this.imageUrls,
  }) : super(key: key);

  @override
  _ProductDetailsPageState createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late Map<String, dynamic> data;
  late List<String> _images;
  int _currentImage = 0;
  bool _isFavorite = false;
  String? _selectedColor;
  double? _userRating;
  bool _hasRated = false;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    data = widget.productDoc.data()!;
    _images = widget.imageUrls;

    // Safe colors list
    final List<String> colorNames =
        (data['colors'] as List?)?.whereType<String>().toList() ??
        ['Black', 'White', 'Blue'];
    _selectedColor = colorNames.first;
    _checkUserRating();
  }

  Future<void> _checkUserRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('produits')
          .doc(widget.productDoc.id)
          .collection('ratings')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _hasRated = true;
          _userRating = (doc.data()!['rating'] as num).toDouble();
        });
      }
    }
  }

  Future<Map<int, int>> _fetchRatingCounts() async {
    final snap = await FirebaseFirestore.instance
        .collection('produits')
        .doc(widget.productDoc.id)
        .collection('ratings')
        .get();
    final counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (var d in snap.docs) {
      final r = (d['rating'] as num).toInt();
      counts[r] = counts[r]! + 1;
    }
    return counts;
  }

  Future<void> _submitRating(double rating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _hasRated) return;
    // Save rating
    await FirebaseFirestore.instance
        .collection('produits')
        .doc(widget.productDoc.id)
        .collection('ratings')
        .doc(user.uid)
        .set({'rating': rating});
    // Save comment if any
    final commentText = _commentController.text.trim();
    if (commentText.isNotEmpty) {
      final profile = user.photoURL ?? '';
      final displayName = user.displayName ?? 'Anonyme';
      await FirebaseFirestore.instance
          .collection('produits')
          .doc(widget.productDoc.id)
          .collection('comments')
          .add({
        'userId': user.uid,
        'userName': displayName,
        'profilePic': profile,
        'rating': rating,
        'comment': commentText,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    _commentController.clear();
    setState(() {
      _hasRated = true;
      _userRating = rating;
    });
  }

  Color _colorFromName(String name) {
    switch (name.toLowerCase()) {
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'blue':
        return Colors.blue;
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Sans nom';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    final desc = data['description'] as String? ?? '';
    final stock = data['stock'] as int? ?? 0;
    final ts = data['createdAt'] as Timestamp?;
    final date = ts != null ? DateFormat.yMMMd().format(ts.toDate()) : 'N/A';
    final List<String> colorNames =
        (data['colors'] as List?)?.whereType<String>().toList() ??
        ['Black', 'White', 'Blue'];

    // --- Promotion parsing fix! ---
    final dynamic rawPromo = data['promotion'];
    double promoPercent = 0.0;
    if (rawPromo is num) {
      promoPercent = rawPromo.toDouble();
    } else if (rawPromo is String) {
      promoPercent = double.tryParse(
              rawPromo.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0.0;
    }
    // discounted price even if promoPercent == 0
    final discountedPrice = price * (1 - promoPercent / 100);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _CircleIconButton(
          icon: Icons.arrow_back,
          onTap: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _CircleIconButton(
              icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
              iconColor: _isFavorite ? Colors.red : Colors.blue,
              onTap: () => setState(() => _isFavorite = !_isFavorite),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Image carousel
          if (_images.isNotEmpty)
            CarouselSlider(
              options: CarouselOptions(
                height: MediaQuery.of(context).size.height * 0.4,
                viewportFraction: 1.0,
                onPageChanged: (i, _) => setState(() => _currentImage = i),
              ),
              items: _images
                  .map((url) => CachedNetworkImage(
                        imageUrl: url,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.error),
                      ))
                  .toList(),
            ),
          if (_images.length > 1)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _images.asMap().entries.map((e) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentImage == e.key ? 12 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentImage == e.key
                          ? Colors.blue
                          : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            ),

          // Details
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Title & Price
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (promoPercent > 0)
                          Text(
                            '${price.toStringAsFixed(2)}DA',
                            style: const TextStyle(
                              fontSize: 16,
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                          ),
                        Text(
                          promoPercent > 0
                              ? '${discountedPrice.toStringAsFixed(2)}DA'
                              : '${price.toStringAsFixed(2)}DA',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Promo badge
                if (promoPercent > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '-${promoPercent.toInt()}%',
                      style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Description
                Text('Description',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700)),
                const SizedBox(height: 8),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.black87)),
                const SizedBox(height: 24),

                // Stock & Date
                Text('Détails',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text('En stock :',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[700])),
                    ),
                    Text('$stock',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text('Ajouté le :',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[700])),
                    ),
                    Text(date,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 24),

                // Colors
                Text('Couleurs',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colorNames.map((n) {
                    final c = _colorFromName(n);
                    final isSel = _selectedColor == n;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = n),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.black,
                              width: isSel ? 2 : 1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // Ratings breakdown
                Text('Évaluations',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700)),
                const SizedBox(height: 8),
                FutureBuilder<Map<int, int>>(
                  future: _fetchRatingCounts(),
                  builder: (ctx, snap) {
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child:
                              CircularProgressIndicator());
                    }
                    final counts = snap.data!;
                    final total = counts.values
                        .fold(0, (a, b) => a + b);
                    return Column(
                      children: List.generate(5, (i) {
                        final star = 5 - i;
                        final cnt = counts[star]!;
                        final pct =
                            total > 0 ? cnt / total : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 2),
                          child: Row(children: [
                            Text('$star★'),
                            const SizedBox(width: 8),
                            Expanded(
                              child:
                                  LinearProgressIndicator(
                                value: pct,
                                backgroundColor:
                                    Colors.grey[200],
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('$cnt'),
                          ]),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // User rating & comment
                Text('Votre note',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700)),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) {
                    final s = i + 1;
                    return IconButton(
                      icon: Icon(
                        _hasRated
                            ? (s <= (_userRating ?? 0)
                                ? Icons.star
                                : Icons.star_border)
                            : Icons.star_border,
                        color: Colors.blue,
                      ),
                      onPressed: _hasRated
                          ? null
                          : () => setState(
                              () => _userRating = s.toDouble()),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 1,
                  enabled: !_hasRated,
                  decoration: InputDecoration(
                    hintText: 'Votre commentaire…',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.send,
                          color: (_commentController
                                          .text
                                          .trim()
                                          .isEmpty ||
                                      _hasRated ||
                                      _userRating == null)
                                  ? Colors.grey
                                  : Colors.blue),
                      onPressed: (_commentController
                                      .text
                                      .trim()
                                      .isEmpty ||
                                  _hasRated ||
                                  _userRating == null)
                          ? null
                          : () => _submitRating(_userRating!),
                    ),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(30)),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 16),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),

                // Comments list
                Text('Commentaires',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700)),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('produits')
                      .doc(widget.productDoc.id)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (snap.data!.docs.isEmpty) {
                      return const Text(
                        'Aucun commentaire pour le moment',
                        style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic),
                      );
                    }
                    return Column(
                      children: snap.data!.docs.map((d) {
                        final m = d.data()! as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(
                              bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey
                                    .withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 8,
                                offset:
                                    const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  margin: const EdgeInsets.only(
                                      right: 16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.green
                                        .shade100,
                                  ),
                                  child: ClipOval(
                                    child: Builder(
                                        builder:
                                            (context) {
                                      final profilePic =
                                          m['profilePic']
                                              ?.toString();
                                      if (profilePic
                                              ?.isEmpty ??
                                          true) {
                                        return Icon(
                                          Icons.person,
                                          color: Colors.green
                                              .shade800,
                                          size: 32,
                                        );
                                      }
                                      return CachedNetworkImage(
                                        imageUrl:
                                            profilePic!,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (_, __) =>
                                                const CircularProgressIndicator(),
                                        errorWidget: (
                                                _,
                                                __,
                                                ___) =>
                                            const Icon(
                                                Icons.person),
                                      );
                                    }),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            (m['userName']
                                                    as String?) ??
                                                'Invité',
                                            style: const TextStyle(
                                                fontSize:
                                                    16,
                                                fontWeight:
                                                    FontWeight
                                                        .w600),
                                          ),
                                          const Spacer(),
                                          Row(
                                            children: List.generate(
                                              5,
                                              (i) => Icon(
                                                i <
                                                        (m['rating']
                                                                as num)
                                                            .toInt()
                                                    ? Icons
                                                        .star_rounded
                                                    : Icons
                                                        .star_border_rounded,
                                                size: 18,
                                                color: Colors
                                                    .amber
                                                    .shade600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                          height: 8),
                                      Text(
                                        m['comment']
                                                ?.toString() ??
                                            '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey
                                              .shade700,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(
                                          height: 6),
                                      if (m['timestamp'] !=
                                          null)
                                        Text(
                                          DateFormat(
                                                  'dd MMM yyyy à HH:mm')
                                              .format(
                                            (m['timestamp']
                                                    as Timestamp)
                                                .toDate(),
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey
                                                .shade500,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Add to cart button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: ElevatedButton(
              onPressed: () => _showAddToCartDialog(
                  context, data),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(8)),
              ),
              child: const Text(
                'Ajouter au panier',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToCartDialog(
      BuildContext context, Map<String, dynamic> product) {
    final availableColors =
        (product['colors'] as List?)
            ?.whereType<String>()
            .toList() ??
        ['Black', 'White', 'Blue'];
    String chosenColor = _selectedColor!;
    int chosenQty = 1;
    final stock = product['stock'] as int? ?? 0;
    final basePrice = (product['price'] as num).toDouble();

    // — SAFE promotion parse again —
    final dynamic rawPromo = product['promotion'];
    double promoPercent = 0.0;
    if (rawPromo is num) {
      promoPercent = rawPromo.toDouble();
    } else if (rawPromo is String) {
      promoPercent = double.tryParse(
              rawPromo.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0.0;
    }
    final effectivePrice =
        basePrice * (1 - promoPercent / 100);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Ajouter au panier'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: chosenColor,
                  items: availableColors
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(
                      () => chosenColor = v!),
                  decoration: const InputDecoration(
                      labelText: 'Couleur'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '$chosenQty',
                  decoration: const InputDecoration(
                      labelText: 'Quantité'),
                  keyboardType:
                      TextInputType.number,
                  onChanged: (v) {
                    final q = int.tryParse(v) ?? 1;
                    setState(() => chosenQty = q);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                    'Prix unitaire: ${effectivePrice.toStringAsFixed(2)}DA'),
                const SizedBox(height: 4),
                Text(
                  'Total: ${(effectivePrice * chosenQty).toStringAsFixed(2)}DA',
                  style:
                      const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  if (chosenQty > stock) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                            content: Text(
                                'Quantité dépasse le stock')));
                    return;
                  }
                  final userId = FirebaseAuth
                      .instance.currentUser!.uid;
                  await FirebaseFirestore.instance
                      .collection('panier')
                      .add({
                    'userId': userId,
                    'productId':
                        widget.productDoc.id,
                    'color': chosenColor,
                    'quantity': chosenQty,
                    'priceAtPurchase':
                        effectivePrice,
                    'timestamp':
                        FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(
                          content: Text(
                              'Produit ajouté au panier')));
                },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  const _CircleIconButton({
    Key? key,
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.blue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }
}
