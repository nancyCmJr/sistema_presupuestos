import 'package:flutter/material.dart';
import 'package:sistema_presupuestos/services/sync_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final auth = AuthService();

  bool loading = false;
  bool ocultarPassword = true;

  // =========================
  // VALIDAR EMAIL
  // =========================
  bool emailValido(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  // =========================
  // LOGIN
  // =========================
  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      mostrarMensaje("Completa todos los campos");
      return;
    }

    if (!emailValido(email)) {
      mostrarMensaje("Ingresa un correo válido");
      return;
    }

    if (password.length < 6) {
      mostrarMensaje("La contraseña debe tener al menos 6 caracteres");
      return;
    }

    setState(() => loading = true);

    try {
      final success = await auth.login(email, password);

      if (!mounted) return;

      if (!success) {
        setState(() => loading = false);
        mostrarMensaje("Correo o contraseña incorrectos");
        return;
      }

      // Verificar token
      final tokenValido = await auth.verificarToken();

      if (!mounted) return;

      if (!tokenValido) {
        setState(() => loading = false);
        mostrarMensaje("Token inválido. Inicia sesión nuevamente.");
        return;
      }

      // Sincronización inicial
      try {
        await SyncService.syncAll();
        await SyncService.descargarDatos();
      } catch (e) {
        print("Error sincronizando al iniciar sesión: $e");

        if (mounted) {
          mostrarMensaje(
            "Sesión iniciada, pero hubo un problema al sincronizar",
          );
        }
      }

      if (!mounted) return;

      setState(() => loading = false);

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print("Error login: $e");

      if (!mounted) return;

      setState(() => loading = false);

      mostrarMensaje("Error al iniciar sesión. Intenta nuevamente.");
    }
  }

  // =========================
  // MENSAJE
  // =========================
  void mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),

          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // LOGO / ICONO
                  Container(
                    width: 95,
                    height: 95,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.electrical_services,
                      size: 52,
                      color: Colors.blue,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Sistema de Presupuestos",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    "Inicia sesión para administrar tus clientes, materiales y presupuestos",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // CARD LOGIN
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),

                    child: Padding(
                      padding: const EdgeInsets.all(20),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Iniciar sesión",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 18),

                          TextField(
                            controller: emailController,
                            enabled: !loading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: "Correo electrónico",
                              hintText: "ejemplo@correo.com",
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          TextField(
                            controller: passwordController,
                            enabled: !loading,
                            obscureText: ocultarPassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!loading) login();
                            },
                            decoration: InputDecoration(
                              labelText: "Contraseña",
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  ocultarPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: loading
                                    ? null
                                    : () {
                                        setState(() {
                                          ocultarPassword = !ocultarPassword;
                                        });
                                      },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: loading ? null : login,
                              icon: loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(
                                loading
                                    ? "Iniciando sesión..."
                                    : "Iniciar sesión",
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: loading
                                ? null
                                : () {
                                    Navigator.pushNamed(context, '/register');
                                  },
                            child: const Text("¿No tienes cuenta? Crear cuenta"),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Tus datos se sincronizan de forma segura con tu cuenta.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}