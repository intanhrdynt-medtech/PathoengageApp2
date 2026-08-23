import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Use Vercel URL
  final String baseUrl = 'https://pathoengage-backend.vercel.app'; 
  
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);
        return data['user'];
      } else {
        debugPrint(data['error']);
        return null;
      }
    } catch (e) {
      debugPrint('Login Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> registerWithEmailAndPassword(
      String fullName, String nim, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email, 
          'password': password,
          'full_name': fullName,
          'nim': nim
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);
        return {'success': true, 'user': data['user'], 'message': 'Registration successful'};
      } else {
        return {
          'success': false,
          'user': null,
          'message': data['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      debugPrint('Registration Error: $e');
      return {
        'success': false,
        'user': null,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }
}
