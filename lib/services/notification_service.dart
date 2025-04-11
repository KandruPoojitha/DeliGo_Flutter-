import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Map to store order status listeners to avoid duplicate subscriptions
  final Map<String, StreamSubscription<DatabaseEvent>> _orderStatusListeners = {};
  
  // Map to store the previous status of each order
  final Map<String, String> _previousOrderStatuses = {};

  // Listen for order status changes for a specific order
  void listenForOrderStatusChanges({
    required String orderId,
    required String userId,
    required BuildContext context,
  }) {
    // Cancel previous listener if exists
    _orderStatusListeners[orderId]?.cancel();

    // Get the initial status and restaurant name
    FirebaseDatabase.instance
        .ref()
        .child('orders')
        .child(orderId)
        .get()
        .then((snapshot) {
      if (snapshot.exists) {
        final orderData = snapshot.value as Map<dynamic, dynamic>;
        _previousOrderStatuses[orderId] = orderData['order_status']?.toString() ?? '';
      }
    });

    // Create a new listener
    final subscription = FirebaseDatabase.instance
        .ref()
        .child('orders')
        .child(orderId)
        .onChildChanged
        .listen((event) {
      // Check if the change is related to order_status
      if (event.snapshot.key == 'order_status') {
        final newStatus = event.snapshot.value as String?;
        final previousStatus = _previousOrderStatuses[orderId];
        
        // Only show notification if status has actually changed
        if (newStatus != null && newStatus != previousStatus) {
          // Update previous status
          _previousOrderStatuses[orderId] = newStatus;
          
          // Get restaurant name for the notification
          FirebaseDatabase.instance
              .ref()
              .child('orders')
              .child(orderId)
              .once()
              .then((DatabaseEvent orderSnapshot) {
            if (orderSnapshot.snapshot.exists) {
              final orderData = orderSnapshot.snapshot.value as Map<dynamic, dynamic>;
              final restaurantName = orderData['restaurantName'] ?? 'Restaurant';
              
              switch (newStatus) {
                case 'accepted':
                  _showNotification(
                    context: context,
                    title: 'Order Accepted!',
                    message: 'Your order from $restaurantName has been accepted and is being prepared.',
                    isPositive: true,
                  );
                  break;
                case 'ready_for_pickup':
                  _showNotification(
                    context: context,
                    title: 'Order Ready!',
                    message: 'Your order from $restaurantName is ready for pickup or delivery.',
                    isPositive: true,
                  );
                  break;
                case 'assigned_driver':
                  _showNotification(
                    context: context,
                    title: 'Driver Assigned',
                    message: 'A driver has been assigned to deliver your order from $restaurantName.',
                    isPositive: true,
                  );
                  break;
                case 'driver_accepted':
                  _showNotification(
                    context: context,
                    title: 'Driver Confirmed',
                    message: 'Your driver has accepted your order from $restaurantName and will pick it up soon.',
                    isPositive: true,
                  );
                  break;
                case 'picked_up':
                  _showNotification(
                    context: context,
                    title: 'Order Picked Up',
                    message: 'Your order from $restaurantName is on the way!',
                    isPositive: true,
                  );
                  break;
                case 'delivered':
                  _showNotification(
                    context: context,
                    title: 'Order Delivered',
                    message: 'Your order from $restaurantName has been delivered. Enjoy your meal!',
                    isPositive: true,
                  );
                  break;
                case 'rejected':
                  _showNotification(
                    context: context,
                    title: 'Order Rejected',
                    message: 'We\'re sorry, but your order was rejected by $restaurantName.',
                    isPositive: false,
                  );
                  break;
              }
            }
          });
        }
      }
    });

    // Store the subscription
    _orderStatusListeners[orderId] = subscription;
  }

  // Cancel order status listener
  void cancelOrderStatusListener(String orderId) {
    _orderStatusListeners[orderId]?.cancel();
    _orderStatusListeners.remove(orderId);
    _previousOrderStatuses.remove(orderId);
  }

  // Cancel all order status listeners
  void cancelAllOrderStatusListeners() {
    for (final subscription in _orderStatusListeners.values) {
      subscription.cancel();
    }
    _orderStatusListeners.clear();
    _previousOrderStatuses.clear();
  }

  // Show in-app notification
  void _showNotification({
    required BuildContext context,
    required String title,
    required String message,
    bool isPositive = true,
  }) {
    if (!context.mounted) return;

    // Create an overlay entry to show notification from the top
    final overlayState = Overlay.of(context);
    final notification = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App icon or notification icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isPositive 
                              ? const Color(0xFFF4A261).withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isPositive ? Icons.restaurant : Icons.info_outline,
                          color: isPositive ? const Color(0xFFF4A261) : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isPositive ? Colors.black87 : Colors.orange.shade800,
                                  ),
                                ),
                                const Text(
                                  'now',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    
    // Show notification
    overlayState.insert(notification);
    
    // Remove after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      notification.remove();
    });
  }
} 