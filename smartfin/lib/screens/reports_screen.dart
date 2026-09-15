import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/month_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/monthly_summary_chart.dart';
import '../widgets/weekly_expense_analysis_chart.dart';
import '../widgets/daily_expense_analysis_chart.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isExporting = false;

  void _handleExportCsv(BuildContext context, DateTime selectedMonth) async {
    setState(() => _isExporting = true);
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final transactions = txProvider.getTransactionsForMonth(selectedMonth);
    
    await ExcelExportService.export(context, transactions, selectedMonth);
    
    setState(() => _isExporting = false);
  }

  void _handleExportPdf(BuildContext context, DateTime selectedMonth) async {
    setState(() => _isExporting = true);
    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final transactions = txProvider.getTransactionsForMonth(selectedMonth);
    
    await PdfExportService.export(context, transactions, selectedMonth);
    
    setState(() => _isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Consumer<MonthProvider>(
            builder: (context, monthProvider, child) {
              final selectedMonth = monthProvider.selectedMonth;
              return PopupMenuButton<String>(
                icon: _isExporting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: const Color(0xFF00BFA6), strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, color: Color(0xFF00BFA6)),
                color: Theme.of(context).cardColor,
                onSelected: (value) {
                  if (value == 'csv') {
                    _handleExportCsv(context, selectedMonth);
                  } else if (value == 'pdf') {
                    _handleExportPdf(context, selectedMonth);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'pdf',
                    child: ListTile(
                      leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                      title: Text('Export PDF', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'csv',
                    child: ListTile(
                      leading: const Icon(Icons.table_chart, color: Colors.greenAccent),
                      title: Text('Export CSV', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<MonthProvider>(
        builder: (context, monthProvider, child) {
          final selectedMonth = monthProvider.selectedMonth;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<DateTime>(
                          value: selectedMonth,
                          dropdownColor: Theme.of(context).cardColor,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF00BFA6)),
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
                          items: monthProvider.lastSixMonths.map((DateTime month) {
                            return DropdownMenuItem<DateTime>(
                              value: month,
                              child: Text(DateFormat('MMMM yyyy').format(month)),
                            );
                          }).toList(),
                          onChanged: (DateTime? newValue) {
                            if (newValue != null) {
                              monthProvider.setSelectedMonth(newValue);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 280,
                        child: MonthlySummaryChart(selectedMonth: selectedMonth),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 280,
                        child: ExpenseAnalysisChart(selectedMonth: selectedMonth),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 300,
                        child: SpendingTrendChart(selectedMonth: selectedMonth),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
