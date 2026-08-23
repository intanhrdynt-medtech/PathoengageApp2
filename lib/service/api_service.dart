import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class ApiService {
  final String baseUrl = 'https://pathoengage-backend.vercel.app';

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
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
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
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching exams: $e');
    }
    return [];
  }

  // --- ACADEMIC TASKS ---
  Future<List<dynamic>> getAcademicTasks() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(Uri.parse('$baseUrl/academic-tasks'), headers: _buildHeaders(token));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching academic tasks: $e');
    }
    return [];
  }

  // --- EXTERNAL ROTATIONS ---
  Future<List<dynamic>> getRotations() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(Uri.parse('$baseUrl/rotations'), headers: _buildHeaders(token));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching rotations: $e');
    }
    return [];
  }
}
