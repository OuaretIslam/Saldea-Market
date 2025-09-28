import 'package:flutter/material.dart';

class ActivityItem extends StatelessWidget {
  final Map<String, String> activity;

  const ActivityItem({super.key, required this.activity});

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'Nouvelle commande':
        return Icons.shopping_bag;
      case 'Paiement reçu':
        return Icons.attach_money;
      case 'Avis client':
        return Icons.star;
      case 'Produit épuisé':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue[50],
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getActivityIcon(activity['type']!),
          color: Colors.blue,
        ),
      ),
      title: Text(activity['type']!),
      subtitle: Text(activity['details']!),
      trailing: Text(
        activity['time']!,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }
}