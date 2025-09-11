import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sakthi_erp/shared/widgets/custom_search_dropdown.dart';
import 'package:sakthi_erp/utils/error_handler.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ReceivableReportScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const ReceivableReportScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
  });

  @override
  State<ReceivableReportScreen> createState() => _ReceivableReportScreenState();
}

class _ReceivableReportScreenState extends State<ReceivableReportScreen> {
  final TextEditingController _dateController = TextEditingController();
  bool _isLoadingPdf = false;
  bool _isLoadingCustomers = true;
  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic>? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  /// Fetches the list of customers from the server.
  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
    });

    final String apiUrl =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_customers';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        if (responseData['message']?['status'] == 'success' &&
            responseData['message']?['customers'] is List) {
          setState(() {
            _customers = List<Map<String, dynamic>>.from(
              responseData['message']['customers'],
            );
          });
        } else {
          throw 'Invalid response format from server.';
        }
      } else {
        throw response.body;
      }
    } catch (e) {
      if (mounted) {
        showApiErrorDialog(context, message: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCustomers = false;
        });
      }
    }
  }

  /// Shows a date picker dialog to select the report date.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  /// Generates the receivable report PDF.
  Future<void> _generatePdf() async {
    if (_selectedCustomer == null || _dateController.text.isEmpty) {
      showErrorDialog(
        context,
        'Validation Error',
        'Please select a customer and a date.',
      );
      return;
    }

    setState(() {
      _isLoadingPdf = true;
    });

    final String apiUrl =
        '${widget.serverUrl}/api/method/sakthi_tmt.api.receivable_report.generate_receivable_pdf';

    final Map<String, String> queryParams = {
      'customer': _selectedCustomer!['name'],
      'customer_name': _selectedCustomer!['customer_name'] ?? '',
      'date': _dateController.text.trim(),
    };

    final uri = Uri.parse(apiUrl).replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {'Cookie': 'sid=${widget.sid}'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String? pdfUrl = responseData['message']?['pdf_url'];

        if (pdfUrl != null && pdfUrl.isNotEmpty) {
          final serverUri = Uri.parse(widget.serverUrl);
          final responsePdfUri = Uri.parse(pdfUrl);
          final finalPdfUri = serverUri.replace(
            path: responsePdfUri.path,
            queryParameters: responsePdfUri.queryParameters,
          );

          final pdfResponse = await http.get(
            finalPdfUri,
            headers: {'Cookie': 'sid=${widget.sid}'},
          );
          
          if (!mounted) return;

          if (pdfResponse.statusCode == 200) {
            final Uint8List pdfBytes = pdfResponse.bodyBytes;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(
                  pdfBytes: pdfBytes,
                  customerName: _selectedCustomer!['customer_name'] ?? 'Report',
                ),
              ),
            );
          } else {
             throw 'Failed to download PDF: ${pdfResponse.statusCode}';
          }
        } else {
          throw 'PDF URL not found in the server response.';
        }
      } else {
        throw response.body;
      }
    } catch (e) {
      if (mounted) {
        showApiErrorDialog(context, message: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPdf = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receivable Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Generate Customer Receivable Report',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _isLoadingCustomers
                    ? const Center(child: CircularProgressIndicator())
                    : CustomSearchableDropdown<Map<String, dynamic>>(
                        label: 'Customer',
                        value: _selectedCustomer,
                        items: _customers,
                        itemAsString: (customer) =>
                            '${customer['name']} - ${customer['customer_name']}',
                        onChanged: (value) {
                          setState(() {
                            _selectedCustomer = value;
                          });
                        },
                        validatorMessage: 'Please select a customer.',
                      ),
                const SizedBox(height: 24),
                _buildDateField(),
                const SizedBox(height: 32),
                _buildGenerateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the date selection field.
  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Posting Date (<=)',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dateController,
          readOnly: true,
          onTap: () => _selectDate(context),
          decoration: const InputDecoration(
            hintText: 'Select a date',
            prefixIcon: Icon(Icons.calendar_today_outlined),
          ),
        ),
      ],
    );
  }

  /// Builds the "Generate PDF" button.
  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      onPressed: _isLoadingPdf ? null : _generatePdf,
      icon: _isLoadingPdf
          ? const SizedBox.shrink()
          : const Icon(Icons.picture_as_pdf_outlined),
      label: _isLoadingPdf
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            )
          : const Text('Generate PDF'),
    );
  }
}

/// A new screen to display the PDF from memory bytes.
class PdfViewerScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String customerName;

  const PdfViewerScreen(
      {super.key, required this.pdfBytes, required this.customerName});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isDownloading = false;

  Future<void> _downloadPdf() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // Request storage permission
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Storage permission is required to download files.')),
          );
        }
        return;
      }

      // Get the directory to save the file
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw 'Could not find a directory to save the file.';
      }

      final downloadsPath = Directory('${directory.path}/Download');
      if (!await downloadsPath.exists()) {
        await downloadsPath.create(recursive: true);
      }

      // Create a unique file name
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName =
          'ReceivableReport_${widget.customerName.replaceAll(' ', '_')}_$timestamp.pdf';
      final filePath = '${downloadsPath.path}/$fileName';

      // Write the PDF bytes to a file
      final file = File(filePath);
      await file.writeAsBytes(widget.pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to Downloads folder: $fileName'),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () {
                OpenFile.open(filePath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showApiErrorDialog(context, message: 'Failed to download PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Preview'),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                  )
                : const Icon(Icons.download),
            onPressed: _isDownloading ? null : _downloadPdf,
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: SfPdfViewer.memory(
        widget.pdfBytes,
      ),
    );
  }
}

