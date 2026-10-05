import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sistema_presupuestos/database/db_helper.dart';

import 'api_service.dart';

class SyncService {
  // =========================
  // SINCRONIZAR TODO
  // =========================
  static Future<void> syncAll() async {
    await syncClientes();
    await syncMateriales();
    await syncPresupuestos();
  }

  // =========================
  // DESCARGAR TODO
  // =========================
  static Future<void> descargarDatos() async {
    await descargarClientes();
    await descargarMateriales();
    await descargarPresupuestos();
  }

  // =========================
  // HELPERS
  // =========================
  static bool ok(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static String now() {
    return DateTime.now().toIso8601String();
  }

  static double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  static String generarUid(String tabla, int id) {
    return "${tabla}_${DateTime.now().microsecondsSinceEpoch}_$id";
  }

  static Future<String> asegurarLocalUid(
    String tabla,
    Map<String, dynamic> row,
  ) async {
    final db = await DBHelper.instance.database;

    final actual = row["local_uid"];

    if (actual != null && actual.toString().isNotEmpty) {
      return actual.toString();
    }

    final id = row["id"] as int;
    final uid = generarUid(tabla, id);

    await db.update(
      tabla,
      {
        "local_uid": uid,
        "sync": 0,
        "updated_at": now(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return uid;
  }

  // =========================
  // SUBIR CLIENTES
  // =========================
  static Future<void> syncClientes() async {
    final db = await DBHelper.instance.database;

    final clientes = await db.query(
      'clientes',
      where: 'sync = 0',
    );

    if (clientes.isEmpty) return;

    final data = <Map<String, dynamic>>[];

    for (final c in clientes) {
      final uid = await asegurarLocalUid('clientes', c);

      data.add({
        ...c,
        "local_id": uid,
      });
    }

    final response = await http.post(
      Uri.parse("${ApiService.baseUrl}/sync/clientes"),
      headers: await ApiService.getHeaders(),
      body: jsonEncode(data),
    );

    if (!ok(response)) {
      throw Exception("Error sync clientes: ${response.body}");
    }

    for (final c in clientes) {
      await db.update(
        'clientes',
        {
          "sync": 1,
          "updated_at": now(),
        },
        where: 'id = ?',
        whereArgs: [c["id"]],
      );
    }
  }

  // =========================
  // SUBIR MATERIALES
  // =========================
  static Future<void> syncMateriales() async {
    final db = await DBHelper.instance.database;

    final materiales = await db.query(
      'materiales',
      where: 'sync = 0',
    );

    if (materiales.isEmpty) return;

    final data = <Map<String, dynamic>>[];

    for (final m in materiales) {
      final uid = await asegurarLocalUid('materiales', m);

      data.add({
        ...m,
        "local_id": uid,
      });
    }

    final response = await http.post(
      Uri.parse("${ApiService.baseUrl}/sync/materiales"),
      headers: await ApiService.getHeaders(),
      body: jsonEncode(data),
    );

    if (!ok(response)) {
      throw Exception("Error sync materiales: ${response.body}");
    }

    for (final m in materiales) {
      await db.update(
        'materiales',
        {
          "sync": 1,
          "updated_at": now(),
        },
        where: 'id = ?',
        whereArgs: [m["id"]],
      );
    }
  }

  // =========================
  // SUBIR PRESUPUESTOS
  // =========================
  static Future<void> syncPresupuestos() async {
    final db = await DBHelper.instance.database;

    final presupuestos = await db.query(
      'presupuestos',
      where: 'sync = 0',
    );

    if (presupuestos.isEmpty) return;

    for (final p in presupuestos) {
      final presupuestoId = p["id"] as int;
      final uidPresupuesto = await asegurarLocalUid('presupuestos', p);

      final clientes = await db.query(
        'clientes',
        where: 'id = ?',
        whereArgs: [p["cliente_id"]],
      );

      Map<String, dynamic>? cliente;

      if (clientes.isNotEmpty) {
        final c = clientes.first;
        final uidCliente = await asegurarLocalUid('clientes', c);

        cliente = {
          ...c,
          "local_id": uidCliente,
        };
      }

      final materiales = await db.rawQuery('''
        SELECT 
          dm.cantidad,
          dm.subtotal,
          m.nombre,
          m.precio
        FROM detalle_materiales dm
        LEFT JOIN materiales m ON m.id = dm.material_id
        WHERE dm.presupuesto_id = ?
      ''', [presupuestoId]);

      final materialesData = materiales.map((m) {
        final cantidad = toDouble(m["cantidad"]);
        final subtotal = toDouble(m["subtotal"]);
        final precio = toDouble(m["precio"]) > 0
            ? toDouble(m["precio"])
            : cantidad > 0
                ? subtotal / cantidad
                : subtotal;

        return {
          "nombre": m["nombre"] ?? "Material",
          "cantidad": cantidad,
          "precio": precio,
          "subtotal": subtotal,
        };
      }).toList();

      final manoObra = await db.rawQuery('''
        SELECT 
          dmo.cantidad,
          dmo.subtotal,
          mo.descripcion,
          mo.precio
        FROM detalle_mano_obra dmo
        LEFT JOIN mano_obra mo ON mo.id = dmo.mano_obra_id
        WHERE dmo.presupuesto_id = ?
      ''', [presupuestoId]);

      final manoObraData = manoObra.map((m) {
        final cantidad = toDouble(m["cantidad"]);
        final subtotal = toDouble(m["subtotal"]);
        final precio = toDouble(m["precio"]) > 0
            ? toDouble(m["precio"])
            : cantidad > 0
                ? subtotal / cantidad
                : subtotal;

        return {
          "descripcion": m["descripcion"] ?? "Mano de obra",
          "cantidad": cantidad,
          "precio": precio,
          "subtotal": subtotal,
        };
      }).toList();

      final gastos = await db.query(
        'gastos',
        where: 'presupuesto_id = ?',
        whereArgs: [presupuestoId],
      );

      final gastosData = gastos.map((g) {
        return {
          "descripcion": g["descripcion"] ?? "Gasto",
          "monto": toDouble(g["monto"]),
        };
      }).toList();

      final payload = {
        "presupuesto": {
          "local_id": uidPresupuesto,
          "descripcion": p["descripcion"] ?? "",
          "estado": p["estado"] ?? "pendiente",
          "fecha": p["fecha"],
          "total": toDouble(p["total"]),
          "deleted": p["deleted"] ?? 0,
        },
        "cliente": cliente,
        "materiales": materialesData,
        "mano_obra": manoObraData,
        "gastos": gastosData,
      };

      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/sync/presupuesto"),
        headers: await ApiService.getHeaders(),
        body: jsonEncode(payload),
      );

      if (!ok(response)) {
        throw Exception(
          "Error sync presupuesto $presupuestoId: ${response.body}",
        );
      }

      await db.update(
        'presupuestos',
        {
          "sync": 1,
          "updated_at": now(),
        },
        where: 'id = ?',
        whereArgs: [presupuestoId],
      );
    }
  }

  // =========================
  // DESCARGAR CLIENTES
  // =========================
  static Future<void> descargarClientes() async {
    final db = await DBHelper.instance.database;

    final response = await http.get(
      Uri.parse("${ApiService.baseUrl}/clientes"),
      headers: await ApiService.getHeaders(),
    );

    if (!ok(response)) {
      throw Exception("Error descargando clientes: ${response.body}");
    }

    final List data = jsonDecode(response.body);

    for (final c in data) {
      final localUid = c["local_id"]?.toString();

      if (localUid == null || localUid.isEmpty) continue;

      final existentes = await db.query(
        'clientes',
        where: 'local_uid = ?',
        whereArgs: [localUid],
        limit: 1,
      );

      if (existentes.isNotEmpty) {
        final local = existentes.first;

        if (local["sync"] == 0) {
          continue;
        }

        await db.update(
          'clientes',
          {
            "nombre": c["nombre"] ?? "",
            "telefono": c["telefono"] ?? "",
            "direccion": c["direccion"] ?? "",
            "email": c["email"] ?? "",
            "deleted": c["deleted"] == true ? 1 : 0,
            "sync": 1,
            "updated_at": c["updatedAt"] ?? now(),
          },
          where: 'local_uid = ?',
          whereArgs: [localUid],
        );
      } else {
        await db.insert('clientes', {
          "local_uid": localUid,
          "nombre": c["nombre"] ?? "",
          "telefono": c["telefono"] ?? "",
          "direccion": c["direccion"] ?? "",
          "email": c["email"] ?? "",
          "deleted": c["deleted"] == true ? 1 : 0,
          "sync": 1,
          "updated_at": c["updatedAt"] ?? now(),
        });
      }
    }
  }

  // =========================
  // DESCARGAR MATERIALES
  // =========================
  static Future<void> descargarMateriales() async {
    final db = await DBHelper.instance.database;

    final response = await http.get(
      Uri.parse("${ApiService.baseUrl}/materiales"),
      headers: await ApiService.getHeaders(),
    );

    if (!ok(response)) {
      throw Exception("Error descargando materiales: ${response.body}");
    }

    final List data = jsonDecode(response.body);

    for (final m in data) {
      final localUid = m["local_id"]?.toString();

      if (localUid == null || localUid.isEmpty) continue;

      final existentes = await db.query(
        'materiales',
        where: 'local_uid = ?',
        whereArgs: [localUid],
        limit: 1,
      );

      if (existentes.isNotEmpty) {
        final local = existentes.first;

        if (local["sync"] == 0) {
          continue;
        }

        await db.update(
          'materiales',
          {
            "nombre": m["nombre"] ?? "",
            "precio": toDouble(m["precio"]),
            "unidad": m["unidad"] ?? "pieza",
            "origen": m["origen"] ?? "api",
            "deleted": m["deleted"] == true ? 1 : 0,
            "sync": 1,
            "updated_at": m["updatedAt"] ?? now(),
          },
          where: 'local_uid = ?',
          whereArgs: [localUid],
        );
      } else {
        await db.insert('materiales', {
          "local_uid": localUid,
          "nombre": m["nombre"] ?? "",
          "precio": toDouble(m["precio"]),
          "unidad": m["unidad"] ?? "pieza",
          "origen": m["origen"] ?? "api",
          "deleted": m["deleted"] == true ? 1 : 0,
          "sync": 1,
          "updated_at": m["updatedAt"] ?? now(),
        });
      }
    }
  }

  // =========================
  // DESCARGAR PRESUPUESTOS
  // =========================
  static Future<void> descargarPresupuestos() async {
    final db = await DBHelper.instance.database;

    final response = await http.get(
      Uri.parse("${ApiService.baseUrl}/presupuestos"),
      headers: await ApiService.getHeaders(),
    );

    if (!ok(response)) {
      throw Exception("Error descargando presupuestos: ${response.body}");
    }

    final List data = jsonDecode(response.body);

    for (final p in data) {
      final localUid = p["local_id"]?.toString();

      if (localUid == null || localUid.isEmpty) continue;

      final existentes = await db.query(
        'presupuestos',
        where: 'local_uid = ?',
        whereArgs: [localUid],
        limit: 1,
      );

      if (existentes.isNotEmpty && existentes.first["sync"] == 0) {
        continue;
      }

      final clienteRemoto = p["cliente"];
      int? clienteLocalId;

      if (clienteRemoto != null && clienteRemoto["local_id"] != null) {
        final clienteUid = clienteRemoto["local_id"].toString();

        final clienteExiste = await db.query(
          'clientes',
          where: 'local_uid = ?',
          whereArgs: [clienteUid],
          limit: 1,
        );

        if (clienteExiste.isNotEmpty) {
          clienteLocalId = clienteExiste.first["id"] as int;

          if (clienteExiste.first["sync"] != 0) {
            await db.update(
              'clientes',
              {
                "nombre": clienteRemoto["nombre"] ?? "",
                "telefono": clienteRemoto["telefono"] ?? "",
                "direccion": clienteRemoto["direccion"] ?? "",
                "email": clienteRemoto["email"] ?? "",
                "sync": 1,
                "updated_at": clienteRemoto["updatedAt"] ?? now(),
                "deleted": clienteRemoto["deleted"] == true ? 1 : 0,
              },
              where: 'local_uid = ?',
              whereArgs: [clienteUid],
            );
          }
        } else {
          clienteLocalId = await db.insert('clientes', {
            "local_uid": clienteUid,
            "nombre": clienteRemoto["nombre"] ?? "",
            "telefono": clienteRemoto["telefono"] ?? "",
            "direccion": clienteRemoto["direccion"] ?? "",
            "email": clienteRemoto["email"] ?? "",
            "sync": 1,
            "updated_at": clienteRemoto["updatedAt"] ?? now(),
            "deleted": clienteRemoto["deleted"] == true ? 1 : 0,
          });
        }
      }

      if (clienteLocalId == null) continue;

      if (p["deleted"] == true) {
        if (existentes.isNotEmpty) {
          await db.update(
            'presupuestos',
            {
              "deleted": 1,
              "sync": 1,
              "updated_at": p["updatedAt"] ?? now(),
            },
            where: 'local_uid = ?',
            whereArgs: [localUid],
          );
        }

        continue;
      }

      int presupuestoLocalId;

      if (existentes.isNotEmpty) {
        presupuestoLocalId = existentes.first["id"] as int;

        await db.update(
          'presupuestos',
          {
            "cliente_id": clienteLocalId,
            "fecha": p["fecha"] ?? now(),
            "total": toDouble(p["total"]),
            "descripcion": p["descripcion"] ?? "",
            "estado": p["estado"] ?? "pendiente",
            "sync": 1,
            "updated_at": p["updatedAt"] ?? now(),
            "deleted": 0,
          },
          where: 'local_uid = ?',
          whereArgs: [localUid],
        );
      } else {
        presupuestoLocalId = await db.insert('presupuestos', {
          "local_uid": localUid,
          "cliente_id": clienteLocalId,
          "fecha": p["fecha"] ?? now(),
          "total": toDouble(p["total"]),
          "descripcion": p["descripcion"] ?? "",
          "estado": p["estado"] ?? "pendiente",
          "sync": 1,
          "updated_at": p["updatedAt"] ?? now(),
          "deleted": 0,
        });
      }

      await db.delete(
        'detalle_materiales',
        where: 'presupuesto_id = ?',
        whereArgs: [presupuestoLocalId],
      );

      await db.delete(
        'detalle_mano_obra',
        where: 'presupuesto_id = ?',
        whereArgs: [presupuestoLocalId],
      );

      await db.delete(
        'gastos',
        where: 'presupuesto_id = ?',
        whereArgs: [presupuestoLocalId],
      );

      final List materiales = p["materiales"] ?? [];

      for (final m in materiales) {
        final materialId = await db.insert('materiales', {
          "nombre": m["nombre"] ?? "Material",
          "precio": toDouble(m["precio"]),
          "unidad": "pieza",
          "origen": "api",
          "sync": 1,
          "updated_at": now(),
          "deleted": 0,
        });

        await db.insert('detalle_materiales', {
          "presupuesto_id": presupuestoLocalId,
          "material_id": materialId,
          "cantidad": toDouble(m["cantidad"]),
          "subtotal": toDouble(m["subtotal"]),
        });
      }

      final List manoObra = p["mano_obra"] ?? [];

      for (final mo in manoObra) {
        final manoObraId = await db.insert('mano_obra', {
          "descripcion": mo["descripcion"] ?? "Mano de obra",
          "precio": toDouble(mo["precio"]),
        });

        await db.insert('detalle_mano_obra', {
          "presupuesto_id": presupuestoLocalId,
          "mano_obra_id": manoObraId,
          "cantidad": toDouble(mo["cantidad"]),
          "subtotal": toDouble(mo["subtotal"]),
        });
      }

      final List gastos = p["gastos"] ?? [];

      for (final g in gastos) {
        await db.insert('gastos', {
          "presupuesto_id": presupuestoLocalId,
          "descripcion": g["descripcion"] ?? "Gasto",
          "monto": toDouble(g["monto"]),
        });
      }
    }
  }
}