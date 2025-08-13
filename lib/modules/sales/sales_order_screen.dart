import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sakthi_erp/utils/error_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'create_sales_order_screen.dart';

class SalesOrderScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final List<String> roles;

  const SalesOrderScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
    required this.roles,
  });

  @override
  State<SalesOrderScreen> createState() => _SalesOrderScreenState();
}

class _SalesOrderScreenState extends State<SalesOrderScreen> {
  List<dynamic> _salesOrders = [];
  List<dynamic> _filteredSalesOrders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMoreData = true;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _selectedOrder;
  DateTimeRange? _selectedDateRange;
  Map<String, int> _statusCounts = {};
  Map<String, int> _workflowStateCounts = {};
  String? _selectedStatusFilter;
  String? _selectedWorkflowStateFilter;
  final List<String> _allStatusValues = [
    'All',
    'Draft',
    'To Deliver and Bill',
    'To Deliver',
    'To Bill',
    'Completed',
    'Closed',
    'Cancelled',
  ];
  final List<String> _allWorkflowStateValues = [
    'All',
    'Draft',
    'Reviewed',
    'Pending',
    'Approved By RM',
    'Rejected By RM',
    'Approved By GM',
    'Rejected By GM',
    'Cancelled',
  ];
  Map<String, Map<String, dynamic>> _connectionCache = {};

