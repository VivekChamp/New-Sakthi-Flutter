import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sakthi_erp/shared/widgets/custom_search_dropdown.dart';
import 'package:sakthi_erp/utils/error_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

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
      showApiErrorDialog(context, message: e.toString());
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

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String? pdfUrl = responseData['message']?['pdf_url'];

        if (pdfUrl != null && pdfUrl.isNotEmpty) {
          // Parse the server URL from login to get the correct scheme, host, and port.
          final serverUri = Uri.parse(widget.serverUrl);
          
          // Parse the pdfUrl from the response. This could be a relative path or a full URL.
          final responsePdfUri = Uri.parse(pdfUrl);

          // Reconstruct the final PDF URI.
          // This ensures that we use the scheme, host, and port from the login URL,
          // and the path from the URL provided in the API response.
          // This corrects any discrepancies in the port number or domain returned by the API.
          final finalPdfUri = serverUri.replace(
            path: responsePdfUri.path,
            queryParameters: responsePdfUri.queryParameters,
          );

          if (await canLaunchUrl(finalPdfUri)) {
            await launchUrl(finalPdfUri, mode: LaunchMode.externalApplication);
          } else {
            throw 'Could not launch PDF URL: $finalPdfUri';
          }
        } else {
          throw 'PDF URL not found in the server response.';
        }
      } else {
        throw response.body;
      }
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
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

