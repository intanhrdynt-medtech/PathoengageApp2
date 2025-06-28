// lib/screens/scan_history_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  _ScanHistoryScreenState createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _confirmDelete(BuildContext context, String scanId) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Confirm Deletion', style: GoogleFonts.poppins()),
          content: Text('Are you sure you want to delete this scan history?',
              style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () async {
                await _firestoreService.deleteScanFromHistory(scanId);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('History item deleted.',
                          style: GoogleFonts.poppins())),
                );
              },
              child: Text('Delete',
                  style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Scan History',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: AppColors.darkTeal),
        ),
        centerTitle: true,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, color: AppColors.primaryOrange),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.backgroundLighter, AppColors.mediumBrownish],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.getScanHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  'No scan history found.',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: AppColors.darkTeal,
                  ),
                ),
              );
            }

            final docs = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                return _buildHistoryCard(context, doc);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate())
        : 'No date';
    final label = data['label'] ?? 'No Label';
    final confidence = (data['confidence'] ?? 0.0) * 100;
    final imageUrl = data['imageUrl'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.backgroundLightest,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        return progress == null
                            ? child
                            : const SizedBox(
                                width: 80,
                                height: 80,
                                child: Center(
                                    child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                )));
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.error, size: 40),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.darkTeal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confidence: ${confidence.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    date,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.darkTeal.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: AppColors.primaryOrange.withOpacity(0.8)),
              onPressed: () => _confirmDelete(context, doc.id),
            ),
          ],
        ),
      ),
    );
  }
}