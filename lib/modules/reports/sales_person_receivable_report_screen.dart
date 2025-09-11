import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sakthi_erp/utils/error_handler.dart';
import 'dart:async';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class SalesPersonReceivableReportScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  const SalesPersonReceivableReportScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
  });
  @override
  State<SalesPersonReceivableReportScreen> createState() =>
      _SalesPersonReceivableReportScreenState();
}

class _SalesPersonReceivableReportScreenState
    extends State<SalesPersonReceivableReportScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  int _page = 1;
  final int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Map<String, dynamic>? _cachedData;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _listAnimationController;
  late Animation<double> _fadeAnimation;
  final Map<String, bool> _isLoadingPdf = {};
  List<String> _companies = [];
  String? _selectedCompany;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _listAnimationController,
      curve: Curves.easeInOut,
    );
    _listAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    try {
      final uri = Uri.parse(
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_company_list');
      final response = await http.get(
        uri,
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> companies = jsonResponse['message']['data'] ?? [];
        setState(() {
          _companies = companies.map((c) => c['name'].toString()).toList();
          _selectedCompany = _companies.contains('SAKTHI STEEL INDUSTRIES LTD')
              ? 'SAKTHI STEEL INDUSTRIES LTD'
              : _companies.isNotEmpty
                  ? _companies[0]
                  : null;
        });
        if (_selectedCompany != null) _loadCustomers();
      }
    } catch (e) {
      if (mounted) {
        showApiErrorDialog(context, message: 'Error loading companies: $e');
      }
    }
  }

  Future<void> _loadCustomers({bool isRefresh = false}) async {
    if (_isLoading || (!_hasMore && !isRefresh)) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    if (isRefresh) {
      _page = 1;
      _customers.clear();
      _filteredCustomers.clear();
      _searchController.clear();
      _hasMore = true;
      _cachedData = null;
    }
    if (widget.serverUrl.isEmpty || widget.sid.isEmpty) {
      if (mounted) {
        showApiErrorDialog(context, message: 'Invalid server URL or SID');
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }
    try {
      String url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_customers_by_company?page=$_page&limit=$_pageSize';
      if (_selectedCompany != null) {
        url += '&company=$_selectedCompany';
      }
      final uri = Uri.parse(url);
      final response = await http.get(
        uri,
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final Map<String, dynamic> data = jsonResponse['message'] ?? {};
        setState(() {
          final newCustomers = data.entries
              .map((entry) => {
                    'name': entry.key,
                    'customer_name':
                        entry.value['customer_name'] ?? 'Unknown Customer',
                    'unpaid_data': entry.value['unpaid_data'] ?? {},
                  })
              .toList()
              .cast<Map<String, dynamic>>();
          if (isRefresh) {
            _customers = newCustomers;
          } else {
            _customers.addAll(newCustomers);
          }
          _filteredCustomers = _customers;
          _page++;
          _hasMore = newCustomers.length == _pageSize;
          _isLoading = false;
          _hasError = false;
        });
        _cachedData = {'data': _customers, 'timestamp': DateTime.now()};
      } else if (response.statusCode == 401) {
        if (mounted) {
          showApiErrorDialog(context,
              message: 'Session expired. Please log in again.');
        }
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (Route<dynamic> route) => false,
            );
          });
        }
      } else {
        if (mounted) {
          showApiErrorDialog(context,
              message:
                  'Failed to load customers: ${response.statusCode} - ${response.reasonPhrase}');
        }
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        showApiErrorDialog(context, message: 'Error loading customers: $e');
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        !_hasError &&
        _hasMore) {
      _loadCustomers();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _filterCustomers);
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _customers
          .where((customer) => customer['customer_name']
              .toString()
              .toLowerCase()
              .contains(query))
          .toList()
          .cast<Map<String, dynamic>>();
    });
  }

  Future<void> _generatePdf(Map<String, dynamic> customer) async {
    final String customerId = customer['name'];
    if (_isLoadingPdf[customerId] == true) return;
    setState(() => _isLoadingPdf[customerId] = true);
    final String customerName = customer['customer_name'];
    final String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String apiUrl =
        '${widget.serverUrl}/api/method/sakthi_tmt.api.receivable_report.generate_receivable_pdf';
    final uri = Uri.parse(apiUrl).replace(queryParameters: {
      'customer': customerId,
      'customer_name': customerName,
      'date': date,
    });
    try {
      final response = await http.get(uri, headers: {
        'Cookie': 'sid=${widget.sid}'
      }).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String? pdfUrl = responseData['message']?['pdf_url']?.toString();

        if (pdfUrl != null && pdfUrl.isNotEmpty) {
          final serverUri = Uri.parse(widget.serverUrl);
          final responsePdfUri = Uri.parse(pdfUrl);

          final finalPdfUri = serverUri.replace(
            path: responsePdfUri.path,
            queryParameters: responsePdfUri.queryParameters,
          );

          // Download the PDF content from the final URL
          final pdfResponse = await http.get(
            finalPdfUri,
            headers: {'Cookie': 'sid=${widget.sid}'},
          );

          if (!mounted) return;

          if (pdfResponse.statusCode == 200) {
            final Uint8List pdfBytes = pdfResponse.bodyBytes;
            // Navigate to the PDF viewer screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(pdfBytes: pdfBytes, customerName: customerName),
              ),
            );
          } else {
            throw 'Failed to download PDF: ${pdfResponse.statusCode}';
          }
        } else {
          throw 'PDF URL not found in the server response.';
        }
      } else {
        if (mounted) {
          showApiErrorDialog(context,
              message: 'Failed to generate PDF: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        showApiErrorDialog(context, message: 'Error generating PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingPdf[customerId] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Person Receivable Report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedCompany,
                        hint: const Text('All Companies'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Companies'),
                          ),
                          ..._companies.map((company) => DropdownMenuItem(
                                value: company,
                                child: Text(
                                  company,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              )),
                        ],
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCompany = newValue;
                            _loadCustomers(isRefresh: true);
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by customer name',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadCustomers(isRefresh: true),
                child: _isLoading && _customers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading customers...',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      )
                    : _hasError
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Failed to load customers',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () =>
                                      _loadCustomers(isRefresh: true),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _filteredCustomers.isEmpty
                            ? Center(
                                child: Text(
                                  _searchController.text.isEmpty
                                      ? 'No customers found'
                                      : 'No customers match your search',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              )
                            : ListView.separated(
                                controller: _scrollController,
                                padding:
                                    EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                                itemCount: _filteredCustomers.length +
                                    (_hasMore ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: isSmallScreen ? 10 : 16),
                                itemBuilder: (context, index) {
                                  if (index == _filteredCustomers.length &&
                                      _hasMore) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: CircularProgressIndicator(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    );
                                  }
                                  final customer = _filteredCustomers[index];
                                  return _buildAnimatedCustomerCard(
                                      customer, index);
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCustomerCard(Map<String, dynamic> customer, int index) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _listAnimationController,
          curve: Interval(index * 0.1, 1.0, curve: Curves.easeInOut),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(
          CurvedAnimation(
            parent: _listAnimationController,
            curve: Interval(index * 0.1, 1.0, curve: Curves.easeInOut),
          ),
        ),
        child: _buildCustomerCard(customer),
      ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final isLoadingPdf = _isLoadingPdf[customer['name']] ?? false;
    final unpaidData = customer['unpaid_data'] as Map<String, dynamic>? ?? {};
    final totalUnpaid =
        unpaidData.values.fold(0.0, (sum, amount) => sum + (amount as num));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  customer['customer_name'],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isLoadingPdf ? null : () => _generatePdf(customer),
                icon: isLoadingPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf, size: 18),
                label: Text(isLoadingPdf ? 'Wait...' : 'PDF'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Unpaid: ₹${totalUnpaid.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: totalUnpaid > 0
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onBackground,
                ),
          ),
        ],
      ),
    );
  }
}

/// A new screen to display the PDF from memory bytes.
class PdfViewerScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String customerName;

  const PdfViewerScreen({super.key, required this.pdfBytes, required this.customerName});

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
        if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to download files.')),
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
      final fileName = 'ReceivableReport_${widget.customerName.replaceAll(' ', '_')}_$timestamp.pdf';
      final filePath = '${downloadsPath.path}/$fileName';

      // Write the PDF bytes to a file
      final file = File(filePath);
      await file.writeAsBytes(widget.pdfBytes);
      
      if(mounted) {
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
      if(mounted) {
      showApiErrorDialog(context, message: 'Failed to download PDF: $e');
      }
    } finally {
      if(mounted) {
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
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
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

