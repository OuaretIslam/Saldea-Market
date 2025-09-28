import 'package:flutter/material.dart';
import 'signin.dart'; // Replace with your sign in page import if needed

class IdentifieScreen extends StatelessWidget {
  const IdentifieScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue, // Background color
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const SizedBox(height: 50), // Spacing at the top

            // Center Image
            Image.asset(
              'assets/images/logo.png', // Replace with your image path
              height: 300,
              width: 300,
              fit: BoxFit.cover,
            ),

            // "S'identifie" Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignInScreen(), // Replace with your desired page
                    ),
                  );
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25), // Pill shape
                  ),
                  child: const Center(
                    child: Text(
                      "S'identifie",
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 50), // Spacing at the bottom
          ],
        ),
      ),
    );
  }
}
