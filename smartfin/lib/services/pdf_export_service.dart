import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../models/transaction.dart';

class PdfExportService {
  static Future<void> export(BuildContext context, List<Transaction> transactions, DateTime month) async {
    try {
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final symbol = currencyProvider.selectedCurrency.symbol;
      final pdf = pw.Document();
      final monthName = DateFormat('MMMM yyyy').format(month);
      
      double totalIncome = 0;
      double totalExpense = 0;

      for (var tx in transactions) {
        if (tx.type == TransactionType.income) {
          totalIncome += tx.amount;
        } else {
          totalExpense += tx.amount;
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SmartFin Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(monthName, style: const pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Summary Block
              pw.Container(
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Total Income', totalIncome, PdfColor.fromHex('#10B981'), symbol),
                    _buildSummaryItem('Total Expense', totalExpense, PdfColor.fromHex('#EF4444'), symbol),
                    _buildSummaryItem('Net Balance', totalIncome - totalExpense, PdfColor.fromHex('#3B82F6'), symbol),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              
              pw.Text('Transaction History', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1.5),
              pw.SizedBox(height: 20),
              
              // Transactions Table
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                  bottom: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9'), borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(8))),
                headerHeight: 40,
                cellHeight: 35,
                headerStyle: pw.TextStyle(color: PdfColor.fromHex('#475569'), fontWeight: pw.FontWeight.bold),
                cellStyle: pw.TextStyle(color: PdfColor.fromHex('#334155')),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
                headers: ['Date', 'Type', 'Category', 'Description', 'Amount'],
                data: List<List<String>>.generate(
                  transactions.length,
                  (index) {
                    final tx = transactions[index];
                    return [
                      DateFormat('MMM dd').format(tx.date),
                      tx.type == TransactionType.income ? 'Income' : 'Expense',
                      tx.categoryName,
                      tx.description,
                      '$symbol${tx.amount.toStringAsFixed(2)}',
                    ];
                  },
                ),
              ),

              pw.SizedBox(height: 40),
            ];
          },
        ),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return _buildChartsList(transactions, symbol);
          },
        ),
      );

      final fileNameFormat = DateFormat('MMM_yyyy').format(month);
      Uint8List pdfBytes = await pdf.save();
      
      final String? path = await FileSaver.instance.saveAs(
        name: 'SmartFin_Report_$fileNameFormat',
        bytes: pdfBytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (context.mounted && path != null) {
         showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Download Complete'),
            content: const Text('PDF Report downloaded successfully!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  static pw.Widget _buildSummaryItem(String label, double amount, PdfColor color, String symbol) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label, style: pw.TextStyle(color: PdfColor.fromHex('#64748B'), fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('$symbol${amount.toStringAsFixed(2)}', style: pw.TextStyle(color: color, fontSize: 20, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static List<pw.Widget> _buildChartsList(List<Transaction> transactions, String symbol) {
    final expenses = transactions.where((tx) => tx.type == TransactionType.expense).toList();
    if (expenses.isEmpty) {
      return [pw.Center(child: pw.Text('No expenses to analyze this month.'))];
    }

    final List<pw.Widget> widgets = [];
    widgets.add(pw.Text('Expense Analysis Charts', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))));
    widgets.add(pw.SizedBox(height: 8));
    widgets.add(pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1.5));
    widgets.add(pw.SizedBox(height: 25));

    // Common Card Style
    final cardDecoration = pw.BoxDecoration(
      color: PdfColor.fromHex('#F8FAFC'),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
      border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1.5),
    );
    final cardPadding = const pw.EdgeInsets.all(24);

    // Helper for Card Title
    pw.Widget buildCardTitle(String title) {
      return pw.Row(
        children: [
          pw.Container(width: 4, height: 18, decoration: pw.BoxDecoration(color: PdfColor.fromHex('#00BFA6'), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)))),
          pw.SizedBox(width: 10),
          pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'))),
        ]
      );
    }

    // 1. Monthly Summary (Donut Chart)
    final Map<String, double> categoryTotals = {};
    for (var tx in expenses) {
      categoryTotals[tx.categoryName] = (categoryTotals[tx.categoryName] ?? 0) + tx.amount;
    }

    final List<PdfColor> colors = [
      PdfColor.fromHex('#FACC15'), PdfColor.fromHex('#38BDF8'), PdfColor.fromHex('#A855F7'), PdfColor.fromHex('#4ADE80'),
      PdfColor.fromHex('#F87171'), PdfColor.fromHex('#818CF8'), PdfColor.fromHex('#F472B6'), PdfColor.fromHex('#A0AEB0'),
    ];

    int colorIndex = 0;
    final List<pw.PieDataSet> pieDatasets = [];
    final totalExpense = categoryTotals.values.fold(0.0, (sum, val) => sum + val);

    final List<pw.Widget> legendItems = [];

    categoryTotals.forEach((category, amount) {
      final color = colors[colorIndex++ % colors.length];
      pieDatasets.add(
        pw.PieDataSet(
          value: amount,
          color: color,
          legendPosition: pw.PieLegendPosition.none,
          borderWidth: 3,
          borderColor: PdfColor.fromHex('#F8FAFC'),
          innerRadius: 65,
        ),
      );

      legendItems.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 12, height: 12, 
                    decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: color)
                  ),
                  pw.SizedBox(width: 12),
                  pw.Text(category, style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#475569'))),
                ]
              ),
              pw.Text('$symbol${amount.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#1E293B'), fontWeight: pw.FontWeight.bold)),
            ]
          )
        )
      );
    });

    final pieChart = pw.Chart(
      grid: pw.PieGrid(),
      datasets: pieDatasets,
    );

    widgets.add(
      pw.Container(
        decoration: cardDecoration,
        padding: cardPadding,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
             buildCardTitle('Monthly Summary'),
             pw.SizedBox(height: 10),
             pw.SizedBox(
               height: 180,
               child: pw.Stack(
                 alignment: pw.Alignment.center,
                 children: [
                   pieChart,
                   pw.Column(
                     mainAxisSize: pw.MainAxisSize.min,
                     children: [
                       pw.Text('Total Expenses', style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#64748B'))),
                       pw.SizedBox(height: 4),
                       pw.Text('$symbol${totalExpense.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                     ]
                   )
                 ]
               )
             ),
             pw.SizedBox(height: 30),
             ...legendItems,
          ],
        )
      )
    );
    widgets.add(pw.SizedBox(height: 40));
    widgets.add(pw.NewPage()); // Push Weekly chart to next page

    // 2. Weekly Expense Analysis (Bar Chart)
    int getWeekNumber(DateTime date) {
      if (date.day <= 7) return 1;
      if (date.day <= 14) return 2;
      if (date.day <= 21) return 3;
      return 4;
    }

    final Map<int, double> weeklyTotals = {1: 0, 2: 0, 3: 0, 4: 0};
    double maxWeeklyExpense = 0;
    for (var tx in expenses) {
      int week = getWeekNumber(tx.date);
      weeklyTotals[week] = (weeklyTotals[week] ?? 0) + tx.amount;
    }
    for (var total in weeklyTotals.values) {
      if (total > maxWeeklyExpense) maxWeeklyExpense = total;
    }
    if (maxWeeklyExpense == 0) maxWeeklyExpense = 1;

    final List<num> yValues = [0, maxWeeklyExpense / 2, maxWeeklyExpense];
    final List<pw.PointChartValue> barData = [];
    for (int i = 1; i <= 4; i++) {
       barData.add(pw.PointChartValue(i.toDouble(), weeklyTotals[i]!));
    }

    final barChart = pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis(
          [0.6, 1, 2, 3, 4, 4.4], 
          format: (v) => (v >= 1 && v <= 4 && v % 1 == 0) ? 'Week ${v.toInt()}' : '',
          textStyle: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#64748B'), fontWeight: pw.FontWeight.bold),
          color: const PdfColor(0, 0, 0, 0),
          ticks: false,
        ),
        yAxis: pw.FixedAxis(
          yValues, 
          format: (v) => '$symbol${v.toInt()}',
          textStyle: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#94A3B8')),
          color: const PdfColor(0, 0, 0, 0),
          divisionsDashed: true,
          divisionsColor: PdfColor.fromHex('#CBD5E1'),
          divisions: true,
          divisionsWidth: 1,
        ),
      ),
      datasets: [
        _RoundedBarDataSet(
          color: PdfColor.fromHex('#4F46E5'),
          data: barData,
          width: 38,
          borderRadius: 8,
        ),
      ],
    );
    widgets.add(
      pw.Container(
        decoration: cardDecoration,
        padding: cardPadding,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
             buildCardTitle('Weekly Expense Analysis'),
             pw.SizedBox(height: 30),
             pw.Container(height: 220, child: barChart),
          ],
        )
      )
    );

    return widgets;
  }
}

