// lib/screens/scan_result_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fp_pemrograman/colors.dart';
import 'package:fp_pemrograman/service/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanResultScreen extends StatefulWidget {
  final String imagePath;
  final Map<String, dynamic> analysisResult;
  final String detectedEczemaType;

  const ScanResultScreen({
    super.key,
    required this.imagePath,
    required this.analysisResult,
    required this.detectedEczemaType,
  });

  @override
  _ScanResultScreenState createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isSaving = false;
  String? _notificationMessage;
  bool _isError = false;

  Future<String> _uploadImage(String imagePath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    final fileName = basename(imagePath);
    final destination = 'scan_images/${user.uid}/$fileName';

    final ref = FirebaseStorage.instance.ref(destination);
    final uploadTask = await ref.putFile(File(imagePath));
    return await uploadTask.ref.getDownloadURL();
  }

  void _saveScanResult() async {
    setState(() {
      _isSaving = true;
      _notificationMessage = null; // Reset previous message
    });

    try {
      final imageUrl = await _uploadImage(widget.imagePath);

      final scanResult = {
        'imageUrl': imageUrl,
        'label': widget.analysisResult['label'],
        'confidence': widget.analysisResult['confidence'],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestoreService.addScanToHistory(scanResult);

      setState(() {
        _notificationMessage = 'Scan saved successfully!';
        _isError = false;
      });

    } catch (e) {
      setState(() {
        _notificationMessage = 'Failed to save scan. Please try again.';
        _isError = true;
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String detectedType = widget.analysisResult['label'] ?? 'Unknown';
    final double confidence = (widget.analysisResult['confidence'] ?? 0.0) * 100;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.backgroundLighter, AppColors.mediumBrownish],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Hasil Scan',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: AppColors.darkTeal),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: AppColors.primaryOrange),
            onPressed: () => Navigator.of(context).pop(),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ini adalah hasil scan Anda:",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryOrange,
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Image.file(
                  File(widget.imagePath),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              _buildResultCard(
                title: 'Tipe Terdeteksi',
                value: detectedType,
                icon: Icons.biotech_outlined,
                iconColor: AppColors.secondaryTeal,
              ),
              const SizedBox(height: 16),
              _buildResultCard(
                title: 'Tingkat Keyakinan',
                value: '${confidence.toStringAsFixed(1)}%',
                icon: Icons.verified_user_outlined,
                iconColor: AppColors.primaryOrange,
              ),
              const SizedBox(height: 24),
              if (_isSaving)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveScanResult,
                    icon: const Icon(Icons.save_alt, color: Colors.white),
                    label: Text('Save to History',
                        style: GoogleFonts.poppins(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              // --- Notification Message Widget ---
              if (_notificationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Center(
                    child: Text(
                      _notificationMessage!,
                      style: GoogleFonts.poppins(
                        color: _isError ? Colors.redAccent : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              _buildDisclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.backgroundLightest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkTeal,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLightest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disclaimer:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: AppColors.darkTeal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hasil ini dibuat oleh model AI dan bukan pengganti nasihat medis profesional. Silakan konsultasikan dengan dokter kulit untuk diagnosis yang akurat.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.darkTeal,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}