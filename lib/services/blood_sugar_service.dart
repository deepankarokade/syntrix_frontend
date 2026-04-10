import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BloodSugarService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Save blood sugar reading
  static Future<void> saveReading({
    required double value,
    required String type, // 'Fasting', 'Post-meal', 'Random'
    required DateTime date,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = DateTime.now().millisecondsSinceEpoch.toString();
    
    await _db
        .collection('blood_sugar_logs')
        .doc(user.uid)
        .collection('readings')
        .doc(docId)
        .set({
      'value': value,
      'type': type,
      'timestamp': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update the last reading in the user profile for quick access
    await _db.collection('users').doc(user.uid).set({
      'lastBloodSugar': value,
      'lastBloodSugarType': type,
      'lastBloodSugarTime': Timestamp.fromDate(date),
    }, SetOptions(merge: true));
  }

  /// Get the latest blood sugar reading
  static Future<Map<String, dynamic>?> getLatestReading() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await _db
        .collection('blood_sugar_logs')
        .doc(user.uid)
        .collection('readings')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data();
  }

  /// Get readings for the last 7 days
  static Future<List<Map<String, dynamic>>> getRecentReadings({int days = 7}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final cutoff = DateTime.now().subtract(Duration(days: days));
    final snapshot = await _db
        .collection('blood_sugar_logs')
        .doc(user.uid)
        .collection('readings')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
