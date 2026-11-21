import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fp_pemrograman/service/session.dart';

class ApiService {
  // Use Vercel Backend
  // Default: backend production. Untuk uji lokal:
  // flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:5000
  final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-intan12.vercel.app',
  );

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Map<String, String> _buildHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- COMPETENCIES ---
  Future<List<dynamic>> getCompetencies() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/competencies'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching competencies: $e');
    }
    return [];
  }

  Future<bool> updateCompetencyStatus(int id, String status) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/competencies/$id'),
        headers: _buildHeaders(token),
        body: jsonEncode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating competency: $e');
    }
    return false;
  }

  Future<bool> updateCompetencyEvidence(int id, String status, String evidenceUrl) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/competencies/$id'),
        headers: _buildHeaders(token),
        body: jsonEncode({'status': status, 'evidence_url': evidenceUrl}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating competency evidence: $e');
    }
    return false;
  }

  // --- EXAMS ---
  Future<List<dynamic>> getExams() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/exams'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching exams: $e');
    }
    return [];
  }

  Future<bool> updateExamEvidence(int id, String result, String evidenceUrl) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/exams/$id'),
        headers: _buildHeaders(token),
        body: jsonEncode({'result': result, 'evidence_url': evidenceUrl}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating exam evidence: $e');
    }
    return false;
  }

  // --- ACADEMIC TASKS ---
  Future<List<dynamic>> getAcademicTasks() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/academic-tasks'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching academic tasks: $e');
    }
    return [];
  }

  Future<bool> updateAcademicEvidence(int id, String status, String evidenceUrl) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/academic-tasks/$id'),
        headers: _buildHeaders(token),
        body: jsonEncode({'status': status, 'document_proof_url': evidenceUrl}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating academic evidence: $e');
    }
    return false;
  }

  Future<bool> updateAcademicNotes(int id, String status, String notes) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/academic-tasks/$id'),
        headers: _buildHeaders(token),
        body: jsonEncode({'status': status, 'notes': notes}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating academic notes: $e');
    }
    return false;
  }

  // --- EXTERNAL ROTATIONS ---
  Future<List<dynamic>> getRotations() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/rotations'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching rotations: $e');
    }
    return [];
  }

  // --- ADMIN: USERS ---
  Future<List<dynamic>> getUsers() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/users'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
    return [];
  }

  // Helper to expose token for admin use in screens
  Future<String?> getAdminToken() async => _getToken();

  Future<Map<String, dynamic>?> createAdminUser(
      String email, String password, String fullName, String nim) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users'),
        headers: _buildHeaders(token),
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
          'nim': nim,
          'role': 'admin',
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) return data;
      return {'error': data['error'] ?? 'Gagal membuat admin'};
    } catch (e) {
      debugPrint('Error creating admin: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> createUserWithRole(
      String email, String password, String fullName, String role) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users'),
        headers: _buildHeaders(token),
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
          'nim': '-',
          'role': role,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) return data;
      return {'error': data['error'] ?? 'Gagal membuat user'};
    } catch (e) {
      debugPrint('Error creating user with role: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> createPpdsUser(
      String email, String password, String fullName, String nim) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users'),
        headers: _buildHeaders(token),
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
          'nim': nim,
          'role': 'ppds',
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) return data;
      return {'error': data['error'] ?? 'Gagal membuat user'};
    } catch (e) {
      debugPrint('Error creating user: $e');
    }
    return null;
  }

  Future<bool> updateUser(int uid, Map<String, dynamic> fields) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/users/$uid'),
        headers: _buildHeaders(token),
        body: jsonEncode(fields),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating user: $e');
    }
    return false;
  }

  Future<bool> deleteUser(int id) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.delete(Uri.parse('$baseUrl/admin/users/$id'), headers: _buildHeaders(token));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting user: $e');
    }
    return false;
  }

  // --- JOURNAL READING ---
  Future<List<dynamic>> getMyJournalReadings() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/journal-readings'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching my journal readings: $e');
    }
    return [];
  }

  Future<List<dynamic>> getAllJournalReadings(String query) async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/journal-readings/all?q=${Uri.encodeComponent(query)}'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching all journal readings: $e');
    }
    return [];
  }

  Future<bool> submitJournalReading(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/journal-readings'),
        headers: _buildHeaders(token),
        body: jsonEncode(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      debugPrint('Failed to submit journal. Code: ${response.statusCode}, Body: ${response.body}');
    } catch (e) {
      debugPrint('Error submitting journal reading: $e');
    }
    return false;
  }

  Future<bool> updateJournalReadingBukti(int id, String buktiUrl) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/journal-readings/$id/bukti'),
        headers: _buildHeaders(token),
        body: jsonEncode({'bukti_url': buktiUrl}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating journal reading bukti: $e');
    }
    return false;
  }

  Future<List<dynamic>> getAdminJournalReadings(String status) async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
          Uri.parse('$baseUrl/admin/journal-readings?status=${Uri.encodeComponent(status)}'),
          headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching admin journal readings: $e');
    }
    return [];
  }

  Future<bool> adminReviewJournal(int jid, String status, String catatan) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/journal-readings/$jid/review'),
        headers: _buildHeaders(token),
        body: jsonEncode({'action': status, 'catatan_admin': catatan}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error reviewing journal: $e');
    }
    return false;
  }

  // --- ADMIN: VERIFICATIONS ---
  Future<List<dynamic>> getPendingVerifications() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
          Uri.parse('$baseUrl/admin/pending_verifications'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching pending verifications: $e');
    }
    return [];
  }

  Future<bool> verifyTask(String typeCategory, int itemId, String action) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/verify/$typeCategory/$itemId'),
        headers: _buildHeaders(token),
        body: jsonEncode({'action': action}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error verifying task: $e');
    }
    return false;
  }

  // --- ADMIN: PROGRESS ---
  Future<Map<String, dynamic>?> getUserProgress(int uid) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
          Uri.parse('$baseUrl/admin/progress/$uid'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching user progress: $e');
    }
    return null;
  }

  // --- ADMIN: ADD TASK ---
  Future<bool> adminAddTask(Map<String, dynamic> taskData) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/academic-tasks'),
        headers: _buildHeaders(token),
        body: jsonEncode(taskData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
    return false;
  }

  Future<bool> adminUpdateAcademicTask(int id, Map<String, dynamic> taskData) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/academic-tasks/$id'),
        headers: _buildHeaders(token),
        body: jsonEncode(taskData),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error updating academic task: $e');
    }
    return false;
  }

  // --- ADMIN: ROTATIONS ---
  Future<bool> adminUpdateRotation(int rid, Map<String, dynamic> fields) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/rotations/$rid'),
        headers: _buildHeaders(token),
        body: jsonEncode(fields),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating rotation: $e');
    }
    return false;
  }

  Future<bool> adminAddRotation(Map<String, dynamic> rotData) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/rotations'),
        headers: _buildHeaders(token),
        body: jsonEncode(rotData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error adding rotation: $e');
    }
    return false;
  }

  // --- PENELITIAN ---
  Future<List<dynamic>> getMyPenelitian() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/penelitian'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
      debugPrint('getMyPenelitian error: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error fetching my penelitian: $e');
    }
    return [];
  }

  Future<List<dynamic>> getAllPenelitian(String query) async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/penelitian/all?q=${Uri.encodeComponent(query)}'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
      debugPrint('getAllPenelitian error: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error fetching all penelitian: $e');
    }
    return [];
  }

  Future<bool> submitPenelitian(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/penelitian'),
        headers: _buildHeaders(token),
        body: jsonEncode(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return true;
      debugPrint('submitPenelitian error: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error submitting penelitian: $e');
    }
    return false;
  }

  Future<bool> updatePenelitian(int id, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/penelitian/$id'),
        headers: _buildHeaders(token),
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) return true;
      debugPrint('updatePenelitian error: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error updating penelitian: $e');
    }
    return false;
  }

  // --- ORGAN EXAMS ---
  Future<List<dynamic>> getMyOrganExams() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/organ-exams'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching my organ exams: $e');
    }
    return [];
  }

  // --- ADMIN: ORGAN EXAM ---
  Future<bool> adminSetWarning(int uid, bool active, String message) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/users/$uid/warning'),
        headers: _buildHeaders(token),
        body: jsonEncode({'warning_active': active, 'warning_message': message}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error setting warning: $e');
    }
    return false;
  }

  Future<bool> adminAddOrganExam(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/organ-exams'),
        headers: _buildHeaders(token),
        body: jsonEncode(data),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding organ exam: $e');
    }
    return false;
  }

  Future<List<dynamic>> adminGetOrganExams(int uid) async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/organ-exams?user_id=$uid'),
        headers: _buildHeaders(token),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching organ exams: $e');
    }
    return [];
  }

  Future<bool> adminUpdateOrganExam(int id, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/organ-exams/$id'),
        headers: _buildHeaders(token),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating organ exam: $e');
    }
    return false;
  }

  // --- SURVEY ---
  Future<List<dynamic>> getActiveSurveys() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/surveys/active'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching active surveys: $e');
    }
    return [];
  }

  Future<List<dynamic>> adminGetSurveys() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/surveys'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching surveys: $e');
    }
    return [];
  }

  /// Mengembalikan null bila sukses, atau pesan error dari server.
  Future<String?> adminSaveSurvey(int? id, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) return 'Sesi login habis';
    try {
      final response = id == null
          ? await http.post(Uri.parse('$baseUrl/admin/surveys'), headers: _buildHeaders(token), body: jsonEncode(data))
          : await http.patch(Uri.parse('$baseUrl/admin/surveys/$id'), headers: _buildHeaders(token), body: jsonEncode(data));
      if (response.statusCode == 200 || response.statusCode == 201) return null;
      final body = jsonDecode(response.body);
      return (body is Map && body['error'] != null) ? body['error'].toString() : 'Gagal menyimpan survey';
    } catch (e) {
      debugPrint('Error saving survey: $e');
      return 'Gagal menyimpan survey';
    }
  }

  Future<bool> adminUpdatePenelitianStatus(int pid, String status, String catatan) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/penelitian/$pid/status'),
        headers: _buildHeaders(token),
        body: jsonEncode({'status': status, 'catatan': catatan}),
      );
      if (response.statusCode == 200) return true;
      debugPrint('adminUpdatePenelitianStatus error: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error updating penelitian status: $e');
    }
    return false;
  }

  // --- TOPIC DUPLICATION CHECK ---
  Future<Map<String, dynamic>> checkTopicDuplication(String judul, String jenis) async {
    final token = await _getToken();
    if (token == null) return {'exists': false};
    try {
      final uri = Uri.parse('$baseUrl/check-topic?judul=${Uri.encodeComponent(judul)}&jenis=${Uri.encodeComponent(jenis)}');
      final response = await http.get(uri, headers: _buildHeaders(token));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error checking topic: $e');
    }
    return {'exists': false};
  }

  // --- ADMIN: PROFILE UPDATE ---
  Future<bool> adminUpdateUserProfile(int uid, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/users/$uid/profile'),
        headers: _buildHeaders(token),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating user profile: $e');
    }
    return false;
  }

  // --- PENGABDIAN MASYARAKAT ---
  Future<List<dynamic>> getPengabdian() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/pengabdian'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching pengabdian: $e');
    }
    return [];
  }

  Future<bool> addPengabdian(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pengabdian'),
        headers: _buildHeaders(token),
        body: jsonEncode(data),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding pengabdian: $e');
    }
    return false;
  }

  // --- PRESTASI ---
  Future<List<dynamic>> getPrestasi() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/prestasi'), headers: _buildHeaders(token));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error fetching prestasi: $e');
    }
    return [];
  }

  Future<bool> addPrestasi(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/prestasi'),
        headers: _buildHeaders(token),
        body: jsonEncode(data),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding prestasi: $e');
    }
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  // Helper generik: setiap panggilan menyimpan pesan error terakhir di
  // [lastError] supaya layar bisa menampilkan alasan kegagalan ke pengguna.
  // ════════════════════════════════════════════════════════════════════════

  String? lastError;

  /// Kode status HTTP terakhir (null bila gagal terhubung).
  int? lastStatus;

  String _errorFrom(http.Response r) {
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['error'] != null) return body['error'].toString();
    } catch (_) {}
    if (r.statusCode == 401) return 'Sesi login berakhir. Silakan login ulang.';
    if (r.statusCode == 429) return 'Terlalu banyak percobaan. Coba lagi nanti.';
    return 'Terjadi kesalahan (kode ${r.statusCode}).';
  }

  /// Mengembalikan body JSON (Map/List) bila sukses, atau null bila gagal.
  Future<dynamic> _send(String method, String path, {Map<String, dynamic>? body}) async {
    lastError = null;
    lastStatus = null;
    final token = await _getToken();
    if (token == null) {
      lastError = 'Sesi login berakhir. Silakan login ulang.';
      lastStatus = 401;
      return null;
    }
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = _buildHeaders(token);
      final encoded = body == null ? null : jsonEncode(body);
      late http.Response r;
      switch (method) {
        case 'GET':
          r = await http.get(uri, headers: headers);
          break;
        case 'POST':
          r = await http.post(uri, headers: headers, body: encoded);
          break;
        case 'PUT':
          r = await http.put(uri, headers: headers, body: encoded);
          break;
        case 'PATCH':
          r = await http.patch(uri, headers: headers, body: encoded);
          break;
        case 'DELETE':
          r = await http.delete(uri, headers: headers);
          break;
      }
      lastStatus = r.statusCode;
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      }
      lastError = _errorFrom(r);
      if (r.statusCode == 401) {
        lastError = 'Sesi login berakhir. Silakan login ulang.';
        handleUnauthorized();
      }
    } catch (e) {
      debugPrint('API $method $path error: $e');
      lastError = 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
    }
    return null;
  }

  // --- PROFIL & KALUNG ---
  /// /me: data user + progres kalung (`kalung`). null bila gagal.
  Future<Map<String, dynamic>?> getMe() async => await _send('GET', '/me') as Map<String, dynamic>?;

  // --- NOTIFIKASI (semua peran) ---
  Future<Map<String, dynamic>?> getNotifications() async =>
      await _send('GET', '/notifications') as Map<String, dynamic>?;
  Future<bool> markNotificationRead(int id) async => await _send('PATCH', '/notifications/$id/read') != null;
  Future<bool> markAllNotificationsRead() async => await _send('PATCH', '/notifications/read-all') != null;

  // --- VERIFIKASI ADMIN (dengan alasan) ---
  /// action: approve | reject | fail (fail khusus ujian = tidak lulus).
  Future<bool> verifyItem(String typeCategory, int itemId, String action, {String? alasan, double? score}) async =>
      await _send('PUT', '/admin/verify/$typeCategory/$itemId', body: {
        'action': action,
        if (alasan != null && alasan.isNotEmpty) 'alasan': alasan,
        if (score != null) 'score': score,
      }) !=
      null;

  // --- JOURNAL: perbaiki / ajukan ulang ---
  Future<bool> editJournalReading(int id, Map<String, dynamic> data) async =>
      await _send('PATCH', '/journal-readings/$id', body: data) != null;
  Future<bool> uploadJournalBukti(int id, String buktiUrl) async =>
      await _send('PATCH', '/journal-readings/$id/bukti', body: {'bukti_url': buktiUrl}) != null;

  // --- PENGABDIAN & PRESTASI: ubah / hapus ---
  Future<bool> updatePengabdian(int id, Map<String, dynamic> data) async =>
      await _send('PATCH', '/pengabdian/$id', body: data) != null;
  Future<bool> deletePengabdian(int id) async => await _send('DELETE', '/pengabdian/$id') != null;
  Future<bool> updatePrestasi(int id, Map<String, dynamic> data) async =>
      await _send('PATCH', '/prestasi/$id', body: data) != null;
  Future<bool> deletePrestasi(int id) async => await _send('DELETE', '/prestasi/$id') != null;

  // --- PENILAIAN (PPDS melihat nilainya) ---
  Future<List<dynamic>?> getMyPenilaian() async => await _send('GET', '/me/penilaian') as List<dynamic>?;

  // --- PENILAI / DOSEN ---
  Future<List<dynamic>?> getBimbingan() async => await _send('GET', '/penilai/bimbingan') as List<dynamic>?;
  Future<Map<String, dynamic>?> getBimbinganProgress(int ppdsId) async =>
      await _send('GET', '/penilai/bimbingan/$ppdsId/progress') as Map<String, dynamic>?;
  Future<bool> beriPenilaian(int ppdsId, String peran, double nilai, String catatan, {int? semester}) async =>
      await _send('POST', '/penilaian', body: {
        'ppds_id': ppdsId,
        'peran': peran,
        'nilai': nilai,
        'catatan': catatan,
        if (semester != null) 'semester': semester,
      }) !=
      null;
  Future<List<dynamic>?> getUjianYangSayaUji() async => await _send('GET', '/penilai/ujian-organ') as List<dynamic>?;
  Future<bool> isiHasilUjianOrgan(int examId, Map<String, dynamic> data) async =>
      await _send('PATCH', '/penilai/ujian-organ/$examId', body: data) != null;
  Future<List<dynamic>?> getPendingJournals() async =>
      await _send('GET', '/admin/journal-readings?status=pending') as List<dynamic>?;
  Future<List<dynamic>?> getAllPenelitianOrNull() async => await _send('GET', '/penelitian/all') as List<dynamic>?;

  // --- ADMIN: penugasan, penilaian, stase ---
  Future<List<dynamic>?> getPenilaiList() async => await _send('GET', '/admin/penilai') as List<dynamic>?;
  Future<List<dynamic>?> adminGetPenilaian(int ppdsId) async =>
      await _send('GET', '/admin/penilaian?ppds_id=$ppdsId') as List<dynamic>?;
  Future<Map<String, dynamic>?> adminGetProgress(int uid) async =>
      await _send('GET', '/admin/progress/$uid') as Map<String, dynamic>?;
  Future<List<dynamic>?> adminGetUsers() async => await _send('GET', '/admin/users') as List<dynamic>?;
  Future<bool> adminSaveProfile(int uid, Map<String, dynamic> data) async =>
      await _send('PATCH', '/admin/users/$uid/profile', body: data) != null;
  Future<bool> adminCreateRotation(Map<String, dynamic> data) async =>
      await _send('POST', '/admin/rotations', body: data) != null;
  Future<bool> adminSaveRotation(int id, Map<String, dynamic> data) async =>
      await _send('PUT', '/admin/rotations/$id', body: data) != null;
  Future<List<dynamic>?> getPendingVerificationsOrNull() async =>
      await _send('GET', '/admin/pending_verifications') as List<dynamic>?;
}
