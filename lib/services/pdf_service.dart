import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfService {
  // =========================
  // GENERAR PDF
  // =========================
  static Future<File> generarPDF({
    required Map presupuesto,
    required Map cliente,
    required List materiales,
    required List manoObra,
    required List gastos,
  }) async {
    final pdf = pw.Document();

    final membrete = await _obtenerMembrete();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(45, 95, 45, 55),
          buildBackground: (context) {
            if (membrete == null) {
              return pw.SizedBox();
            }
            
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(
              membrete,
              fit: pw.BoxFit.cover,
            ),
          );
        },
      ),

    build: (pw.Context context) {
          return [
            _encabezado(presupuesto),

            pw.SizedBox(height: 18),

            _seccionCliente(cliente),

            pw.SizedBox(height: 15),

            _seccionDescripcion(presupuesto),

            pw.SizedBox(height: 15),

            if (materiales.isNotEmpty)
              _tabla(
                titulo: "Materiales",
                encabezados: const ["Descripción", "Cantidad", "Subtotal"],
                filas: materiales.map((m) {
                  return [
                    _texto(m["nombre"], defecto: "Material"),
                    _texto(m["cantidad"], defecto: "1"),
                    _money(m["subtotal"]),
                  ];
                }).toList(),
              ),

            if (manoObra.isNotEmpty)
              _tabla(
                titulo: "Mano de obra",
                encabezados: const ["Descripción", "Cantidad", "Subtotal"],
                filas: manoObra.map((m) {
                  return [
                    _texto(m["descripcion"], defecto: "Mano de obra"),
                    _texto(m["cantidad"], defecto: "1"),
                    _money(m["subtotal"]),
                  ];
                }).toList(),
              ),

            if (gastos.isNotEmpty)
              _tabla(
                titulo: "Gastos",
                encabezados: const ["Descripción", "Cantidad", "Subtotal"],
                filas: gastos.map((g) {
                  return [
                    _texto(g["descripcion"], defecto: "Gasto"),
                    "-",
                    _money(g["monto"]),
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 20),

            _total(presupuesto),

            pw.SizedBox(height: 20),

            _nota(),
          ];
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();

    final id = _texto(presupuesto["id"], defecto: "sin_id");
    final file = File("${dir.path}/presupuesto_$id.pdf");

    await file.writeAsBytes(await pdf.save());

    return file;
  }

  // =========================
  // OBTENER MEMBRETE
  // =========================
  static Future<pw.MemoryImage?> _obtenerMembrete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString("membrete_path");

      if (path == null || path.isEmpty) {
        return null;
      }

      final file = File(path);

      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        return null;
      }

      return pw.MemoryImage(bytes);
    } catch (e) {
      return null;
    }
  }

  // =========================
  // ENCABEZADO
  // =========================
  static pw.Widget _encabezado(Map presupuesto) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey500),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "PRESUPUESTO",
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("Fecha: ${_fechaCorta(presupuesto["fecha"])}"),
              pw.Text("ID: ${_texto(presupuesto["id"])}"),
              pw.Text(
                "Estado: ${_texto(presupuesto["estado"], defecto: "pendiente")}",
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // CLIENTE
  // =========================
  static pw.Widget _seccionCliente(Map cliente) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Cliente",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 5),

          pw.Text("Nombre: ${_texto(cliente["nombre"], defecto: "Sin cliente")}"),
          pw.Text("Teléfono: ${_texto(cliente["telefono"])}"),
          pw.Text("Dirección: ${_texto(cliente["direccion"])}"),

          if (_texto(cliente["email"]).isNotEmpty)
            pw.Text("Correo: ${_texto(cliente["email"])}"),
        ],
      ),
    );
  }

  // =========================
  // DESCRIPCIÓN
  // =========================
  static pw.Widget _seccionDescripcion(Map presupuesto) {
    final descripcion = _texto(presupuesto["descripcion"]);

    if (descripcion.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Descripción",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 5),

          pw.Text(descripcion),
        ],
      ),
    );
  }

  // =========================
  // TABLA
  // =========================
  static pw.Widget _tabla({
    required String titulo,
    required List<String> encabezados,
    required List<List<String>> filas,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 8),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                children: encabezados.map((h) {
                  return _cell(h, bold: true);
                }).toList(),
              ),

              ...filas.map((fila) {
                return pw.TableRow(
                  children: fila.map((texto) {
                    return _cell(texto);
                  }).toList(),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // =========================
  // TOTAL
  // =========================
  static pw.Widget _total(Map presupuesto) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: PdfColors.green),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          "TOTAL: ${_money(presupuesto["total"])}",
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green,
          ),
        ),
      ),
    );
  }

  // =========================
  // NOTA
  // =========================
  static pw.Widget _nota() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        "Este presupuesto está sujeto a cambios según condiciones del servicio, materiales requeridos o ajustes solicitados por el cliente.",
        style: const pw.TextStyle(
          fontSize: 9,
          color: PdfColors.grey700,
        ),
      ),
    );
  }

  // =========================
  // HELPERS
  // =========================
  static String _texto(dynamic value, {String defecto = ""}) {
    if (value == null) return defecto;

    final texto = value.toString();

    if (texto == "null") return defecto;

    return texto;
  }

  static String _fechaCorta(dynamic value) {
    final texto = _texto(value);

    if (texto.length >= 10) {
      return texto.substring(0, 10);
    }

    return texto;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  static String _money(dynamic value) {
    return "\$${_toDouble(value).toStringAsFixed(2)}";
  }

  // =========================
  // IMPRIMIR
  // =========================
  static Future<void> imprimir(File file) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return file.readAsBytes();
      },
    );
  }
}