import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:retry/retry.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:sakthi_erp/utils/error_handler.dart';

class QuotationScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final Map<String, dynamic>? initialData;
  const QuotationScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
    this.initialData,
  });
  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  List<dynamic> _itemsList = [];
  List<dynamic> _customersList = [];
  List<dynamic> _salespersonsList = [];
  List<Map<String, dynamic>> _selectedItems = [];
  List<dynamic> _costCenters = [];
  List<Map<String, dynamic>> _taxTemplates = [];
  List<Map<String, dynamic>> _companyList = [];
  List<Map<String, dynamic>> _selectedTaxes = [];
  String? _selectedCostCenter;
  Map<String, dynamic>? _selectedCustomer;
  Map<String, dynamic>? _selectedSalesperson;
  String? _selectedTaxTemplate;
  String? _selectedCompany;
  bool _companySelected = false;
  bool _isLoading = true;
  bool _isFetchingItems = false;
  bool _isFetchingCustomers = false;
  bool _isFetchingSalespersons = false;
  bool _isFetchingCostCenters = false;
  bool _isFetchingTaxTemplates = false;
  static List<dynamic>? _cachedItems;
  static List<dynamic>? _cachedCustomers;
  static List<dynamic>? _cachedSalespersons;
  static List<dynamic>? _cachedCostCenters;
  final _quotationToController = TextEditingController(text: 'Customer');
  DateTime _transactionDate = DateTime.now();
  double _cachedTotalAmount = 0.0;
  double _cachedGrandTotal = 0.0;
  int _cachedTotalQuantity = 0;
  String _namingSeries = 'SAL-QTN-.YYYY';
  String _sellingPriceList = 'Standard Selling';
  String _currency = 'INR';
  List<String> _uomList = [
    'MTS',
    'Unit',
    'Box',
    'Nos',
    'Pair',
    'Set',
    'Meter',
    'Barleycorn',
    'Calibre',
  ];
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _quotationToController.dispose();
    for (var item in _selectedItems) {
      item['quantityController']?.dispose();
      item['discountPercentController']?.dispose();
      item['discountAmountController']?.dispose();
      item['amountController']?.dispose();
    }
    for (var tax in _selectedTaxes) {
      (tax['rateController'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchItems(),
        _fetchCustomers(),
        _fetchSalespersons(),
        _fetchCostCenters(),
        _fetchCompanyList(),
      ]);
      _loadInitialData();
      _updateTotals();
    } catch (e) {
      showApiErrorDialog(context, message: 'Failed to load initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadInitialData() {
    if (widget.initialData != null) {
      final data = widget.initialData!;
      setState(() {
        _quotationToController.text =
            data['quotation_to']?.toString() ?? 'Customer';
        _transactionDate =
            DateTime.tryParse(data['transaction_date']?.toString() ?? '') ??
                DateTime.now();
        _selectedItems = List<Map<String, dynamic>>.from(
          (data['items'] as List<dynamic>?)?.map(
                (item) => ({
                  'item_name': item['item_name']?.toString() ?? 'Unknown',
                  'item_code': item['item_code']?.toString() ?? '',
                  'quantity': item['qty'] is num ? item['qty'].toInt() : 1,
                  'uom': item['uom']?.toString() ?? 'Nos',
                  'stock_uom': item['stock_uom']?.toString() ?? 'Nos',
                  'conversion_factor':
                      (item['conversion_factor'] as num?)?.toDouble() ?? 0.0,
                  'price_list_rate':
                      (item['price_list_rate'] as num?)?.toDouble() ?? 0.0,
                  'discount_percent':
                      (item['discount_percentage'] as num?)?.toDouble() ?? 0.0,
                  'discount_amount':
                      (item['discount_amount'] as num?)?.toDouble() ?? 0.0,
                  'rate': (item['rate'] as num?)?.toDouble() ?? 0.0,
                  'stock_qty': (item['stock_qty'] as num?)?.toInt() ?? 0,
                  'amount': _calculateAmount(item),
                  'image': item['image']?.toString(),
                  'barcode': item['barcode']?.toString() ?? '',
                  'quantityController': TextEditingController(
                      text: (item['qty'] ?? 1).toString()),
                  'discountPercentController': TextEditingController(
                    text: ((item['discount_percentage'] ?? 0.0) as num)
                        .toDouble()
                        .toStringAsFixed(2),
                  ),
                  'discountAmountController': TextEditingController(
                    text: ((item['discount_amount'] ?? 0.0) as num)
                        .toDouble()
                        .toStringAsFixed(2),
                  ),
                  'amountController': TextEditingController(
                    text: _calculateAmount(item).toStringAsFixed(2),
                  ),
                  'selectedUom': item['uom']?.toString() ?? 'Nos',
                }),
              ) ??
              [],
        );
        final customerNameFromData =
            data['customer']?.toString() ?? data['customer_name']?.toString();
        if (customerNameFromData != null) {
          _selectedCustomer = _customersList.firstWhere(
            (customer) => customer['name'] == customerNameFromData,
            orElse: () => {
              'name': customerNameFromData,
              'customer_name': customerNameFromData,
              'company':
                  data['company']?.toString() ?? 'Sakthi Steel Industries Ltd',
            },
          );
        }
        if (data['salesperson_name'] != null) {
          _selectedSalesperson = _salespersonsList.firstWhere(
            (sp) =>
                sp['salesperson_name'] == data['salesperson_name'].toString(),
            orElse: () =>
                {'salesperson_name': data['salesperson_name'].toString()},
          );
        }
        _selectedCostCenter = data['cost_center']?.toString() ??
            (_costCenters.isNotEmpty ? _costCenters[0]['name'] : null);
        _selectedCompany = data['company']?.toString() ??
            (_companyList.isNotEmpty ? _companyList[0]['name'] : null);
        _companySelected = _selectedCompany != null;
        _selectedTaxTemplate = data['taxes_and_charges']?.toString();
        if (_selectedTaxTemplate != null) {
          _updateSelectedTaxes();
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _selectedCompany =
            _companyList.isNotEmpty ? _companyList[0]['name'] : null;
        _companySelected = _selectedCompany != null;
        if (_companySelected) {
          _fetchTaxTemplates();
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchItems() async {
    if (_cachedItems != null) {
      setState(() {
        _itemsList = _cachedItems!;
        _isFetchingItems = false;
      });
      return;
    }
    setState(() => _isFetchingItems = true);
    try {
      final response = await retry(
        () => http.get(
          Uri.parse(
              "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.qtn.get_item_details"),
          headers: _getHeaders(),
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _itemsList = (data['message'] as List<dynamic>?)
                  ?.map(
                    (item) => ({
                      'item_code': item['item_code']?.toString() ?? '',
                      'item_name': item['item_name']?.toString() ?? '',
                      'image': item['image']?.toString(),
                      'price_list_rate':
                          (item['price_list_rate'] as num?)?.toDouble() ?? 0.0,
                      'uom': item['uom']?.toString() ?? 'Nos',
                      'stock_uom': item['stock_uom']?.toString() ?? 'Nos',
                      'conversion_factor':
                          (item['conversion_factor'] as num?)?.toDouble() ??
                              0.0,
                      'barcode': item['barcode']?.toString() ?? '',
                    }),
                  )
                  .toList() ??
              [];
          _cachedItems = _itemsList;
          _isFetchingItems = false;
        });
      } else {
        throw Exception('Failed to fetch items: ${response.statusCode}');
      }
    } catch (e) {
      showApiErrorDialog(context, message: 'Failed to fetch items: $e');
      setState(() => _isFetchingItems = false);
    }
  }

  Future<void> _fetchCustomers() async {
    if (_cachedCustomers != null) {
      setState(() {
        _customersList = _cachedCustomers!;
        _isFetchingCustomers = false;
      });
      return;
    }
    setState(() => _isFetchingCustomers = true);
    try {
      final response = await retry(
        () => http.get(
          Uri.parse(
              "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.qtn.get_customers"),
          headers: _getHeaders(),
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _customersList = (data['message'] as List<dynamic>?)
                  ?.map(
                    (customer) => ({
                      'name': customer['name']?.toString() ?? '',
                      'customer_name': customer['customer_name']?.toString() ??
                          customer['name']?.toString() ??
                          '',
                      'company': customer['company']?.toString() ??
                          'Sakthi Steel Industries Ltd',
                    }),
                  )
                  .toList() ??
              [];
          _cachedCustomers = _customersList;
          _isFetchingCustomers = false;
        });
      } else {
        throw Exception('Failed to fetch customers: ${response.statusCode}');
      }
    } catch (e) {
      showApiErrorDialog(context, message: 'Failed to fetch customers: $e');
      setState(() => _isFetchingCustomers = false);
    }
  }

  Future<void> _fetchSalespersons() async {
    if (_cachedSalespersons != null) {
      setState(() {
        _salespersonsList = _cachedSalespersons!;
        _isFetchingSalespersons = false;
      });
      return;
    }
    setState(() => _isFetchingSalespersons = true);
    try {
      final response = await retry(
        () => http.get(
          Uri.parse(
              "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.qtn.get_salesperson"),
          headers: _getHeaders(),
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _salespersonsList = (data['message'] as List<dynamic>?)
                  ?.map(
                    (item) => ({
                      'salesperson_name':
                          item['sales_person_name']?.toString() ?? '',
                    }),
                  )
                  .toList() ??
              [];
          _cachedSalespersons = _salespersonsList;
          _isFetchingSalespersons = false;
        });
      } else {
        throw Exception('Failed to fetch salespersons: ${response.statusCode}');
      }
    } catch (e) {
      showApiErrorDialog(context, message: 'Failed to fetch salespersons: $e');
      setState(() => _isFetchingSalespersons = false);
    }
  }

  Future<void> _fetchCostCenters() async {
    if (_cachedCostCenters != null) {
      setState(() {
        _costCenters = _cachedCostCenters!;
        _selectedCostCenter =
            _costCenters.isNotEmpty ? _costCenters[0]['name'] : null;
        _isFetchingCostCenters = false;
      });
      return;
    }
    setState(() => _isFetchingCostCenters = true);
    try {
      final response = await retry(
        () => http.get(
          Uri.parse(
              "${widget.serverUrl}/api/resource/Cost%20Center?fields=[\"name\"]"),
          headers: _getHeaders(),
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _costCenters = (data['data'] as List<dynamic>?) ?? [];
          _cachedCostCenters = _costCenters;
          _selectedCostCenter =
              _costCenters.isNotEmpty ? _costCenters[0]['name'] : null;
          _isFetchingCostCenters = false;
        });
      } else {
        throw Exception('Failed to fetch cost centers: ${response.statusCode}');
      }
    } catch (e) {
      showApiErrorDialog(context, message: 'Failed to fetch cost centers: $e');
      setState(() => _isFetchingCostCenters = false);
    }
  }

  Future<void> _fetchCompanyList() async {
    try {
      final response = await retry(
        () => http.get(
          Uri.parse(
              "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_company_list"),
          headers: _getHeaders(),
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _companyList =
              List<Map<String, dynamic>>.from(data['message']['data'] ?? []);
          _selectedCompany = _companyList.firstWhere(
            (company) =>
                company['name'].toLowerCase() ==
                'sakthi steel industries ltd'.toLowerCase(),
            orElse: () => _companyList.isNotEmpty
                ? _companyList[0]
                : {'name': 'Sakthi Steel Industries Ltd', 'abbr': 'SSIL'},
          )['name'];
          _companySelected = true;
          _fetchTaxTemplates();
        });
      } else {
        throw Exception('Failed to fetch company list: ${response.statusCode}');
      }
    } catch (e) {
      showApiErrorDialog(context, message: 'Failed to fetch company list: $e');
    }
  }

  Future<void> _fetchTaxTemplates() async {
    if (_selectedCompany == null) return;
    setState(() => _isFetchingTaxTemplates = true);
    try {
      final companyAbbr = _companyList.firstWhere(
        (company) => company['name'] == _selectedCompany,
        orElse: () => {'abbr': 'SSIL'},
      )['abbr'];
      final response = await retry(
        () => http.get(
          Uri.parse(
              "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_all_sales_taxes_templates?company_abbr=$companyAbbr&filters=Docstatus!=2"),
          headers: _getHeaders(),
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
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
          _selectedTaxTemplate = null;
          _selectedTaxes = [];
          _isFetchingTaxTemplates = false;
        });
      } else {
        throw Exception(
            'Failed to fetch tax templates: ${response.statusCode}');
      }
    } catch (e) {
      showApiErrorDialog(context, message: 'Failed to fetch tax templates: $e');
      setState(() => _isFetchingTaxTemplates = false);
    }
  }

  Map<String, String> _getHeaders() => {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
  Future<void> _scanBarcode() async {
    if (await Permission.camera.request().isGranted) {
      try {
        final result = await BarcodeScanner.scan();
        if (result.type == ResultType.Barcode) {
          final barcode = result.rawContent;
          final item = _itemsList.firstWhere(
            (item) => item['barcode'] == barcode,
            orElse: () => null,
          );
          if (item != null) {
            _addItemToResult(item);
          } else {
            showApiErrorDialog(context,
                message: 'No item found for barcode: $barcode');
          }
        }
      } catch (e) {
        showApiErrorDialog(context, message: 'Failed to scan barcode: $e');
      }
    } else {
      showApiErrorDialog(context, message: 'Camera permission denied');
    }
  }

  void _addItemToResult(dynamic item) {
    final newItem = {
      'item_code': item['item_code'] ?? '',
      'item_name': item['item_name'] ?? 'Unknown',
      'quantity': 1,
      'uom': item['uom'] ?? 'Nos',
      'stock_uom': item['stock_uom'] ?? 'Nos',
      'conversion_factor':
          (item['conversion_factor'] as num?)?.toDouble() ?? 0.0,
      'price_list_rate': (item['price_list_rate'] as num?)?.toDouble() ?? 0.0,
      'discount_percent': 0.0,
      'discount_amount': 0.0,
      'rate': (item['price_list_rate'] as num?)?.toDouble() ?? 0.0,
      'stock_qty': 1,
      'image': item['image'],
      'barcode': item['barcode'] ?? '',
      'quantityController': TextEditingController(text: '1'),
      'discountPercentController': TextEditingController(text: '0'),
      'discountAmountController': TextEditingController(text: '0'),
      'amountController': TextEditingController(
          text: ((item['price_list_rate'] as num?)?.toDouble() ?? 0.0)
              .toString()),
      'selectedUom': item['uom'] ?? 'Nos',
    };
    newItem['amount'] =
        double.tryParse(newItem['amountController'].text) ?? 0.0;
    setState(() {
      _selectedItems.add(newItem);
      _updateTotals();
      _calculateTaxAmounts();
    });
  }

  void _updateItem(
    int index, {
    String? quantity,
    String? discountPercent,
    String? discountAmount,
    String? amount,
    String? uom,
  }) {
    setState(() {
      final item = _selectedItems[index];
      if (quantity != null) {
        final qty = int.tryParse(quantity) ?? 0;
        if (qty <= 0) {
          _selectedItems[index]['quantityController']?.dispose();
          _selectedItems[index]['discountPercentController']?.dispose();
          _selectedItems[index]['discountAmountController']?.dispose();
          _selectedItems[index]['amountController']?.dispose();
          _selectedItems.removeAt(index);
          _updateTotals();
          _calculateTaxAmounts();
          return;
        }
        item['quantity'] = qty;
        item['stock_qty'] = qty;
        item['quantityController'].text = qty.toString();
        // Recalculate rate and amount based on manual amount if it exists
        final currentAmount = double.tryParse(item['amountController'].text);
        if (currentAmount != null) {
          item['rate'] = currentAmount / qty;
          item['amount'] = currentAmount;
        }
      }
      if (amount != null) {
        final newAmount = double.tryParse(amount) ?? 0.0;
        item['amount'] = newAmount;
        final qty = item['quantity'] as int;
        if (qty > 0) {
          item['rate'] = newAmount / qty;
        }
        // Reset discount fields to 0
        item['discount_amount'] = 0.0;
        item['discount_percent'] = 0.0;
        item['discountPercentController'].text = '0';
        item['discountAmountController'].text = '0';
      }
      if (discountPercent != null) {
        final percent = double.tryParse(discountPercent) ?? 0.0;
        final subtotal = item['price_list_rate'] * (item['quantity'] as int);
        item['discount_percent'] = percent.clamp(0, 100);
        item['discount_amount'] =
            (subtotal * item['discount_percent'] / 100).clamp(0, subtotal);
        item['amount'] = subtotal - item['discount_amount'];
        item['rate'] = item['price_list_rate'] -
            (item['discount_amount'] / (item['quantity'] as int));
        item['amountController'].text = item['amount'].toString();
        item['discountAmountController'].text =
            item['discount_amount'].toString();
      }
      if (discountAmount != null) {
        final amount = double.tryParse(discountAmount) ?? 0.0;
        final subtotal = item['price_list_rate'] * (item['quantity'] as int);
        item['discount_amount'] = amount.clamp(0, subtotal);
        item['discount_percent'] = subtotal > 0
            ? (item['discount_amount'] / subtotal * 100).clamp(0, 100)
            : 0.0;
        item['amount'] = subtotal - item['discount_amount'];
        item['rate'] = item['price_list_rate'] -
            (item['discount_amount'] / (item['quantity'] as int));
        item['amountController'].text = item['amount'].toString();
        item['discountPercentController'].text =
            item['discount_percent'].toString();
      }
      if (uom != null) {
        item['selectedUom'] = uom;
      }
      _updateTotals();
      _calculateTaxAmounts();
    });
  }

  double _calculateAmount(Map<String, dynamic> item) {
    final price = (item['price_list_rate'] as double?) ?? 0.0;
    final qty = (item['quantity'] as int?) ?? 1;
    final discount = (item['discount_amount'] as double?) ?? 0.0;
    return (price * qty - discount).clamp(0.0, double.infinity);
  }

  void _updateTotals() {
    _cachedTotalQuantity = _selectedItems.fold(
      0,
      (sum, item) => sum + (item['quantity'] as int),
    );
    _cachedTotalAmount = _selectedItems.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as double),
    );
    _cachedGrandTotal = _cachedTotalAmount + _getTotalTaxAmount();
  }

  double _getTotalTaxAmount() {
    return _selectedTaxes.fold(
      0.0,
      (sum, tax) => sum + (tax['amount'] as double? ?? 0.0),
    );
  }

  void _updateSelectedTaxes() {
    if (_selectedTaxTemplate != null) {
      final selectedTemplate = _taxTemplates.firstWhere(
        (template) => template['template_name'] == _selectedTaxTemplate,
        orElse: () => {},
      );
      if (selectedTemplate.isNotEmpty) {
        final currentCompanyAbbr = _companyList.firstWhere(
          (company) => company['name'] == _selectedCompany,
          orElse: () => {'abbr': 'SSIL'},
        )['abbr'];
        setState(() {
          _selectedTaxes =
              List<Map<String, dynamic>>.from(selectedTemplate['taxes'] ?? [])
                  .map((tax) {
            final isEditable = (tax['charge_type'] == 'On Item Quantity' &&
                    (tax['account_head'] ==
                            'Freight and Forwarding Charges - $currentCompanyAbbr' ||
                        tax['account_head'] ==
                            'HANDLING CHARGES - $currentCompanyAbbr')) ||
                tax['charge_type'] == 'Actual';
            final adjustedTax = {
              ...tax,
              'account_head': tax['account_head']
                          ?.contains(currentCompanyAbbr) ==
                      false
                  ? '${tax['account_head']?.replaceAll(RegExp(r'-[^-]+$'), '')}-$currentCompanyAbbr'
                  : tax['account_head'],
              'description': tax['account_head']
                          ?.contains(currentCompanyAbbr) ==
                      false
                  ? '${tax['description']} (Adjusted for $currentCompanyAbbr)'
                  : tax['description'],
              'rateController': isEditable
                  ? TextEditingController(
                      text: (tax['rate']?.toString() ?? '0'))
                  : null,
              'editableRate':
                  isEditable ? (tax['rate'] as num?)?.toDouble() ?? 0.0 : null,
            };
            return adjustedTax;
          }).toList();
          _calculateTaxAmounts();
        });
      }
    } else {
      setState(() {
        _selectedTaxes = [];
        _updateTotals();
      });
    }
  }

  void _calculateTaxAmounts() {
    double netTotal = _cachedTotalAmount;
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
      int? rowId =
          int.tryParse(tax['row_id']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0');
      final currentCompanyAbbr = _companyList.firstWhere(
        (company) => company['name'] == _selectedCompany,
        orElse: () => {'abbr': 'SSIL'},
      )['abbr'];
      switch (chargeType) {
        case 'On Item Quantity':
          if (tax['account_head'] ==
                  'Freight and Forwarding Charges - $currentCompanyAbbr' ||
              tax['account_head'] == 'HANDLING CHARGES - $currentCompanyAbbr') {
            baseAmount = _cachedTotalQuantity.toDouble();
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
          (tax['account_head'] ==
                  'Freight and Forwarding Charges - $currentCompanyAbbr' ||
              tax['account_head'] ==
                  'HANDLING CHARGES - $currentCompanyAbbr')) {
        taxAmount = _cachedTotalQuantity.toDouble() * rate;
      } else if (chargeType == 'Actual') {
        taxAmount = rate;
      } else {
        taxAmount = (baseAmount * rate) / 100;
      }
      double currentTotal = (rowTotals[rowId ??
                  (calculatedTaxes.isNotEmpty
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
      }
      calculatedTaxes.add({
        ...tax,
        'amount': taxAmount,
        'total': currentTotal,
        'row_id_val': rowId,
      });
      rowTotals[rowId ?? calculatedTaxes.length - 1] = currentTotal;
    }
    setState(() {
      _selectedTaxes = calculatedTaxes;
      _updateTotals();
    });
  }

  void _updateTaxRate(int index, String value) {
    if (index >= 0 && index < _selectedTaxes.length) {
      final tax = _selectedTaxes[index];
      final currentCompanyAbbr = _companyList.firstWhere(
        (company) => company['name'] == _selectedCompany,
        orElse: () => {'abbr': 'SSIL'},
      )['abbr'];
      if ((tax['charge_type'] == 'On Item Quantity' &&
              (tax['account_head'] ==
                      'Freight and Forwarding Charges - $currentCompanyAbbr' ||
                  tax['account_head'] ==
                      'HANDLING CHARGES - $currentCompanyAbbr')) ||
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

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF65C18C)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _transactionDate = picked;
      });
    }
  }

  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) {
      showApiErrorDialog(context, message: 'Please fill all required fields');
      return;
    }
    if (_selectedCustomer == null) {
      showApiErrorDialog(context, message: 'Please select a customer');
      return;
    }
    if (_selectedSalesperson == null) {
      showApiErrorDialog(context, message: 'Please select a salesperson');
      return;
    }
    if (_selectedItems.isEmpty) {
      showApiErrorDialog(context, message: 'Please add at least one item');
      return;
    }
    if (_selectedCostCenter == null && _costCenters.isNotEmpty) {
      showApiErrorDialog(context, message: 'Please select a cost center');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final itemsToSave = _selectedItems.map((item) {
        final percent =
            double.tryParse(item['discountPercentController'].text) ?? 0.0;
        final amount =
            double.tryParse(item['discountAmountController'].text) ?? 0.0;
        return {
          'item_code': item['item_code'],
          'item_name': item['item_name'],
          'qty': item['quantity'],
          'uom': item['selectedUom'],
          'stock_uom': item['stock_uom'],
          'conversion_factor': item['conversion_factor'],
          'price_list_rate': item['price_list_rate'],
          'discount_percentage': percent,
          'discount_amount': amount,
          'rate': item['rate'],
          'stock_qty': item['stock_qty'],
          'amount': item['amount'],
          'barcode': item['barcode'],
          if (_selectedCostCenter != null) 'cost_center': _selectedCostCenter,
        };
      }).toList();
      final taxes = _selectedTaxes.map((tax) {
        return {
          'charge_type': tax['charge_type'],
          'account_head': tax['account_head'],
          'description': tax['description'],
          'rate': tax['editableRate'] ?? tax['rate'],
          'tax_amount': tax['amount'],
          'total': tax['total'],
          if (tax['row_id'] != null) 'row_id': tax['row_id'],
        };
      }).toList();
      final quotationData = {
        'doctype': 'Quotation',
        'quotation_to': _quotationToController.text.isEmpty
            ? 'Customer'
            : _quotationToController.text,
        'customer': _selectedCustomer!['name'].toString(),
        'party_name': _selectedCustomer!['customer_name'].toString(),
        'salesperson': _selectedSalesperson!['salesperson_name'].toString(),
        'transaction_date': DateFormat('yyyy-MM-dd').format(_transactionDate),
        'status': widget.initialData?['status']?.toString() ?? 'Draft',
        'items': itemsToSave,
        if (_selectedCostCenter != null) 'cost_center': _selectedCostCenter,
        if (_selectedTaxTemplate != null)
          'taxes_and_charges': _selectedTaxTemplate,
        if (taxes.isNotEmpty) 'taxes': taxes,
        'naming_series': _namingSeries,
        'selling_price_list': _sellingPriceList,
        'currency': _currency,
        'company': _selectedCompany,
        'in_words': numberToWords(_cachedGrandTotal.toInt()),
      };
      final client = http.Client();
      final request = http.Request(
        'POST',
        Uri.parse("${widget.serverUrl}/api/resource/Quotation"),
      );
      request.headers.addAll({
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });
      request.body = json.encode(quotationData);
      final response = await retry(
        () => client.send(request).then(
            (streamedResponse) => http.Response.fromStream(streamedResponse)),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation saved successfully')),
        );
        Navigator.pop(context, true);
      } else if (response.statusCode == 417) {
        showApiErrorDialog(context,
            message:
                'Failed to save quotation: Server rejected request (417). Please check server configuration or contact support.');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        showApiErrorDialog(context,
            message: 'Session expired. Please log in again.');
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        showApiErrorDialog(context,
            message:
                'Failed to save quotation: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      showApiErrorDialog(context, message: 'Failed to save quotation: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems[index]['quantityController']?.dispose();
      _selectedItems[index]['discountPercentController']?.dispose();
      _selectedItems[index]['discountAmountController']?.dispose();
      _selectedItems[index]['amountController']?.dispose();
      _selectedItems.removeAt(index);
      _updateTotals();
      _calculateTaxAmounts();
    });
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
      'Nine'
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
      'Nineteen'
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
      'Ninety'
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    String? validatorMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.secondary,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            decoration: InputDecoration(
              hintText: 'Enter $label',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
            validator: (value) {
              if (validatorMessage != null &&
                  (value == null || value.isEmpty)) {
                return validatorMessage;
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdownField(
    String label,
    dynamic value,
    List<dynamic> items,
    ValueChanged<dynamic>? onChanged,
    String compareKey, {
    bool enabled = true,
    String? validatorMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.secondary,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)
            ],
          ),
          child: DropdownSearch<dynamic>(
            items: (String filter, LoadProps? loadProps) => Future.value(
              items
                  .where(
                    (item) =>
                        item[compareKey]
                            ?.toString()
                            .toLowerCase()
                            .contains(filter.toLowerCase()) ??
                        false,
                  )
                  .toList(),
            ),
            selectedItem: value,
            onChanged: enabled
                ? (newValue) {
                    onChanged?.call(newValue);
                    if (label == 'Customer' && newValue != null) {
                      final company = newValue['company']?.toString() ??
                          _selectedCompany ??
                          'Sakthi Steel Industries Ltd';
                      if (company != _selectedCompany) {
                        setState(() {
                          _selectedCompany = company;
                          _companySelected = true;
                          _taxTemplates = [];
                          _selectedTaxTemplate = null;
                          _selectedTaxes = [];
                        });
                        _fetchTaxTemplates();
                      }
                    } else if (label == 'Company') {
                      setState(() {
                        _taxTemplates = [];
                        _selectedTaxTemplate = null;
                        _selectedTaxes = [];
                      });
                      _fetchTaxTemplates();
                    } else if (label == 'Sales Taxes and Charges Template') {
                      setState(() {
                        _selectedTaxTemplate =
                            newValue?['template_name']?.toString();
                        _updateSelectedTaxes();
                      });
                    }
                  }
                : null,
            enabled: enabled,
            compareFn: (item1, item2) => item1[compareKey] == item2[compareKey],
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  labelText: 'Search $label',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            dropdownBuilder: (context, selectedItem) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                selectedItem?[compareKey]?.toString() ?? 'Select $label',
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            itemAsString: (item) => item[compareKey]?.toString() ?? '',
            validator: (value) => validatorMessage != null && value == null
                ? validatorMessage
                : null,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)
              ],
            ),
            child: Row(
              children: [
                _buildTableHeaderCell('No.', 50),
                _buildTableHeaderCell('Item Name', 200),
                _buildTableHeaderCell('Qty', 90),
                _buildTableHeaderCell('UOM', 130),
                _buildTableHeaderCell('Disc %', 90),
                _buildTableHeaderCell('Disc ₹', 90),
                _buildTableHeaderCell('Amount (₹)', 100),
                _buildTableHeaderCell('', 50),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._selectedItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildTableCell(
                    Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    50,
                  ),
                  _buildTableCell(
                    Text(
                      item['item_name'],
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    200,
                  ),
                  _buildTableCell(
                    TextFormField(
                      controller: item['quantityController'],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                      ),
                      onChanged: (value) => _updateItem(index, quantity: value),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    90,
                  ),
                  _buildTableCell(
                    DropdownButtonFormField<String>(
                      value: item['selectedUom'],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                      ),
                      items: _uomList
                          .map((uom) => DropdownMenuItem<String>(
                                value: uom,
                                child: Text(
                                  uom,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (newValue) =>
                          _updateItem(index, uom: newValue),
                    ),
                    130,
                  ),
                  _buildTableCell(
                    TextFormField(
                      controller: item['discountPercentController'],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                      ),
                      onChanged: (value) =>
                          _updateItem(index, discountPercent: value),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    90,
                  ),
                  _buildTableCell(
                    TextFormField(
                      controller: item['discountAmountController'],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                      ),
                      onChanged: (value) =>
                          _updateItem(index, discountAmount: value),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    90,
                  ),
                  _buildTableCell(
                    TextFormField(
                      controller: item['amountController'],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                      ),
                      onChanged: (value) => _updateItem(index, amount: value),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    100,
                  ),
                  _buildTableCell(
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeItem(index),
                    ),
                    50,
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTaxesTable(BuildContext context) {
    if (_selectedTaxTemplate == null || _selectedTaxes.isEmpty)
      return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          columns: const [
            DataColumn(
                label:
                    Text('No.', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Charge Type',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Account Head',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Tax Rate',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Amount (₹)',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Total (₹)',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _selectedTaxes.asMap().entries.map((entry) {
            final index = entry.key;
            final tax = entry.value;
            final currentCompanyAbbr = _companyList.firstWhere(
              (company) => company['name'] == _selectedCompany,
              orElse: () => {'abbr': 'SSIL'},
            )['abbr'];
            final isEditable = (tax['charge_type'] == 'On Item Quantity' &&
                    (tax['account_head'] ==
                            'Freight and Forwarding Charges - $currentCompanyAbbr' ||
                        tax['account_head'] ==
                            'HANDLING CHARGES - $currentCompanyAbbr')) ||
                tax['charge_type'] == 'Actual';
            return DataRow(
              cells: [
                DataCell(Text('${index + 1}', textAlign: TextAlign.center)),
                DataCell(Text(tax['charge_type']?.toString() ?? '')),
                DataCell(Text(tax['account_head']?.toString() ?? '')),
                DataCell(
                  isEditable
                      ? TextFormField(
                          controller:
                              tax['rateController'] as TextEditingController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (value) => _updateTaxRate(index, value),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 14),
                          textAlign: TextAlign.center,
                        )
                      : Text('${tax['rate']?.toString() ?? '0'}',
                          textAlign: TextAlign.center),
                ),
                DataCell(Text((tax['amount'] ?? 0.0).toStringAsFixed(2),
                    textAlign: TextAlign.right)),
                DataCell(Text((tax['total'] ?? 0.0).toStringAsFixed(2),
                    textAlign: TextAlign.right)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String title, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(8.0),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.bold),
        textAlign: title == 'No.' ||
                title == 'Qty' ||
                title == 'Disc %' ||
                title == 'Disc ₹' ||
                title == 'Amount (₹)'
            ? TextAlign.center
            : TextAlign.left,
      ),
    );
  }

  Widget _buildTableCell(Widget child, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialData == null ? 'Create Quotation' : 'Edit Quotation',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        'Quotation To',
                        _quotationToController,
                        validatorMessage: 'Quotation To is required',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Transaction Date',
                        TextEditingController(
                            text: DateFormat('yyyy-MM-dd')
                                .format(_transactionDate)),
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        validatorMessage: 'Transaction Date is required',
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Company',
                        _companyList.firstWhere(
                          (company) => company['name'] == _selectedCompany,
                          orElse: () => {'name': _selectedCompany ?? ''},
                        ),
                        _companyList,
                        (value) => setState(() {
                          _selectedCompany = value?['name']?.toString();
                          _companySelected = true;
                        }),
                        'name',
                        validatorMessage: 'Company is required',
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Customer',
                        _selectedCustomer,
                        _customersList,
                        (value) => setState(() => _selectedCustomer = value),
                        'customer_name',
                        validatorMessage: 'Customer is required',
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Salesperson',
                        _selectedSalesperson,
                        _salespersonsList,
                        (value) => setState(() => _selectedSalesperson = value),
                        'salesperson_name',
                        validatorMessage: 'Salesperson is required',
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Cost Center',
                        _costCenters.isNotEmpty
                            ? {'name': _selectedCostCenter}
                            : null,
                        _costCenters,
                        (value) => setState(
                            () => _selectedCostCenter = value?['name']),
                        'name',
                        validatorMessage: 'Cost Center is required',
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableDropdownField(
                        'Sales Taxes and Charges Template',
                        _taxTemplates.firstWhere(
                          (template) =>
                              template['template_name'] == _selectedTaxTemplate,
                          orElse: () =>
                              {'template_name': _selectedTaxTemplate ?? ''},
                        ),
                        _taxTemplates,
                        (value) => setState(() {}),
                        'template_name',
                        enabled: _companySelected,
                      ),
                      _buildTaxesTable(context),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final selected = await showSearch(
                                  context: context,
                                  delegate: ItemSearchDelegate(
                                      _itemsList, widget.serverUrl),
                                );
                                if (selected != null)
                                  _addItemToResult(selected);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 6)
                                  ],
                                ),
                                child: Text(
                                  'Select Item',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner,
                                color: Color(0xFF195533)),
                            onPressed: _scanBarcode,
                          ),
                        ],
                      ),
                      if (_selectedItems.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Selected Items',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _buildItemsTable(context),
                      ],
                      const SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Quantity:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                        ),
                                  ),
                                  Text(
                                    '$_cachedTotalQuantity',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Amount:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                        ),
                                  ),
                                  Text(
                                    '₹${_cachedTotalAmount.toStringAsFixed(2)}',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                              if (_getTotalTaxAmount() > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Tax:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                    ),
                                    Text(
                                      '₹${_getTotalTaxAmount().toStringAsFixed(2)}',
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Grand Total:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                        ),
                                  ),
                                  Text(
                                    '₹${_cachedGrandTotal.toStringAsFixed(2)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveQuotation,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text(
                                'Save Quotation',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final selected = await showSearch(
            context: context,
            delegate: ItemSearchDelegate(_itemsList, widget.serverUrl),
          );
          if (selected != null) _addItemToResult(selected);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CustomerSearchDelegate extends SearchDelegate<dynamic> {
  final List<dynamic> customers;
  CustomerSearchDelegate(this.customers);
  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
        appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
        textTheme: Theme.of(context).textTheme.copyWith(
              titleLarge:
                  const TextStyle(fontFamily: 'Poppins', color: Colors.white),
            ),
      );
  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );
  @override
  Widget buildResults(BuildContext context) {
    final results = customers
        .where(
          (customer) =>
              (customer['name']
                      ?.toString()
                      .toLowerCase()
                      .contains(query.toLowerCase()) ??
                  false) ||
              (customer['customer_name']
                      ?.toString()
                      .toLowerCase()
                      .contains(query.toLowerCase()) ??
                  false),
        )
        .toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final customer = results[index];
        return ListTile(
          title: Text(customer['customer_name'],
              style: Theme.of(context).textTheme.bodyLarge),
          onTap: () => close(context, customer),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

class SalespersonSearchDelegate extends SearchDelegate<dynamic> {
  final List<dynamic> salespersons;
  SalespersonSearchDelegate(this.salespersons);
  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
        appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
        textTheme: Theme.of(context).textTheme.copyWith(
              titleLarge:
                  const TextStyle(fontFamily: 'Poppins', color: Colors.white),
            ),
      );
  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );
  @override
  Widget buildResults(BuildContext context) {
    final results = salespersons
        .where(
          (salesperson) => salesperson['salesperson_name']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final salesperson = results[index];
        return ListTile(
          title: Text(salesperson['salesperson_name'],
              style: Theme.of(context).textTheme.bodyLarge),
          onTap: () => close(context, salesperson),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

class ItemSearchDelegate extends SearchDelegate<dynamic> {
  final List<dynamic> items;
  final String serverUrl;
  ItemSearchDelegate(this.items, this.serverUrl);
  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
        // Search bar colors for better visibility
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.white,
          backgroundColor: Color(0xFF195533),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          // Input text color
          hintStyle: TextStyle(color: Colors.white54),
          labelStyle: TextStyle(color: Colors.white),
          border: InputBorder.none,
        ),
        textTheme: Theme.of(context).textTheme.copyWith(
              titleLarge:
                  const TextStyle(fontFamily: 'Poppins', color: Colors.white),
              // Text color in the search field
              bodyLarge: const TextStyle(color: Colors.white),
            ),
      );
  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );
  @override
  Widget buildResults(BuildContext context) {
    final results = items
        .where(
          (item) =>
              item['item_name']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              item['item_code']
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          leading: item['image'] != null
              ? CachedNetworkImage(
                  imageUrl: item['image'].startsWith('http')
                      ? item['image']
                      : '$serverUrl${item['image']}',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  placeholder: (context, _) =>
                      const CircularProgressIndicator(),
                  errorWidget: (context, _, __) =>
                      const Icon(Icons.broken_image),
                )
              : const Icon(Icons.image_not_supported),
          title: Text(item['item_name'],
              style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text('Code: ${item['item_code']}',
              style: Theme.of(context).textTheme.bodyMedium),
          onTap: () => close(context, item),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}
