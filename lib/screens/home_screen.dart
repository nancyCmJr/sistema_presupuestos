import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int totalPresupuestos = 0;
  int totalClientes = 0;
  int pendientesSync = 0;

  double totalCotizado = 0;

  bool cargando = true;
  bool sincronizando = false;

  @override
  void initState() {
    super.initState();
    cargarResumen();
  }

  // =========================
  // HELPERS
  // =========================
  double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String money(dynamic value) {
    return "\$${toDouble(value).toStringAsFixed(2)}";
  }

  // =========================
  // CARGAR RESUMEN
  // =========================
  Future<void> cargarResumen() async {
    final db = await DBHelper.instance.database;

    final presupuestos = await db.rawQuery('''
      SELECT 
        COUNT(*) AS total,
        IFNULL(SUM(total), 0) AS total_cotizado
      FROM presupuestos
      WHERE deleted = 0
    ''');

    final clientes = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM clientes
      WHERE deleted = 0
    ''');

    final pendientesPresupuestos = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM presupuestos
      WHERE sync = 0
    ''');

    final pendientesClientes = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM clientes
      WHERE sync = 0
    ''');

    final pendientesMateriales = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM materiales
      WHERE sync = 0
    ''');

    setState(() {
      totalPresupuestos = presupuestos.first["total"] as int;
      totalCotizado = toDouble(presupuestos.first["total_cotizado"]);
      totalClientes = clientes.first["total"] as int;

      pendientesSync =
          (pendientesPresupuestos.first["total"] as int) +
          (pendientesClientes.first["total"] as int) +
          (pendientesMateriales.first["total"] as int);

      cargando = false;
    });
  }

  // =========================
  // SINCRONIZAR
  // =========================
  Future<void> sincronizar() async {
    if (sincronizando) return;

    setState(() {
      sincronizando = true;
    });

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sincronizando datos...")),
      );

      await SyncService.syncAll();
      await SyncService.descargarDatos();

      await cargarResumen();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sincronización completada")),
      );
    } catch (e) {
      print("Error al sincronizar: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al sincronizar: $e")),
      );
    }

    if (mounted) {
      setState(() {
        sincronizando = false;
      });
    }
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
          "Se limpiarán los datos locales de este dispositivo para evitar mezclar información con otra cuenta.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.logout),
            label: const Text("Cerrar sesión"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await AuthService().logout();
      await DBHelper.instance.limpiarBaseDatos();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    }
  }

  // =========================
  // CARD RESUMEN
  // =========================
  Widget resumenCard({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icono, color: color, size: 30),

              const SizedBox(height: 8),

              Text(
                valor,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // ACCESO RÁPIDO
  // =========================
  Widget accesoRapido({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color color,
    required String ruta,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pushNamed(context, ruta).then((_) => cargarResumen());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icono, color: color, size: 28),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitulo,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inicio"),
        actions: [
          IconButton(
            tooltip: "Sincronizar",
            icon: sincronizando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
            onPressed: sincronizando ? null : sincronizar,
          ),

          IconButton(
            tooltip: "Cerrar sesión",
            icon: const Icon(Icons.logout),
            onPressed: confirmarCerrarSesion,
          ),
        ],
      ),

      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: cargarResumen,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // BIENVENIDA
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 32,
                          child: Icon(
                            Icons.electrical_services,
                            size: 34,
                          ),
                        ),

                        const SizedBox(width: 15),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Sistema de Presupuestos",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 5),

                              Text(
                                pendientesSync > 0
                                    ? "Tienes $pendientesSync cambio(s) pendientes de sincronizar."
                                    : "Todo está sincronizado.",
                                style: TextStyle(
                                  color: pendientesSync > 0
                                      ? Colors.orange
                                      : Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // BOTÓN PRINCIPAL
                  SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, "/create")
                            .then((_) => cargarResumen());
                      },
                      icon: const Icon(Icons.note_add),
                      label: const Text(
                        "Crear nuevo presupuesto",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // RESUMEN
                  Row(
                    children: [
                      resumenCard(
                        titulo: "Presupuestos",
                        valor: "$totalPresupuestos",
                        icono: Icons.folder,
                        color: Colors.indigo,
                      ),

                      resumenCard(
                        titulo: "Clientes",
                        valor: "$totalClientes",
                        icono: Icons.people,
                        color: Colors.purple,
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      resumenCard(
                        titulo: "Total cotizado",
                        valor: money(totalCotizado),
                        icono: Icons.attach_money,
                        color: Colors.green,
                      ),

                      resumenCard(
                        titulo: "Pendientes sync",
                        valor: "$pendientesSync",
                        icono: Icons.sync_problem,
                        color: pendientesSync > 0
                            ? Colors.orange
                            : Colors.green,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // SINCRONIZACIÓN
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.15),
                        child: sincronizando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_sync, color: Colors.blue),
                      ),
                      title: const Text(
                        "Sincronización",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        pendientesSync > 0
                            ? "Hay cambios locales pendientes."
                            : "Tus datos están actualizados.",
                      ),
                      trailing: ElevatedButton(
                        onPressed: sincronizando ? null : sincronizar,
                        child: const Text("Sincronizar"),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Accesos rápidos",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  accesoRapido(
                    titulo: "Presupuestos",
                    subtitulo: "Consulta, edita y cambia estados",
                    icono: Icons.folder,
                    color: Colors.indigo,
                    ruta: "/budgets",
                  ),

                  accesoRapido(
                    titulo: "Clientes",
                    subtitulo: "Administra tus clientes",
                    icono: Icons.person,
                    color: Colors.purple,
                    ruta: "/clients",
                  ),

                  accesoRapido(
                    titulo: "Materiales",
                    subtitulo: "Catálogo y comparación de precios",
                    icono: Icons.electrical_services,
                    color: Colors.blue,
                    ruta: "/materials",
                  ),

                  accesoRapido(
                    titulo: "Mano de Obra",
                    subtitulo: "Trabajos reutilizables",
                    icono: Icons.handyman,
                    color: Colors.orange,
                    ruta: "/labor",
                  ),

                  accesoRapido(
                    titulo: "Otros Gastos",
                    subtitulo: "Transporte, viáticos e imprevistos",
                    icono: Icons.money,
                    color: Colors.green,
                    ruta: "/expenses",
                  ),

                  accesoRapido(
                    titulo: "Reportes",
                    subtitulo: "Ingresos, costos y estados",
                    icono: Icons.bar_chart,
                    color: Colors.teal,
                    ruta: "/reports",
                  ),

                  accesoRapido(
                    titulo: "Configuración",
                    subtitulo: "Datos del trabajador, moneda y membrete",
                    icono: Icons.settings,
                    color: Colors.grey,
                    ruta: "/settings",
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}