// lib/service/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> addScanToHistory(Map<String, dynamic> scanResult) async {
    if (_currentUser == null) return;

    await _db
        .collection('users')
        .doc(_currentUser.uid)
        .collection('scanHistory')
        .add(scanResult);
  }

  Stream<QuerySnapshot> getScanHistory() {
    if (_currentUser == null) {
      return const Stream.empty();
    }
    return _db
        .collection('users')
        .doc(_currentUser.uid)
        .collection('scanHistory')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // --- ADD THIS METHOD ---
  Future<void> deleteScanFromHistory(String scanId) async {
    if (_currentUser == null) return;

    await _db
        .collection('users')
        .doc(_currentUser.uid)
        .collection('scanHistory')
        .doc(scanId)
        .delete();
  }
}