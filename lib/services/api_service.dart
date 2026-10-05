import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static const String baseUrl =
      "https://electricista-api.onrender.com/api";

  static final AuthService auth = AuthService();

  // =========================
  // HEADERS
  // =========================
  static Future<Map<String, String>> getHeaders() async {
    final token = await auth.getToken();

    if (token == null || token.isEmpty || token == "null") {
      throw Exception("No hay token guardado. Inicia sesión nuevamente.");
    }

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // =========================
  // HANDLE RESPONSE
  // =========================
  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      throw Exception(
        "Error ${response.statusCode}: ${response.body}",
      );
    }
  }

  // =========================
  // CLIENTES
  // =========================
  static Future<List<Map<String, dynamic>>> getClientes() async {
    final response = await http.get(
      Uri.parse("$baseUrl/clientes"),
      headers: await getHeaders(),
    );

    final data = _handleResponse(response);

    return List<Map<String, dynamic>>.from(data);
  }

  // =========================
  // MATERIALES
  // =========================
  static Future<List<Map<String, dynamic>>> getMateriales() async {
    final response = await http.get(
      Uri.parse("$baseUrl/materiales"),
      headers: await getHeaders(),
    );

    final data = _handleResponse(response);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<bool> addMaterial(
    String nombre,
    double precio,
    String categoria,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/materiales"),
      headers: await getHeaders(),
      body: jsonEncode({
        "nombre": nombre,
        "precio": precio,
        "categoria": categoria,
      }),
    );

    return response.statusCode == 200 ||
        response.statusCode == 201;
  }

  // =========================
  // PRECIOS
  // =========================
  static Future<Map<String, dynamic>> obtenerPrecios(String nombre) async {
    final response = await http.post(
      Uri.parse("$baseUrl/precios"),
      headers: await getHeaders(),
      body: jsonEncode({
        "nombre": nombre,
        "zona": "Puebla",
      }),
    );

    final data = _handleResponse(response);

    return {
      "precios": List<Map<String, dynamic>>.from(
        data["precios"] ?? [],
      ),
      "comparacion": data["comparacion"],
    };
  }

  // =========================
  // PRESUPUESTOS
  // =========================
  static Future<bool> crearPresupuesto(Map data) async {
    final response = await http.post(
      Uri.parse("$baseUrl/presupuestos"),
      headers: await getHeaders(),
      body: jsonEncode(data),
    );

    return response.statusCode == 200 ||
        response.statusCode == 201;
  }

  static Future<List<Map<String, dynamic>>> getPresupuestos() async {
    final response = await http.get(
      Uri.parse("$baseUrl/presupuestos"),
      headers: await getHeaders(),
    );

    final data = _handleResponse(response);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<bool> eliminarPresupuesto(String id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/presupuestos/$id"),
      headers: await getHeaders(),
    );

    return response.statusCode == 200;
  }

  // =========================
  // SINCRONIZACIÓN GENÉRICA
  // =========================
  static Future<dynamic> syncUp(
    String endpoint,
    dynamic data,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/sync/$endpoint"),
      headers: await getHeaders(),
      body: jsonEncode(data),
    );

    return _handleResponse(response);
  }

  static Future<List<Map<String, dynamic>>> syncDown(
    String endpoint,
    String lastSync,
  ) async {
    final response = await http.get(
      Uri.parse("$baseUrl/sync/$endpoint?updated_after=$lastSync"),
      headers: await getHeaders(),
    );

    final res = _handleResponse(response);

    return List<Map<String, dynamic>>.from(res);
  }
}