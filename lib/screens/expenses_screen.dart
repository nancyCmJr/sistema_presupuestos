import 'package:flutter/material.dart';
import 'package:sistema_presupuestos/database/db_helper.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> gastos = [];
  List<Map<String, dynamic>> filtrados = [];

  final searchController = TextEditingController();

  bool cargando = true;

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

  double totalGastos() {
    double total = 0;

    for (final g in gastos) {
      total += toDouble(g["monto"]);
    }

    return total;
  }

  // =========================
  // CARGAR GASTOS DE CATÁLOGO
  // =========================
  Future<void> cargar() async {
    final db = await DBHelper.instance.database;

    final data = await db.query(
      'gastos',
      where: 'presupuesto_id IS NULL',
      orderBy: 'descripcion ASC',
    );

    setState(() {
      gastos = List<Map<String, dynamic>>.from(data);
      cargando = false;
    });

    aplicarFiltro();
  }

  // =========================
  // BUSCAR
  // =========================
  void aplicarFiltro() {
    final query = searchController.text.trim().toLowerCase();

    final data = gastos.where((g) {
      final descripcion = g["descripcion"].toString().toLowerCase();
      return descripcion.contains(query);
    }).toList();

    setState(() {
      filtrados = data;
    });
  }

  // =========================
  // FORMULARIO AGREGAR / EDITAR
  // =========================
  Future<void> mostrarFormulario({Map<String, dynamic>? gasto}) async {
    final editando = gasto != null;

    final descripcionController = TextEditingController(
      text: editando ? gasto["descripcion"] : "",
    );

    final montoController = TextEditingController(
      text: editando ? toDouble(gasto["monto"]).toStringAsFixed(2) : "",
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(editando ? "Editar gasto" : "Agregar gasto"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: descripcionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: "Descripción",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: montoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Monto",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
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

          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Guardar"),
            onPressed: () async {
              final descripcion = descripcionController.text.trim();
              final monto = double.tryParse(montoController.text.trim()) ?? 0;

              if (descripcion.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("La descripción es obligatoria"),
                  ),
                );
                return;
              }

              if (monto <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Ingresa un monto válido"),
                  ),
                );
                return;
              }

              final db = await DBHelper.instance.database;

              if (editando) {
                await db.update(
                  'gastos',
                  {
                    "descripcion": descripcion,
                    "monto": monto,
                  },
                  where: 'id = ?',
                  whereArgs: [gasto["id"]],
                );
              } else {
                await db.insert('gastos', {
                  "presupuesto_id": null,
                  "descripcion": descripcion,
                  "monto": monto,
                });
              }

              if (!mounted) return;

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    editando
                        ? "Gasto actualizado correctamente"
                        : "Gasto agregado correctamente",
                  ),
                ),
              );

              await cargar();
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // CONFIRMAR ELIMINAR
  // =========================
  Future<void> confirmarEliminar(Map<String, dynamic> gasto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Eliminar gasto"),
        content: Text(
          "¿Seguro que deseas eliminar \"${gasto["descripcion"]}\"?",
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
            icon: const Icon(Icons.delete),
            label: const Text("Eliminar"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await eliminar(gasto["id"]);
    }
  }

  // =========================
  // ELIMINAR
  // =========================
  Future<void> eliminar(int id) async {
    final db = await DBHelper.instance.database;

    await db.delete(
      'gastos',
      where: 'id = ? AND presupuesto_id IS NULL',
      whereArgs: [id],
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Gasto eliminado")),
    );

    await cargar();
  }

  // =========================
  // CARD GASTO
  // =========================
  Widget gastoCard(Map<String, dynamic> gasto) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.15),
          child: const Icon(
            Icons.payments,
            color: Colors.orange,
          ),
        ),
        title: Text(
          gasto["descripcion"] ?? "Gasto",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text("Gasto reutilizable para presupuestos"),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == "editar") {
              mostrarFormulario(gasto: gasto);
            } else if (value == "eliminar") {
              confirmarEliminar(gasto);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: "editar",
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text("Editar"),
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
        onTap: () => mostrarFormulario(gasto: gasto),
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
              buscando ? Icons.search_off : Icons.payments_outlined,
              size: 70,
              color: Colors.grey,
            ),

            const SizedBox(height: 12),

            Text(
              buscando
                  ? "No se encontraron gastos"
                  : "No hay gastos registrados",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              buscando
                  ? "Intenta buscar con otro nombre."
                  : "Agrega gastos comunes como transporte, viáticos, renta de herramienta o imprevistos.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 16),

            if (!buscando)
              ElevatedButton.icon(
                onPressed: () => mostrarFormulario(),
                icon: const Icon(Icons.add),
                label: const Text("Agregar gasto"),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gastos"),
        actions: [
          IconButton(
            tooltip: "Actualizar",
            icon: const Icon(Icons.refresh),
            onPressed: cargar,
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormulario(),
        icon: const Icon(Icons.add),
        label: const Text("Agregar"),
      ),

      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payments, color: Colors.orange),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          "${gastos.length} gastos registrados",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      Text(
                        money(totalGastos()),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Buscar gasto",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                aplicarFiltro();
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (_) => aplicarFiltro(),
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: filtrados.isEmpty
                      ? estadoVacio()
                      : RefreshIndicator(
                          onRefresh: cargar,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: filtrados.length,
                            itemBuilder: (context, index) {
                              final gasto = filtrados[index];

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Colors.orange.withOpacity(0.15),
                                    child: const Icon(
                                      Icons.payments,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  title: Text(
                                    gasto["descripcion"] ?? "Gasto",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    "Gasto reutilizable para presupuestos",
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        money(gasto["monto"]),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == "editar") {
                                            mostrarFormulario(gasto: gasto);
                                          } else if (value == "eliminar") {
                                            confirmarEliminar(gasto);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: "editar",
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit,
                                                  color: Colors.blue,
                                                ),
                                                SizedBox(width: 8),
                                                Text("Editar"),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: "eliminar",
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 8),
                                                Text("Eliminar"),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () => mostrarFormulario(gasto: gasto),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}