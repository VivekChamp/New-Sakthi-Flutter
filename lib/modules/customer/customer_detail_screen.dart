import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sakthi_erp/utils/error_handler.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  final String serverUrl;
  final String sid;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
    required this.serverUrl,
    required this.sid,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Map<String, dynamic> _customerDetails = {};
  bool _isLoading = true;
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<Map<String, dynamic>> _sections = [
    {'title': 'Basic Info', 'icon': Icons.person_outline},
    {'title': 'Address', 'icon': Icons.location_on_outlined},
    {'title': 'Sales Team', 'icon': Icons.group_outlined},
    {'title': 'Bank Details', 'icon': Icons.account_balance_outlined},
    {'title': 'Contact', 'icon': Icons.contact_phone_outlined},
    {'title': 'Credit Limits', 'icon': Icons.account_balance_wallet_outlined},
    {'title': 'Attachments', 'icon': Icons.attachment_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchCustomerDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomerDetails() async {
    setState(() {
      _isLoading = true;
    });

    final customerName = widget.customer['name'] ?? '';
    if (customerName.isEmpty) {
      showErrorDialog(context, 'Error', 'Invalid customer ID.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final url = "${widget.serverUrl}/api/resource/Customer/$customerName";
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
        setState(() {
          _customerDetails = data['data'] ?? {};
          _isLoading = false;
        });
      } else {
        throw response.body;
      }
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _removeHtmlTags(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return 'N/A';
    return htmlString.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
          const SizedBox(height: 16),
          const Text(
            'Failed to load customer details.',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchCustomerDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(24.0), child: child),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value, {bool isBold = false}) {
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

  Widget _buildBasicInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Customer Name', _customerDetails['customer_name'],
            isBold: true),
        _buildInfoRow('Customer Type', _customerDetails['customer_type']),
        _buildInfoRow('Customer Group', _customerDetails['customer_group']),
        _buildInfoRow('Target', _customerDetails['custom_target']?.toString()),
        _buildInfoRow('PHP ID', _customerDetails['custom_php_id']),
        _buildInfoRow('MSME Category', _customerDetails['custom_msme_cat']),
        _buildInfoRow('Annual Turnover',
            _customerDetails['custom_annual_turnover']?.toString()),
        _buildInfoRow('Payment Terms', _customerDetails['payment_terms']),
        _buildInfoRow('GSTIN', _customerDetails['gstin']),
        _buildInfoRow('PAN', _customerDetails['pan']),
        _buildInfoRow('GST Category', _customerDetails['custom_gst_category']),
        _buildInfoRow('LHS ID', _customerDetails['custom_lhs_id']),
        _buildInfoRow('Is Internal Customer',
            _customerDetails['is_internal_customer'] == 1 ? 'Yes' : 'No'),
        _buildInfoRow('Owner', _customerDetails['owner']),
        _buildInfoRow('Account Manager', _customerDetails['account_manager']),
      ],
    );
  }

  Widget _buildAddressInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Address Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Primary Address',
            _removeHtmlTags(_customerDetails['primary_address'])),
        _buildInfoRow('Customer Primary Address',
            _customerDetails['customer_primary_address']),
      ],
    );
  }

  Widget _buildSalesTeamSection() {
    final salesTeam = _customerDetails['sales_team'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sales Team',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        if (salesTeam.isEmpty)
          const Text('No sales team assigned.')
        else
          ...salesTeam.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value as Map<String, dynamic>;
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubSectionTitle('Sales Person ${index + 1}'),
                    _buildInfoRow('Sales Person', member['sales_person']),
                    _buildInfoRow('Allocated Percentage',
                        member['allocated_percentage']?.toString()),
                    _buildInfoRow('Allocated Amount',
                        member['allocated_amount']?.toString()),
                    _buildInfoRow(
                        'Incentives', member['incentives']?.toString()),
                    _buildInfoRow('Parent Sales Person',
                        member['custom_parent_sales_person']),
                    _buildInfoRow('Regional Sales Person',
                        member['custom_regional_sales_person']),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildBankDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bank Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Account Number', _customerDetails['custom_account_no']),
        _buildInfoRow('Bank Name', _customerDetails['custom_bank_name']),
        _buildInfoRow('Branch', _customerDetails['custom_branch']),
        _buildInfoRow('IFSC Code', _customerDetails['custom_ifsc_code']),
        _buildInfoRow('Security Cheque Number',
            _customerDetails['custom_security_cheque_no']),
      ],
    );
  }

  Widget _buildContactInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Phone Number', _customerDetails['phone']),
        _buildInfoRow('Email', _customerDetails['email_id']),
        _buildInfoRow(
            'Contact Person', _customerDetails['contact_person_name']),
        _buildInfoRow(
            'Customer Owner', _customerDetails['custom_customer_owner']),
      ],
    );
  }

  Widget _buildCreditLimitsSection() {
    final creditLimits =
        _customerDetails['credit_limits'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Credit Limits',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        if (creditLimits.isEmpty)
          const Text('No credit limits assigned.')
        else
          ...creditLimits.asMap().entries.map((entry) {
            final index = entry.key;
            final limit = entry.value as Map<String, dynamic>;
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubSectionTitle('Credit Limit ${index + 1}'),
                    _buildInfoRow('Company', limit['company']),
                    _buildInfoRow(
                        'Credit Limit', limit['credit_limit']?.toString()),
                    _buildInfoRow('Bypass Credit Limit Check',
                        limit['bypass_credit_limit_check'] == 1 ? 'Yes' : 'No'),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
            'GST Certificate', _customerDetails['custom_gst_certificate']),
        _buildInfoRow('Aadhar Card', _customerDetails['custom_adhar_card']),
        _buildInfoRow(
            'Other Document', _customerDetails['custom_other_document']),
        _buildInfoRow(
            'Bank Statement', _customerDetails['custom_bank_statement']),
        _buildInfoRow('PAN Card', _customerDetails['custom_pan_card']),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer['customer_name'] ?? 'Customer Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customerDetails.isEmpty
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildSectionNavBar(),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        children: [
                          _buildSectionCard(_buildBasicInformationSection()),
                          _buildSectionCard(_buildAddressInformationSection()),
                          _buildSectionCard(_buildSalesTeamSection()),
                          _buildSectionCard(_buildBankDetailsSection()),
                          _buildSectionCard(_buildContactInformationSection()),
                          _buildSectionCard(_buildCreditLimitsSection()),
                          _buildSectionCard(_buildAttachmentsSection()),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
