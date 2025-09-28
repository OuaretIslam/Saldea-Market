import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Main Service Client Menu Page
class ServClientPage extends StatefulWidget {
  const ServClientPage({Key? key}) : super(key: key);

  @override
  _ServClientPageState createState() => _ServClientPageState();
}

class _ServClientPageState extends State<ServClientPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
        margin: const EdgeInsets.symmetric(vertical: 8),
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
    const primaryColor = Colors.blue;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Service client',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildOption(
              icon: Icons.report,
              title: 'Envoyer un rapport',
              subtitle: 'Signalez un problème ou une suggestion',
              color: primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SendReportPage()),
                );
              },
            ),
            _buildOption(
              icon: Icons.support_agent,
              title: 'Contacter le service client',
              subtitle: 'Nos coordonnées et support direct',
              color: primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactClientPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Page to send a report with modern animations
class SendReportPage extends StatefulWidget {
  const SendReportPage({Key? key}) : super(key: key);

  @override
  _SendReportPageState createState() => _SendReportPageState();
}

class _SendReportPageState extends State<SendReportPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _reportController = TextEditingController();
  bool _isSending = false;
  late AnimationController _buttonController;

  @override
  void initState() {
    super.initState();
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.95,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _reportController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _sendReport() async {
    final reportText = _reportController.text.trim();
    if (reportText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir votre rapport')),
      );
      return;
    }

    setState(() => _isSending = true);
    await _buttonController.reverse();
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('servclient').add({
        'rapport': reportText,
        'username': user?.email ?? user?.uid ?? 'inconnu',
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapport envoyé avec succès')),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi : \$e")),
      );
    } finally {
      setState(() => _isSending = false);
      _buttonController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blue;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Envoyer un rapport', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedOpacity(
              opacity: _isSending ? 0.5 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _reportController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Écrivez votre rapport ici...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ScaleTransition(
              scale: _buttonController,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Envoyer',
                          key: ValueKey('sendText'),
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Contact Client Page with tappable links
class ContactClientPage extends StatelessWidget {
  const ContactClientPage({Key? key}) : super(key: key);

  Future<void> _launchPhone() async {
    const phoneUri = 'tel:+33123456789';
    if (await canLaunchUrlString(phoneUri)) {
      await launchUrlString(phoneUri);
    }
  }

  Future<void> _launchEmail() async {
    const emailUri = 'mailto:support@exemple.com';
    if (await canLaunchUrlString(emailUri)) {
      await launchUrlString(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.blue;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Contact client', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Besoin d\'aide ?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.email, color: primaryColor),
              title: const Text('support@exemple.com'),
              onTap: _launchEmail,
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: primaryColor),
              title: const Text('+33 1 23 45 67 89'),
              onTap: _launchPhone,
            ),
          ],
        ),
      ),
    );
  }
}
