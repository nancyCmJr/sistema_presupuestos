import 'package:flutter/material.dart';
import 'package:sistema_presupuestos/database/db_helper.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Map<String, dynamic>> clientes = [];
  List<Map<String, dynamic>> filtrados = [];

  final searchController = TextEditingController();

  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarClientes();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =========================
  // HELPERS
  // =========================
  String now() {
    return DateTime.now().toIso8601String();
  }

  bool pendienteSync(Map<String, dynamic> cliente) {
    return cliente["sync"] == 0 || cliente["sync"] == false;
  }

  // =========================
  // CARGAR CLIENTES
  // =========================
  Future<void> cargarClientes() async {
    final db = await DBHelper.instance.database;

    final data = await db.query(
      'clientes',
      where: 'deleted = 0',
      orderBy: 'nombre ASC',
    );

    setState(() {
      clientes = List<Map<String, dynamic>>.from(data);
      cargando = false;
    });

    aplicarFiltro();
  }

  // =========================
  // BUSCAR
  // =========================
  void aplicarFiltro() {
    final query = searchController.text.trim().toLowerCase();

    final data = clientes.where((c) {
      final nombre = c["nombre"]?.toString().toLowerCase() ?? "";
      final telefono = c["telefono"]?.toString().toLowerCase() ?? "";
      final direccion = c["direccion"]?.toString().toLowerCase() ?? "";
      final email = c["email"]?.toString().toLowerCase() ?? "";

      return nombre.contains(query) ||
          telefono.contains(query) ||
          direccion.contains(query) ||
          email.contains(query);
    }).toList();

    setState(() {
      filtrados = data;
    });
  }

  // =========================
  // FORMULARIO AGREGAR / EDITAR
  // =========================
  Future<void> mostrarFormulario({Map<String, dynamic>? cliente}) async {
    final editando = cliente != null;

    final nombreController = TextEditingController(
      text: editando ? cliente["nombre"] ?? "" : "",
    );

    final telefonoController = TextEditingController(
      text: editando ? cliente["telefono"] ?? "" : "",
    );

    final direccionController = TextEditingController(
      text: editando ? cliente["direccion"] ?? "" : "",
    );

    final emailController = TextEditingController(
      text: editando ? cliente["email"] ?? "" : "",
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(editando ? "Editar cliente" : "Agregar cliente"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "Nombre",
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
                controller: direccionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: "Dirección",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
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
              final telefono = telefonoController.text.trim();
              final direccion = direccionController.text.trim();
              final email = emailController.text.trim();

              if (nombre.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("El nombre es obligatorio"),
                  ),
                );
                return;
              }

              if (email.isNotEmpty && !email.contains("@")) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Ingresa un email válido"),
                  ),
                );
                return;
              }

              final db = await DBHelper.instance.database;

              if (editando) {
                await db.update(
                  'clientes',
                  {
                    "nombre": nombre,
                    "telefono": telefono,
                    "direccion": direccion,
                    "email": email,
                    "sync": 0,
                    "updated_at": now(),
                    "deleted": 0,
                  },
                  where: 'id = ?',
                  whereArgs: [cliente["id"]],
                );
              } else {
                await db.insert('clientes', {
                  "nombre": nombre,
                  "telefono": telefono,
                  "direccion": direccion,
                  "email": email,
                  "sync": 0,
                  "updated_at": now(),
                  "deleted": 0,
                });
              }

              if (!mounted) return;

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    editando
                        ? "Cliente actualizado correctamente"
                        : "Cliente agregado correctamente",
                  ),
                ),
              );

              await cargarClientes();
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // CONFIRMAR ELIMINAR
  // =========================
  Future<void> confirmarEliminar(Map<String, dynamic> cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Eliminar cliente"),
        content: Text(
          "¿Seguro que deseas eliminar a \"${cliente["nombre"]}\"?\n\n"
          "El cliente se marcará como eliminado para sincronizar el cambio.",
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
      await eliminar(cliente["id"]);
    }
  }

  // =========================
  // ELIMINAR CLIENTE SOFT DELETE
  // =========================
  Future<void> eliminar(int id) async {
    final db = await DBHelper.instance.database;

    await db.update(
      'clientes',
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
      const SnackBar(content: Text("Cliente eliminado")),
    );

    await cargarClientes();
  }

  // =========================
  // CARD CLIENTE
  // =========================
  Widget clienteCard(Map<String, dynamic> cliente) {
    final syncPendiente = pendienteSync(cliente);

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
          backgroundColor: Colors.purple.withOpacity(0.15),
          child: const Icon(
            Icons.person,
            color: Colors.purple,
          ),
        ),

        title: Text(
          cliente["nombre"] ?? "Cliente",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            if ((cliente["telefono"] ?? "").toString().isNotEmpty)
              Text("Tel: ${cliente["telefono"]}"),

            if ((cliente["direccion"] ?? "").toString().isNotEmpty)
              Text("Dir: ${cliente["direccion"]}"),

            if ((cliente["email"] ?? "").toString().isNotEmpty)
              Text("Email: ${cliente["email"]}"),

            const SizedBox(height: 6),

            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                syncPendiente ? "Pendiente sync" : "Sincronizado",
                style: TextStyle(
                  color: syncPendiente ? Colors.orange : Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: syncPendiente
                  ? Colors.orange.withOpacity(0.12)
                  : Colors.green.withOpacity(0.12),
            ),
          ],
        ),

        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == "editar") {
              mostrarFormulario(cliente: cliente);
            } else if (value == "eliminar") {
              confirmarEliminar(cliente);
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

        onTap: () => mostrarFormulario(cliente: cliente),
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
              buscando ? Icons.search_off : Icons.people_outline,
              size: 70,
              color: Colors.grey,
            ),

            const SizedBox(height: 12),

            Text(
              buscando
                  ? "No se encontraron clientes"
                  : "No hay clientes registrados",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              buscando
                  ? "Intenta buscar por nombre, teléfono, dirección o email."
                  : "Agrega clientes para poder crear presupuestos.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 16),

            if (!buscando)
              ElevatedButton.icon(
                onPressed: () => mostrarFormulario(),
                icon: const Icon(Icons.add),
                label: const Text("Agregar cliente"),
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
    final pendientes = clientes.where(pendienteSync).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Clientes"),
        actions: [
          IconButton(
            tooltip: "Actualizar",
            icon: const Icon(Icons.refresh),
            onPressed: cargarClientes,
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
                    color: Colors.purple.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people, color: Colors.purple),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          "${clientes.length} clientes registrados",
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

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Buscar cliente",
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
                          onRefresh: cargarClientes,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: filtrados.length,
                            itemBuilder: (context, index) {
                              return clienteCard(filtrados[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}