class _RoundedBarDataSet extends pw.PointDataSet<pw.PointChartValue> {
  _RoundedBarDataSet({
    required super.data,
    super.color = PdfColors.blue,
    this.width = 10,
    this.borderRadius = 8,
  }) : super(drawPoints: false);

  final double width;
  final double borderRadius;

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints, {bool parentUsesSize = false}) {
    super.layout(context, constraints, parentUsesSize: parentUsesSize);
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    if (data.isEmpty) return;

    final grid = pw.Chart.of(context).grid as pw.CartesianGrid;
    final yOffset = grid.xAxisOffset;

    for (final value in data) {
      final p = grid.toChart(value.point);
      final x = p.x - width / 2;
      final y = yOffset;
      final h = p.y - y;

      if (h <= 0) continue;

      final r = borderRadius > h ? h : borderRadius;
      final magic = 0.552284749831;
      final offsetC = r * magic;

      // Draw the base shape with a very light version of the color
      context.canvas
        ..setFillColor(PdfColor(color!.red, color!.green, color!.blue, 0.2))
        ..moveTo(x, y)
        ..lineTo(x + width, y)
        ..lineTo(x + width, y + h - r)
        ..curveTo(x + width, y + h - r + offsetC, x + width - r + offsetC, y + h, x + width - r, y + h)
        ..lineTo(x + r, y + h)
        ..curveTo(x + r - offsetC, y + h, x, y + h - r + offsetC, x, y + h - r)
        ..lineTo(x, y)
        ..fillPath();

      // Simulate a gradient by drawing 20 overlapping rects/shapes fading out towards the top
      int steps = 20;
      for (int i = 0; i < steps; i++) {
        double currentHeight = h * (1 - (i / steps));
        double alpha = 0.8 * (1 - (i / steps));
        if (currentHeight <= 0) continue;

        context.canvas.setFillColor(PdfColor(color!.red, color!.green, color!.blue, alpha));
        
        if (currentHeight > h - r) {
             // We are inside the rounded corner area
             double currentRadius = r > currentHeight ? currentHeight : r; // Simplify curve logic
             
             context.canvas
                ..moveTo(x, y)
                ..lineTo(x + width, y)
                ..lineTo(x + width, y + currentHeight - currentRadius)
                ..curveTo(x + width, y + currentHeight - currentRadius + (currentRadius * magic), x + width - currentRadius + (currentRadius * magic), y + currentHeight, x + width - currentRadius, y + currentHeight)
                ..lineTo(x + currentRadius, y + currentHeight)
                ..curveTo(x + currentRadius - (currentRadius * magic), y + currentHeight, x, y + currentHeight - currentRadius + (currentRadius * magic), x, y + currentHeight - currentRadius)
                ..lineTo(x, y)
                ..fillPath();
        } else {
             // We are in the flat rectangle area
             context.canvas
                ..moveTo(x, y)
                ..lineTo(x + width, y)
                ..lineTo(x + width, y + currentHeight)
                ..lineTo(x, y + currentHeight)
                ..fillPath();
        }
      }
    }
  }
}
