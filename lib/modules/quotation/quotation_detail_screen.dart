import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sakthi_erp/utils/error_handler.dart';

class QuotationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> quotation;
  final String serverUrl;
  final String sid;

  const QuotationDetailScreen({
    super.key,
    required this.quotation,
    required this.serverUrl,
    required this.sid,
  });

  @override
  _QuotationDetailScreenState createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  Map<String, dynamic> quotationDetails = {};
  bool isLoading = true;
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<Map<String, dynamic>> _sections = [
    {'title': 'Quotation Details', 'icon': Icons.description},
    {'title': 'Customer Details', 'icon': Icons.person},
    {'title': 'Summary', 'icon': Icons.account_balance_wallet},
    {'title': 'Items', 'icon': Icons.inventory},
    {'title': 'Taxes', 'icon': Icons.receipt},
    {'title': 'Sales Order', 'icon': Icons.shopping_cart},
    {'title': 'Sales Invoice', 'icon': Icons.receipt_long},
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    fetchQuotationDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> fetchQuotationDetails() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse(
            '${widget.serverUrl}/api/resource/Quotation/${widget.quotation['name']}'),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          quotationDetails = data['data'] ?? {};
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load quotation: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching quotation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load quotation: $e')),
      );
      setState(() {
        quotationDetails = widget.quotation;
        isLoading = false;
      });
    }
  }

  double get _totalAmount {
    return (quotationDetails['items'] as List<dynamic>?)?.fold<double>(
          0.0,
          (sum, item) => sum + (item['amount']?.toDouble() ?? 0.0),
        ) ??
        0.0;
  }

  double get _totalTaxAmount {
    return (quotationDetails['taxes'] as List<dynamic>?)?.fold<double>(
          0.0,
          (sum, tax) => sum + (tax['tax_amount']?.toDouble() ?? 0.0),
        ) ??
        0.0;
  }

  double get _grandTotal {
    return _totalAmount + _totalTaxAmount;
  }

  int get _totalQuantity {
    return (quotationDetails['items'] as List<dynamic>?)?.fold<int>(
          0,
          (sum, item) => sum + (item['qty'] as num? ?? 0).toInt(),
        ) ??
        0;
  }

  Future<pw.Document> generatePdf() async {
    final pdf = pw.Document();
    pw.Font ttf;
    List<pw.Font> fontFallbacks = [];

    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
      fontFallbacks = [ttf];
    } catch (e) {
      print('Error loading NotoSans font: $e. Using Times with fallback.');
      ttf = pw.Font.times();
      try {
        final dejavuFontData =
            await rootBundle.load('assets/fonts/DejaVuSans.ttf');
        fontFallbacks = [pw.Font.ttf(dejavuFontData)];
      } catch (_) {
        fontFallbacks = [pw.Font.times()];
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            quotationDetails['company'] ?? 'N/A',
            style: pw.TextStyle(
                font: ttf, fontSize: 8, fontFallback: fontFallbacks),
            textAlign: pw.TextAlign.center,
          ),
        ),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Text(
                'QUOTATION',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  fontFallback: fontFallbacks,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                quotationDetails['name'] ?? 'N/A',
                style: pw.TextStyle(
                    font: ttf, fontSize: 12, fontFallback: fontFallbacks),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                quotationDetails['company'] ?? 'N/A',
                style: pw.TextStyle(
                    font: ttf, fontSize: 12, fontFallback: fontFallbacks),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 12),
              // Customer Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'Customer Name: ',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              fontFallback: fontFallbacks,
                            ),
                          ),
                          pw.Text(
                            quotationDetails['customer_name'] ?? 'N/A',
                            style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                fontFallback: fontFallbacks),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Mobile No: ',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              fontFallback: fontFallbacks,
                            ),
                          ),
                          pw.Text(
                            quotationDetails['contact_mobile'] ?? 'N/A',
                            style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                fontFallback: fontFallbacks),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'Date: ',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              fontFallback: fontFallbacks,
                            ),
                          ),
                          pw.Text(
                            formatDate(quotationDetails['transaction_date']) ??
                                'N/A',
                            style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                fontFallback: fontFallbacks),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Valid Till: ',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              fontFallback: fontFallbacks,
                            ),
                          ),
                          pw.Text(
                            formatDate(quotationDetails['valid_till']) ?? 'N/A',
                            style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                fontFallback: fontFallbacks),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              // Item Table
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FixedColumnWidth(80),
                  2: const pw.FlexColumnWidth(),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(80),
                  5: const pw.FixedColumnWidth(80),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfTableHeader('Sr', ttf, fontFallbacks),
                      _pdfTableHeader('Item Code', ttf, fontFallbacks),
                      _pdfTableHeader('Description', ttf, fontFallbacks),
                      _pdfTableHeader('Quantity', ttf, fontFallbacks),
                      _pdfTableHeader('Rate', ttf, fontFallbacks),
                      _pdfTableHeader('Amount', ttf, fontFallbacks),
                    ],
                  ),
                  ...(quotationDetails['items'] as List<dynamic>?)
                          ?.asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key + 1;
                        final item = entry.value;
                        return pw.TableRow(
                          children: [
                            _pdfTableCell(index.toString(), ttf, fontFallbacks),
                            _pdfTableCell(
                                item['item_code'] ?? 'N/A', ttf, fontFallbacks),
                            _pdfTableCell(
                                item['item_name'] ?? 'N/A', ttf, fontFallbacks),
                            _pdfTableCell(
                                '${item['qty']?.toString() ?? '0'} ${item['stock_uom'] ?? ''}',
                                ttf,
                                fontFallbacks),
                            _pdfTableCell(
                                '₹ ${(item['rate']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                ttf,
                                fontFallbacks),
                            _pdfTableCell(
                                '₹ ${(item['amount']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                ttf,
                                fontFallbacks),
                          ],
                        );
                      })?.toList() ??
                      [],
                ],
              ),
              pw.SizedBox(height: 12),
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'Total Quantity: ',
                            style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                fontFallback: fontFallbacks),
                          ),
                          pw.Text(
                            _totalQuantity.toString(),
                            style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                fontFallback: fontFallbacks),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Total: ',
                            style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                fontFallback: fontFallbacks),
                          ),
                          pw.Text(
                            '₹ ${_totalAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                                font: ttf,
                                fontSize: 10,
                                fontFallback: fontFallbacks),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              // Taxes Table
              if ((quotationDetails['taxes'] as List<dynamic>?)?.isNotEmpty ??
                  false)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Taxes and Charges',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        fontFallback: fontFallbacks,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(width: 0.5),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(),
                        1: const pw.FixedColumnWidth(100),
                      },
                      children: [
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _pdfTableHeader('Description', ttf, fontFallbacks),
                            _pdfTableHeader('Amount', ttf, fontFallbacks),
                          ],
                        ),
                        ...(quotationDetails['taxes'] as List<dynamic>?)
                                ?.map((tax) => pw.TableRow(
                                      children: [
                                        _pdfTableCell(
                                          tax['description'] ??
                                              tax['account_head'] ??
                                              'Tax',
                                          ttf,
                                          fontFallbacks,
                                        ),
                                        _pdfTableCell(
                                          '₹ ${(tax['tax_amount']?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                          ttf,
                                          fontFallbacks,
                                        ),
                                      ],
                                    ))
                                .toList() ??
                            [],
                      ],
                    ),
                  ],
                ),
              pw.SizedBox(height: 12),
              // Terms & Conditions
              pw.Text(
                'TERMS & CONDITIONS',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  fontFallback: fontFallbacks,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildTermsRow(
                  'Quality As per IS Specification 1786', ttf, fontFallbacks),
              _buildTermsRow(
                  'Weighment Tolerance +/- 0.50% Per Ton', ttf, fontFallbacks),
              _buildTermsRow(
                  'Test Certificate will be provided each consignment',
                  ttf,
                  fontFallbacks),
              _buildTermsRow('Material Type Full Length', ttf, fontFallbacks),
              _buildTermsRow(
                  'Site contact person name & mobile no.', ttf, fontFallbacks),
              _buildTermsRow(
                  'Delivery - ${quotationDetails['delivery_location'] ?? 'T. Nagar, Chennai'}',
                  ttf,
                  fontFallbacks),
              pw.SizedBox(height: 12),
              // Grand Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Grand Total: ',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      fontFallback: fontFallbacks,
                    ),
                  ),
                  pw.Text(
                    '₹ ${_grandTotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      fontFallback: fontFallbacks,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Text(
                    'Payment Terms: ',
                    style: pw.TextStyle(
                        font: ttf, fontSize: 10, fontFallback: fontFallbacks),
                  ),
                  pw.Text(
                    quotationDetails['payment_terms'] ?? 'Advance',
                    style: pw.TextStyle(
                        font: ttf, fontSize: 10, fontFallback: fontFallbacks),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Text(
                    'In Words: ',
                    style: pw.TextStyle(
                        font: ttf, fontSize: 10, fontFallback: fontFallbacks),
                  ),
                  pw.Text(
                    quotationDetails['in_words'] ?? 'N/A',
                    style: pw.TextStyle(
                        font: ttf, fontSize: 10, fontFallback: fontFallbacks),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return pdf;
  }

  pw.Widget _buildTermsRow(
      String text, pw.Font font, List<pw.Font> fontFallbacks) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('[ ] ',
              style: pw.TextStyle(
                  font: font, fontSize: 10, fontFallback: fontFallbacks)),
          pw.Text(text,
              style: pw.TextStyle(
                  font: font, fontSize: 10, fontFallback: fontFallbacks)),
        ],
      ),
    );
  }

  pw.Widget _pdfTableHeader(
      String title, pw.Font font, List<pw.Font> fontFallbacks) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          fontFallback: fontFallbacks,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfTableCell(
      String text, pw.Font font, List<pw.Font> fontFallbacks) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style:
            pw.TextStyle(font: font, fontSize: 10, fontFallback: fontFallbacks),
        textAlign: pw.TextAlign.left,
      ),
    );
  }

  String removeHtmlTags(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return 'N/A';
    final RegExp exp = RegExp(
      r'<[^>]*>',
      multiLine: true,
      caseSensitive: false,
    );
    return htmlString.replaceAll(exp, ' ').trim();
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _printQuotation() async {
    if (quotationDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No quotation data to print')),
      );
      return;
    }
    try {
      final pdf = await generatePdf();
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      print('Error printing PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print PDF: $e')),
      );
    }
  }

  Future<void> _saveAsPdf() async {
    if (quotationDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No quotation data to save')),
      );
      return;
    }
    try {
      final pdf = await generatePdf();
      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'quotation_${quotationDetails['name']}.pdf',
      );
    } catch (e) {
      print('Error saving PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: $e')),
      );
    }
  }

  void _onNavBarTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          quotationDetails['name'] ?? 'Quotation Details',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _printQuotation,
            tooltip: 'Print',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt, color: Colors.white),
            onPressed: _saveAsPdf,
            tooltip: 'Save as PDF',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : quotationDetails.isEmpty
              ? Center(
                  child: Text(
                    'Quotation not found',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : Column(
                  children: [
                    Container(
                      height: 70,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.05),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        itemCount: _sections.length,
                        itemBuilder: (context, index) {
                          final isSelected = _selectedIndex == index;
                          return GestureDetector(
                            onTap: () => _onNavBarTap(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _sections[index]['icon'],
                                    color: isSelected
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _sections[index]['title'],
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        children: [
                          _buildSectionCard(_buildQuotationDetailsSection()),
                          _buildSectionCard(_buildCustomerDetailsSection()),
                          _buildSectionCard(_buildSummarySection()),
                          _buildSectionCard(_buildItemsSection()),
                          _buildSectionCard(_buildTaxesSection()),
                          _buildSectionCard(_buildSalesOrderSection()),
                          _buildSectionCard(_buildSalesInvoiceSection()),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSectionCard(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: const Color(0xFFFFFFFF),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value,
      {String? status, bool isBold = false}) {
    Color textColor = Theme.of(context).colorScheme.onBackground;
    if (status != null) {
      if (status == 'Ordered') {
        textColor = const Color(0xFF4CAF50);
      } else if (status == 'Partially Ordered') {
        textColor = const Color(0xFFFFA000);
      } else if (status == 'Open') {
        textColor = const Color(0xFF2196F3);
      } else if (status == 'Cancelled') {
        textColor = const Color(0xFFF44336);
      }
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.6),
                  fontSize: 14,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                value?.toString() ?? 'N/A',
                style: TextStyle(
                  fontWeight: isBold || status != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 14,
                  color: textColor,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildQuotationDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Quotation Details'),
        const SizedBox(height: 12),
        _buildInfoRow('Quotation ID', quotationDetails['name'], isBold: true),
        _buildInfoRow('Quotation To', quotationDetails['party_name']),
        _buildInfoRow('Status', quotationDetails['status'],
            status: quotationDetails['status']),
        _buildInfoRow('Salesperson', quotationDetails['salesperson_name']),
        _buildInfoRow('Transaction Date',
            formatDate(quotationDetails['transaction_date'])),
        _buildInfoRow('Valid Till', formatDate(quotationDetails['valid_till'])),
        _buildInfoRow('Cost Center', quotationDetails['cost_center']),
        _buildInfoRow('Company', quotationDetails['company']),
        _buildInfoRow('Currency', quotationDetails['currency']),
        _buildInfoRow('In Words', quotationDetails['in_words']),
        _buildInfoRow('Naming Series', quotationDetails['naming_series']),
        _buildInfoRow(
            'Selling Price List', quotationDetails['selling_price_list']),
      ],
    );
  }

  Widget _buildCustomerDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Customer Details'),
        const SizedBox(height: 12),
        _buildInfoRow('Customer', quotationDetails['customer_name']),
        _buildInfoRow('Customer Name', quotationDetails['customer_name'],
            isBold: true),
        _buildInfoRow('Address Display',
            removeHtmlTags(quotationDetails['customer_address'])),
        _buildInfoRow(
            'Tax Category', quotationDetails['tax_category'] ?? 'N/A'),
        _buildInfoRow('Contact Mobile', quotationDetails['contact_mobile']),
      ],
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Summary'),
        const SizedBox(height: 12),
        _buildInfoRow('Total Quantity', _totalQuantity.toString()),
        _buildInfoRow('Total Amount', '₹ ${_totalAmount.toStringAsFixed(2)}'),
        if (_totalTaxAmount > 0)
          _buildInfoRow('Total Tax', '₹ ${_totalTaxAmount.toStringAsFixed(2)}'),
        _buildInfoRow('Grand Total', '₹ ${_grandTotal.toStringAsFixed(2)}'),
        _buildInfoRow('In Words', quotationDetails['in_words']),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Items'),
        const SizedBox(height: 12),
        ...(quotationDetails['items'] as List<dynamic>? ?? [])
            .asMap()
            .entries
            .map((entry) {
          final index = entry.key;
          final item = entry.value as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubSectionTitle('Item ${index + 1}'),
                    _buildInfoRow('Item Code', item['item_code']),
                    _buildInfoRow('Item Name', item['item_name'], isBold: true),
                    _buildInfoRow('Quantity', item['qty']?.toString()),
                    _buildInfoRow('Stock UOM', item['stock_uom']),
                    _buildInfoRow('UOM', item['uom']),
                    _buildInfoRow('Conversion Factor',
                        item['conversion_factor']?.toString()),
                    _buildInfoRow('Stock Qty', item['stock_qty']?.toString()),
                    _buildInfoRow('Price List Rate',
                        '₹ ${item['price_list_rate']?.toString() ?? '0'}'),
                    _buildInfoRow('Discount Amount',
                        '₹ ${item['discount_amount']?.toString() ?? '0'}'),
                    _buildInfoRow(
                        'Rate', '₹ ${item['rate']?.toString() ?? '0'}'),
                    _buildInfoRow(
                        'Amount', '₹ ${item['amount']?.toString() ?? '0'}'),
                    if (item['image'] != null && item['image'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: CachedNetworkImage(
                          imageUrl: item['image'].startsWith('http')
                              ? item['image']
                              : '${widget.serverUrl}${item['image']}',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, _) =>
                              const CircularProgressIndicator(),
                          errorWidget: (context, _, __) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTaxesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Taxes'),
        const SizedBox(height: 12),
        ...(quotationDetails['taxes'] as List<dynamic>? ?? [])
            .asMap()
            .entries
            .map((entry) {
          final index = entry.key;
          final tax = entry.value as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubSectionTitle('Tax ${index + 1}'),
                    _buildInfoRow('Charge Type', tax['charge_type']),
                    _buildInfoRow('Account Head', tax['account_head'],
                        isBold: true),
                    _buildInfoRow('Description', tax['description']),
                    _buildInfoRow('Rate (%)', tax['rate']?.toString()),
                    _buildInfoRow('Tax Amount',
                        '₹ ${tax['tax_amount']?.toString() ?? '0'}'),
                    _buildInfoRow(
                        'Total', '₹ ${tax['total']?.toString() ?? '0'}'),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
        if (quotationDetails['taxes'] == null ||
            (quotationDetails['taxes'] as List<dynamic>).isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No taxes applied.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildSalesOrderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Sales Order'),
        const SizedBox(height: 12),
        const Text(
          'No Sales Order linked to this Quotation.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSalesInvoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Sales Invoice'),
        const SizedBox(height: 12),
        const Text(
          'No Sales Invoice linked to this Quotation.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
