import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class RestaurantReviewsPage extends StatelessWidget {
  final String restaurantId;
  final String restaurantName;

  const RestaurantReviewsPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime date;
    if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      date = DateTime.parse(timestamp);
    } else {
      return '';
    }
    
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reviews for $restaurantName'),
        backgroundColor: const Color(0xFFF4A261),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref()
            .child('restaurants')
            .child(restaurantId)
            .child('ratingsandcomments')
            .onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final ratingsData = snapshot.data?.snapshot.value as Map?;
          
          if (ratingsData == null || ratingsData.isEmpty) {
            return const Center(
              child: Text('No reviews yet'),
            );
          }

          final ratings = ratingsData['rating'] as Map? ?? {};
          final comments = ratingsData['comment'] as Map? ?? {};
          final timestamps = ratingsData['timestamp'] as Map? ?? {};

          // Calculate average rating
          double averageRating = 0;
          if (ratings.isNotEmpty) {
            double totalRating = 0;
            ratings.forEach((key, value) {
              if (value is int) {
                totalRating += value;
              }
            });
            averageRating = totalRating / ratings.length;
          }

          return Column(
            children: [
              // Average Rating Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF4A261),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < averageRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 24,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${ratings.length} ${ratings.length == 1 ? 'review' : 'reviews'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Reviews List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ratings.length,
                  itemBuilder: (context, index) {
                    final customerId = ratings.keys.elementAt(index);
                    final rating = ratings[customerId] as int;
                    final comment = comments[customerId] as String?;
                    final timestamp = timestamps[customerId];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Color(0xFFF4A261),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      StreamBuilder(
                                        stream: FirebaseDatabase.instance
                                            .ref()
                                            .child('customers')
                                            .child(customerId)
                                            .child('fullName')
                                            .onValue,
                                        builder: (context, nameSnapshot) {
                                          final customerName = nameSnapshot.data?.snapshot.value as String?;
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                customerName ?? 'Anonymous Customer',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              if (timestamp != null)
                                                Text(
                                                  _formatDate(timestamp),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: List.generate(5, (index) {
                                                  return Icon(
                                                    index < rating ? Icons.star : Icons.star_border,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  );
                                                }),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (comment != null && comment.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                comment,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 