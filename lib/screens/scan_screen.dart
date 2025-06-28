// lib/screens/scan_screen.dart

import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fp_pemrograman/screens/scan_result_screen.dart';
import 'package:tflite_flutter/tflite_flutter.dart'; // Import tflite_flutter
import 'package:image/image.dart' as img; // Import image package
import 'dart:io'; // Untuk File
import 'package:flutter/services.dart'
    show rootBundle; // Untuk memuat labels.txt
import 'package:google_fonts/google_fonts.dart'; // Import GoogleFonts
import 'package:fp_pemrograman/colors.dart'; // Import AppColors
import 'dart:typed_data'; // Untuk Float32List
import 'package:flutter/foundation.dart'; // Untuk debugPrint

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<CameraDescription>? cameras;
  CameraController? controller;
  bool _isRearCameraSelected = true;
  bool _isLoadingModel = true; // State untuk memuat model dan menganalisis
  Interpreter? _interpreter; // Variabel untuk interpreter TFLite
  List<String>? _labels; // Variabel untuk labels

  // Definisikan konstanta ukuran gambar di sini, sesuai dengan model ML Anda
  // Asumsi: Model Anda mengharapkan input 224x224 piksel untuk gambar
  static const int IMG_HEIGHT = 224;
  static const int IMG_WIDTH = 224;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModelAndLabels(); // Panggil fungsi untuk memuat model dan label
  }

  Future<void> _initializeCamera([bool rearCamera = true]) async {
    try {
      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) {
        if (mounted) {
          _showErrorDialog("Tidak ada kamera yang tersedia di perangkat ini.");
        }
        return;
      }

      final selectedCamera = cameras!.firstWhere(
        (camera) =>
            camera.lensDirection ==
            (rearCamera ? CameraLensDirection.back : CameraLensDirection.front),
        orElse: () => cameras!.first,
      );

      controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error menginisialisasi kamera: $e");
      if (mounted) {
        _showErrorDialog('Gagal menginisialisasi kamera: $e');
      }
    }
  }

  // Fungsi untuk memuat model TFLite dan labels
  Future<void> _loadModelAndLabels() async {
    try {
      // Perbarui path model dan label sesuai contoh yang Anda berikan
      _interpreter = await Interpreter.fromAsset('assets/models/model.tflite');
      debugPrint('Model TFLite berhasil dimuat!');

      final labelsData =
          await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      debugPrint('Labels berhasil dimuat: $_labels');
    } catch (e) {
      debugPrint('Error memuat model atau labels: $e');
      if (mounted) {
        _showErrorDialog(
            'Gagal memuat model ML atau label: $e. Pastikan file ada di assets/models/ dan pubspec.yaml sudah benar.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingModel = false; // Model selesai dimuat (berhasil atau gagal)
        });
      }
    }
  }

  // Fungsi untuk menampilkan dialog error kustom
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: <Widget>[
          TextButton(
            child: Text('Oke',
                style: GoogleFonts.poppins(color: AppColors.primaryOrange)),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    _interpreter?.close(); // Tutup interpreter saat dispose
    super.dispose();
  }

  Future<void> _processImage(XFile image) async {
    if (_interpreter == null || _labels == null || _labels!.isEmpty) {
      if (mounted) {
        _showErrorDialog(
            'Model ML atau label belum dimuat. Mohon tunggu atau restart aplikasi.');
      }
      return;
    }

    // Tampilkan dialog loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryOrange),
            SizedBox(height: 16),
            Text(
              'Menganalisis gambar...',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    try {
      final imageBytes = await image.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception("Tidak dapat mendekode gambar.");
      }

      // Resize gambar ke ukuran yang dibutuhkan model
      img.Image resizedImage =
          img.copyResize(originalImage, width: IMG_WIDTH, height: IMG_HEIGHT);

      // Konversi gambar ke Float32List (input model)
      // PENTING: Menghapus normalisasi / 255.0 karena model sudah memiliki lapisan Rescaling(1./255)
      var input =
          Float32List(1 * IMG_WIDTH * IMG_HEIGHT * 3); // 3 channel untuk RGB
      var buffer = Float32List.view(
          input.buffer); // Memakai buffer yang sama untuk efisiensi

      int pixelIndex = 0;
      for (int y = 0; y < IMG_HEIGHT; y++) {
        for (int x = 0; x < IMG_WIDTH; x++) {
          var pixel = resizedImage.getPixel(x, y); // Gunakan getPixel
          // Hanya konversi ke double, jangan dibagi 255.0
          buffer[pixelIndex++] = pixel.r.toDouble(); // Red
          buffer[pixelIndex++] = pixel.g.toDouble(); // Green
          buffer[pixelIndex++] = pixel.b.toDouble(); // Blue
        }
      }

      // Siapkan output buffer
      // Output tensor. Ukuran harus sesuai dengan jumlah kelas Anda (7 kelas).
      var output =
          List.filled(1 * _labels!.length, 0.0).reshape([1, _labels!.length]);

      // Jalankan inferensi
      _interpreter!.run(input.reshape([1, IMG_HEIGHT, IMG_WIDTH, 3]), output);

      // Proses hasil
      final List<double> confidenceScores = output[0].cast<double>();
      double maxConfidence = 0;
      int predictedIndex = -1;

      // --- DEBUGGING PRINTS DITAMBAHKAN DI SINI ---
      debugPrint('DEBUG: Raw Confidence Scores: $confidenceScores');
      debugPrint(
          'DEBUG: Labels (pastikan urutan cocok dengan keluaran model): $_labels');
      // --------------------------------------------

      for (int i = 0; i < confidenceScores.length; i++) {
        if (confidenceScores[i] > maxConfidence) {
          maxConfidence = confidenceScores[i];
          predictedIndex = i;
        }
      }

      // --- DEBUGGING PRINTS DITAMBAHKAN DI SINI ---
      debugPrint('DEBUG: Predicted Index: $predictedIndex');
      debugPrint('DEBUG: Max Confidence: $maxConfidence');
      // --------------------------------------------

      String detectedEczemaType = 'Unknown';

      // Ambang batas kepercayaan, bisa disesuaikan.
      // Coba turunkan ambang batas ini jika hasil sering "Tidak Yakin"
      if (predictedIndex != -1 && maxConfidence > 0.4) { // Contoh: Turunkan ambang batas ke 0.4
        detectedEczemaType = _labels![predictedIndex];
        debugPrint(
            'Terdeteksi: $detectedEczemaType dengan keyakinan: ${maxConfidence.toStringAsFixed(2)}');
      } else {
        detectedEczemaType = "Tidak Yakin. Coba gambar yang lebih jelas.";
        debugPrint(
            'Prediksi tidak yakin atau keyakinan rendah. Keyakinan maksimal: ${maxConfidence.toStringAsFixed(2)}');
      }

      if (mounted) {
        Navigator.of(context).pop(); // Tutup dialog loading
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ScanResultScreen(
              imagePath: image.path,
              analysisResult: {
                'label': detectedEczemaType,
                'confidence': maxConfidence,
              },
              detectedEczemaType: detectedEczemaType,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error menganalisis gambar: $e");
      if (mounted) {
        Navigator.of(context).pop(); // Tutup dialog loading
        _showErrorDialog('Gagal menganalisis gambar dengan model ML: $e');
      }
    }
  }

  Future<void> _onCapture() async {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }
    try {
      final image = await controller!.takePicture();
      await _processImage(image);
    } catch (e) {
      debugPrint("Error mengambil gambar: $e");
      if (mounted) {
        _showErrorDialog("Gagal mengambil gambar: $e");
      }
    }
  }

  Future<void> _onPickFromGallery() async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85); // Menambahkan imageQuality
    if (image != null) {
      await _processImage(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan loading model ML atau jika kamera belum siap
    if (_isLoadingModel ||
        controller == null ||
        !controller!.value.isInitialized) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.backgroundLighter, AppColors.accentBrown],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primaryOrange),
                SizedBox(height: 16),
                Text(
                  _isLoadingModel
                      ? 'Memuat model ML...'
                      : 'Menginisialisasi kamera...',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(controller!),
          ),

          // Tombol kembali
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Kontrol Bawah
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: Colors.black.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Tombol Galeri
                  IconButton(
                    onPressed: _onPickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined,
                        color: Colors.white, size: 36),
                  ),
                  // Tombol Capture
                  GestureDetector(
                    onTap: _onCapture,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.grey, width: 2),
                      ),
                    ),
                  ),
                  // Tombol Balik Kamera
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isRearCameraSelected = !_isRearCameraSelected;
                      });
                      _initializeCamera(_isRearCameraSelected);
                    },
                    icon: const Icon(Icons.flip_camera_ios_outlined,
                        color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}