import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  final auth = AuthService();

  bool loading = false;
  bool ocultarPassword = true;
  bool ocultarConfirmPassword = true;

  // =========================
  // VALIDAR EMAIL
  // =========================
  bool emailValido(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  // =========================
  // REGISTRO
  // =========================
  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      mostrarMensaje("Completa todos los campos");
      return;
    }

    if (!emailValido(email)) {
      mostrarMensaje("Ingresa un correo válido");
      return;
    }

    if (password.length < 6) {
      mostrarMensaje("La contraseña debe tener mínimo 6 caracteres");
      return;
    }

    if (password != confirm) {
      mostrarMensaje("Las contraseñas no coinciden");
      return;
    }

    setState(() => loading = true);

    try {
      final success = await auth.register(email, password);

      if (!mounted) return;

      setState(() => loading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Usuario creado correctamente"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } else {
        mostrarMensaje("No se pudo registrar. El correo podría estar en uso.");
      }
    } catch (e) {
      print("Error registro: $e");

      if (!mounted) return;

      setState(() => loading = false);

      mostrarMensaje("Error al registrar. Intenta nuevamente.");
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
    confirmController.dispose();
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
                  // ICONO
                  Container(
                    width: 95,
                    height: 95,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add,
                      size: 52,
                      color: Colors.green,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Crear cuenta",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    "Regístrate para guardar y sincronizar tus presupuestos",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 30),

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
                            "Datos de registro",
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
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: "Contraseña",
                              hintText: "Mínimo 6 caracteres",
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

                          const SizedBox(height: 15),

                          TextField(
                            controller: confirmController,
                            enabled: !loading,
                            obscureText: ocultarConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!loading) register();
                            },
                            decoration: InputDecoration(
                              labelText: "Confirmar contraseña",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  ocultarConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: loading
                                    ? null
                                    : () {
                                        setState(() {
                                          ocultarConfirmPassword =
                                              !ocultarConfirmPassword;
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
                              onPressed: loading ? null : register,
                              icon: loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.person_add),
                              label: Text(
                                loading ? "Registrando..." : "Registrarse",
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
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
                                    Navigator.pop(context);
                                  },
                            child: const Text("¿Ya tienes cuenta? Inicia sesión"),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Al crear una cuenta podrás sincronizar tus datos con la nube.",
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