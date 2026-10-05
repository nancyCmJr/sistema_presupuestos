import 'package:flutter/material.dart';
import 'package:sistema_presupuestos/database/db_helper.dart';
import 'package:sistema_presupuestos/services/api_service.dart';
import 'package:sistema_presupuestos/services/pdf_service.dart';

class BudgetDetailScreen extends StatefulWidget {
  const BudgetDetailScreen({super.key});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  Map<String, dynamic>? presupuesto;
  Map<String, dynamic>? cliente;

  List<Map<String, dynamic>> materiales = [];
  List<Map<String, dynamic>> manoObra = [];
  List<Map<String, dynamic>> gastos = [];

  bool editando = false;
  bool cargando = true;
  bool _cargado = false;

  final descripcionController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_cargado) {
      _cargado = true;
      final id = ModalRoute.of(context)!.settings.arguments as int;
      cargar(id);
    }
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

  int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String now() {
    return DateTime.now().toIso8601String();
  }

  // =========================
  // CARGAR DATOS
  // =========================
  Future<void> cargar(int id) async {
    final db = await DBHelper.instance.database;

    final pres = await db.query(
      'presupuestos',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (pres.isEmpty) {
      setState(() {
        cargando = false;
      });
      return;
    }

    final mats = await db.rawQuery('''
      SELECT 
        dm.*,
        m.nombre,
        m.precio
      FROM detalle_materiales dm
      LEFT JOIN materiales m ON m.id = dm.material_id
      WHERE dm.presupuesto_id = ?
    ''', [id]);

    final mo = await db.rawQuery('''
      SELECT 
        dmo.*,
        mo.descripcion,
        mo.precio
      FROM detalle_mano_obra dmo
      LEFT JOIN mano_obra mo ON mo.id = dmo.mano_obra_id
      WHERE dmo.presupuesto_id = ?
    ''', [id]);

    final gas = await db.query(
      'gastos',
      where: 'presupuesto_id = ?',
      whereArgs: [id],
    );

    final cli = await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [pres.first["cliente_id"]],
    );

    setState(() {
      presupuesto = Map<String, dynamic>.from(pres.first);

      materiales = mats.map((m) {
        final map = Map<String, dynamic>.from(m);
        final cantidad = toDouble(map["cantidad"]);
        final subtotal = toDouble(map["subtotal"]);

        map["nombre"] = map["nombre"] ?? "Material";
        map["precio"] = toDouble(map["precio"]) > 0
            ? toDouble(map["precio"])
            : cantidad > 0
                ? subtotal / cantidad
                : subtotal;

        map["cantidad"] = cantidad;
        map["subtotal"] = subtotal;

        return map;
      }).toList();

      manoObra = mo.map((m) {
        final map = Map<String, dynamic>.from(m);
        final cantidad = toDouble(map["cantidad"]);
        final subtotal = toDouble(map["subtotal"]);

        map["descripcion"] = map["descripcion"] ?? "Mano de obra";
        map["precio"] = toDouble(map["precio"]) > 0
            ? toDouble(map["precio"])
            : cantidad > 0
                ? subtotal / cantidad
                : subtotal;

        map["cantidad"] = cantidad;
        map["subtotal"] = subtotal;

        return map;
      }).toList();

      gastos = gas.map((g) {
        final map = Map<String, dynamic>.from(g);

        map["descripcion"] = map["descripcion"] ?? "Gasto";
        map["monto"] = toDouble(map["monto"]);

        return map;
      }).toList();

      cliente = cli.isNotEmpty ? Map<String, dynamic>.from(cli.first) : {};

      descripcionController.text = presupuesto!["descripcion"] ?? "";

      cargando = false;
    });

    recalcularTotal();
  }

  // =========================
  // RECALCULAR TOTAL
  // =========================
  void recalcularTotal() {
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

    setState(() {
      presupuesto!["total"] = t;
    });
  }

  // =========================
  // CONFIRMAR ELIMINACIÓN
  // =========================
  Future<void> confirmarEliminarItem({
    required String nombre,
    required VoidCallback onConfirm,
  }) async {
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
      onConfirm();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Elemento eliminado")),
      );
    }
  }

  // =========================
  // GUARDAR CAMBIOS
  // =========================
  Future<void> guardarCambios() async {
    final db = await DBHelper.instance.database;
    final id = presupuesto!["id"];

    recalcularTotal();

    await db.update(
      'presupuestos',
      {
        "descripcion": descripcionController.text.trim(),
        "total": toDouble(presupuesto!["total"]),
        "sync": 0,
        "updated_at": now(),
        "deleted": 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await db.delete(
      'detalle_materiales',
      where: 'presupuesto_id = ?',
      whereArgs: [id],
    );

    await db.delete(
      'detalle_mano_obra',
      where: 'presupuesto_id = ?',
      whereArgs: [id],
    );

    await db.delete(
      'gastos',
      where: 'presupuesto_id = ?',
      whereArgs: [id],
    );

    for (var m in materiales) {
      await db.insert('detalle_materiales', {
        "presupuesto_id": id,
        "material_id": m["material_id"],
        "cantidad": toDouble(m["cantidad"]),
        "subtotal": toDouble(m["subtotal"]),
      });
    }

    for (var m in manoObra) {
      await db.insert('detalle_mano_obra', {
        "presupuesto_id": id,
        "mano_obra_id": m["mano_obra_id"],
        "cantidad": toDouble(m["cantidad"]),
        "subtotal": toDouble(m["subtotal"]),
      });
    }

    for (var g in gastos) {
      await db.insert('gastos', {
        "presupuesto_id": id,
        "descripcion": g["descripcion"],
        "monto": toDouble(g["monto"]),
      });
    }

    setState(() {
      editando = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Presupuesto actualizado")),
    );

    await cargar(id);
  }

  // =========================
  // CAMBIAR CANTIDAD MATERIAL
  // =========================
  void cambiarCantidadMaterial(Map<String, dynamic> m, String val) {
    final nuevaCantidad = double.tryParse(val) ?? 1;
    final cantidadFinal = nuevaCantidad <= 0 ? 1 : nuevaCantidad;
    final precio = toDouble(m["precio"]);

    setState(() {
      m["cantidad"] = cantidadFinal;
      m["subtotal"] = cantidadFinal * precio;
    });

    recalcularTotal();
  }

  // =========================
  // CAMBIAR CANTIDAD MANO DE OBRA
  // =========================
  void cambiarCantidadManoObra(Map<String, dynamic> m, String val) {
    final nuevaCantidad = double.tryParse(val) ?? 1;
    final cantidadFinal = nuevaCantidad <= 0 ? 1 : nuevaCantidad;
    final precio = toDouble(m["precio"]);

    setState(() {
      m["cantidad"] = cantidadFinal;
      m["subtotal"] = cantidadFinal * precio;
    });

    recalcularTotal();
  }

  // =========================
  // AGREGAR MATERIAL
  // =========================
  Future<void> agregarMaterial() async {
    final controller = TextEditingController();

    List<Map<String, dynamic>> resultadosLocales = [];
    List<Map<String, dynamic>> resultadosOnline = [];

    bool loadingOnline = false;

    await showDialog(
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
                const SnackBar(content: Text("Escribe el nombre del material")),
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
              print("Error buscando material online: $e");

              setStateDialog(() {
                resultadosOnline = [];
              });
            }

            setStateDialog(() {
              loadingOnline = false;
            });
          }

          void agregarLocal(Map<String, dynamic> item) {
            final precio = toDouble(item["precio"]);

            setState(() {
              materiales.add({
                "nombre": item["nombre"],
                "material_id": item["id"],
                "cantidad": 1.0,
                "precio": precio,
                "subtotal": precio,
              });
            });

            recalcularTotal();
            Navigator.pop(context);
          }

          Future<void> agregarOnline(Map<String, dynamic> item) async {
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
                "material_id": nuevoMaterialId,
                "cantidad": 1.0,
                "precio": precio,
                "subtotal": precio,
              });
            });

            recalcularTotal();
            Navigator.pop(context);
          }

          return AlertDialog(
            title: const Text("Agregar material"),
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
                    icon: const Icon(Icons.wifi_find_outlined),
                    label: const Text("Buscar precio online"),
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
                            padding: EdgeInsets.all(8),
                            child: Text("No hay materiales locales encontrados"),
                          ),

                        ...resultadosLocales.map((item) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.inventory),
                              title: Text(item["nombre"]),
                              subtitle: Text(item["origen"] ?? "local"),
                              trailing: Text(
                                "\$${toDouble(item["precio"]).toStringAsFixed(2)}",
                              ),
                              onTap: () => agregarLocal(item),
                            ),
                          );
                        }),

                        const Divider(),

                        const Text(
                          "Resultados online",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        if (loadingOnline)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          ),

                        if (!loadingOnline && resultadosOnline.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text("Sin resultados online"),
                          ),

                        ...resultadosOnline.map((item) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.public),
                              title: Text(item["nombre"] ?? ""),
                              subtitle: Text(item["tienda"] ?? "internet"),
                              trailing: Text(
                                "\$${toDouble(item["precio"]).toStringAsFixed(2)}",
                              ),
                              onTap: () => agregarOnline(item),
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
  // AGREGAR MANO DE OBRA
  // =========================
  Future<void> agregarManoObra() async {
    final db = await DBHelper.instance.database;

    List<Map<String, dynamic>> catalogo = List<Map<String, dynamic>>.from(
      await db.query('mano_obra', orderBy: 'descripcion ASC'),
    );

    final descripcionController = TextEditingController();
    final precioController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> recargar() async {
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
                "mano_obra_id": item["id"],
                "cantidad": 1.0,
                "precio": precio,
                "subtotal": precio,
              });
            });

            recalcularTotal();
            Navigator.pop(context);
          }

          Future<void> crearYAgregar() async {
            final descripcion = descripcionController.text.trim();
            final precio = double.tryParse(precioController.text.trim()) ?? 0;

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

            await recargar();

            setState(() {
              manoObra.add({
                "descripcion": descripcion,
                "mano_obra_id": nuevoId,
                "cantidad": 1.0,
                "precio": precio,
                "subtotal": precio,
              });
            });

            recalcularTotal();
            Navigator.pop(context);
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
                    "Crear nueva",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: "Descripción",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: precioController,
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
                      onPressed: crearYAgregar,
                      icon: const Icon(Icons.add),
                      label: const Text("Crear y agregar"),
                    ),
                  ),

                  const Divider(),

                  const Text(
                    "Seleccionar del catálogo",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
  // AGREGAR GASTO
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

    final descripcionController = TextEditingController();
    final montoController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> recargar() async {
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

            recalcularTotal();
            Navigator.pop(context);
          }

          Future<void> crearYAgregar() async {
            final descripcion = descripcionController.text.trim();
            final monto = double.tryParse(montoController.text.trim()) ?? 0;

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

            await recargar();

            setState(() {
              gastos.add({
                "descripcion": descripcion,
                "monto": monto,
              });
            });

            recalcularTotal();
            Navigator.pop(context);
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
                    "Crear nuevo",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: descripcionController,
                    decoration: const InputDecoration(
                      labelText: "Descripción",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: montoController,
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
                      onPressed: crearYAgregar,
                      icon: const Icon(Icons.add),
                      label: const Text("Crear y agregar"),
                    ),
                  ),

                  const Divider(),

                  const Text(
                    "Seleccionar del catálogo",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: catalogo.isEmpty
                        ? const Center(child: Text("No hay gastos registrados"))
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
  // SECCIÓN
  // =========================
  Widget seccion(
    String titulo,
    List<Map<String, dynamic>> items,
    Widget Function(Map<String, dynamic>) builder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text("Sin elementos"),
          ),
        ...items.map(builder),
        const SizedBox(height: 10),
      ],
    );
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    if (cargando || presupuesto == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle Presupuesto"),
        actions: [
          IconButton(
            icon: Icon(editando ? Icons.save : Icons.edit),
            onPressed: () async {
              if (editando) {
                await guardarCambios();
              } else {
                setState(() {
                  editando = true;
                });
              }
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CLIENTE
              const Text(
                "Cliente",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              Text(cliente?["nombre"] ?? ""),
              Text(cliente?["telefono"] ?? ""),
              Text(cliente?["direccion"] ?? ""),

              const SizedBox(height: 20),

              // DESCRIPCIÓN
              TextField(
                controller: descripcionController,
                enabled: editando,
                decoration: const InputDecoration(
                  labelText: "Descripción",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              // MATERIALES
              seccion("Materiales", materiales, (m) {
                return Card(
                  child: ListTile(
                    title: Text(m["nombre"] ?? "Material"),

                    subtitle: editando
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Precio unitario: \$${toDouble(m["precio"]).toStringAsFixed(2)}",
                              ),
                              TextFormField(
                                initialValue: toDouble(
                                  m["cantidad"],
                                ).toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Cantidad",
                                ),
                                onChanged: (val) {
                                  cambiarCantidadMaterial(m, val);
                                },
                              ),
                            ],
                          )
                        : Text(
                            "Cantidad: ${toDouble(m["cantidad"])} | Precio: \$${toDouble(m["precio"]).toStringAsFixed(2)}",
                          ),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "\$${toDouble(m["subtotal"]).toStringAsFixed(2)}",
                        ),

                        if (editando)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              confirmarEliminarItem(
                                nombre: m["nombre"] ?? "Material",
                                onConfirm: () {
                                  setState(() {
                                    materiales.remove(m);
                                  });
                                  recalcularTotal();
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              }),

              if (editando)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: agregarMaterial,
                    icon: const Icon(Icons.add),
                    label: const Text("Agregar material"),
                  ),
                ),

              const SizedBox(height: 20),

              // MANO DE OBRA
              seccion("Mano de obra", manoObra, (m) {
                return Card(
                  child: ListTile(
                    title: Text(m["descripcion"] ?? "Mano de obra"),

                    subtitle: editando
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Precio unitario: \$${toDouble(m["precio"]).toStringAsFixed(2)}",
                              ),
                              TextFormField(
                                initialValue: toDouble(
                                  m["cantidad"],
                                ).toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Cantidad",
                                ),
                                onChanged: (val) {
                                  cambiarCantidadManoObra(m, val);
                                },
                              ),
                            ],
                          )
                        : Text(
                            "Cantidad: ${toDouble(m["cantidad"])} | Precio: \$${toDouble(m["precio"]).toStringAsFixed(2)}",
                          ),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "\$${toDouble(m["subtotal"]).toStringAsFixed(2)}",
                        ),

                        if (editando)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              confirmarEliminarItem(
                                nombre: m["descripcion"] ?? "Mano de obra",
                                onConfirm: () {
                                  setState(() {
                                    manoObra.remove(m);
                                  });
                                  recalcularTotal();
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              }),

              if (editando)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: agregarManoObra,
                    icon: const Icon(Icons.add),
                    label: const Text("Agregar mano de obra"),
                  ),
                ),

              const SizedBox(height: 20),

              // GASTOS
              seccion("Gastos", gastos, (g) {
                return Card(
                  child: ListTile(
                    title: editando
                        ? TextFormField(
                            initialValue: g["descripcion"] ?? "",
                            decoration: const InputDecoration(
                              labelText: "Descripción",
                            ),
                            onChanged: (val) {
                              setState(() {
                                g["descripcion"] = val;
                              });
                            },
                          )
                        : Text(g["descripcion"] ?? "Gasto"),

                    subtitle: editando
                        ? TextFormField(
                            initialValue: toDouble(g["monto"]).toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Monto",
                            ),
                            onChanged: (val) {
                              setState(() {
                                g["monto"] = double.tryParse(val) ?? 0;
                              });
                              recalcularTotal();
                            },
                          )
                        : Text(
                            "Monto: \$${toDouble(g["monto"]).toStringAsFixed(2)}",
                          ),

                    trailing: editando
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              confirmarEliminarItem(
                                nombre: g["descripcion"] ?? "Gasto",
                                onConfirm: () {
                                  setState(() {
                                    gastos.remove(g);
                                  });
                                  recalcularTotal();
                                },
                              );
                            },
                          )
                        : null,
                  ),
                );
              }),

              if (editando)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: agregarGasto,
                    icon: const Icon(Icons.add),
                    label: const Text("Agregar gasto"),
                  ),
                ),

              const Divider(),

              Text(
                "TOTAL: \$${toDouble(presupuesto!["total"]).toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 20),

              if (!editando)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        if (presupuesto == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("No hay presupuesto cargado")),
                          );
                        return;
                        }
                            
                        final file = await PdfService.generarPDF(
                          presupuesto: presupuesto!,
                          cliente: cliente ?? {},
                          materiales: materiales,
                          manoObra: manoObra,
                          gastos: gastos,
                        );
                              
                        await PdfService.imprimir(file);
                        } catch (e) {
                          print("ERROR GENERANDO PDF: $e");
                          
                          if (!mounted) return;
                                
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error generando PDF: $e")),
                          );
                        }
                      },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("Generar PDF"),
                  ),
                ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}