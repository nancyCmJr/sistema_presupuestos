import 'package:flutter/material.dart';
import 'package:sistema_presupuestos/database/db_helper.dart';

class LaborScreen extends StatefulWidget {
  const LaborScreen({super.key});

  @override
  State<LaborScreen> createState() => _LaborScreenState();
}

class _LaborScreenState extends State<LaborScreen> {
  List<Map<String, dynamic>> trabajos = [];
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

  double totalManoObra() {
    double total = 0;

    for (final t in trabajos) {
      total += toDouble(t["precio"]);
    }

    return total;
  }

  // =========================
  // CARGAR MANO DE OBRA
  // =========================
  Future<void> cargar() async {
    final db = await DBHelper.instance.database;

    final data = await db.query(
      'mano_obra',
      orderBy: 'descripcion ASC',
    );

    setState(() {
      trabajos = List<Map<String, dynamic>>.from(data);
      cargando = false;
    });

    aplicarFiltro();
  }

  // =========================
  // BUSCAR
  // =========================
  void aplicarFiltro() {
    final query = searchController.text.trim().toLowerCase();

    final data = trabajos.where((t) {
      final descripcion = t["descripcion"].toString().toLowerCase();
      return descripcion.contains(query);
    }).toList();

    setState(() {
      filtrados = data;
    });
  }

  // =========================
  // FORMULARIO AGREGAR / EDITAR
  // =========================
  Future<void> mostrarFormulario({Map<String, dynamic>? trabajo}) async {
    final editando = trabajo != null;

    final descripcionController = TextEditingController(
      text: editando ? trabajo["descripcion"] : "",
    );

    final precioController = TextEditingController(
      text: editando ? toDouble(trabajo["precio"]).toStringAsFixed(2) : "",
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(editando ? "Editar mano de obra" : "Agregar mano de obra"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: descripcionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: "Descripción del trabajo",
                  hintText: "Ej. Instalación de apagador",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.handyman),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: precioController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Precio",
                  hintText: "Ej. 150",
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
              final precio = double.tryParse(precioController.text.trim()) ?? 0;

              if (descripcion.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("La descripción es obligatoria"),
                  ),
                );
                return;
              }

              if (precio <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Ingresa un precio válido"),
                  ),
                );
                return;
              }

              final db = await DBHelper.instance.database;

              if (editando) {
                await db.update(
                  'mano_obra',
                  {
                    "descripcion": descripcion,
                    "precio": precio,
                  },
                  where: 'id = ?',
                  whereArgs: [trabajo["id"]],
                );
              } else {
                await db.insert('mano_obra', {
                  "descripcion": descripcion,
                  "precio": precio,
                });
              }

              if (!mounted) return;

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    editando
                        ? "Mano de obra actualizada correctamente"
                        : "Mano de obra agregada correctamente",
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
  Future<void> confirmarEliminar(Map<String, dynamic> trabajo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Eliminar mano de obra"),
        content: Text(
          "¿Seguro que deseas eliminar \"${trabajo["descripcion"]}\"?",
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
      await eliminar(trabajo["id"]);
    }
  }

  // =========================
  // ELIMINAR
  // =========================
  Future<void> eliminar(int id) async {
    final db = await DBHelper.instance.database;

    await db.delete(
      'mano_obra',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Mano de obra eliminada")),
    );

    await cargar();
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
              buscando ? Icons.search_off : Icons.handyman_outlined,
              size: 70,
              color: Colors.grey,
            ),

            const SizedBox(height: 12),

            Text(
              buscando
                  ? "No se encontraron trabajos"
                  : "No hay mano de obra registrada",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              buscando
                  ? "Intenta buscar con otra descripción."
                  : "Agrega trabajos comunes como instalación, revisión, reparación o mantenimiento.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 16),

            if (!buscando)
              ElevatedButton.icon(
                onPressed: () => mostrarFormulario(),
                icon: const Icon(Icons.add),
                label: const Text("Agregar mano de obra"),
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
        title: const Text("Mano de Obra"),
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
                    color: Colors.blue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.handyman, color: Colors.blue),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          "${trabajos.length} trabajos registrados",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      Text(
                        money(totalManoObra()),
                        style: const TextStyle(
                          color: Colors.blue,
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
                      hintText: "Buscar mano de obra",
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
                              final trabajo = filtrados[index];

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
                                        Colors.blue.withOpacity(0.15),
                                    child: const Icon(
                                      Icons.handyman,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  title: Text(
                                    trabajo["descripcion"] ??
                                        "Mano de obra",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    "Trabajo reutilizable para presupuestos",
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        money(trabajo["precio"]),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == "editar") {
                                            mostrarFormulario(
                                              trabajo: trabajo,
                                            );
                                          } else if (value == "eliminar") {
                                            confirmarEliminar(trabajo);
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
                                  onTap: () => mostrarFormulario(
                                    trabajo: trabajo,
                                  ),
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