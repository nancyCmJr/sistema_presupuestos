import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sistema_presupuestos/database/db_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool cargando = true;

  Map<String, dynamic> kpis = {};
  List<Map<String, dynamic>> ingresosPorDia = [];
  List<Map<String, dynamic>> distribucionCostos = [];
  List<Map<String, dynamic>> estados = [];
  List<Map<String, dynamic>> ultimosPresupuestos = [];

  @override
  void initState() {
    super.initState();
    cargarReportes();
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

  String money(dynamic value) {
    return "\$${toDouble(value).toStringAsFixed(2)}";
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
  // CARGAR REPORTES
  // =========================
  Future<void> cargarReportes() async {
    final db = await DBHelper.instance.database;

    final ingresos = await db.rawQuery('''
      SELECT IFNULL(SUM(total), 0) AS total
      FROM presupuestos
      WHERE estado = 'aprobado' AND deleted = 0
    ''');

    final totalCotizado = await db.rawQuery('''
      SELECT IFNULL(SUM(total), 0) AS total
      FROM presupuestos
      WHERE deleted = 0
    ''');

    final totalPresupuestos = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM presupuestos
      WHERE deleted = 0
    ''');

    final pendientes = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM presupuestos
      WHERE estado = 'pendiente' AND deleted = 0
    ''');

    final aprobados = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM presupuestos
      WHERE estado = 'aprobado' AND deleted = 0
    ''');

    final rechazados = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM presupuestos
      WHERE estado = 'rechazado' AND deleted = 0
    ''');

    final clientes = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM clientes
      WHERE deleted = 0
    ''');

    final costosMateriales = await db.rawQuery('''
      SELECT IFNULL(SUM(dm.subtotal), 0) AS total
      FROM detalle_materiales dm
      INNER JOIN presupuestos p ON p.id = dm.presupuesto_id
      WHERE p.estado = 'aprobado' AND p.deleted = 0
    ''');

    final costosManoObra = await db.rawQuery('''
      SELECT IFNULL(SUM(dmo.subtotal), 0) AS total
      FROM detalle_mano_obra dmo
      INNER JOIN presupuestos p ON p.id = dmo.presupuesto_id
      WHERE p.estado = 'aprobado' AND p.deleted = 0
    ''');

    final costosGastos = await db.rawQuery('''
      SELECT IFNULL(SUM(g.monto), 0) AS total
      FROM gastos g
      INNER JOIN presupuestos p ON p.id = g.presupuesto_id
      WHERE p.estado = 'aprobado' AND p.deleted = 0
    ''');

    final ingresosDia = await db.rawQuery('''
      SELECT 
        DATE(fecha) AS dia,
        IFNULL(SUM(total), 0) AS total
      FROM presupuestos
      WHERE estado = 'aprobado' AND deleted = 0
      GROUP BY DATE(fecha)
      ORDER BY DATE(fecha) ASC
      LIMIT 7
    ''');

    final estadosData = await db.rawQuery('''
      SELECT estado, COUNT(*) AS total
      FROM presupuestos
      WHERE deleted = 0
      GROUP BY estado
    ''');

    final ultimos = await db.rawQuery('''
      SELECT 
        p.id,
        p.fecha,
        p.total,
        p.estado,
        p.descripcion,
        c.nombre AS cliente
      FROM presupuestos p
      INNER JOIN clientes c ON c.id = p.cliente_id
      WHERE p.deleted = 0
      ORDER BY p.fecha DESC
      LIMIT 5
    ''');

    final mat = toDouble(costosMateriales.first["total"]);
    final mano = toDouble(costosManoObra.first["total"]);
    final gas = toDouble(costosGastos.first["total"]);
    final costosTotales = mat + mano + gas;
    final ingresosTotales = toDouble(ingresos.first["total"]);
    final utilidad = ingresosTotales - costosTotales;

    setState(() {
      kpis = {
        "ingresos": ingresosTotales,
        "totalCotizado": toDouble(totalCotizado.first["total"]),
        "costos": costosTotales,
        "utilidad": utilidad,
        "presupuestos": toInt(totalPresupuestos.first["total"]),
        "pendientes": toInt(pendientes.first["total"]),
        "aprobados": toInt(aprobados.first["total"]),
        "rechazados": toInt(rechazados.first["total"]),
        "clientes": toInt(clientes.first["total"]),
      };

      ingresosPorDia = List<Map<String, dynamic>>.from(ingresosDia);

      distribucionCostos = [
        {
          "tipo": "Materiales",
          "total": mat,
          "color": Colors.blue,
        },
        {
          "tipo": "Mano de obra",
          "total": mano,
          "color": Colors.green,
        },
        {
          "tipo": "Gastos",
          "total": gas,
          "color": Colors.orange,
        },
      ];

      estados = List<Map<String, dynamic>>.from(estadosData);
      ultimosPresupuestos = List<Map<String, dynamic>>.from(ultimos);

      cargando = false;
    });
  }

  Future<void> refrescar() async {
    setState(() {
      cargando = true;
    });

    await cargarReportes();
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reportes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refrescar,
          ),
        ],
      ),

      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: refrescar,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kpis(),

                    const SizedBox(height: 20),

                    _resumenEstados(),

                    const SizedBox(height: 20),

                    _graficaIngresos(),

                    const SizedBox(height: 20),

                    _graficaCostos(),

                    const SizedBox(height: 20),

                    _ultimosPresupuestos(),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  // =========================
  // KPI CARDS
  // =========================
  Widget _kpis() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.35,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _cardKpi(
          titulo: "Ingresos aprobados",
          valor: money(kpis["ingresos"]),
          icono: Icons.attach_money,
          color: Colors.green,
        ),
        _cardKpi(
          titulo: "Utilidad estimada",
          valor: money(kpis["utilidad"]),
          icono: Icons.trending_up,
          color: toDouble(kpis["utilidad"]) >= 0 ? Colors.blue : Colors.red,
        ),
        _cardKpi(
          titulo: "Costos aprobados",
          valor: money(kpis["costos"]),
          icono: Icons.payments,
          color: Colors.orange,
        ),
        _cardKpi(
          titulo: "Clientes",
          valor: "${kpis["clientes"]}",
          icono: Icons.people,
          color: Colors.purple,
        ),
        _cardKpi(
          titulo: "Total cotizado",
          valor: money(kpis["totalCotizado"]),
          icono: Icons.request_quote,
          color: Colors.teal,
        ),
        _cardKpi(
          titulo: "Presupuestos",
          valor: "${kpis["presupuestos"]}",
          icono: Icons.folder,
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _cardKpi({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: color, size: 32),

            const SizedBox(height: 8),

            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              valor,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // RESUMEN ESTADOS
  // =========================
  Widget _resumenEstados() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Estado de presupuestos",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _estadoMiniCard(
                    "Pendientes",
                    "${kpis["pendientes"]}",
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _estadoMiniCard(
                    "Aprobados",
                    "${kpis["aprobados"]}",
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _estadoMiniCard(
                    "Rechazados",
                    "${kpis["rechazados"]}",
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoMiniCard(String titulo, String valor, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 22,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // GRÁFICA INGRESOS
  // =========================
  Widget _graficaIngresos() {
    if (ingresosPorDia.isEmpty) {
      return _emptyCard(
        titulo: "Ingresos por día",
        mensaje: "Aún no hay presupuestos aprobados para graficar ingresos.",
      );
    }

    final maxY = ingresosPorDia
        .map((e) => toDouble(e["total"]))
        .fold<double>(0, (prev, item) => item > prev ? item : prev);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ingresos por día",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 230,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY <= 0 ? 100 : maxY * 1.2,
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();

                          if (index < 0 || index >= ingresosPorDia.length) {
                            return const SizedBox();
                          }

                          final dia = ingresosPorDia[index]["dia"].toString();

                          return Text(
                            dia.length >= 10 ? dia.substring(5) : dia,
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.green,
                      dotData: FlDotData(show: true),
                      spots: ingresosPorDia.asMap().entries.map((e) {
                        return FlSpot(
                          e.key.toDouble(),
                          toDouble(e.value["total"]),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // GRÁFICA COSTOS
  // =========================
  Widget _graficaCostos() {
    final totalCostos = distribucionCostos.fold<double>(
      0,
      (sum, item) => sum + toDouble(item["total"]),
    );

    if (totalCostos <= 0) {
      return _emptyCard(
        titulo: "Distribución de costos",
        mensaje: "Aún no hay costos de presupuestos aprobados.",
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Distribución de costos aprobados",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 230,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 40,
                  sectionsSpace: 3,
                  sections: distribucionCostos.map((c) {
                    final total = toDouble(c["total"]);
                    final porcentaje = totalCostos == 0
                        ? 0
                        : (total / totalCostos) * 100;

                    return PieChartSectionData(
                      value: total,
                      color: c["color"],
                      radius: 70,
                      title: "${porcentaje.toStringAsFixed(1)}%",
                      titleStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 10),

            ...distribucionCostos.map((c) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: c["color"],
                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(c["tipo"]),
                    ),

                    Text(
                      money(c["total"]),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // =========================
  // ÚLTIMOS PRESUPUESTOS
  // =========================
  Widget _ultimosPresupuestos() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Últimos presupuestos",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (ultimosPresupuestos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text("No hay presupuestos registrados."),
              ),

            ...ultimosPresupuestos.map((p) {
              final estado = p["estado"]?.toString() ?? "pendiente";

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: estadoColor(estado).withOpacity(0.15),
                  child: Icon(
                    Icons.receipt_long,
                    color: estadoColor(estado),
                  ),
                ),
                title: Text(p["cliente"] ?? "Cliente"),
                subtitle: Text(
                  "${estadoTexto(estado)} · ${p["fecha"] ?? ""}",
                ),
                trailing: Text(
                  money(p["total"]),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // =========================
  // EMPTY CARD
  // =========================
  Widget _emptyCard({
    required String titulo,
    required String mensaje,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.insert_chart_outlined,
                    size: 50,
                    color: Colors.grey,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}