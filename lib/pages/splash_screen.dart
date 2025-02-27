import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:deligoflutter/pages/login_page.dart';
import 'package:deligoflutter/pages/home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2)); // Show splash for 2 seconds

    if (!mounted) return;

    final User? user = _auth.currentUser;
    
    if (user != null) {
      // User is logged in, get their role from the database
      try {
        // Check in each role collection for the user
        final roles = ['customers', 'restaurants', 'drivers'];
        String? userRole;
        
        for (final role in roles) {
          final snapshot = await _database
              .child(role)
              .child(user.uid)
              .get();
          
          if (snapshot.exists) {
            userRole = role.substring(0, role.length - 1); // Remove 's' from end
            break;
          }
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(userRole: userRole ?? 'customer'),
            ),
          );
        }
      } catch (e) {
        // If there's an error, log out and go to login page
        await _auth.signOut();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      }
    } else {
      // User is not logged in
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/deligo_logo.jpg',
          width: 200,
          height: 200,
        ),
      ),
    );
  }
} 