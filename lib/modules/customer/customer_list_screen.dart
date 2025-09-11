import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sakthi_erp/utils/error_handler.dart';

class CustomerListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;

  const CustomerListScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  });

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<dynamic> _customers = [];
  List<dynamic> _filteredCustomers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCustomers);
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches the list of customers from the server.
  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
    });

    final url =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_customers';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message']?['status'] == 'success') {
          setState(() {
            _customers = List.from(data['message']['customers'] ?? []);
            _customers.sort(
              (a, b) => (a['customer_name'] ?? '').toLowerCase().compareTo(
                (b['customer_name'] ?? '').toLowerCase(),
              ),
            );
            _filteredCustomers = List.from(_customers);
          });
        } else {
          throw data['message']?['message'] ?? 'Failed to load customers';
        }
      } else {
        throw response.body;
      }
    } catch (error) {
      showApiErrorDialog(context, message: error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Filters the customer list based on the search query.
  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _customers.where((c) {
        final customerName = (c['customer_name'] ?? '').toLowerCase();
        final customerId = (c['name'] ?? '').toLowerCase();
        return customerName.contains(query) || customerId.contains(query);
      }).toList();
    });
  }

  /// Navigates to the screen to add a new customer.
  void _navigateToAddCustomer() async {
    final result = await Navigator.pushNamed(
      context,
      '/addNewCustomer',
      arguments: {
        'serverUrl': widget.serverUrl,
        'sid': widget.sid,
        'email': widget.email,
      },
    );

    // If a customer was added successfully, refresh the list.
    if (result == true) {
      _fetchCustomers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _fetchCustomers,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (ctx, index) {
                        final customer = _filteredCustomers[index];
                        return _buildCustomerCard(customer);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddCustomer,
        tooltip: 'Add New Customer',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Builds the search bar widget.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by Customer Name or ID',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
        ),
      ),
    );
  }

  /// Builds the widget to display when no customers are found.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Customers Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add a new customer.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Builds a card for a single customer in the list.
  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            (customer['customer_name'] ?? 'N')[0].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        title: Text(
          customer['customer_name'] ?? 'No Name',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(customer['custom_city'] ?? 'No city available'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/customerDetail',
            arguments: {
              'customer': customer,
              'serverUrl': widget.serverUrl,
              'sid': widget.sid,
            },
          );
        },
      ),
    );
  }
}
