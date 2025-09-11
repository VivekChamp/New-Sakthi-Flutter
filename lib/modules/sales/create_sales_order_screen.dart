import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:sakthi_erp/utils/error_handler.dart';

class CreateSalesOrderScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const CreateSalesOrderScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _CreateSalesOrderScreenState createState() => _CreateSalesOrderScreenState();
}

class _CreateSalesOrderScreenState extends State<CreateSalesOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _companySelected = false;
  bool _isLoading = false;
  String? _series = 'SAL-ORD-.YYYY.-';
  final TextEditingController _transactionDateController =
      TextEditingController();
  final TextEditingController _deliveryDateController = TextEditingController();
  String? _customer;
  String? _company;
  final String _orderType = 'Sales';
  final TextEditingController _poNoController = TextEditingController();
  final TextEditingController _poDateController = TextEditingController();
  final TextEditingController _termsContentController = TextEditingController();
  final List<Map<String, dynamic>> _items = [
    {
      'itemCode': null,
      'itemName': null,
      'deliveryDate': TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      ),
      'qty': TextEditingController(text: '1.0'),
      'uom': null,
      'rate': TextEditingController(text: '0.0'),
      'amount': 0.0,
    },
  ];
  String? _taxTemplate;
  List<Map<String, dynamic>> _taxTemplates = [];
  List<Map<String, dynamic>> _selectedTaxes = [];
  String? _paymentTermsTemplate;
  List<Map<String, dynamic>> _paymentTermsTemplates = [];

  // New fields for Sales Person
  String? selectedSalesPersonName;
  String? selectedSalesPersonId;
  List<Map<String, String>> salesPersons = [];

  List<Map<String, dynamic>> customerList = [];
  List<Map<String, dynamic>> itemList = [];
  List<Map<String, dynamic>> companyList = [];

  // Reusable colors from main.dart
  static const Color primaryColor = Color(0xff65C18C);
  static const Color darkGreenColor = Color(0xff195533);
  static const Color backgroundColor = Color(0xffDDF1E5);
  static const Color blackColor = Color(0xff000000);

  @override
  void initState() {
    super.initState();
    _transactionDateController.text =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    _deliveryDateController.text =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        fetchNamingSeries(),
        fetchCustomers(),
        fetchItems(),
        fetchCompanyList(),
        fetchPaymentTermsTemplates(),
        _fetchSalesPersons(),
      ]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load initial data: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _fetchInitialData,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _transactionDateController.dispose();
    _deliveryDateController.dispose();
    _poNoController.dispose();
    _poDateController.dispose();
    _termsContentController.dispose();
    for (var item in _items) {
      item['deliveryDate'].dispose();
      item['qty'].dispose();
      item['rate'].dispose();
    }
    for (var tax in _selectedTaxes) {
      (tax['rateController'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  Future<void> fetchNamingSeries() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_sales_order_naming_series';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          final series = List<String>.from(
            data['message']['naming_series_options'] ?? [],
          );
          series.removeWhere((item) => item.isEmpty);
          series.sort((a, b) => a == 'SAL-ORD-.YYYY.-' ? -1 : 1);
          _series = series.isNotEmpty ? 'SAL-ORD-.YYYY.-' : null;
        });
      } else {
        throw Exception(
            'Failed to fetch naming series: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching naming series: $e');
    }
  }

  Future<void> fetchCustomers() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_customers';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          customerList = List<Map<String, dynamic>>.from(
            data['message']['customers'] ?? [],
          );
        });
      } else {
        throw Exception('Failed to fetch customers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching customers: $e');
    }
  }

  Future<void> fetchItems() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_item_details';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          itemList = List<Map<String, dynamic>>.from(
            data['message']['items'] ?? [],
          );
        });
      } else {
        throw Exception('Failed to fetch items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching items: $e');
    }
  }

  Future<void> fetchCompanyList() async {
    try {
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_company_list';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          companyList = List<Map<String, dynamic>>.from(
            data['message']['data'] ?? [],
          );
          _company = companyList.firstWhere(
            (company) =>
                company['name'].toLowerCase() ==
                'sakthi steel industries ltd'.toLowerCase(),
            orElse: () => companyList.isNotEmpty
                ? companyList[0]
                : {'name': 'SAKTHI STEEL INDUSTRIES LTD'},
          )['name'];
          _companySelected = true;
          fetchTaxTemplates();
        });
      } else {
        throw Exception('Failed to fetch company list: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching company list: $e');
    }
  }

  Future<void> fetchTaxTemplates() async {
    try {
      if (_company == null) return;
      final companyAbbr = companyList.firstWhere(
        (company) => company['name'] == _company,
        orElse: () => {'abbr': 'SSIL'},
      )['abbr'];
      final url =
          '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_all_sales_taxes_templates?company_abbr=$companyAbbr&filters=Docstatus!=2';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final filteredTemplates = data['message']
            .where(
              (template) =>
                  template['template_name'].toString().contains(companyAbbr) &&
                  !template['template_name'].toString().contains('RCM'),
            )
            .toList();
        setState(() {
          _taxTemplates = List<Map<String, dynamic>>.from(filteredTemplates);
          _taxTemplate = null;
          _updateSelectedTaxes();
        });
      } else {
        throw Exception(
          'Failed to fetch tax templates: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching tax templates: $e');
    }
  }

  Future<void> fetchPaymentTermsTemplates() async {
    try {
      final url = '${widget.serverUrl}/api/resource/Payment Terms Template';
      final headers = {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _paymentTermsTemplates = List<Map<String, dynamic>>.from(
            data['data'] ?? [],
          );
          _paymentTermsTemplate = null;
        });
      } else {
        throw Exception(
          'Failed to fetch payment terms templates: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching payment terms templates: $e');
    }
  }

  Future<void> _fetchSalesPersons() async {
    final url =
        "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_salesperson";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['message'] != null &&
            responseData['message']['data'] != null) {
          List<dynamic> data = responseData['message']['data'];
          setState(() {
            salesPersons = data
                .map(
                  (sp) => {
                    'name': sp['name'] as String,
                    'sales_person_name': sp['sales_person_name'] as String,
                  },
                )
                .toList();
            selectedSalesPersonName = salesPersons.isNotEmpty
                ? salesPersons.first['sales_person_name']
                : null;
            selectedSalesPersonId =
                salesPersons.isNotEmpty ? salesPersons.first['name'] : null;
          });
        } else {
          throw Exception('Invalid sales person data format');
        }
      } else {
        throw Exception(
            'Failed to fetch sales persons: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching sales persons: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateSelectedTaxes() {
    if (_taxTemplate != null) {
      final selectedTemplate = _taxTemplates.firstWhere(
        (template) => template['template_name'] == _taxTemplate,
        orElse: () => {},
      );
      if (selectedTemplate.isNotEmpty) {
        setState(() {
          _selectedTaxes =
              List<Map<String, dynamic>>.from(selectedTemplate['taxes'] ?? [])
                  .map((tax) {
            final isEditable = tax['charge_type'] == 'On Item Quantity' &&
                (tax['account_head'] ==
                        'Freight and Forwarding Charges - SSIL' ||
                    tax['account_head'] == 'HANDLING CHARGES - SSIL' ||
                    tax['account_head'] ==
                        'Freight and Forwarding Charges - SFAIPL' ||
                    tax['account_head'] == 'HANDLING CHARGES - SFAIPL');
            return {
              ...tax,
              'rateController': isEditable
                  ? TextEditingController(
                      text: (tax['rate']?.toString() ?? '0.0'),
                    )
                  : null,
              'editableRate':
                  isEditable ? (tax['rate'] as num?)?.toDouble() ?? 0.0 : null,
            };
          }).toList();
          _validateAndAdjustTaxes();
          _calculateTaxAmounts();
        });
      }
    } else {
      setState(() {
        _selectedTaxes = [];
      });
    }
  }

  void _validateAndAdjustTaxes() {
    final currentCompanyAbbr = companyList.firstWhere(
      (company) => company['name'] == _company,
      orElse: () => {'abbr': 'SSIL'},
    )['abbr'];

    _selectedTaxes = _selectedTaxes.map((tax) {
      if (tax['account_head']?.contains(currentCompanyAbbr) == false) {
        return {
          ...tax,
          'account_head':
              '${tax['account_head']?.replaceAll(RegExp(r'-[^-]+$'), '')}-$currentCompanyAbbr',
          'description':
              '${tax['description']} (Adjusted for $currentCompanyAbbr)',
        };
      }
      return tax;
    }).toList();
  }

  void _calculateTaxAmounts() {
    double netTotal = getTotalAmount();
    List<Map<String, dynamic>> calculatedTaxes = [];
    Map<int?, double> rowTotals = {null: netTotal};

    _selectedTaxes.sort((a, b) {
      final aRowId =
          int.tryParse(a['row_id']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ??
              0;
      final bRowId =
          int.tryParse(b['row_id']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ??
              0;
      return aRowId.compareTo(bRowId);
    });

    for (var tax in _selectedTaxes) {
      final rate =
          (tax['editableRate'] ?? (tax['rate'] as num?)?.toDouble() ?? 0.0);
      final chargeType = tax['charge_type'] as String? ?? 'On Net Total';
      double baseAmount = 0.0;
      int? rowId = int.tryParse(
        tax['row_id']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0',
      );

      switch (chargeType) {
        case 'On Item Quantity':
          if (tax['account_head'] == 'Freight and Forwarding Charges - SSIL' ||
              tax['account_head'] == 'HANDLING CHARGES - SSIL' ||
              tax['account_head'] ==
                  'Freight and Forwarding Charges - SFAIPL' ||
              tax['account_head'] == 'HANDLING CHARGES - SFAIPL') {
            baseAmount = getTotalQuantity();
          } else {
            baseAmount = netTotal;
          }
          break;
        case 'On Net Total':
          baseAmount = netTotal;
          break;
        case 'On Previous Row Total':
          baseAmount =
              (rowId != null && rowId > 0 && rowTotals.containsKey(rowId - 1))
                  ? (rowTotals[rowId - 1] ?? netTotal)
                  : netTotal;
          break;
        case 'Actual':
          baseAmount = 1.0;
          break;
        default:
          baseAmount = netTotal;
      }

      double taxAmount;
      if (chargeType == 'On Item Quantity' &&
          (tax['account_head'] == 'Freight and Forwarding Charges - SSIL' ||
              tax['account_head'] == 'HANDLING CHARGES - SSIL' ||
              tax['account_head'] ==
                  'Freight and Forwarding Charges - SFAIPL' ||
              tax['account_head'] == 'HANDLING CHARGES - SFAIPL')) {
        taxAmount = getTotalQuantity() * rate;
      } else if (chargeType == 'Actual') {
        taxAmount = rate;
      } else {
        taxAmount = (baseAmount * rate) / 100;
      }

      double currentTotal = (rowTotals[rowId ??
                  (calculatedTaxes.length > 0
                      ? calculatedTaxes.last['row_id_val']
                      : null)] ??
              netTotal) +
          taxAmount;

      if (rowId == null) {
        final lastCalculatedTotal =
            calculatedTaxes.isEmpty ? netTotal : calculatedTaxes.last['total'];
        currentTotal = lastCalculatedTotal + taxAmount;
      } else if (rowTotals.containsKey(rowId - 1)) {
        currentTotal = (rowTotals[rowId - 1] ?? netTotal) + taxAmount;
      } else {
        currentTotal = netTotal + taxAmount;
      }

      calculatedTaxes.add({
        ...tax,
        'amount': taxAmount,
        'total': currentTotal,
        'row_id_val': rowId,
      });

      rowTotals[rowId ?? (calculatedTaxes.length - 1)] = currentTotal;
    }

    setState(() {
      _selectedTaxes = calculatedTaxes;
    });
  }

  void _updateTaxRate(int index, String value) {
    if (index >= 0 && index < _selectedTaxes.length) {
      final tax = _selectedTaxes[index];
      if ((tax['charge_type'] == 'On Item Quantity' &&
              (tax['account_head'] == 'Freight and Forwarding Charges - SSIL' ||
                  tax['account_head'] == 'HANDLING CHARGES - SSIL' ||
                  tax['account_head'] ==
                      'Freight and Forwarding Charges - SFAIPL' ||
                  tax['account_head'] == 'HANDLING CHARGES - SFAIPL')) ||
          tax['charge_type'] == 'Actual') {
        setState(() {
          final rate = double.tryParse(value) ?? 0.0;
          _selectedTaxes[index]['editableRate'] = rate;
          if ((_selectedTaxes[index]['rateController'] as TextEditingController)
                  .text !=
              value) {
            (_selectedTaxes[index]['rateController'] as TextEditingController)
                .text = value;
          }
          _calculateTaxAmounts();
        });
      }
    }
  }

  Future<void> _createSalesOrder() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final url = "${widget.serverUrl}/api/resource/Sales Order";
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final items = _items.map((item) {
      return {
        "item_code": item['itemCode'],
        "item_name": item['itemName'],
        "delivery_date": item['deliveryDate'].text,
        "qty": double.tryParse(item['qty'].text) ?? 0.0,
        "uom": item['uom'],
        "rate": double.tryParse(item['rate'].text) ?? 0.0,
        "amount": item['amount'],
      };
    }).toList();

    final taxes = _selectedTaxes.map((tax) {
      final Map<String, dynamic> taxData = {
        "charge_type": tax['charge_type'],
        "account_head": tax['account_head'],
        "rate": tax['editableRate'] ?? tax['rate'],
        "amount": tax['amount'],
        "description": tax['description'],
        "cost_center": tax['cost_center'],
        "total": tax['total'],
      };
      if (tax['row_id'] != null) {
        taxData['row_id'] = tax['row_id'];
      }
      return taxData;
    }).toList();

    final body = jsonEncode({
      "naming_series": _series,
      "transaction_date": _transactionDateController.text,
      "delivery_date": _deliveryDateController.text,
      "customer": _customer,
      "order_type": _orderType,
      "po_no": _poNoController.text,
      "po_date":
          _poDateController.text.isNotEmpty ? _poDateController.text : null,
      "items": items,
      "taxes": taxes,
      "taxes_and_charges": _taxTemplate,
      "payment_terms_template": _paymentTermsTemplate,
      "terms": _termsContentController.text.isNotEmpty
          ? _termsContentController.text
          : null,
      "company": _company,
      "currency": companyList.firstWhere(
        (company) => company['name'] == _company,
        orElse: () => {'default_currency': 'INR'},
      )['default_currency'],
      "selling_price_list": "Standard Selling",
      "status": "Draft",
      "sales_team": selectedSalesPersonId != null
          ? [
              {
                "sales_person": selectedSalesPersonId,
                "allocated_percentage": 100.0,
              },
            ]
          : [],
    });

    http.Response? response;
    try {
      response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sales Order Created Successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(
            'Failed to create sales order: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      showApiErrorDialog(context,
          statusCode: response?.statusCode, message: e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller, {
    bool isDeliveryDate = false,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
        controller.text = formattedDate;
        if (isDeliveryDate) {
          for (var item in _items) {
            item['deliveryDate'].text = formattedDate;
          }
        }
      });
    }
  }

  void _addItemRow() {
    setState(() {
      _items.add({
        'itemCode': null,
        'itemName': null,
        'deliveryDate': TextEditingController(
          text: _deliveryDateController.text,
        ),
        'qty': TextEditingController(text: '1.0'),
        'uom': null,
        'rate': TextEditingController(text: '0.0'),
        'amount': 0.0,
      });
    });
  }

  void _removeItemRow(int index) {
    setState(() {
      if (_items.length > 1) {
        _items[index]['deliveryDate'].dispose();
        _items[index]['qty'].dispose();
        _items[index]['rate'].dispose();
        _items.removeAt(index);
        _calculateTaxAmounts();
      }
    });
  }

  double getTotalQuantity() {
    return _items.fold(
        0.0, (sum, item) => sum + (double.tryParse(item['qty'].text) ?? 0.0));
  }

  double getTotalAmount() {
    return _items.fold(0.0, (sum, item) => sum + (item['amount'] as double));
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    int maxLines = 1,
    String? validatorMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
            maxLines: maxLines,
            validator: (value) {
              if (validatorMessage != null &&
                  (value == null || value.isEmpty)) {
                return validatorMessage;
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: Colors.grey[600]),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
              errorStyle: TextStyle(color: Colors.red[700]),
            ),
            style: TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdownField(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?>? onChanged, {
    bool enabled = true,
    String? validatorMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DropdownSearch<String>(
            items: (String filter, LoadProps? loadProps) => Future.value(
              items
                  .where((item) =>
                      item.toLowerCase().contains(filter.toLowerCase()))
                  .toList(),
            ),
            selectedItem: value,
            onChanged: enabled ? onChanged : null,
            enabled: enabled,
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  labelText: 'Search $label',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            dropdownBuilder: (context, selectedItem) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                selectedItem ?? 'Select $label',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
          ),
        ),
        if (validatorMessage != null && (value == null || value.isEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              validatorMessage,
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildItemsTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildTableHeaderCell('No.', 60),
                _buildTableHeaderCell('Item Code', 250),
                _buildTableHeaderCell('Quantity', 100),
                _buildTableHeaderCell('Rate (INR)', 150),
                _buildTableHeaderCell('Amount (INR)', 100),
                _buildTableHeaderCell('', 60),
              ],
            ),
          ),
          SizedBox(height: 8),
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final qty = double.tryParse(item['qty'].text) ?? 0.0;
            final rate = double.tryParse(item['rate'].text) ?? 0.0;
            item['amount'] = qty * rate;
            return Container(
              margin: EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildTableCell(
                    Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black87),
                    ),
                    60,
                  ),
                  _buildTableCell(
                    DropdownSearch<String>(
                      items: (String filter, LoadProps? loadProps) =>
                          Future.value(
                        itemList
                            .map((item) =>
                                '${item['item_code']} - ${item['item_name']}')
                            .toList(),
                      ),
                      selectedItem: item['itemCode'] != null
                          ? '${item['itemCode']} - ${item['itemName']}'
                          : null,
                      onChanged: (value) {
                        setState(() {
                          item['itemCode'] = value?.split(' - ')[0];
                          final selectedItem = itemList.firstWhere(
                            (element) =>
                                element['item_code'] == item['itemCode'],
                            orElse: () => {
                              'item_name': '',
                              'uom': '',
                              'price_list_rate': 0.0,
                            },
                          );
                          item['itemName'] = selectedItem['item_name'];
                          item['uom'] = selectedItem['uom'];
                          item['rate'].text =
                              (selectedItem['price_list_rate'] as num)
                                  .toDouble()
                                  .toString();
                          final qty = double.tryParse(item['qty'].text) ?? 0.0;
                          final rate =
                              double.tryParse(item['rate'].text) ?? 0.0;
                          item['amount'] = qty * rate;
                          _calculateTaxAmounts();
                        });
                      },
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(
                            labelText: 'Search Item Code',
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      dropdownBuilder: (context, selectedItem) => Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          selectedItem ?? 'Select Item Code',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ),
                    ),
                    250,
                  ),
                  _buildTableCell(
                    TextFormField(
                      controller: item['qty'],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Quantity is required'
                          : null,
                      onChanged: (value) {
                        setState(() {
                          final qty = double.tryParse(value) ?? 0.0;
                          final rate =
                              double.tryParse(item['rate'].text) ?? 0.0;
                          item['amount'] = qty * rate;
                          _calculateTaxAmounts();
                        });
                      },
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    100,
                  ),
                  _buildTableCell(
                    TextFormField(
                      controller: item['rate'],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Rate is required'
                          : null,
                      onChanged: (value) {
                        setState(() {
                          final rate = double.tryParse(value) ?? 0.0;
                          final qty = double.tryParse(item['qty'].text) ?? 0.0;
                          item['amount'] = qty * rate;
                          _calculateTaxAmounts();
                        });
                      },
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    150,
                  ),
                  _buildTableCell(
                    Text(
                      item['amount'].toStringAsFixed(2),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black87),
                    ),
                    100,
                  ),
                  _buildTableCell(
                    _items.length > 1
                        ? IconButton(
                            icon: Icon(Icons.delete, color: Colors.red[700]),
                            onPressed: () => _removeItemRow(index),
                          )
                        : SizedBox(),
                    60,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String title, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.all(8.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black87,
        ),
        textAlign: title == 'No.' ||
                title == 'Quantity' ||
                title == 'Rate (INR)' ||
                title == 'Amount (INR)' ||
                title == 'Tax Rate'
            ? TextAlign.center
            : TextAlign.left,
      ),
    );
  }

  Widget _buildTableCell(Widget child, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Sales Order',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchableDropdownField(
                        'Naming Series',
                        _series,
                        ['SAL-ORD-.YYYY.-'],
                        (value) => setState(() => _series = value),
                        validatorMessage: 'Naming Series is required',
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        'Transaction Date',
                        _transactionDateController,
                        readOnly: true,
                        onTap: () =>
                            _selectDate(context, _transactionDateController),
                        validatorMessage: 'Transaction Date is required',
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        'Delivery Date',
                        _deliveryDateController,
                        readOnly: true,
                        onTap: () => _selectDate(
                          context,
                          _deliveryDateController,
                          isDeliveryDate: true,
                        ),
                        validatorMessage: 'Delivery Date is required',
                      ),
                      SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Company',
                        _company,
                        companyList
                            .map((company) => company['name'] as String)
                            .toList(),
                        (value) {
                          setState(() {
                            _company = value;
                            _companySelected = true;
                            _taxTemplate = null;
                            _selectedTaxes = [];
                            fetchTaxTemplates();
                          });
                        },
                        validatorMessage: 'Company is required',
                      ),
                      SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Customer',
                        _customer,
                        customerList
                            .map((customer) =>
                                '${customer['name']} - ${customer['customer_name']} - ${customer['custom_city']}')
                            .toList(),
                        (value) =>
                            setState(() => _customer = value?.split(' - ')[0]),
                        validatorMessage: 'Customer is required',
                      ),
                      SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Sales Person',
                        selectedSalesPersonName,
                        salesPersons
                            .map((sp) => sp['sales_person_name']!)
                            .toList(),
                        (value) {
                          setState(() {
                            selectedSalesPersonName = value;
                            selectedSalesPersonId =
                                salesPersons.firstWhereOrNull((sp) =>
                                    sp['sales_person_name'] == value)?['name'];
                          });
                        },
                        enabled: _companySelected,
                        validatorMessage: 'Sales Person is required',
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        "Customer's Purchase Order (PO No)",
                        _poNoController,
                        onChanged: (value) => setState(() {}),
                      ),
                      if (_poNoController.text.isNotEmpty) ...[
                        SizedBox(height: 16),
                        _buildTextField(
                          "Customer's Purchase Order Date",
                          _poDateController,
                          readOnly: true,
                          onTap: () => _selectDate(context, _poDateController),
                        ),
                      ],
                      SizedBox(height: 16),
                      Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: darkGreenColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildItemsTable(context),
                      SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Sales Taxes and Charges Template',
                        _taxTemplate,
                        _taxTemplates
                            .map((template) =>
                                template['template_name'] as String)
                            .toList(),
                        (value) {
                          setState(() {
                            _taxTemplate = value;
                            _updateSelectedTaxes();
                          });
                        },
                        enabled: _companySelected,
                      ),
                      if (_taxTemplate != null &&
                          _selectedTaxes.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                columnSpacing: 20,
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'No.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blackColor,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Charge Type',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blackColor,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Account Head',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blackColor,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Tax Rate',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blackColor,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Amount (INR)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blackColor,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Total (INR)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blackColor,
                                      ),
                                    ),
                                  ),
                                ],
                                rows:
                                    _selectedTaxes.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final tax = entry.value;
                                  final isEditable =
                                      (tax['charge_type'] ==
                                                  'On Item Quantity' &&
                                              (tax['account_head'] ==
                                                      'Freight and Forwarding Charges - SSIL' ||
                                                  tax['account_head'] ==
                                                      'HANDLING CHARGES - SSIL' ||
                                                  tax['account_head'] ==
                                                      'Freight and Forwarding Charges - SFAIPL' ||
                                                  tax['account_head'] ==
                                                      'HANDLING CHARGES - SFAIPL')) ||
                                          (tax['charge_type'] == 'Actual');
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          '${index + 1}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: blackColor),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          tax['charge_type'] ?? '',
                                          style: TextStyle(color: blackColor),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          tax['account_head'] ?? '',
                                          style: TextStyle(color: blackColor),
                                        ),
                                      ),
                                      DataCell(
                                        isEditable
                                            ? TextFormField(
                                                controller: tax[
                                                        'rateController']
                                                    as TextEditingController,
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 8,
                                                  ),
                                                ),
                                                keyboardType: TextInputType
                                                    .numberWithOptions(
                                                        decimal: true),
                                                onChanged: (value) =>
                                                    _updateTaxRate(
                                                        index, value),
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color: blackColor),
                                                textAlign: TextAlign.center,
                                              )
                                            : Text(
                                                '${tax['rate'] ?? 0}',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: blackColor),
                                              ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${(tax['amount'] ?? 0.0).toStringAsFixed(2)}',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(color: blackColor),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${(tax['total'] ?? 0.0).toStringAsFixed(2)}',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(color: blackColor),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Payment Terms Template',
                        _paymentTermsTemplate,
                        _paymentTermsTemplates
                            .map((term) => term['name'] as String)
                            .toList(),
                        (value) {
                          setState(() {
                            _paymentTermsTemplate = value;
                          });
                        },
                        enabled: _companySelected,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        'Terms and Conditions Details',
                        _termsContentController,
                        maxLines: 4,
                        onChanged: (value) => setState(() {}),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _createSalesOrder,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Create Sales Order',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: Center(
                child: CircularProgressIndicator(color: primaryColor),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItemRow,
        backgroundColor: primaryColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (T element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
