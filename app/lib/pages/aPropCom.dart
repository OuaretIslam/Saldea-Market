import 'package:flutter/material.dart';
import 'chngMdp.dart';
import 'package:app/services/auth_services.dart'; // Import your authentication service file
import 'signin.dart'; // Import your sign-in screen
import 'infoCompte.dart';

class InfoComptePage extends StatefulWidget {
  const InfoComptePage({super.key});

  @override
  _InfoComptePageState createState() => _InfoComptePageState();
}

class _InfoComptePageState extends State<InfoComptePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Animation controller for a page fade-in effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Generic option widget builder for the account page
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

  // Dialog for confirming account deletion by entering email and password.
  Future<void> _showDeleteAccountDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Supprimer le compte"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Veuillez confirmer votre email et votre mot de passe pour supprimer définitivement votre compte.",
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Mot de passe",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Clear fields and close dialog
                _emailController.clear();
                _passwordController.clear();
                Navigator.of(context).pop();
              },
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_emailController.text.isEmpty ||
                    _passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Veuillez saisir votre email et mot de passe"),
                    ),
                  );
                  return;
                }

                setState(() {
                  _isProcessing = true;
                });

                try {
                  await authService.value.deleteAccount(
                    email: _emailController.text.trim(),
                    password: _passwordController.text.trim(),
                  );
                  // Clear the text fields and pop the dialog.
                  _emailController.clear();
                  _passwordController.clear();
                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Compte supprimé avec succès"),
                    ),
                  );
                  // Navigate to the sign-in screen (or appropriate screen).
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const SignInScreen()),
                    (route) => false,
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erreur lors de la suppression : $error"),
                    ),
                  );
                } finally {
                  setState(() {
                    _isProcessing = false;
                  });
                }
              },
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Supprimer"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Color palette used in the page
    final Color primaryColor = Colors.blue;
    final Color redColor = Colors.redAccent;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'À propos du compte',
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
            // Option to change account information.
            _buildOption(
              icon: Icons.edit,
              title: 'Changer les infos de compte',
              subtitle: 'Modifiez vos informations personnelles',
              color: primaryColor,
              onTap: () {
                // Navigate to account information modification page.
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InfoMComptePage()),
                );
              },
            ),
            const SizedBox(height: 16),
            // Option to change password.
            _buildOption(
              icon: Icons.lock,
              title: 'Modifier le mot de passe',
              subtitle: 'Changez votre mot de passe actuel',
              color: primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const changMDP()),
                );
              },
            ),
            const SizedBox(height: 16),
            // Option to delete the account.
            _buildOption(
              icon: Icons.delete_forever,
              title: 'Supprimer le compte',
              subtitle: 'Supprimez définitivement votre compte',
              color: redColor,
              onTap: () {
                // Show dialog to confirm deletion.
                _showDeleteAccountDialog();
              },
            ),
            const SizedBox(height: 16),
            // You may add other options below as needed.
          ],
        ),
      ),
    );
  }
}
