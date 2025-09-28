import 'package:flutter/material.dart';
import 'cMdpEmail.dart';
import 'cMdpCmdp.dart' ;

class changMDP extends StatefulWidget {
  const changMDP({super.key});

  @override
  _changMDPState createState() => _changMDPState();
}

class _changMDPState extends State<changMDP>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // Contrôleur d'animation pour un effet d'apparition sur toute la page
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Widget générique pour créer les options d'actions
  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 13),
          ),
          trailing: const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Palette de couleurs utilisée
    final Color primaryColor = Colors.blue;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Changement de mot de passe',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bouton pour SUPPRIMER LE COMPTE
            
            _buildOption(
              icon: Icons.lock,
              title: 'En utilisent l\'ancien Mot de passe',
              subtitle: 'changer votre mot de passe actuel en utilisant l\'ancien mot de passe',
              color: primaryColor,
              onTap: () {
                // Implémentez ici la navigation ou l'action pour modifier les mdp du compte
                Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CmpdCmpd(),
                              ),
                            );
              },
            ),
            const SizedBox(height: 16),
            // Bouton pour MODIFIER LE MOT DE PASSE
            _buildOption(
              icon: Icons.email,
              title: "En utilisant l'email",
              subtitle: 'Changez votre mot de passe actuel en utilisant l\'email',
              color: primaryColor,
              onTap: () {
                // Implémentez ici la navigation vers la page de modification du mot de passe
                Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CmpdEmail(),
                              ),
                            );
              },
            ),
            const SizedBox(height: 16),
            // Bouton pour CHANGER LES INFOS DE COMPTE
            // Vous pouvez ajouter d'autres options si nécessaire en reprenant le modèle ci-dessus.
          ],
        ),
      ),
    );
  }
}
