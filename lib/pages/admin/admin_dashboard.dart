import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_management/user_management_screen.dart';
import 'chat_management/chat_management_screen.dart';
import 'order_management/order_management_screen.dart';
import 'payment_transactions/payment_transactions_screen.dart';
import '../login_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _auth = FirebaseAuth.instance;
  int _selectedIndex = -1;
  Widget _currentScreen = Container();

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error logging out. Please try again.')),
        );
      }
    }
  }

  void _navigateToScreen(int index, Widget screen) {
    setState(() {
      _selectedIndex = index;
      _currentScreen = screen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _selectedIndex == -1
          ? GridView.count(
              padding: const EdgeInsets.all(16.0),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildDashboardCard(
                  context,
                  'User Management',
                  Icons.people,
                  Colors.green,
                  () => _navigateToScreen(0, const UserManagementScreen()),
                ),
                _buildDashboardCard(
                  context,
                  'Chat Management',
                  Icons.chat,
                  Colors.orange,
                  () => _navigateToScreen(1, const ChatManagementScreen()),
                ),
                _buildDashboardCard(
                  context,
                  'Order Management',
                  Icons.receipt_long,
                  Colors.blue,
                  () => _navigateToScreen(2, const OrderManagementScreen()),
                ),
                _buildDashboardCard(
                  context,
                  'Payment Transactions',
                  Icons.payment,
                  Colors.purple,
                  () => _navigateToScreen(3, const PaymentTransactionsScreen()),
                ),
              ],
            )
          : _currentScreen,
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 