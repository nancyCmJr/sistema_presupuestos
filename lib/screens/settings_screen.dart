import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistema_presupuestos/database/db_helper.dart';
import 'package:sistema_presupuestos/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String nombreTrabajador = "";
  String telefonoTrabajador = "";
  String emailTrabajador = "";
  String direccionTrabajador = "";
  String moneda = "MXN";
  String? membretePath;

  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarConfiguracion();
  }

  // =========================
  // CARGAR CONFIGURACIÓN
  // =========================
  Future<void> cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      nombreTrabajador = prefs.getString("trabajador_nombre") ?? "";
      telefonoTrabajador = prefs.getString("trabajador_telefono") ?? "";
      emailTrabajador = prefs.getString("trabajador_email") ?? "";
      direccionTrabajador = prefs.getString("trabajador_direccion") ?? "";
      moneda = prefs.getString("moneda") ?? "MXN";
      membretePath = prefs.getString("membrete_path");
      cargando = false;
    });
  }

  // =========================
  // GUARDAR DATOS TRABAJADOR
  // =========================
  Future<void> guardarDatosTrabajador({
    required String nombre,
    required String telefono,
    required String email,
    required String direccion,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("trabajador_nombre", nombre);
    await prefs.setString("trabajador_telefono", telefono);
    await prefs.setString("trabajador_email", email);
    await prefs.setString("trabajador_direccion", direccion);

    setState(() {
      nombreTrabajador = nombre;
      telefonoTrabajador = telefono;
      emailTrabajador = email;
      direccionTrabajador = direccion;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Datos guardados correctamente")),
    );
  }

  // =========================
  // GUARDAR MONEDA
  // =========================
  Future<void> guardarMoneda(String nuevaMoneda) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("moneda", nuevaMoneda);

    setState(() {
      moneda = nuevaMoneda;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Moneda cambiada a $nuevaMoneda")),
    );
  }

  // =========================
  // SELECCIONAR MEMBRETE
  // =========================
  Future<void> seleccionarMembrete() async {
    final picker = ImagePicker();

    final XFile? imagen = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (imagen == null) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("membrete_path", imagen.path);

    setState(() {
      membretePath = imagen.path;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Hoja membretada guardada")),
    );
  }

  // =========================
  // QUITAR MEMBRETE
  // =========================
  Future<void> quitarMembrete() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Quitar membrete"),
        content: const Text(
          "¿Seguro que deseas quitar la hoja membretada del PDF?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Quitar"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove("membrete_path");

    setState(() {
      membretePath = null;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Membrete eliminado")),
    );
  }

  // =========================
  // MODAL MEMBRETE
  // =========================
  void mostrarMembrete() {
    final existeArchivo = membretePath != null && File(membretePath!).existsSync();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hoja membretada"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              if (existeArchivo)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(membretePath!),
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported, size: 50),
                      SizedBox(height: 10),
                      Text(
                        "No hay hoja membretada cargada",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 15),

              const Text(
                "Recomendación: usa una imagen vertical tamaño carta o A4, "
                "con buena resolución, para que el PDF se vea profesional.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),

          if (existeArchivo)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await quitarMembrete();
              },
              child: const Text("Quitar"),
            ),

          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await seleccionarMembrete();
            },
            icon: const Icon(Icons.upload_file),
            label: Text(existeArchivo ? "Cambiar" : "Cargar"),
          ),
        ],
      ),
    );
  }

  // =========================
  // MODAL DATOS TRABAJADOR
  // =========================
  void mostrarDatosTrabajador() {
    final nombreController = TextEditingController(text: nombreTrabajador);
    final telefonoController = TextEditingController(text: telefonoTrabajador);
    final emailController = TextEditingController(text: emailTrabajador);
    final direccionController = TextEditingController(text: direccionTrabajador);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Datos del trabajador"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre completo",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: telefonoController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Teléfono",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Correo",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: direccionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Dirección",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),

          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("El nombre es obligatorio")),
                );
                return;
              }

              await guardarDatosTrabajador(
                nombre: nombreController.text.trim(),
                telefono: telefonoController.text.trim(),
                email: emailController.text.trim(),
                direccion: direccionController.text.trim(),
              );

              if (!mounted) return;

              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // =========================
  // MONEDA
  // =========================
  void mostrarMoneda() {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text("Seleccionar moneda"),
        children: [
          RadioListTile<String>(
            title: const Text("Peso mexicano"),
            subtitle: const Text("MXN - \$"),
            value: "MXN",
            groupValue: moneda,
            onChanged: (value) async {
              if (value == null) return;

              await guardarMoneda(value);

              if (!mounted) return;
              Navigator.pop(context);
            },
          ),

          RadioListTile<String>(
            title: const Text("Dólar estadounidense"),
            subtitle: const Text("USD - US\$"),
            value: "USD",
            groupValue: moneda,
            onChanged: (value) async {
              if (value == null) return;

              await guardarMoneda(value);

              if (!mounted) return;
              Navigator.pop(context);
            },
          ),

          RadioListTile<String>(
            title: const Text("Euro"),
            subtitle: const Text("EUR - €"),
            value: "EUR",
            groupValue: moneda,
            onChanged: (value) async {
              if (value == null) return;

              await guardarMoneda(value);

              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // ACERCA DE
  // =========================
  void mostrarAcercaDe() {
    showAboutDialog(
      context: context,
      applicationName: "Sistema de Presupuestos",
      applicationVersion: "1.0.0",
      applicationIcon: const Icon(
        Icons.electrical_services,
        size: 45,
      ),
      children: const [
        Text(
          "Aplicación para crear presupuestos de servicios eléctricos, "
          "registrar clientes, materiales, mano de obra, gastos, generar PDF "
          "y sincronizar datos con la nube.",
        ),
      ],
    );
  }

  // =========================
  // CERRAR SESIÓN
  // =========================
  Future<void> confirmarCerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cerrar sesión"),
        content: const Text(
          "¿Seguro que deseas cerrar sesión?\n\n"
          "Se limpiarán los datos locales de este dispositivo.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Cerrar sesión"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await cerrarSesion();
    }
  }

  Future<void> cerrarSesion() async {
    try {
      await AuthService().logout();
      await DBHelper.instance.limpiarBaseDatos();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cerrar sesión: $e")),
      );
    }
  }

  // =========================
  // TILE
  // =========================
  Widget configTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    final existeMembrete =
        membretePath != null && File(membretePath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuración"),
      ),

      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: Colors.blue.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            child: Icon(Icons.person, size: 32),
                          ),

                          const SizedBox(width: 15),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombreTrabajador.isEmpty
                                      ? "Trabajador no configurado"
                                      : nombreTrabajador,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  telefonoTrabajador.isEmpty
                                      ? "Sin teléfono registrado"
                                      : telefonoTrabajador,
                                ),

                                Text(
                                  emailTrabajador.isEmpty
                                      ? "Sin correo registrado"
                                      : emailTrabajador,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                configTile(
                  icon: Icons.person,
                  title: "Datos del trabajador",
                  subtitle: nombreTrabajador.isEmpty
                      ? "Agrega nombre, teléfono, correo y dirección"
                      : "Editar información del trabajador",
                  onTap: mostrarDatosTrabajador,
                  color: Colors.blue,
                ),

                configTile(
                  icon: Icons.image,
                  title: "Hoja membretada",
                  subtitle: existeMembrete
                      ? "Membrete cargado para los PDF"
                      : "Sin membrete, el PDF se generará normal",
                  onTap: mostrarMembrete,
                  color: Colors.purple,
                ),

                configTile(
                  icon: Icons.attach_money,
                  title: "Moneda",
                  subtitle: "Moneda actual: $moneda",
                  onTap: mostrarMoneda,
                  color: Colors.green,
                ),

                configTile(
                  icon: Icons.info,
                  title: "Acerca de la app",
                  subtitle: "Información del sistema",
                  onTap: mostrarAcercaDe,
                  color: Colors.orange,
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: confirmarCerrarSesion,
                    icon: const Icon(Icons.logout),
                    label: const Text("Cerrar sesión"),
                  ),
                ),
              ],
            ),
    );
  }
}