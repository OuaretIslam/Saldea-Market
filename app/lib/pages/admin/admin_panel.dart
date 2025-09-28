import 'package:flutter/material.dart';
import 'dashboard_section.dart';
import 'account_management.dart';
import 'catalog_managment.dart';
import 'promotions_management.dart';
import 'dispute_management.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _selectedIndex = 0;

  final List<Widget> _sections = [
    DashboardSection(),
    const AccountManagement(),
    const CatalogManagement(),
    const PromotionsManagement(),
    const DisputeManagement(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Saldae Market',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue,
        actions: [
          
        ],
      ),
      body: _sections[_selectedIndex],
      bottomNavigationBar: _buildNavBar(),
    );
  }

  BottomNavigationBar _buildNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      onTap: (index) => setState(() => _selectedIndex = index),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: 'Comptes'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Catalogue'),
        BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: 'Promos'),
        BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Litiges'),
      ],
    );
  }

 
              
            
          
        
        
      
    
  }
