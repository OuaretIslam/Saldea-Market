// lib/pages/signup.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:app/services/auth_services.dart';
import 'package:app/services/database_services.dart';
import 'package:app/modeles/users.dart';

import 'signin.dart';
import 'profile.dart';
import 'accueil.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Widget _buildField({
    required String hint,
    required IconData icon,
    required TextEditingController ctrl,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white70,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.blue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20, horizontal: 20
          ),
        ),
      ),
    );
  }

  Future<void> _signUp() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passwordCtrl.text.trim();
    final name  = _usernameCtrl.text.trim();

    if (!email.contains('@') || pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email invalide ou mot de passe trop court")),
      );
      return;
    }

    setState(() => _isLoading = true);
    UserCredential cred;
    // 1) Create Auth account
    try {
      cred = await authService.value.createAccount(
        email: email, password: pass
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Échec création compte : ${e.message}"))
      );
      setState(() => _isLoading = false);
      return;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur inconnue Auth: $e"))
      );
      setState(() => _isLoading = false);
      return;
    }

    final uid = cred.user!.uid;

    // 2) Update displayName (optional)
    if (name.isNotEmpty) {
      try {
        await authService.value.updateUsername(username: name);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible définir nom: $e"))
        );
        // continue anyway
      }
    }

    // 3) Build user model (no image, no address input, default type)
    final user = UserModel(
      uid:       uid,
      email:     email,
      username:  name,
      address:   '',            // default
      type:      ['client'],    // default
      picture:   '',            // no image
      createdAt: null,          // will become serverTimestamp()
    );

    // 4) Write to Firestore
    try {
      await DatabaseService().createUser(user);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Échec enregistrement Firestore: $e"))
      );
      setState(() => _isLoading = false);
      return;
    }

    // 5) Navigate away
    setState(() => _isLoading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Colors.white,
    body: SingleChildScrollView(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // --- your existing header & Home button ---
            Stack(children: [
              Container(
                height: 300, width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.lightBlueAccent],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(80),
                    bottomRight: Radius.circular(80),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(tag: 'logo',
                      child: Image.asset('assets/images/logo.png', height: 100)
                    ),
                    const SizedBox(height: 20),
                    const Text('Bienvenue!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 20, left: 10,
                child: IconButton(
                  icon: const Icon(Icons.home, color: Colors.white),
                  onPressed: () => Navigator.push(
                    c, MaterialPageRoute(builder: (_) => const HomePage())
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 30),

            // --- Form fields ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(children: [
                _buildField(
                  hint: "Nom d'utilisateur",
                  icon: Icons.person,
                  ctrl: _usernameCtrl
                ),
                _buildField(
                  hint: "Email",
                  icon: Icons.email,
                  ctrl: _emailCtrl
                ),
                _buildField(
                  hint: "Mot de passe",
                  icon: Icons.lock,
                  ctrl: _passwordCtrl,
                  obscure: true
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)
                      ),
                    ),
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                      ? const SizedBox(
                          width:20, height:20,
                          child: CircularProgressIndicator(
                            strokeWidth:2, color:Colors.white
                          )
                        )
                      : const Text("S'inscrire",
                          style: TextStyle(
                            fontSize:18, color:Colors.white
                          )
                        ),
                  ),
                ),

                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Déjà un compte ?"),
                  TextButton(
                    onPressed: () => Navigator.push(
                      c, MaterialPageRoute(builder: (_) => const SignInScreen())
                    ),
                    child: const Text("Sign In",
                      style: TextStyle(
                        color:Colors.blue,
                        fontWeight:FontWeight.bold
                      )
                    ),
                  ),
                ]),
              ]),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}
