import 'package:flutter/material.dart';
import 'package:sistema_presupuestos/database/db_helper.dart';

class BudgetsListScreen extends StatefulWidget {
  const BudgetsListScreen({super.key});

  @override
  State<BudgetsListScreen> createState() => _BudgetsListScreenState();
}

class _BudgetsListScreenState extends State<BudgetsListScreen> {
  List<Map<String, dynamic>> presupuestos = [];
  List<Map<String, dynamic>> filtrados = [];

  final searchController = TextEditingController();

  bool cargando = true;
  String filtroEstado = "todos";

  @override
  void initState() {
    super.initState();
    cargar();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

  String now() {
    return DateTime.now().toIso8601String();
  }

  bool pendienteSync(Map<String, dynamic> p) {
    return p["sync"] == 0 || p["sync"] == false;
  }

  String formatearFecha(dynamic value) {
    if (value == null) return "Sin fecha";

    final fecha = value.toString();

    if (fecha.length >= 10) {
      return fecha.substring(0, 10);
    }

    return fecha;
  }

  String estadoTexto(String estado) {
    switch (estado) {
      case "aprobado":
        return "Aprobado";
      case "rechazado":
        return "Rechazado";
      default:
        return "Pendiente";
    }
  }

  IconData estadoIcono(String estado) {
    switch (estado) {
      case "aprobado":
        return Icons.check_circle;
      case "rechazado":
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  Color estadoColor(String estado) {
    switch (estado) {
      case "aprobado":
        return Colors.green;
      case "rechazado":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  // =========================
  // CARGAR DATOS
  // =========================
  Future<void> cargar() async {
    final db = await DBHelper.instance.database;

    final data = await db.rawQuery('''
      SELECT 
        p.*,
        c.nombre AS cliente_nombre,
        c.telefono AS cliente_telefono
      FROM presupuestos p
      LEFT JOIN clientes c ON c.id = p.cliente_id
      WHERE p.deleted = 0
      ORDER BY p.fecha DESC
    ''');

    setState(() {
      presupuestos = List<Map<String, dynamic>>.from(data);
      cargando = false;
    });

    aplicarFiltros();
  }

  // =========================
  // FILTRAR
  // =========================
  void aplicarFiltros() {
    final query = searchController.text.trim().toLowerCase();

    final data = presupuestos.where((p) {
      final estado = p["estado"]?.toString() ?? "pendiente";
      final cliente = p["cliente_nombre"]?.toString().toLowerCase() ?? "";
      final descripcion = p["descripcion"]?.toString().toLowerCase() ?? "";
      final id = p["id"].toString();

      final coincideBusqueda =
          cliente.contains(query) ||
          descripcion.contains(query) ||
          id.contains(query);

      final coincideEstado =
          filtroEstado == "todos" || estado == filtroEstado;

      return coincideBusqueda && coincideEstado;
    }).toList();

    setState(() {
      filtrados = data;
    });
  }

  // =========================
  // CAMBIAR FILTRO
  // =========================
  void cambiarFiltro(String estado) {
    setState(() {
      filtroEstado = estado;
    });

    aplicarFiltros();
  }

  // =========================
  // RESUMEN
  // =========================
  int contarPorEstado(String estado) {
    return presupuestos.where((p) {
      return (p["estado"] ?? "pendiente") == estado;
    }).length;
  }

  double totalGeneral() {
    double total = 0;

    for (final p in presupuestos) {
      total += toDouble(p["total"]);
    }

    return total;
  }

  int totalPendientesSync() {
    return presupuestos.where(pendienteSync).length;
  }

  // =========================
  // CAMBIAR ESTADO
  // =========================
  Future<void> seleccionarEstado(Map<String, dynamic> presupuesto) async {
    final id = presupuesto["id"];
    final estadoActual = presupuesto["estado"] ?? "pendiente";

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cambiar estado"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _opcionEstado(
              id: id,
              estadoActual: estadoActual,
              nuevoEstado: "pendiente",
              titulo: "Pendiente",
              icono: Icons.hourglass_empty,
              color: Colors.orange,
            ),
            _opcionEstado(
              id: id,
              estadoActual: estadoActual,
              nuevoEstado: "aprobado",
              titulo: "Aprobado",
              icono: Icons.check_circle,
              color: Colors.green,
            ),
            _opcionEstado(
              id: id,
              estadoActual: estadoActual,
              nuevoEstado: "rechazado",
              titulo: "Rechazado",
              icono: Icons.cancel,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcionEstado({
    required int id,
    required String estadoActual,
    required String nuevoEstado,
    required String titulo,
    required IconData icono,
    required Color color,
  }) {
    final seleccionado = estadoActual == nuevoEstado;

    return ListTile(
      leading: Icon(icono, color: color),
      title: Text(titulo),
      trailing: seleccionado ? const Icon(Icons.check) : null,
      onTap: () async {
        Navigator.pop(context);
        await actualizarEstado(id, nuevoEstado);
      },
    );
  }

  Future<void> actualizarEstado(int id, String estado) async {
    final db = await DBHelper.instance.database;

    await db.update(
      'presupuestos',
      {
        "estado": estado,
        "sync": 0,
        "updated_at": now(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await cargar();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Estado actualizado a ${estadoTexto(estado)}"),
      ),
    );
  }

  // =========================
  // CONFIRMAR ELIMINACIÓN
  // =========================
  Future<void> confirmarEliminar(Map<String, dynamic> presupuesto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Eliminar presupuesto"),
        content: Text(
          "¿Seguro que deseas eliminar el presupuesto #${presupuesto["id"]}?\n\n"
          "Se marcará como eliminado para sincronizar el cambio.",
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
            icon: const Icon(Icons.delete),
            label: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await eliminar(presupuesto["id"]);
    }
  }

  // =========================
  // ELIMINAR SOFT DELETE
  // =========================
  Future<void> eliminar(int id) async {
    final db = await DBHelper.instance.database;

    await db.update(
      'presupuestos',
      {
        "deleted": 1,
        "sync": 0,
        "updated_at": now(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await cargar();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Presupuesto eliminado")),
    );
  }

  // =========================
  // CARD PRESUPUESTO
  // =========================
  Widget presupuestoCard(Map<String, dynamic> p) {
    final estado = p["estado"]?.toString() ?? "pendiente";
    final syncPendiente = pendienteSync(p);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pushNamed(
            context,
            "/budget-detail",
            arguments: p["id"],
          ).then((_) => cargar());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ENCABEZADO
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: estadoColor(estado).withOpacity(0.15),
                    child: Icon(
                      estadoIcono(estado),
                      color: estadoColor(estado),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Presupuesto #${p["id"]}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(
                          p["cliente_nombre"] ?? "Cliente no encontrado",
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == "estado") {
                        seleccionarEstado(p);
                      } else if (value == "detalle") {
                        Navigator.pushNamed(
                          context,
                          "/budget-detail",
                          arguments: p["id"],
                        ).then((_) => cargar());
                      } else if (value == "eliminar") {
                        confirmarEliminar(p);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: "detalle",
                        child: Row(
                          children: [
                            Icon(Icons.visibility, color: Colors.blue),
                            SizedBox(width: 8),
                            Text("Ver detalle"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "estado",
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz, color: Colors.green),
                            SizedBox(width: 8),
                            Text("Cambiar estado"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: "eliminar",
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text("Eliminar"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if ((p["descripcion"] ?? "").toString().trim().isNotEmpty)
                Text(
                  p["descripcion"],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text(formatearFecha(p["fecha"])),

                  const Spacer(),

                  Text(
                    money(p["total"]),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      estadoTexto(estado),
                      style: TextStyle(
                        color: estadoColor(estado),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: estadoColor(estado).withOpacity(0.12),
                  ),

                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      syncPendiente ? "Pendiente sync" : "Sincronizado",
                      style: TextStyle(
                        color: syncPendiente ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: syncPendiente
                        ? Colors.orange.withOpacity(0.12)
                        : Colors.green.withOpacity(0.12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // FILTROS
  // =========================
  Widget filtros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          filtroChip("todos", "Todos", Icons.list),
          filtroChip("pendiente", "Pendientes", Icons.hourglass_empty),
          filtroChip("aprobado", "Aprobados", Icons.check_circle),
          filtroChip("rechazado", "Rechazados", Icons.cancel),
        ],
      ),
    );
  }

  Widget filtroChip(String value, String label, IconData icon) {
    final selected = filtroEstado == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        avatar: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : Colors.black54,
        ),
        label: Text(label),
        selectedColor: Colors.blue,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
        ),
        onSelected: (_) => cambiarFiltro(value),
      ),
    );
  }

  // =========================
  // ESTADO VACÍO
  // =========================
  Widget estadoVacio() {
    final buscando = searchController.text.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              buscando ? Icons.search_off : Icons.receipt_long_outlined,
              size: 70,
              color: Colors.grey,
            ),

            const SizedBox(height: 12),

            Text(
              buscando
                  ? "No se encontraron presupuestos"
                  : "No hay presupuestos registrados",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              buscando
                  ? "Intenta buscar por cliente, descripción o número de presupuesto."
                  : "Crea tu primer presupuesto para comenzar a trabajar.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 16),

            if (!buscando)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, "/create").then((_) => cargar());
                },
                icon: const Icon(Icons.add),
                label: const Text("Crear presupuesto"),
              ),
          ],
        ),
      ),
    );
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    final pendientesSync = totalPendientesSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Presupuestos"),
        actions: [
          IconButton(
            tooltip: "Actualizar",
            icon: const Icon(Icons.refresh),
            onPressed: cargar,
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, "/create").then((_) => cargar());
        },
        icon: const Icon(Icons.add),
        label: const Text("Nuevo"),
      ),

      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // RESUMEN
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, color: Colors.blue),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              "${presupuestos.length} presupuestos",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),

                          Text(
                            money(totalGeneral()),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _resumenMini(
                              "Pendientes",
                              contarPorEstado("pendiente").toString(),
                              Colors.orange,
                            ),
                          ),
                          Expanded(
                            child: _resumenMini(
                              "Aprobados",
                              contarPorEstado("aprobado").toString(),
                              Colors.green,
                            ),
                          ),
                          Expanded(
                            child: _resumenMini(
                              "Rechazados",
                              contarPorEstado("rechazado").toString(),
                              Colors.red,
                            ),
                          ),
                        ],
                      ),

                      if (pendientesSync > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "$pendientesSync presupuesto(s) pendientes de sincronizar",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // BUSCADOR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Buscar por cliente, descripción o ID",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                aplicarFiltros();
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (_) => aplicarFiltros(),
                  ),
                ),

                const SizedBox(height: 10),

                filtros(),

                const SizedBox(height: 6),

                Expanded(
                  child: filtrados.isEmpty
                      ? estadoVacio()
                      : RefreshIndicator(
                          onRefresh: cargar,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: filtrados.length,
                            itemBuilder: (context, index) {
                              return presupuestoCard(filtrados[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _resumenMini(String titulo, String valor, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}