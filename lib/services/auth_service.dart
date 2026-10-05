import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = "https://electricista-api.onrender.com/api/auth";

  // =========================
  // LOGIN
  // =========================
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final token = data['token'];
        final userId = data['userId'];

        if (token == null || token.toString().isEmpty) {
          print("Login exitoso, pero la API no devolvió token");
          return false;
        }

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('token', token.toString());
        await prefs.setString('userId', userId.toString());

        print("Token guardado correctamente");

        return true;
      } else {
        print("Error login: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error en login: $e");
      return false;
    }
  }

  // =========================
  // REGISTER
  // =========================
  Future<bool> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print("Error register: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error en register: $e");
      return false;
    }
  }

  // =========================
  // OBTENER TOKEN
  // =========================
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty || token == "null") {
      return null;
    }

    return token;
  }

  // =========================
  // OBTENER USER ID
  // =========================
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  // =========================
  // LOGOUT
  // =========================
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
  }

  // =========================
  // VERIFICAR SESIÓN LOCAL
  // =========================
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // =========================
  // VERIFICAR TOKEN CON API
  // =========================
  Future<bool> verificarToken() async {
    final token = await getToken();

    if (token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return true;
      }

      print("Token no válido: ${response.body}");
      await logout();
      return false;
    } catch (e) {
      print("Error verificando token: $e");
      return false;
    }
  }
}