import 'package:flutter/material.dart';
import 'package:sistema_presupuestos/database/db_helper.dart';
import 'package:sistema_presupuestos/services/api_service.dart';

class CreateBudgetScreen extends StatefulWidget {
  const CreateBudgetScreen({super.key});

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  List<Map<String, dynamic>> clientes = [];
  int? clienteSeleccionadoId;

  List<Map<String, dynamic>> materiales = [];
  List<Map<String, dynamic>> manoObra = [];
  List<Map<String, dynamic>> gastos = [];

  double total = 0;

  final descripcionController = TextEditingController();
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarClientes();
  }

  @override
  void dispose() {
    descripcionController.dispose();
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

  String now() {
    return DateTime.now().toIso8601String();
  }

  // =========================
  // CARGAR CLIENTES
  // =========================
  Future<void> cargarClientes() async {
    final data = await DBHelper.instance.obtenerClientes();

    setState(() {
      clientes = List<Map<String, dynamic>>.from(data);
      cargando = false;
    });
  }

  // =========================
  // CALCULAR TOTAL
  // =========================
  void calcularTotal() {
    double t = 0;

    for (var m in materiales) {
      t += toDouble(m["subtotal"]);
    }

    for (var m in manoObra) {
      t += toDouble(m["subtotal"]);
    }

    for (var g in gastos) {
      t += toDouble(g["monto"]);
    }

    setState(() => total = t);
  }

  // =========================
  // CONFIRMAR ELIMINACIÓN
  // =========================
  Future<void> confirmarEliminarItem(
    List lista,
    int index,
    String nombre,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmar eliminación"),
        content: Text("¿Seguro que deseas eliminar \"$nombre\"?"),
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
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() {
        lista.removeAt(index);
      });

      calcularTotal();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Elemento eliminado")),
      );
    }
  }

  // =========================
  // EDITAR CANTIDAD MATERIAL
  // =========================
  void editarCantidadMaterial(int index) {
    final controller = TextEditingController(
      text: materiales[index]["cantidad"].toString(),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Editar cantidad"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Cantidad",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            child: const Text("Guardar"),
            onPressed: () {
              int cantidad = int.tryParse(controller.text) ?? 1;

              if (cantidad <= 0) cantidad = 1;

              setState(() {
                materiales[index]["cantidad"] = cantidad;
                materiales[index]["subtotal"] =
                    cantidad * toDouble(materiales[index]["precio"]);
              });

              calcularTotal();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // BUSCAR MATERIAL LOCAL + ONLINE
  // =========================
  void buscarMaterial() {
    final controller = TextEditingController();

    List<Map<String, dynamic>> resultadosLocales = [];
    List<Map<String, dynamic>> resultadosOnline = [];

    bool loadingOnline = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> buscarLocal(String query) async {
            final db = await DBHelper.instance.database;

            if (query.trim().isEmpty) {
              setStateDialog(() {
                resultadosLocales = [];
                resultadosOnline = [];
              });
              return;
            }

            final data = await db.query(
              'materiales',
              where: 'deleted = 0 AND nombre LIKE ?',
              whereArgs: ['%${query.trim()}%'],
              orderBy: 'nombre ASC',
            );

            setStateDialog(() {
              resultadosLocales = List<Map<String, dynamic>>.from(data);
            });
          }

          Future<void> buscarOnline() async {
            final query = controller.text.trim();

            if (query.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Escribe el nombre del material"),
                ),
              );
              return;
            }

            setStateDialog(() {
              loadingOnline = true;
              resultadosOnline = [];
            });

            try {
              final res = await ApiService.obtenerPrecios(query);

              setStateDialog(() {
                resultadosOnline = List<Map<String, dynamic>>.from(
                  res["precios"] ?? [],
                );
              });
            } catch (e) {
              print("Error buscando precios online: $e");

              setStateDialog(() {
                resultadosOnline = [];
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("No se pudieron obtener precios online"),
                ),
              );
            }

            setStateDialog(() {
              loadingOnline = false;
            });
          }

          void agregarMaterialLocal(Map<String, dynamic> item) {
            final precio = toDouble(item["precio"]);

            setState(() {
              materiales.add({
                "nombre": item["nombre"],
                "precio": precio,
                "cantidad": 1,
                "subtotal": precio,
                "material_id": item["id"],
              });
            });

            calcularTotal();
            Navigator.pop(context);
          }

          Future<void> agregarMaterialOnline(
            Map<String, dynamic> item,
          ) async {
            final db = await DBHelper.instance.database;

            final precio = toDouble(item["precio"]);

            final nuevoMaterialId = await db.insert('materiales', {
              "nombre": item["nombre"],
              "precio": precio,
              "unidad": "pieza",
              "origen": item["tienda"] ?? "api",
              "sync": 0,
              "updated_at": now(),
              "deleted": 0,
            });

            setState(() {
              materiales.add({
                "nombre": item["nombre"],
                "precio": precio,
                "cantidad": 1,
                "subtotal": precio,
                "material_id": nuevoMaterialId,
              });
            });

            calcularTotal();
            Navigator.pop(context);
          }

          return AlertDialog(
            title: const Text("Buscar material"),
            content: SizedBox(
              width: double.maxFinite,
              height: 450,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: "Buscar material",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: buscarLocal,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: buscarOnline,
                    icon: const Icon(Icons.wifi_find),
                    label: const Text("Buscar precio en internet"),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: [
                        const Text(
                          "Materiales locales",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        if (resultadosLocales.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("No hay materiales locales encontrados"),
                          ),

                        ...resultadosLocales.map((item) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.inventory),
                              title: Text(item["nombre"]),
                              subtitle: Text(
                                "Origen: ${item["origen"] ?? "local"}",
                              ),
                              trailing: Text(
                                "\$${toDouble(item["precio"]).toStringAsFixed(2)}",
                              ),
                              onTap: () => agregarMaterialLocal(item),
                            ),
                          );
                        }),

                        const Divider(),

                        const Text(
                          "Resultados de internet",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        if (loadingOnline)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),

                        if (!loadingOnline && resultadosOnline.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Sin resultados online"),
                          ),

                        ...resultadosOnline.map((item) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.public),
                              title: Text(item["nombre"] ?? ""),
                              subtitle: Text(
                                "Tienda: ${item["tienda"] ?? "internet"}",
                              ),
                              trailing: Text(
                                "\$${toDouble(item["precio"]).toStringAsFixed(2)}",
                              ),
                              onTap: () => agregarMaterialOnline(item),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cerrar"),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================
  // AGREGAR / CREAR MANO DE OBRA
  // =========================
  Future<void> agregarManoObra() async {
    final db = await DBHelper.instance.database;

    List<Map<String, dynamic>> catalogo = List<Map<String, dynamic>>.from(
      await db.query(
        'mano_obra',
        orderBy: 'descripcion ASC',
      ),
    );

    final descripcionNuevaController = TextEditingController();
    final precioNuevoController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> recargarCatalogo() async {
            final data = await db.query(
              'mano_obra',
              orderBy: 'descripcion ASC',
            );

            setStateDialog(() {
              catalogo = List<Map<String, dynamic>>.from(data);
            });
          }

          void agregarDesdeCatalogo(Map<String, dynamic> item) {
            final precio = toDouble(item["precio"]);

            setState(() {
              manoObra.add({
                "descripcion": item["descripcion"],
                "precio": precio,
                "cantidad": 1,
                "subtotal": precio,
                "id": item["id"],
              });
            });

            calcularTotal();
            Navigator.pop(context);
          }

          Future<void> crearYAgregarManoObra() async {
            final descripcion = descripcionNuevaController.text.trim();
            final precio = double.tryParse(
                  precioNuevoController.text.trim(),
                ) ??
                0;

            if (descripcion.isEmpty || precio <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Ingresa descripción y precio válido"),
                ),
              );
              return;
            }

            final nuevoId = await db.insert('mano_obra', {
              "descripcion": descripcion,
              "precio": precio,
            });

            await recargarCatalogo();

            setState(() {
              manoObra.add({
                "descripcion": descripcion,
                "precio": precio,
                "cantidad": 1,
                "subtotal": precio,
                "id": nuevoId,
              });
            });

            calcularTotal();

            if (!mounted) return;

            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Mano de obra agregada al presupuesto"),
              ),
            );
          }

          return AlertDialog(
            title: const Text("Agregar mano de obra"),
            content: SizedBox(
              width: double.maxFinite,
              height: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Crear nueva mano de obra",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: descripcionNuevaController,
                    decoration: const InputDecoration(
                      labelText: "Descripción",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: precioNuevoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Precio",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: crearYAgregarManoObra,
                      icon: const Icon(Icons.add),
                      label: const Text("Crear y agregar"),
                    ),
                  ),

                  const Divider(),

                  const Text(
                    "Seleccionar del catálogo",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: catalogo.isEmpty
                        ? const Center(
                            child: Text("No hay mano de obra registrada"),
                          )
                        : ListView.builder(
                            itemCount: catalogo.length,
                            itemBuilder: (_, i) {
                              final item = catalogo[i];
                              final precio = toDouble(item["precio"]);

                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.handyman),
                                  title: Text(item["descripcion"]),
                                  trailing: Text(
                                    "\$${precio.toStringAsFixed(2)}",
                                  ),
                                  onTap: () => agregarDesdeCatalogo(item),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cerrar"),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================
  // AGREGAR / CREAR GASTO
  // =========================
  Future<void> agregarGasto() async {
    final db = await DBHelper.instance.database;

    List<Map<String, dynamic>> catalogo = List<Map<String, dynamic>>.from(
      await db.query(
        'gastos',
        where: 'presupuesto_id IS NULL',
        orderBy: 'descripcion ASC',
      ),
    );

    final descripcionNuevaController = TextEditingController();
    final montoNuevoController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> recargarCatalogo() async {
            final data = await db.query(
              'gastos',
              where: 'presupuesto_id IS NULL',
              orderBy: 'descripcion ASC',
            );

            setStateDialog(() {
              catalogo = List<Map<String, dynamic>>.from(data);
            });
          }

          void agregarDesdeCatalogo(Map<String, dynamic> item) {
            final monto = toDouble(item["monto"]);

            setState(() {
              gastos.add({
                "descripcion": item["descripcion"],
                "monto": monto,
              });
            });

            calcularTotal();
            Navigator.pop(context);
          }

          Future<void> crearYAgregarGasto() async {
            final descripcion = descripcionNuevaController.text.trim();
            final monto = double.tryParse(
                  montoNuevoController.text.trim(),
                ) ??
                0;

            if (descripcion.isEmpty || monto <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Ingresa descripción y monto válido"),
                ),
              );
              return;
            }

            await db.insert('gastos', {
              "presupuesto_id": null,
              "descripcion": descripcion,
              "monto": monto,
            });

            await recargarCatalogo();

            setState(() {
              gastos.add({
                "descripcion": descripcion,
                "monto": monto,
              });
            });

            calcularTotal();

            if (!mounted) return;

            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Gasto agregado al presupuesto"),
              ),
            );
          }

          return AlertDialog(
            title: const Text("Agregar gasto"),
            content: SizedBox(
              width: double.maxFinite,
              height: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Crear nuevo gasto",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: descripcionNuevaController,
                    decoration: const InputDecoration(
                      labelText: "Descripción",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: montoNuevoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Monto",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: crearYAgregarGasto,
                      icon: const Icon(Icons.add),
                      label: const Text("Crear y agregar"),
                    ),
                  ),

                  const Divider(),

                  const Text(
                    "Seleccionar del catálogo",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: catalogo.isEmpty
                        ? const Center(
                            child: Text("No hay gastos registrados"),
                          )
                        : ListView.builder(
                            itemCount: catalogo.length,
                            itemBuilder: (_, i) {
                              final item = catalogo[i];
                              final monto = toDouble(item["monto"]);

                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.money),
                                  title: Text(item["descripcion"]),
                                  trailing: Text(
                                    "\$${monto.toStringAsFixed(2)}",
                                  ),
                                  onTap: () => agregarDesdeCatalogo(item),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cerrar"),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================
  // GUARDAR PRESUPUESTO
  // =========================
  Future<void> guardar() async {
    if (clienteSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un cliente")),
      );
      return;
    }

    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agrega conceptos")),
      );
      return;
    }

    final db = await DBHelper.instance.database;

    final id = await db.insert('presupuestos', {
      "cliente_id": clienteSeleccionadoId,
      "descripcion": descripcionController.text.trim(),
      "total": total,
      "estado": "pendiente",
      "sync": 0,
      "updated_at": now(),
      "deleted": 0,
    });

    for (var m in materiales) {
      await db.insert('detalle_materiales', {
        "presupuesto_id": id,
        "material_id": m["material_id"],
        "cantidad": m["cantidad"],
        "subtotal": m["subtotal"],
      });
    }

    for (var m in manoObra) {
      await db.insert('detalle_mano_obra', {
        "presupuesto_id": id,
        "mano_obra_id": m["id"],
        "cantidad": m["cantidad"] ?? 1,
        "subtotal": m["subtotal"],
      });
    }

    for (var g in gastos) {
      await db.insert('gastos', {
        "presupuesto_id": id,
        "descripcion": g["descripcion"],
        "monto": g["monto"],
      });
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Guardado correctamente")),
    );

    Navigator.pop(context);
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nuevo presupuesto"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: guardar,
        child: const Icon(Icons.save),
      ),

      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),

              child: ListView(
                children: [
                  DropdownButtonFormField<int>(
                    value: clienteSeleccionadoId,
                    hint: const Text("Seleccionar cliente"),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: clientes.map((c) {
                      return DropdownMenuItem<int>(
                        value: c["id"],
                        child: Text(c["nombre"]),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        clienteSeleccionadoId = val;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: "Descripción",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton.icon(
                        onPressed: buscarMaterial,
                        icon: const Icon(Icons.inventory),
                        label: const Text("Material"),
                      ),

                      ElevatedButton.icon(
                        onPressed: agregarManoObra,
                        icon: const Icon(Icons.handyman),
                        label: const Text("Mano Obra"),
                      ),

                      ElevatedButton.icon(
                        onPressed: agregarGasto,
                        icon: const Icon(Icons.money),
                        label: const Text("Gasto"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (materiales.isNotEmpty)
                    const Text(
                      "Materiales agregados",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  ...materiales.asMap().entries.map((entry) {
                    int i = entry.key;
                    var m = entry.value;

                    return Card(
                      child: ListTile(
                        title: Text("${m["nombre"]} x${m["cantidad"]}"),
                        subtitle: Text(
                          "Precio: \$${toDouble(m["precio"]).toStringAsFixed(2)}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "\$${toDouble(m["subtotal"]).toStringAsFixed(2)}",
                            ),

                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => editarCantidadMaterial(i),
                            ),

                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => confirmarEliminarItem(
                                materiales,
                                i,
                                m["nombre"],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  if (manoObra.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        "Mano de obra agregada",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  ...manoObra.asMap().entries.map((entry) {
                    int i = entry.key;
                    var m = entry.value;

                    return Card(
                      child: ListTile(
                        title: Text(m["descripcion"]),
                        subtitle: Text("Cantidad: ${m["cantidad"] ?? 1}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "\$${toDouble(m["subtotal"]).toStringAsFixed(2)}",
                            ),

                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => confirmarEliminarItem(
                                manoObra,
                                i,
                                m["descripcion"],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  if (gastos.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        "Gastos agregados",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  ...gastos.asMap().entries.map((entry) {
                    int i = entry.key;
                    var g = entry.value;

                    return Card(
                      child: ListTile(
                        title: Text(g["descripcion"]),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "\$${toDouble(g["monto"]).toStringAsFixed(2)}",
                            ),

                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => confirmarEliminarItem(
                                gastos,
                                i,
                                g["descripcion"],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const Divider(),

                  Text(
                    "TOTAL: \$${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}