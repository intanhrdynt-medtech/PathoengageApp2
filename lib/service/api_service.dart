import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Use Vercel Backend
  final String baseUrl = 'https://backend-intan12.vercel.app';

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
      final response = await http.get(Uri.parse('$baseUrl/journal-readings/all?q=$query'), headers: _buildHeaders(token));
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
          Uri.parse('$baseUrl/admin/journal-readings?status=$status'),
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
}

