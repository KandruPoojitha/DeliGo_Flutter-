import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import 'package:firebase_database/firebase_database.dart';
//import 'home_page.dart';
import 'admin/admin_dashboard.dart';
import 'driver_page.dart';
import 'customer_page.dart';
import 'restaurant_page.dart';
import 'restaurant_document_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Sign out any existing user when login page is opened
    _auth.signOut();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        final user = userCredential.user;
        if (user != null) {
          // First check if user is admin
          final adminSnapshot = await FirebaseDatabase.instance
              .ref()
              .child('admins')
              .child(user.uid)
              .get();
          
          if (adminSnapshot.exists) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminDashboard(),
                ),
              );
            }
            return;
          }

          // If not admin, check other roles
          final roles = ['customers', 'restaurants', 'drivers'];
          String? userRole;
          
          for (final role in roles) {
            final snapshot = await FirebaseDatabase.instance
                .ref()
                .child(role)
                .child(user.uid)
                .get();
            
            if (snapshot.exists) {
              userRole = role.substring(0, role.length - 1); // Remove 's' from end
              
              // If user is a driver or restaurant, check if they have completed their profile
              if (userRole == 'driver' || userRole == 'restaurant') {
                final snapshot = await FirebaseDatabase.instance
                    .ref()
                    .child('${userRole}s')
                    .child(user.uid)
                    .get();
                
                if (snapshot.exists) {
                  final userData = snapshot.value as Map<dynamic, dynamic>;
                  final documentsSubmitted = userData['documentsSubmitted'] ?? false;
                  final status = userData['status'] ?? 'pending_review';

                  // If documents are not submitted or status is pending_review, redirect to document page
                  if (!documentsSubmitted || status == 'pending_review') {
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => userRole == 'driver' 
                              ? const DriverPage() 
                              : const RestaurantDocumentPage(),
                        ),
                      );
                    }
                    return;
                  }
                }
              }
              
              // Redirect to role-specific page
              if (mounted) {
                Widget page;
                switch (userRole) {
                  case 'customer':
                    page = const CustomerPage();
                    break;
                  case 'restaurant':
                    page = const RestaurantPage();
                    break;
                  case 'driver':
                    page = const DriverPage();
                    break;
                  default:
                    page = const CustomerPage();
                }
                
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => page),
                );
              }
              return;
            }
          }

          // If no role found, redirect to customer page as default
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomerPage(),
              ),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        String message;
        switch (e.code) {
          case 'user-not-found':
            message = 'No user found with this email.';
            break;
          case 'wrong-password':
            message = 'Wrong password provided.';
            break;
          case 'invalid-email':
            message = 'The email address is invalid.';
            break;
          case 'user-disabled':
            message = 'This user account has been disabled.';
            break;
          default:
            message = 'An error occurred. Please try again.';
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Image.asset(
                      'assets/deligo_logo.jpg',
                      width: 120,
                      height: 120,
                    ),
                    const SizedBox(height: 100),
                    
                    // Email Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Password Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4A261),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Login',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                    
                    // Forgot Password
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                    ),
                    
                    // Sign Up Link
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupPage()),
                          );
                        },
                        child: const Text(
                          'Don\'t have an account? Signup',
                          style: TextStyle(
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 