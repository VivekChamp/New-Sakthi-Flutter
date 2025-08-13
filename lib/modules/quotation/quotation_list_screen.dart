import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:sakthi_erp/utils/error_handler.dart';

class QuotationListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const QuotationListScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
  });

  @override
  State<QuotationListScreen> createState() => _QuotationListScreenState();
}

class _QuotationListScreenState extends State<QuotationListScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _quotations = [];
  List<Map<String, dynamic>> _filteredQuotations = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  int _page = 1;
  final int _pageSize = 10;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Map<String, dynamic>? _cachedData;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _listAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadQuotations();
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

  Future<void> _loadQuotations({bool isRefresh = false}) async {
    if (_isLoading || (!_hasMore && !isRefresh)) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    if (isRefresh) {
      _page = 1;
      _quotations.clear();
      _filteredQuotations.clear();
      _searchController.clear();
      _hasMore = true;
      _cachedData = null;
    }

    if (widget.serverUrl.isEmpty || widget.sid.isEmpty) {
      showApiErrorDialog(context, message: 'Invalid server URL or SID');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    try {
      final uri = Uri.parse(
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.qtn.get_quotation_details?page=$_page&limit=$_pageSize',
      );
      final response = await http.get(
        uri,
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> data = jsonResponse['message'] ?? [];
        setState(() {
          final newQuotations = data.cast<Map<String, dynamic>>();
          if (isRefresh) {
            _quotations = newQuotations;
          } else {
            _quotations.addAll(newQuotations);
          }
          _filteredQuotations = _quotations;
          _page++;
          _hasMore = data.length == _pageSize;
          _isLoading = false;
          _hasError = false;
        });
        _cachedData = {'data': _quotations, 'timestamp': DateTime.now()};
      } else if (response.statusCode == 401) {
        showApiErrorDialog(context,
            message: 'Session expired. Please log in again.');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (Route<dynamic> route) => false,
          );
        });
      } else {
        showApiErrorDialog(context,
            message:
                'Failed to load quotations: ${response.statusCode} - ${response.reasonPhrase}');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      showApiErrorDialog(context, message: 'Error loading quotations: $e');
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
        !_hasError) {
      _loadQuotations();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _filterQuotations);
  }

  void _filterQuotations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredQuotations = _quotations
          .where(
            (quote) =>
                (quote['name']?.toString().toLowerCase().contains(query) ??
                    false) ||
                (quote['quotation_to']
                        ?.toString()
                        .toLowerCase()
                        .contains(query) ??
                    false) ||
                (quote['transaction_date']
                        ?.toString()
                        .toLowerCase()
                        .contains(query) ??
                    false) ||
                (quote['customer_name']
                        ?.toString()
                        .toLowerCase()
                        .contains(query) ??
                    false),
          )
          .toList()
          .cast<Map<String, dynamic>>();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotations'),
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
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, date, customer',
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
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadQuotations(isRefresh: true),
                child: _isLoading && _quotations.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Failed to load quotations',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () =>
                                      _loadQuotations(isRefresh: true),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _filteredQuotations.isEmpty && !_hasError
                            ? Center(
                                child: Text(
                                  'No quotations found',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              )
                            : ListView.separated(
                                controller: _scrollController,
                                padding:
                                    EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                                itemCount: _filteredQuotations.length +
                                    (_hasMore ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: isSmallScreen ? 6 : 8),
                                itemBuilder: (context, index) {
                                  if (index == _filteredQuotations.length &&
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
                                  final quote = _filteredQuotations[index];
                                  return _buildAnimatedQuotationCard(
                                      quote, index);
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fadeAnimation,
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.pushNamed(
              context,
              '/addQuotation',
              arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
            );
            _loadQuotations(isRefresh: true);
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildAnimatedQuotationCard(Map<String, dynamic> quote, int index) {
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
        child: _buildQuotationCard(quote),
      ),
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> quote) {
    final isOrdered = quote['status'] == 'Ordered';
    final isPartiallyOrdered = quote['status'] == 'Partially Ordered';
    final isOpen = quote['status'] == 'Open';
    final isCancelled = quote['status'] == 'Cancelled';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOrdered
            ? const BorderSide(color: Color(0xFF4CAF50), width: 2)
            : isPartiallyOrdered
                ? const BorderSide(color: Color(0xFFFFA000), width: 2)
                : isOpen
                    ? const BorderSide(color: Color(0xFF2196F3), width: 2)
                    : isCancelled
                        ? const BorderSide(color: Color(0xFFF44336), width: 2)
                        : BorderSide.none,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOrdered
              ? const Color(0xFFE8F5E9)
              : isPartiallyOrdered
                  ? const Color(0xFFFFF3E0)
                  : isOpen
                      ? const Color(0xFFE3F2FD)
                      : isCancelled
                          ? const Color(0xFFFEF1F0)
                          : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          title: Text(
            quote['name']?.toString() ?? 'Unnamed Quotation',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer: ${quote['customer_name']?.toString() ?? 'N/A'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Date: ${quote['transaction_date']?.toString() ?? 'N/A'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'To: ${quote['quotation_to']?.toString() ?? 'N/A'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Status: ${quote['status']?.toString() ?? 'N/A'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isOrdered
                          ? const Color(0xFF4CAF50)
                          : isPartiallyOrdered
                              ? const Color(0xFFFFA000)
                              : isOpen
                                  ? const Color(0xFF2196F3)
                                  : isCancelled
                                      ? const Color(0xFFF44336)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onBackground,
                      fontWeight: isOrdered ||
                              isPartiallyOrdered ||
                              isOpen ||
                              isCancelled
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.primary,
          ),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/quotationDetail',
              arguments: {
                'quotation': quote,
                'serverUrl': widget.serverUrl,
                'sid': widget.sid,
              },
            );
          },
        ),
      ),
    );
  }
}
