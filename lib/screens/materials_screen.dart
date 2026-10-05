import 'package:flutter/material.dart';
import 'package:sistema_presupuestos/database/db_helper.dart';
import 'package:sistema_presupuestos/services/api_service.dart';
import 'package:sqflite/sqflite.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  List<Map<String, dynamic>> materiales = [];
  List<Map<String, dynamic>> filtrados = [];

  final searchController = TextEditingController();

  bool loading = false;
  String filtroActual = "todos";

  @override
  void initState() {
    super.initState();
    cargarMateriales();
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

  String origenTexto(dynamic origen) {
    final value = origen?.toString().toLowerCase() ?? "local";

    if (value == "api") return "API";
    if (value == "local") return "Local";

    return value;
  }

  Color origenColor(dynamic origen) {
    final value = origen?.toString().toLowerCase() ?? "local";

    if (value == "api") return Colors.blue;
    if (value == "local") return Colors.green;

    return Colors.purple;
  }

  bool estaPendienteSync(Map<String, dynamic> material) {
    return material["sync"] == 0 || material["sync"] == false;
  }

  // =========================
  // CARGAR MATERIALES
  // =========================
  Future<void> cargarMateriales() async {
    final db = await DBHelper.instance.database;

    final result = await db.query(
      'materiales',
      where: 'deleted = 0',
      orderBy: 'nombre ASC',
    );

    setState(() {
      materiales = List<Map<String, dynamic>>.from(result);
    });

    aplicarFiltros();
  }

  // =========================
  // APLICAR FILTROS
  // =========================
  void aplicarFiltros() {
    final query = searchController.text.trim().toLowerCase();

    List<Map<String, dynamic>> data = materiales.where((m) {
      final nombre = m["nombre"].toString().toLowerCase();
      final origen = (m["origen"] ?? "local").toString().toLowerCase();
      final pendiente = estaPendienteSync(m);

      final coincideBusqueda = nombre.contains(query);

      bool coincideFiltro = true;

      if (filtroActual == "local") {
        coincideFiltro = origen == "local";
      } else if (filtroActual == "api") {
        coincideFiltro = origen == "api";
      } else if (filtroActual == "pendientes") {
        coincideFiltro = pendiente;
      }

      return coincideBusqueda && coincideFiltro;
    }).toList();

    setState(() {
      filtrados = data;
    });
  }

  // =========================
  // CAMBIAR FILTRO
  // =========================
  void cambiarFiltro(String filtro) {
    setState(() {
      filtroActual = filtro;
    });

    aplicarFiltros();
  }

  // =========================
  // AGREGAR MATERIAL
  // =========================
  Future<void> mostrarDialogoAgregar() async {
    final nombreController = TextEditingController();
    final precioController = TextEditingController();
    final unidadController = TextEditingController(text: "pieza");

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Agregar material"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "Nombre",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: precioController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Precio",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: unidadController,
                decoration: const InputDecoration(
                  labelText: "Unidad",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.straighten),
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
              final nombre = nombreController.text.trim();
              final precio = double.tryParse(precioController.text.trim()) ?? 0;
              final unidad = unidadController.text.trim().isEmpty
                  ? "pieza"
                  : unidadController.text.trim();

              if (nombre.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("El nombre es obligatorio")),
                );
                return;
              }

              if (precio <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ingresa un precio válido")),
                );
                return;
              }

              final db = await DBHelper.instance.database;

              await db.insert('materiales', {
                "nombre": nombre,
                "precio": precio,
                "unidad": unidad,
                "origen": "local",
                "sync": 0,
                "updated_at": now(),
                "deleted": 0,
              });

              if (!mounted) return;

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Material agregado")),
              );

              await cargarMateriales();
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // EDITAR MATERIAL
  // =========================
  Future<void> mostrarDialogoEditar(Map<String, dynamic> material) async {
    final nombreController = TextEditingController(text: material["nombre"]);
    final precioController = TextEditingController(
      text: toDouble(material["precio"]).toStringAsFixed(2),
    );
    final unidadController = TextEditingController(
      text: material["unidad"]?.toString() ?? "pieza",
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Editar material"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "Nombre",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: precioController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Precio",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: unidadController,
                decoration: const InputDecoration(
                  labelText: "Unidad",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.straighten),
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
              final nombre = nombreController.text.trim();
              final precio = double.tryParse(precioController.text.trim()) ?? 0;
              final unidad = unidadController.text.trim().isEmpty
                  ? "pieza"
                  : unidadController.text.trim();

              if (nombre.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("El nombre es obligatorio")),
                );
                return;
              }

              if (precio <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ingresa un precio válido")),
                );
                return;
              }

              final db = await DBHelper.instance.database;

              await db.update(
                'materiales',
                {
                  "nombre": nombre,
                  "precio": precio,
                  "unidad": unidad,
                  "sync": 0,
                  "updated_at": now(),
                },
                where: 'id = ?',
                whereArgs: [material["id"]],
              );

              if (!mounted) return;

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Material actualizado")),
              );

              await cargarMateriales();
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // CONFIRMAR ELIMINAR
  // =========================
  Future<void> confirmarEliminar(Map<String, dynamic> material) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Eliminar material"),
        content: Text(
          "¿Seguro que deseas eliminar \"${material["nombre"]}\"?\n\n"
          "El material se marcará como eliminado para sincronizar el cambio.",
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
      await eliminarMaterial(material["id"]);
    }
  }

  // =========================
  // ELIMINAR MATERIAL
  // =========================
  Future<void> eliminarMaterial(int id) async {
    final db = await DBHelper.instance.database;

    await db.update(
      'materiales',
      {
        "deleted": 1,
        "sync": 0,
        "updated_at": now(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Material eliminado")),
    );

    await cargarMateriales();
  }

  // =========================
  // CARGAR DESDE API
  // =========================
  Future<void> cargarDesdeAPI() async {
    setState(() => loading = true);

    try {
      final data = await ApiService.getMateriales();
      final db = await DBHelper.instance.database;

      int insertados = 0;
      int actualizados = 0;

      for (var m in data) {
        final nombre = m["nombre"]?.toString().trim() ?? "";

        if (nombre.isEmpty) continue;

        final existentes = await db.query(
          'materiales',
          where: 'LOWER(nombre) = LOWER(?) AND deleted = 0',
          whereArgs: [nombre],
          limit: 1,
        );

        if (existentes.isNotEmpty) {
          await db.update(
            'materiales',
            {
              "precio": toDouble(m["precio"]),
              "unidad": m["unidad"] ?? "pieza",
              "origen": "api",
              "sync": 1,
              "updated_at": now(),
              "deleted": 0,
            },
            where: 'id = ?',
            whereArgs: [existentes.first["id"]],
          );

          actualizados++;
        } else {
          await db.insert(
            'materiales',
            {
              "nombre": nombre,
              "precio": toDouble(m["precio"]),
              "unidad": m["unidad"] ?? "pieza",
              "origen": "api",
              "sync": 1,
              "updated_at": now(),
              "deleted": 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          insertados++;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Carga completa: $insertados nuevos, $actualizados actualizados",
          ),
        ),
      );

      await cargarMateriales();
    } catch (e) {
      print("Error cargando materiales desde API: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error cargando materiales desde API")),
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  // =========================
  // VER PRECIOS ONLINE
  // =========================
  Future<void> verPrecios(Map<String, dynamic> material) async {
    setState(() => loading = true);

    try {
      final data = await ApiService.obtenerPrecios(material["nombre"]);

      final List precios = data["precios"] ?? [];
      final comparacion = data["comparacion"];

      if (precios.isNotEmpty) {
        await DBHelper.instance.guardarHistorial(precios, material["nombre"]);
      }

      if (!mounted) return;

      setState(() => loading = false);

      mostrarDialogoPrecios(
        material: material,
        precios: precios,
        comparacion: comparacion,
      );
    } catch (e) {
      print("Error obteniendo precios: $e");

      if (mounted) {
        setState(() => loading = false);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error obteniendo precios")),
      );
    }
  }

  // =========================
  // DIALOGO PRECIOS
  // =========================
  void mostrarDialogoPrecios({
    required Map<String, dynamic> material,
    required List precios,
    required dynamic comparacion,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Precios de ${material["nombre"]}"),
        content: SizedBox(
          width: double.maxFinite,
          child: precios.isEmpty
              ? const Text("No se encontraron precios online.")
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (comparacion != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Más barato: ${money(comparacion["mas_barato"]?["precio"])}",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Más caro: ${money(comparacion["mas_caro"]?["precio"])}",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Promedio: ${money(comparacion["promedio"])}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],

                      ...precios.map((p) {
                        final precio = toDouble(p["precio"]);

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.store),
                            title: Text(p["nombre"] ?? "Producto"),
                            subtitle: Text(p["tienda"] ?? "Tienda"),
                            trailing: Text(
                              money(precio),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              mostrarOpcionesPrecio(material, p);
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  // =========================
  // OPCIONES PRECIO ONLINE
  // =========================
  void mostrarOpcionesPrecio(
    Map<String, dynamic> material,
    Map<String, dynamic> precioOnline,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final precio = toDouble(precioOnline["precio"]);
        final nombre = precioOnline["nombre"] ?? material["nombre"];
        final tienda = precioOnline["tienda"] ?? "api";

        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.price_check, color: Colors.green),
                title: const Text("Actualizar precio de este material"),
                subtitle: Text("Nuevo precio: ${money(precio)}"),
                onTap: () async {
                  Navigator.pop(context);
                  Navigator.pop(context);

                  await actualizarPrecioMaterial(material["id"], precio);

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Precio actualizado")),
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.add_shopping_cart, color: Colors.blue),
                title: const Text("Guardar como nuevo material"),
                subtitle: Text(nombre),
                onTap: () async {
                  Navigator.pop(context);
                  Navigator.pop(context);

                  await guardarPrecioComoMaterial(
                    nombre: nombre,
                    precio: precio,
                    tienda: tienda,
                  );

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Material guardado")),
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.close),
                title: const Text("Cancelar"),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================
  // ACTUALIZAR PRECIO DESDE ONLINE
  // =========================
  Future<void> actualizarPrecioMaterial(int id, double precio) async {
    final db = await DBHelper.instance.database;

    await db.update(
      'materiales',
      {
        "precio": precio,
        "sync": 0,
        "updated_at": now(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await cargarMateriales();
  }

  // =========================
  // GUARDAR PRECIO ONLINE COMO MATERIAL
  // =========================
  Future<void> guardarPrecioComoMaterial({
    required String nombre,
    required double precio,
    required String tienda,
  }) async {
    final db = await DBHelper.instance.database;

    await db.insert('materiales', {
      "nombre": nombre,
      "precio": precio,
      "unidad": "pieza",
      "origen": tienda,
      "sync": 0,
      "updated_at": now(),
      "deleted": 0,
    });

    await cargarMateriales();
  }

  // =========================
  // CARD MATERIAL
  // =========================
  Widget materialCard(Map<String, dynamic> m) {
    final pendiente = estaPendienteSync(m);
    final origen = m["origen"] ?? "local";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

        leading: CircleAvatar(
          backgroundColor: origenColor(origen).withOpacity(0.15),
          child: Icon(
            Icons.inventory_2,
            color: origenColor(origen),
          ),
        ),

        title: Text(
          m["nombre"] ?? "Material",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            Text(
              "Precio: ${money(m["precio"])} · Unidad: ${m["unidad"] ?? "pieza"}",
            ),

            const SizedBox(height: 6),

            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(origenTexto(origen)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: origenColor(origen).withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: origenColor(origen),
                    fontSize: 12,
                  ),
                ),

                Chip(
                  label: Text(pendiente ? "Pendiente sync" : "Sincronizado"),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: pendiente
                      ? Colors.orange.withOpacity(0.12)
                      : Colors.green.withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: pendiente ? Colors.orange : Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),

        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == "editar") {
              mostrarDialogoEditar(m);
            } else if (value == "precios") {
              verPrecios(m);
            } else if (value == "eliminar") {
              confirmarEliminar(m);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: "editar",
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text("Editar"),
                ],
              ),
            ),
            const PopupMenuItem(
              value: "precios",
              child: Row(
                children: [
                  Icon(Icons.compare_arrows, color: Colors.green),
                  SizedBox(width: 8),
                  Text("Comparar precios"),
                ],
              ),
            ),
            const PopupMenuItem(
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

        onTap: () => mostrarDialogoEditar(m),
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
          filtroChip("local", "Locales", Icons.phone_android),
          filtroChip("api", "API", Icons.cloud),
          filtroChip("pendientes", "Pendientes", Icons.sync_problem),
        ],
      ),
    );
  }

  Widget filtroChip(String value, String label, IconData icon) {
    final selected = filtroActual == value;

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
  // EMPTY STATE
  // =========================
  Widget estadoVacio() {
    final hayBusqueda = searchController.text.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hayBusqueda ? Icons.search_off : Icons.inventory_2_outlined,
              size: 70,
              color: Colors.grey,
            ),

            const SizedBox(height: 12),

            Text(
              hayBusqueda
                  ? "No se encontraron materiales"
                  : "No hay materiales registrados",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              hayBusqueda
                  ? "Intenta con otro nombre o cambia el filtro."
                  : "Agrega materiales manualmente o descarga materiales desde la API.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 16),

            if (!hayBusqueda)
              ElevatedButton.icon(
                onPressed: mostrarDialogoAgregar,
                icon: const Icon(Icons.add),
                label: const Text("Agregar material"),
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
    final total = materiales.length;
    final pendientes = materiales.where(estaPendienteSync).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Materiales"),
        actions: [
          IconButton(
            tooltip: "Descargar desde API",
            icon: const Icon(Icons.cloud_download),
            onPressed: loading ? null : cargarDesdeAPI,
          ),
          IconButton(
            tooltip: "Actualizar",
            icon: const Icon(Icons.refresh),
            onPressed: loading ? null : cargarMateriales,
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: mostrarDialogoAgregar,
        icon: const Icon(Icons.add),
        label: const Text("Agregar"),
      ),

      body: Column(
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
            child: Row(
              children: [
                const Icon(Icons.inventory, color: Colors.blue),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    "$total materiales registrados",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                if (pendientes > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$pendientes pendientes",
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // BUSCADOR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Buscar material",
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

          if (loading)
            const LinearProgressIndicator(),

          Expanded(
            child: filtrados.isEmpty
                ? estadoVacio()
                : RefreshIndicator(
                    onRefresh: cargarMateriales,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) {
                        return materialCard(filtrados[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}