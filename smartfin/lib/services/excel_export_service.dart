import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import '../models/transaction.dart';

class ExcelExportService {
  static Future<void> export(BuildContext context, List<Transaction> transactions, DateTime month) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['SmartFin Report'];
      excel.setDefaultSheet('SmartFin Report');

      // Define Styles
      var headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'), // Light Slate 100
        fontColorHex: ExcelColor.fromHexString('#475569'),       // Slate 600
        verticalAlign: VerticalAlign.Center,
      );

      var titleStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),       // Slate 900
        fontSize: 12,
      );

      var summaryHeaderStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'), // Slate 50
        fontColorHex: ExcelColor.fromHexString('#1E293B'),       // Slate 800
      );
      
      // Calculate Summaries
      double totalIncome = 0;
      double totalExpense = 0;
      final Map<String, double> categoryTotals = {};
      final Map<int, double> weeklyTotals = {1: 0, 2: 0, 3: 0, 4: 0};

      int getWeekNumber(DateTime date) {
        if (date.day <= 7) return 1;
        if (date.day <= 14) return 2;
        if (date.day <= 21) return 3;
        return 4;
      }

      for (var tx in transactions) {
        if (tx.type == TransactionType.income) {
          totalIncome += tx.amount;
        } else {
          totalExpense += tx.amount;
          categoryTotals[tx.categoryName] = (categoryTotals[tx.categoryName] ?? 0) + tx.amount;
          int week = getWeekNumber(tx.date);
          weeklyTotals[week] = (weeklyTotals[week] ?? 0) + tx.amount;
        }
      }

      // Add Headers
      sheetObject.appendRow([
        TextCellValue('Date'), TextCellValue('Type'), TextCellValue('Category'), 
        TextCellValue('Description'), TextCellValue('Amount')
      ]);

      // Style Headers
      for (int i = 0; i < 5; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = headerStyle;
      }

      // Add Transactions
      for (var tx in transactions) {
        sheetObject.appendRow([
          TextCellValue(DateFormat('yyyy-MM-dd').format(tx.date)),
          TextCellValue(tx.type == TransactionType.income ? 'Income' : 'Expense'),
          TextCellValue(tx.categoryName),
          TextCellValue(tx.description),
          DoubleCellValue(tx.amount)
        ]);
      }

      sheetObject.appendRow([TextCellValue('')]);
      sheetObject.appendRow([TextCellValue('')]);
      
      int summaryTitleRow = sheetObject.maxRows;
      sheetObject.appendRow([TextCellValue('Overall Summary')]);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryTitleRow)).cellStyle = titleStyle;

      sheetObject.appendRow([TextCellValue('Total Income'), DoubleCellValue(totalIncome)]);
      sheetObject.appendRow([TextCellValue('Total Expense'), DoubleCellValue(totalExpense)]);
      sheetObject.appendRow([TextCellValue('Net Balance'), DoubleCellValue(totalIncome - totalExpense)]);
      
      if (categoryTotals.isNotEmpty) {
          sheetObject.appendRow([TextCellValue('')]);
          sheetObject.appendRow([TextCellValue('')]);
          
          int catTitleRow = sheetObject.maxRows;
          sheetObject.appendRow([TextCellValue('Monthly Category Summary (Expenses)')]);
          sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: catTitleRow)).cellStyle = titleStyle;

          int catHeaderRow = sheetObject.maxRows;
          sheetObject.appendRow([TextCellValue('Category'), TextCellValue('Total Amount')]);
          sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: catHeaderRow)).cellStyle = summaryHeaderStyle;
          sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: catHeaderRow)).cellStyle = summaryHeaderStyle;

          categoryTotals.forEach((category, amount) {
             sheetObject.appendRow([TextCellValue(category), DoubleCellValue(amount)]);
          });

          sheetObject.appendRow([TextCellValue('')]);
          sheetObject.appendRow([TextCellValue('')]);
          
          int weekTitleRow = sheetObject.maxRows;
          sheetObject.appendRow([TextCellValue('Weekly Expense Analysis (Expenses)')]);
          sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: weekTitleRow)).cellStyle = titleStyle;

          int weekHeaderRow = sheetObject.maxRows;
          sheetObject.appendRow([TextCellValue('Week'), TextCellValue('Total Amount')]);
          sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: weekHeaderRow)).cellStyle = summaryHeaderStyle;
          sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: weekHeaderRow)).cellStyle = summaryHeaderStyle;

          for (int i = 1; i <= 4; i++) {
             sheetObject.appendRow([TextCellValue('Week $i'), DoubleCellValue(weeklyTotals[i]!)]);
          }
      }

      var fileBytes = excel.save();
      if (fileBytes == null) throw Exception("Failed to generate Excel file");
      
      final String monthName = DateFormat('MMM_yyyy').format(month);
      
      final String? path = await FileSaver.instance.saveAs(
        name: 'SmartFin_Report_$monthName',
        bytes: Uint8List.fromList(fileBytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (context.mounted && path != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Download Complete'),
            content: const Text('Excel Report downloaded successfully!'),
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
          SnackBar(content: Text('Failed to export Excel: $e')),
        );
      }
    }
  }
}