  @override
  void initState() {
    super.initState();
    for (var state in _allStatusValues) {
      _statusCounts[state] = 0;
    }
    for (var state in _allWorkflowStateValues) {
      _workflowStateCounts[state] = 0;
    }
    _fetchSalesOrders();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_filterSalesOrders);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterSalesOrders);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchSalesOrders({bool loadMore = false}) async {
    if (_isLoadingMore || (loadMore && !_hasMoreData)) return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
    });

    final url =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_sales_orders_detailed?page=$_currentPage&page_size=$_pageSize';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['message'];
        if (data['status'] != 'success') {
          throw data['message'] ?? 'Failed to load sales orders';
        }

        final List<dynamic> newOrders = List.from(data['sales_orders'] ?? []);
        if (mounted) {
          setState(() {
            if (loadMore) {
              _salesOrders.addAll(newOrders);
            } else {
              _salesOrders = newOrders;
            }
            _updateStatusCounts();
            _filteredSalesOrders = List.from(_salesOrders);
            _currentPage++;
            _hasMoreData = data['has_more'] == true;
          });
        }
      } else {
        throw response.body;
      }
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _updateStatusCounts() {
    for (var state in _allStatusValues) {
      _statusCounts[state] = 0;
    }
    _statusCounts['All'] = _salesOrders.length;

    for (var state in _allWorkflowStateValues) {
      _workflowStateCounts[state] = 0;
    }
    _workflowStateCounts['All'] = _salesOrders.length;

    for (var order in _salesOrders) {
      final status = order['status'] ?? 'Unknown';
      _statusCounts.update(status, (value) => value + 1, ifAbsent: () => 1);
      final workflowState = order['workflow_state'] ?? 'Unknown';
      _workflowStateCounts.update(
        workflowState,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _fetchSalesOrders(loadMore: true);
    }
  }

  void _filterSalesOrders() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSalesOrders = _salesOrders.where((order) {
        final orderId = (order['name'] ?? '').toLowerCase();
        final customerName = (order['customer_name'] ?? '').toLowerCase();
        final status = (order['status'] ?? '').toLowerCase();
        final workflowState = (order['workflow_state'] ?? '').toLowerCase();
        final matchesSearchQuery =
            orderId.contains(query) || customerName.contains(query);

        bool matchesDateRange = true;
        if (_selectedDateRange != null) {
          final transactionDateStr = order['transaction_date'];
          if (transactionDateStr != null && transactionDateStr.isNotEmpty) {
            try {
              final transactionDate = DateTime.parse(transactionDateStr);
              matchesDateRange = transactionDate.isAfter(_selectedDateRange!
                      .start
                      .subtract(const Duration(days: 1))) &&
                  transactionDate.isBefore(
                      _selectedDateRange!.end.add(const Duration(days: 1)));
            } catch (e) {
              matchesDateRange = false;
            }
          } else {
            matchesDateRange = false;
          }
        }

        bool matchesStatusFilter = true;
        if (_selectedStatusFilter != null && _selectedStatusFilter != 'All') {
          matchesStatusFilter = status == _selectedStatusFilter!.toLowerCase();
        }

        bool matchesWorkflowStateFilter = true;
        if (_selectedWorkflowStateFilter != null &&
            _selectedWorkflowStateFilter != 'All') {
          matchesWorkflowStateFilter =
              workflowState == _selectedWorkflowStateFilter!.toLowerCase();
        }

        return matchesSearchQuery &&
            matchesDateRange &&
            matchesStatusFilter &&
            matchesWorkflowStateFilter;
      }).toList()
        ..sort((a, b) => (b['transaction_date'] ?? '9999-12-31')
            .compareTo(a['transaction_date'] ?? '9999-12-31'));
    });
  }

  Future<void> _refreshSalesOrders() async {
    setState(() {
      _currentPage = 0;
      _salesOrders.clear();
      _filteredSalesOrders.clear();
      _hasMoreData = true;
      _searchController.clear();
      _selectedDateRange = null;
      _selectedStatusFilter = null;
      _selectedWorkflowStateFilter = null;
      for (var state in _allStatusValues) {
        _statusCounts[state] = 0;
      }
      for (var state in _allWorkflowStateValues) {
        _workflowStateCounts[state] = 0;
      }
      _connectionCache.clear();
      _selectedOrder = null;
    });
    await _fetchSalesOrders();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _filterSalesOrders();
    }
  }

  void _navigateToCreateSalesOrder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSalesOrderScreen(
          serverUrl: widget.serverUrl,
          sid: widget.sid,
        ),
      ),
    );
    if (result == true) {
      _refreshSalesOrders();
    }
  }

  Future<Map<String, dynamic>> _fetchConnections(String salesOrderId) async {
    if (_connectionCache.containsKey(salesOrderId)) {
      return _connectionCache[salesOrderId]!;
    }

    final url =
        "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_sales_order_connections?sales_order_name=$salesOrderId";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _connectionCache[salesOrderId] = data['message'];
        return data['message'];
      } else {
        throw response.body;
      }
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
      return {'sales_invoices': [], 'delivery_notes': []};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedOrder != null ? 'Order Details' : 'Sales Orders'),
        leading: _selectedOrder != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedOrder = null;
                  });
                },
              )
            : null,
        actions: _selectedOrder != null
            ? [
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () {
                    final detailScreenState = context.findAncestorStateOfType<
                        _SalesOrderDetailScreenState>();
                    if (detailScreenState != null) {
                      detailScreenState._printSalesOrder();
                    }
                  },
                  tooltip: 'Print',
                ),
                IconButton(
                  icon: const Icon(Icons.save_alt),
                  onPressed: () {
                    final detailScreenState = context.findAncestorStateOfType<
                        _SalesOrderDetailScreenState>();
                    if (detailScreenState != null) {
                      detailScreenState._saveAsPdf();
                    }
                  },
                  tooltip: 'Save as PDF',
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshSalesOrders,
                ),
              ],
      ),
      body: _selectedOrder == null
          ? _buildSalesOrderList()
          : SalesOrderDetailScreen(
              orderId: _selectedOrder!['name'],
              serverUrl: widget.serverUrl,
              sid: widget.sid,
              roles: widget.roles,
              fetchConnectionsCallback: _fetchConnections,
            ),
      floatingActionButton: _selectedOrder == null
          ? FloatingActionButton(
              onPressed: _navigateToCreateSalesOrder,
              tooltip: 'Create Sales Order',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSalesOrderList() {
    return Column(
      children: [
        _buildSearchBar(),
        if (_selectedDateRange != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Date Range: ${DateFormat('MMM d, y').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, y').format(_selectedDateRange!.end)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedDateRange = null;
                      });
                      _filterSalesOrders();
                    },
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: DropdownButtonFormField<String>(
            value: _selectedStatusFilter ?? 'All',
            decoration: const InputDecoration(labelText: 'Filter by Status'),
            items: _allStatusValues.map((value) {
              final count = _statusCounts[value] ?? 0;
              return DropdownMenuItem<String>(
                  value: value, child: Text('$value ($count)'));
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedStatusFilter = newValue;
              });
              _filterSalesOrders();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: DropdownButtonFormField<String>(
            value: _selectedWorkflowStateFilter ?? 'All',
            decoration:
                const InputDecoration(labelText: 'Filter by Workflow State'),
            items: _allWorkflowStateValues.map((value) {
              final count = _workflowStateCounts[value] ?? 0;
              return DropdownMenuItem<String>(
                  value: value, child: Text('$value ($count)'));
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedWorkflowStateFilter = newValue;
              });
              _filterSalesOrders();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.date_range),
          onPressed: () => _selectDateRange(context),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredSalesOrders.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _refreshSalesOrders,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _filteredSalesOrders.length +
                            (_isLoadingMore ? 1 : 0),
                        itemBuilder: (ctx, index) {
                          if (index == _filteredSalesOrders.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _buildSalesOrderCard(
                              _filteredSalesOrders[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by Order ID or Customer',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No Sales Orders Found',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Tap the + button to create a new one.',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildSalesOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'N/A';
    final color = _getStatusColor(status);
    return Card(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedOrder = order;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order['name'] ?? 'No ID',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 18),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order['customer_name'] ?? 'No Customer Name',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: _buildInfoColumn(
                          'Date', _formatDate(order['transaction_date']))),
                  Expanded(
                      child: _buildInfoColumn('Amount',
                          order['grand_total']?.toStringAsFixed(2) ?? '0.00',
                          isAmount: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {bool isAmount = false}) {
    return Column(
      crossAxisAlignment:
          isAmount ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Draft':
        return Colors.grey;
      case 'To Deliver and Bill':
      case 'To Deliver':
      case 'To Bill':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      case 'Closed':
        return Colors.blueGrey;
      default:
        return Colors.black;
    }
  }
}

class SalesOrderDetailScreen extends StatefulWidget {
  final String orderId;
  final String serverUrl;
  final String sid;
  final List<String> roles;
  final Future<Map<String, dynamic>> Function(String) fetchConnectionsCallback;

  const SalesOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.serverUrl,
    required this.sid,
    required this.roles,
    required this.fetchConnectionsCallback,
  });

  @override
  _SalesOrderDetailScreenState createState() => _SalesOrderDetailScreenState();
}

class _SalesOrderDetailScreenState extends State<SalesOrderDetailScreen> {
  Map<String, dynamic> _orderDetails = {};
  Map<String, dynamic> _connections = {};
  Map<String, dynamic>? _taxDetails;
  bool _isLoading = true;
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<Map<String, dynamic>> _sections = [
    {'title': 'Order Details', 'icon': Icons.description},
    {'title': 'Customer Details', 'icon': Icons.person},
    {'title': 'Items', 'icon': Icons.inventory},
    {'title': 'Sales Taxes', 'icon': Icons.receipt},
    {'title': 'Financials', 'icon': Icons.account_balance_wallet},
    {'title': 'Sales Team', 'icon': Icons.group},
    {'title': 'Payment', 'icon': Icons.schedule},
    {'title': 'Connections', 'icon': Icons.link},
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchOrderDetails();
    _fetchConnections();
    _fetchTaxDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrderDetails() async {
    setState(() => _isLoading = true);
    final url =
        "${widget.serverUrl}/api/resource/Sales Order/${widget.orderId}";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _orderDetails = data['data'] ?? {};
          });
        }
      } else {
        throw response.body;
      }
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchConnections() async {
    try {
      final data = await widget.fetchConnectionsCallback(widget.orderId);
      if (mounted) {
        setState(() {
          _connections = data;
        });
      }
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
    }
  }

  Future<void> _fetchTaxDetails() async {
    final url =
        "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_sales_order_with_taxes?sales_order_name=${widget.orderId}";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _taxDetails = data['message']['data'];
          });
        }
      } else {
        throw response.body;
      }
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String removeHtmlTags(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return 'N/A';
    final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return htmlString.replaceAll(exp, ' ').trim();
  }

  String numberToWords(int number) {
    if (number == 0) return 'Zero';
    if (number < 0) return 'Minus ${numberToWords(number.abs())}';

    String words = '';
    const units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
    ];
    const teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if ((number ~/ 10000000) > 0) {
      words += '${numberToWords(number ~/ 10000000)} Crore ';
      number %= 10000000;
    }
    if ((number ~/ 100000) > 0) {
      words += '${numberToWords(number ~/ 100000)} Lakh ';
      number %= 100000;
    }
    if ((number ~/ 1000) > 0) {
      words += '${numberToWords(number ~/ 1000)} Thousand ';
      number %= 1000;
    }
    if ((number ~/ 100) > 0) {
      words += '${numberToWords(number ~/ 100)} Hundred ';
      number %= 100;
    }
    if (number > 0) {
      if (words.isNotEmpty) words += 'and ';
      if (number < 10) {
        words += units[number];
      } else if (number < 20) {
        words += teens[number - 10];
      } else {
        words += tens[number ~/ 10];
        if (number % 10 > 0) words += ' ${units[number % 10]}';
      }
    }
    return words.trim();
  }

  Future<void> _printSalesOrder() async {
    final pdf = await _generatePdf(_orderDetails);
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _saveAsPdf() async {
    final pdf = await _generatePdf(_orderDetails);
    final bytes = await pdf.save();
    await Printing.sharePdf(
        bytes: bytes, filename: 'sales_order_${_orderDetails['name']}.pdf');
  }

  Future<pw.Document> _generatePdf(Map<String, dynamic> orderDetails) async {
    final pdf = pw.Document();
    final items = orderDetails['items'] as List<dynamic>? ?? [];
    final totalQuantity =
        items.fold(0, (sum, item) => sum + (item['qty'] as num? ?? 0).toInt());
    final totalAmount = items.fold(
        0.0, (sum, item) => sum + (item['amount'] as num? ?? 0).toDouble());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 6.0),
          child: pw.Text(
            'SAKTHI STEEL INDUSTRIES LTD, Madurai',
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ),
        build: (pw.Context context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SAKTHI STEEL INDUSTRIES LTD',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'SALES ORDER',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        orderDetails['name'] ?? '',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 8),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Customer Name:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(orderDetails['customer'] ?? 'N/A'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Date:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          _formatDate(orderDetails['transaction_date']) ??
                              'N/A',
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'PO No:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(orderDetails['po_no'] ?? 'N/A'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'PO Date:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          _formatDate(orderDetails['po_date']) ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Address:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          removeHtmlTags(orderDetails['address_display']) ??
                              'N/A',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          'Delivery Date:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Text(
                          _formatDate(orderDetails['delivery_date']) ?? 'N/A',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(60),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _pdfTableHeader('Sr'),
                      _pdfTableHeader('Item'),
                      _pdfTableHeader('Quantity'),
                      _pdfTableHeader('Rate'),
                      _pdfTableHeader('Amount'),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final item = entry.value;
                    return pw.TableRow(
                      children: [
                        _pdfTableCell(index.toString()),
                        _pdfTableCell(
                            item['item_code'] ?? item['item_name'] ?? ''),
                        _pdfTableCell(item['qty'].toString()),
                        _pdfTableCell('INR ${item['rate'] ?? 0}'),
                        _pdfTableCell('INR ${item['amount'] ?? 0}'),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: 200),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Quantity: $totalQuantity',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Net Total: INR ${orderDetails['net_total']?.toStringAsFixed(2) ?? '0.00'}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Total Taxes: INR ${orderDetails['total_taxes_and_charges']?.toStringAsFixed(2) ?? '0.00'}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Grand Total: INR ${orderDetails['grand_total']?.toStringAsFixed(2) ?? '0.00'}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'In Words: INR ${numberToWords(totalAmount.toInt())} only.',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
    return pdf;
  }

  pw.Widget _pdfTableHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  Future<void> _handleWorkflowAction(String action, String nextState) async {
    final url =
        "${widget.serverUrl}/api/resource/Sales Order/${widget.orderId}";
    final payload = <String, dynamic>{'workflow_state': nextState};
    if (nextState == 'Approved By GM') {
      payload['status'] = 'To Deliver and Bill';
      if (_orderDetails['docstatus'] == 0) {
        payload['docstatus'] = 1;
      }
    }
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json'
        },
        body: json.encode(payload),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$action successful'),
              backgroundColor: Colors.green),
        );
        _fetchOrderDetails();
      } else {
        throw response.body;
      }
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
    }
  }

  List<Map<String, String>> _getWorkflowButtons() {
    final currentState = _orderDetails['workflow_state'] ?? 'Draft';
    final userRoles = widget.roles;
    final List<Map<String, String>> buttons = [];

    if (currentState == 'Draft' &&
        (userRoles.contains('Sakthi Sales Person') ||
            userRoles.contains('Sakthi RM'))) {
      buttons.add({'action': 'Review', 'next_state': 'Pending'});
    }
    if (currentState == 'Draft' && userRoles.contains('Sakthi GM')) {
      buttons.add({'action': 'Approve', 'next_state': 'Approved By GM'});
    }
    if (currentState == 'Reviewed' && userRoles.contains('Sales User')) {
      buttons.add({'action': 'Submit', 'next_state': 'Pending'});
    }
    if (currentState == 'Pending' && userRoles.contains('Sakthi RM')) {
      buttons.add({'action': 'Approve', 'next_state': 'Approved By RM'});
      buttons.add({'action': 'Reject', 'next_state': 'Rejected By RM'});
    }
    if (currentState == 'Pending' && userRoles.contains('Sakthi GM')) {
      buttons.add({'action': 'Approve', 'next_state': 'Approved By GM'});
      buttons.add({'action': 'Reject', 'next_state': 'Rejected By GM'});
    }
    if (currentState == 'Approved By RM' && userRoles.contains('Sakthi GM')) {
      buttons.add({'action': 'Approve', 'next_state': 'Approved By GM'});
      buttons.add({'action': 'Reject', 'next_state': 'Rejected By GM'});
    }
    if (currentState == 'To Deliver and Bill' ||
        currentState == 'To Deliver' ||
        currentState == 'To Bill') {
      buttons.add({'action': 'Mark as Completed', 'next_state': 'Completed'});
    }
    if (currentState == 'Approved By GM' ||
        currentState == 'To Deliver and Bill' ||
        currentState == 'To Deliver' ||
        currentState == 'To Bill') {
      buttons.add({'action': 'Cancel', 'next_state': 'Cancelled'});
    }
    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    final workflowButtons = _getWorkflowButtons();
    return Column(
      children: [
        _buildSectionNavBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _orderDetails.isEmpty
                  ? const Center(child: Text('Sales order not found'))
                  : PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      children: [
                        _buildSectionCard(_buildOrderDetailsSection()),
                        _buildSectionCard(_buildCustomerDetailsSection()),
                        _buildSectionCard(_buildItemsSection()),
                        _buildSectionCard(_buildSalesTaxesSection()),
                        _buildSectionCard(_buildFinancialSummarySection()),
                        _buildSectionCard(_buildSalesTeamSection()),
                        _buildSectionCard(_buildPaymentScheduleSection()),
                        _buildSectionCard(_buildConnectionsSection()),
                      ],
                    ),
        ),
        if (workflowButtons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ButtonBar(
              alignment: MainAxisAlignment.center,
              children: workflowButtons.map((button) {
                return ElevatedButton(
                  onPressed: () => _handleWorkflowAction(
                      button['action']!, button['next_state']!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: button['action']!
                                .toLowerCase()
                                .contains('reject') ||
                            button['action']!.toLowerCase().contains('cancel')
                        ? Colors.redAccent
                        : Colors.green,
                  ),
                  child: Text(button['action']!),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionNavBar() {
    return Container(
      height: 70,
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _sections.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedIndex == index;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Icon(
                    _sections[index]['icon'],
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sections[index]['title'],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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

  Widget _buildInfoRow(String label, String? value, {bool isBold = false}) {
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
                value ?? 'N/A',
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onBackground,
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

  Widget _buildOrderDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Order Details'),
        const SizedBox(height: 12),
        _buildInfoRow('Order ID', _orderDetails['name'], isBold: true),
        _buildInfoRow('Title', _orderDetails['customer']),
        _buildInfoRow('Naming Series', _orderDetails['naming_series']),
        _buildInfoRow('Order Type', _orderDetails['order_type']),
        _buildInfoRow(
            'Transaction Date', _formatDate(_orderDetails['transaction_date'])),
        _buildInfoRow(
            'Delivery Date', _formatDate(_orderDetails['delivery_date'])),
        _buildInfoRow('PO Number', _orderDetails['po_no']),
        _buildInfoRow('PO Date', _formatDate(_orderDetails['po_date'])),
        _buildInfoRow('Company', _orderDetails['company']),
        _buildInfoRow('Status', _orderDetails['status']),
        _buildInfoRow('Delivery Status', _orderDetails['delivery_status']),
        _buildInfoRow('Billing Status', _orderDetails['billing_status']),
        _buildInfoRow('Letter Head', _orderDetails['letter_head']),
        _buildInfoRow('Owner', _orderDetails['owner']),
        _buildInfoRow('Creation', _formatDate(_orderDetails['creation'])),
        _buildInfoRow('Modified', _formatDate(_orderDetails['modified'])),
        _buildInfoRow('Modified By', _orderDetails['modified_by']),
        _buildInfoRow('Workflow State', _orderDetails['workflow_state']),
      ],
    );
  }

  Widget _buildCustomerDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Customer Details'),
        const SizedBox(height: 12),
        _buildInfoRow('Customer', _orderDetails['customer']),
        _buildInfoRow('Customer Name', _orderDetails['customer_name'],
            isBold: true),
        _buildInfoRow('Address Display',
            removeHtmlTags(_orderDetails['address_display'])),
        _buildInfoRow('Tax Category', _orderDetails['tax_category'] ?? 'N/A'),
      ],
    );
  }

  Widget _buildItemsSection() {
    final items = _orderDetails['items'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Items'),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Text('No items available.')
        else
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSubSectionTitle('Item ${index + 1}'),
                      _buildInfoRow('Item Code', item['item_code'] ?? 'N/A'),
                      _buildInfoRow('Item Name', item['item_name'] ?? 'N/A',
                          isBold: true),
                      _buildInfoRow('Quantity', item['qty']?.toString() ?? '0',
                          isBold: true),
                      _buildInfoRow('Rate',
                          '${item['rate'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}',
                          isBold: true),
                      _buildInfoRow('Amount',
                          '${item['amount'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                      _buildInfoRow('Transaction Date',
                          _formatDate(item['transaction_date'])),
                      _buildInfoRow('Total',
                          '${item['amount'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildSalesTaxesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Sales Taxes and Charges'),
        const SizedBox(height: 12),
        if (_taxDetails == null)
          const Center(
              child: CircularProgressIndicator(color: Color(0xFF005BAC)))
        else if (_taxDetails!['status'] == 'error' ||
            (_taxDetails!['taxes'] as List).isEmpty)
          const Text('No tax details available')
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                  'Sales Order', _taxDetails!['sales_order'] ?? 'N/A'),
              _buildInfoRow('Customer', _taxDetails!['customer'] ?? 'N/A'),
              _buildInfoRow('Company', _taxDetails!['company'] ?? 'N/A'),
              _buildInfoRow(
                  'Posting Date', _formatDate(_taxDetails!['posting_date'])),
              _buildInfoRow(
                  'Tax Template', _taxDetails!['tax_template'] ?? 'N/A'),
              _buildInfoRow('Total Taxes and Charges',
                  '${_taxDetails!['total_taxes_and_charges'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
              _buildInfoRow('Grand Total',
                  '${_taxDetails!['grand_total'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
              const SizedBox(height: 8),
              ...(_taxDetails!['taxes'] as List<dynamic>)
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubSectionTitle('Tax ${index + 1}'),
                          _buildInfoRow(
                              'Charge Type', tax['charge_type'] ?? 'N/A'),
                          _buildInfoRow(
                              'Account Head', tax['account_head'] ?? 'N/A',
                              isBold: true),
                          _buildInfoRow(
                              'Description', tax['description'] ?? 'N/A'),
                          _buildInfoRow('Rate', '${tax['rate'] ?? 0}%',
                              isBold: true),
                          _buildInfoRow('Tax Amount',
                              '${tax['tax_amount'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                          _buildInfoRow('Total',
                              '${tax['total'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                          _buildInfoRow(
                              'Cost Center', tax['cost_center'] ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
      ],
    );
  }

  Widget _buildFinancialSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Financial Summary'),
        const SizedBox(height: 12),
        _buildInfoRow('Currency', _orderDetails['currency']),
        _buildInfoRow('Total Quantity', _orderDetails['total_qty']?.toString()),
        _buildInfoRow('Net Total',
            '${_orderDetails['net_total'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
        _buildInfoRow('Total Taxes and Charges',
            '${_orderDetails['total_taxes_and_charges'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
        _buildInfoRow('Base Grand Total',
            '${_orderDetails['base_grand_total'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
        _buildInfoRow('Base Rounding Adjustment',
            '${_orderDetails['base_rounding_adjustment'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
        _buildInfoRow('Rounded Total',
            '${_orderDetails['rounded_total'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
        _buildInfoRow('In Words', _orderDetails['in_words']),
        _buildInfoRow('Advance Paid',
            '${_orderDetails['advance_paid'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
      ],
    );
  }

  Widget _buildSalesTeamSection() {
    final salesTeam = _orderDetails['sales_team'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Sales Team'),
        const SizedBox(height: 12),
        if (salesTeam.isEmpty)
          const Text('No sales team assigned.')
        else
          ...salesTeam.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSubSectionTitle('Sales Person ${index + 1}'),
                      _buildInfoRow('Sales Person', member['sales_person'],
                          isBold: true),
                      _buildInfoRow('Allocated Percentage',
                          member['allocated_percentage']?.toString()),
                      _buildInfoRow('Allocated Amount',
                          '${member['allocated_amount'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                      _buildInfoRow('Incentives',
                          '${member['incentives'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildPaymentScheduleSection() {
    final paymentSchedule =
        _orderDetails['payment_schedule'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Payment Schedule'),
        const SizedBox(height: 12),
        if (paymentSchedule.isEmpty)
          const Text('No payment schedule available.')
        else
          ...paymentSchedule.asMap().entries.map((entry) {
            final index = entry.key;
            final schedule = entry.value as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSubSectionTitle('Payment ${index + 1}'),
                      _buildInfoRow(
                          'Due Date', _formatDate(schedule['due_date'])),
                      _buildInfoRow('Invoice Portion',
                          schedule['invoice_portion']?.toString()),
                      _buildInfoRow('Discount',
                          '${schedule['discount'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                      _buildInfoRow('Payment Amount',
                          '${schedule['payment_amount'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                      _buildInfoRow('Outstanding',
                          '${schedule['outstanding'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                      _buildInfoRow('Paid Amount',
                          '${schedule['paid_amount'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                      _buildInfoRow('Discounted Amount',
                          '${schedule['discounted_amount'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                      _buildInfoRow('Base Payment Amount',
                          '${schedule['base_payment_amount'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                      _buildInfoRow('Base Outstanding',
                          '${schedule['base_outstanding'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                      _buildInfoRow('Base Paid Amount',
                          '${schedule['base_paid_amount'] ?? 0} ${_orderDetails['currency'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildConnectionsSection() {
    final deliveryNotes =
        _connections['delivery_notes'] as List<dynamic>? ?? [];
    final salesInvoices =
        _connections['sales_invoices'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Connections'),
        const SizedBox(height: 12),
        _buildInfoRow('Delivery Notes', deliveryNotes.length.toString()),
        const SizedBox(height: 8),
        ...deliveryNotes.map(
            (note) => _buildConnectionItem(note['name'] ?? 'N/A', onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/salesInvoiceDetail',
                    arguments: {
                      'invoiceId': note['name'],
                      'serverUrl': widget.serverUrl,
                      'sid': widget.sid,
                    },
                  );
                })),
        const SizedBox(height: 16),
        _buildInfoRow('Sales Invoices', salesInvoices.length.toString()),
        const SizedBox(height: 8),
        ...salesInvoices.map((invoice) =>
            _buildConnectionItem(invoice['name'] ?? 'N/A', onTap: () {
              Navigator.pushNamed(
                context,
                '/salesInvoiceDetail',
                arguments: {
                  'invoiceId': invoice['name'],
                  'serverUrl': widget.serverUrl,
                  'sid': widget.sid,
                },
              );
            })),
      ],
    );
  }

  Widget _buildConnectionRow(String label, int count, Color badgeColor) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label ($count)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: badgeColor == const Color(0xFF757575)
                  ? Colors.white
                  : Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionItem(String name, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.arrow_right, color: Color(0xFF005BAC), size: 16),
            const SizedBox(width: 4),
            Text(
              name,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: const Color(0xFF005BAC)),
            ),
          ],
        ),
      ),
    );
  }
}
