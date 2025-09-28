import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Auto-formats MM/AA by inserting "/" after two digits.
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

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  // User preferences
  bool _orderStatus = true;
  bool _promotions = false;
  bool _updates = true;
  bool _loading = true;

  // Tab controller for switching between notifications and settings
  late TabController _tabController;
  
  final _userDoc = FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPreferences();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final snap = await _userDoc.get();
    final data = snap.data();
    if (data != null) {
      setState(() {
        _orderStatus = data['notifyOrderStatus'] as bool? ?? _orderStatus;
        _promotions = data['notifyPromotions'] as bool? ?? _promotions;
        _updates = data['notifyUpdates'] as bool? ?? _updates;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _savePreference(String key, bool value) {
    return _userDoc.update({key: value});
  }

  // Format timestamp for display
  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    
    // Today
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "Aujourd'hui à ${DateFormat.Hm().format(date)}";
    }
    
    // Yesterday
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return "Hier à ${DateFormat.Hm().format(date)}";
    }
    
    // This week
    if (now.difference(date).inDays < 7) {
      return DateFormat.EEEE().format(date) + " à ${DateFormat.Hm().format(date)}";
    }
    
    // Older
    return DateFormat.yMd().add_Hm().format(date);
  }

  // Build notification item
  Widget _buildNotificationItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final message = data['message'] as String? ?? "Nouvelle notification";
    final sender = data['sender'] as String? ?? "System";
    final timestamp = data['timestamp'] as Timestamp? ?? Timestamp.now();
    final type = data['type'] as String? ?? "all";
    
    // Get icon based on notification type
    IconData notifIcon;
    Color iconColor;
    
    switch (type) {
      case 'order':
        notifIcon = Icons.shopping_bag_outlined;
        iconColor = Colors.orange;
        break;
      case 'promotion':
        notifIcon = Icons.local_offer_outlined;
        iconColor = Colors.purple;
        break;
      case 'update':
        notifIcon = Icons.system_update_outlined;
        iconColor = Colors.blue;
        break;
      case 'all':
      default:
        notifIcon = Icons.notifications_outlined;
        iconColor = Colors.deepOrange;
    }

    return Dismissible(
      key: Key(doc.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        // Delete notification
        FirebaseFirestore.instance.collection('notifications').doc(doc.id).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification supprimée')),
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Mark as read
            FirebaseFirestore.instance
                .collection('notifications')
                .doc(doc.id)
                .update({'isRead': true});  // Changed from 'read' to 'isRead'
            
            // Show notification details
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(notifIcon, color: iconColor),
                    const SizedBox(width: 8),
                    Text(sender, style: const TextStyle(fontSize: 18)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            );
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(notifIcon, color: iconColor, size: 24),
            ),
            title: Text(
              sender,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: data['isRead'] == true ? Colors.grey[700] : Colors.black,  // Changed from 'read' to 'isRead'
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: data['isRead'] == true ? Colors.grey[600] : Colors.black87,  // Changed from 'read' to 'isRead'
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            trailing: data['isRead'] != true  // Changed from 'read' to 'isRead'
                ? Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  // Empty notifications state
  Widget _buildEmptyNotifications() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined, 
            size: 100, 
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Pas de notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous n\'avez aucune notification pour le moment',
            style: TextStyle(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blue;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Notifications', icon: Icon(Icons.notifications_outlined)),
            Tab(text: 'Paramètres', icon: Icon(Icons.settings_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Notifications tab
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              // Loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              // Error state
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Erreur: ${snapshot.error}'),
                    ],
                  ),
                );
              }
              
              // Empty state
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyNotifications();
              }
              
              // Notifications list
              return RefreshIndicator(
                onRefresh: () async {
                  // Just to provide the refresh UI feedback
                  await Future.delayed(const Duration(milliseconds: 800));
                  setState(() {});
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    // Sort the docs by timestamp in memory
                    final sortedDocs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final aTimestamp = a['timestamp'] as Timestamp;
                        final bTimestamp = b['timestamp'] as Timestamp;
                        return bTimestamp.compareTo(aTimestamp); // Descending order
                      });
                    return _buildNotificationItem(sortedDocs[index]);
                  },
                ),
              );
            },
          ),
          
          // Settings tab
          ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Préférences des notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Statut des commandes'),
                subtitle: const Text('Notifications sur vos commandes et livraisons'),
                value: _orderStatus,
                onChanged: (v) {
                  setState(() => _orderStatus = v);
                  _savePreference('notifyOrderStatus', v);
                },
                activeColor: primaryColor,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shopping_bag_outlined, color: primaryColor),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Promotions'),
                subtitle: const Text('Offres spéciales et remises'),
                value: _promotions,
                onChanged: (v) {
                  setState(() => _promotions = v);
                  _savePreference('notifyPromotions', v);
                },
                activeColor: primaryColor,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_offer_outlined, color: Colors.purple),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Mises à jour'),
                subtitle: const Text('Nouveautés et informations importantes'),
                value: _updates,
                onChanged: (v) {
                  setState(() => _updates = v);
                  _savePreference('notifyUpdates', v);
                },
                activeColor: primaryColor,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.system_update_outlined, color: Colors.orange),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Marquer tout comme lu'),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.done_all, color: Colors.green),
                ),
                onTap: () {
                  // Mark all notifications as read
                  FirebaseFirestore.instance
                      .collection('notifications')
                      .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                      .where('isRead', isEqualTo: false)  // Changed from 'read' to 'isRead'
                      .get()
                      .then((snapshot) {
                    for (var doc in snapshot.docs) {
                      doc.reference.update({'isRead': true});  // Changed from 'read' to 'isRead'
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Toutes les notifications ont été marquées comme lues')),
                    );
                  });
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Supprimer toutes les notifications'),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_sweep, color: Colors.red),
                ),
                onTap: () {
                  // Show confirmation dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Supprimer toutes les notifications'),
                      content: const Text('Êtes-vous sûr de vouloir supprimer toutes vos notifications ?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // Delete all notifications
                            FirebaseFirestore.instance
                                .collection('notifications')
                                .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                                .get()
                                .then((snapshot) {
                              for (var doc in snapshot.docs) {
                                doc.reference.delete();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Toutes les notifications ont été supprimées')),
                              );
                            });
                          },
                          child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}