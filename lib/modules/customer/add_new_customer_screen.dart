import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sakthi_erp/shared/widgets/custom_search_dropdown.dart';
import 'package:sakthi_erp/utils/error_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'dart:convert';

class AddNewCustomerScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;
  final String email;
  const AddNewCustomerScreen({
    super.key,
    required this.serverUrl,
    required this.sid,
    required this.email,
  });

  @override
  State<AddNewCustomerScreen> createState() => _AddNewCustomerScreenState();
}

class _AddNewCustomerScreenState extends State<AddNewCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for various text fields
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController addressLine1Controller = TextEditingController();
  final TextEditingController addressLine2Controller = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController districtController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactPersonNameController =
      TextEditingController();
  final TextEditingController dateOfEstdController = TextEditingController();
  final TextEditingController brandDealingController = TextEditingController();
  final TextEditingController annualTurnoverController =
      TextEditingController();
  final TextEditingController msmeCatController = TextEditingController();
  final TextEditingController classificationController =
      TextEditingController();
  final TextEditingController accountNoController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController branchController = TextEditingController();
  final TextEditingController ifscCodeController = TextEditingController();
  final TextEditingController remarksBySalesPersonController =
      TextEditingController();
  final TextEditingController remarksByRMController = TextEditingController();
  final TextEditingController remarksByGMController = TextEditingController();

  // State variables for dropdowns and other data
  String? selectedCustomerType = 'Company';
  String? selectedSalesPersonId;
  String? selectedCountry = 'India';
  String? selectedState;
  String? selectedGstCategory;
  String? selectedPhoneCode = '+91';
  String? selectedAddressType = 'Billing';
  String? selectedEmirate;
  String? selectedAccountManager;
  List<Map<String, dynamic>> salesPersons = [];
  List<String> accountManagerEmails = [];
  List<String> bankNames = [];
  List<String> customerTypes = ['Company', 'Individual', 'Partnership'];
  List<String> countries = [
    'India',
    'United States',
    'United Kingdom',
    'United Arab Emirates',
    'Australia',
    'Canada',
    'Germany',
    'France',
    'Japan',
    'China',
    'Singapore',
  ];
  Map<String, List<String>> statesByCountry = {
    'India': [
      'Kerala',
      'Tamil Nadu',
      'Karnataka',
      'Maharashtra',
      'Delhi',
      'Uttar Pradesh',
    ],
    'United States': ['California', 'Texas', 'New York', 'Florida'],
    'United Arab Emirates': [
      'Dubai',
      'Abu Dhabi',
      'Sharjah',
      'Ajman',
      'Umm Al-Quwain',
      'Ras Al Khaimah',
      'Fujairah',
    ],
  };
  List<String> gstCategories = [
    'Registered Regular',
    'Registered Composition',
    'Unregistered',
    'SEZ',
    'Overseas',
    'Deemed Export',
    'UIN Holders',
    'Tax Deductor',
    'Tax Collector',
    'Input Service Distributor',
  ];
  List<String> addressTypes = ['Billing', 'Shipping', 'Home', 'Work', 'Other'];
  Map<String, String> countryISDCodes = {
    'India': '+91',
    'United States': '+1',
    'United Kingdom': '+44',
    'United Arab Emirates': '+971',
    'Australia': '+61',
  };
  Map<String, File?> attachments = {
    'custom_adhar_card': null,
    'custom_other_document': null,
    'custom_bank_statement': null,
    'custom_pan_card': null,
  };
  String latitude = '';
  String longitude = '';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    customerNameController.dispose();
    addressLine1Controller.dispose();
    addressLine2Controller.dispose();
    cityController.dispose();
    districtController.dispose();
    pincodeController.dispose();
    phoneController.dispose();
    emailController.dispose();
    contactPersonNameController.dispose();
    dateOfEstdController.dispose();
    brandDealingController.dispose();
    annualTurnoverController.dispose();
    msmeCatController.dispose();
    classificationController.dispose();
    accountNoController.dispose();
    bankNameController.dispose();
    branchController.dispose();
    ifscCodeController.dispose();
    remarksBySalesPersonController.dispose();
    remarksByRMController.dispose();
    remarksByGMController.dispose();
    super.dispose();
  }

  /// Fetches initial data required for the form.
  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchSalesPersons(),
        fetchEmails(),
        _fetchBankNames(),
      ]);
    } catch (e) {
      if (mounted) showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Fetches the list of salespersons from the server.
  Future<void> _fetchSalesPersons() async {
    final url =
        "${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_salesperson";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            salesPersons = List<Map<String, dynamic>>.from(
              data['message']['data'],
            );
            final currentUserSalesPerson = salesPersons.firstWhere(
              (sp) =>
                  sp['sales_person_name'] ==
                  widget.email.split('@').first.toUpperCase(),
              orElse: () => {},
            );
            if (currentUserSalesPerson.isNotEmpty) {
              selectedSalesPersonId = currentUserSalesPerson['name'];
            } else {
              selectedSalesPersonId =
                  salesPersons.isNotEmpty ? salesPersons.first['name'] : null;
            }
          });
        }
      } else {
        throw Exception('Failed to load salespersons: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches a list of user emails for the Account Manager dropdown.
  Future<void> fetchEmails() async {
    final url =
        "${widget.serverUrl}/api/resource/User?fields=[\"email\"]&filters=[[\"enabled\", \"=\", 1]]";
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'Cookie': 'sid=${widget.sid}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body)['data'];
        if (mounted) {
          setState(() {
            accountManagerEmails =
                data.map((user) => user['email'] as String).toList();
            if (accountManagerEmails.contains(widget.email)) {
              selectedAccountManager = widget.email;
            } else {
              selectedAccountManager = accountManagerEmails.isNotEmpty
                  ? accountManagerEmails.first
                  : null;
            }
          });
        }
      } else {
        throw Exception('Failed to fetch emails: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches bank names for the autocomplete field.
  Future<void> _fetchBankNames() async {
    final url =
        "${widget.serverUrl}/api/resource/Bank?fields=[\"bank_name\"]&limit_page_length=0";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cookie': 'sid=${widget.sid}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> banks = data['data'];
        if (mounted) {
          setState(() {
            bankNames =
                banks.map((b) => b['bank_name'].toString()).toSet().toList();
          });
        }
      } else {
        debugPrint('Failed to load bank names: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching bank names: $e');
    }
  }

  /// Creates a new bank record if it doesn't exist.
  Future<bool> _createBank(String bankName) async {
    final url = "${widget.serverUrl}/api/resource/Bank";
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'bank_name': bankName}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            if (!bankNames.contains(bankName)) {
              bankNames.add(bankName);
            }
          });
        }
        return true;
      } else {
        debugPrint('Failed to create bank: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error creating bank: $e');
      return false;
    }
  }

  /// Gets the current device location.
  Future<void> _getCurrentLocation() async {
    // ... (Existing _getCurrentLocation logic remains unchanged)
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      showErrorDialog(
        context,
        'Location Error',
        'Location services are disabled.',
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        showErrorDialog(
          context,
          'Location Error',
          'Location permissions are denied.',
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      showErrorDialog(
        context,
        'Location Error',
        'Location permissions are permanently denied.',
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        latitude = position.latitude.toString();
        longitude = position.longitude.toString();
      });
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        cityController.text = place.locality ?? '';
        pincodeController.text = place.postalCode ?? '';
        districtController.text = place.subAdministrativeArea ?? '';
        if (place.country != null && countries.contains(place.country)) {
          selectedCountry = place.country;
        } else {
          selectedCountry = 'India';
        }
        if (selectedCountry == 'India' &&
            place.administrativeArea != null &&
            statesByCountry['India']!.contains(place.administrativeArea)) {
          selectedState = place.administrativeArea;
        } else if (selectedCountry == 'United Arab Emirates' &&
            place.administrativeArea != null &&
            statesByCountry['United Arab Emirates']!
                .contains(place.administrativeArea)) {
          selectedEmirate = place.administrativeArea;
        } else {
          selectedState = null;
          selectedEmirate = null;
        }
      }
    } catch (e) {
      showErrorDialog(
        context,
        'Location Error',
        'Error getting location: $e',
      );
    }
  }

  /// Generates a Google Maps link.
  String _generateMapLink(String lat, String lon) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
  }

  /// Opens the file picker.
  Future<void> _pickFile(String attachmentKey) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        attachments[attachmentKey] = File(result.files.single.path!);
      });
    }
  }

  /// Opens a selected file.
  Future<void> _openFile(File file) async {
    try {
      await OpenFile.open(file.path);
    } catch (e) {
      showErrorDialog(
        context,
        'File Error',
        'Error opening file: $e',
      );
    }
  }

  /// Creates a new address record.
  Future<String?> _createAddress(String customerId) async {
    // ... (Existing _createAddress logic remains unchanged)
    if (addressLine1Controller.text.isEmpty &&
        addressLine2Controller.text.isEmpty &&
        cityController.text.isEmpty &&
        pincodeController.text.isEmpty &&
        selectedCountry == null &&
        selectedState == null &&
        selectedEmirate == null) {
      return null;
    }

    final url = "${widget.serverUrl}/api/resource/Address";
    final addressData = {
      'address_title': customerNameController.text,
      'address_type': selectedAddressType,
      'address_line1': addressLine1Controller.text,
      'address_line2': addressLine2Controller.text,
      'city': cityController.text,
      'district': districtController.text,
      'state': selectedCountry == 'United Arab Emirates'
          ? selectedEmirate
          : selectedState,
      'country': selectedCountry,
      'pincode': pincodeController.text,
      'links': [
        {'link_doctype': 'Customer', 'link_name': customerId},
      ],
    };
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: json.encode(addressData),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body)['data']['name'];
      } else {
        throw response.body;
      }
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
      return null;
    }
  }

  /// Creates a new contact record.
  Future<String?> _createContact(String customerId) async {
    // ... (Existing _createContact logic remains unchanged)
    if (contactPersonNameController.text.isEmpty &&
        emailController.text.isEmpty &&
        phoneController.text.isEmpty) {
      return null;
    }

    final url = "${widget.serverUrl}/api/resource/Contact";
    final contactData = {
      'first_name': contactPersonNameController.text.isNotEmpty
          ? contactPersonNameController.text
          : customerNameController.text,
      if (emailController.text.isNotEmpty)
        'email_ids': [
          {'email_id': emailController.text, 'is_primary': 1},
        ],
      if (phoneController.text.isNotEmpty)
        'phone_nos': [
          {
            'phone': "$selectedPhoneCode${phoneController.text}",
            'is_primary_phone': 1,
          },
        ],
      'links': [
        {'link_doctype': 'Customer', 'link_name': customerId},
      ],
    };
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: json.encode(contactData),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body)['data']['name'];
      } else {
        throw response.body;
      }
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
      return null;
    }
  }

  /// Uploads an attachment file.
  Future<void> _uploadAttachment(
      String customerId, String fieldName, File file) async {
    final url = "${widget.serverUrl}/api/method/upload_file";
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers['Cookie'] = 'sid=${widget.sid}'
      ..fields['doctype'] = 'Customer'
      ..fields['docname'] = customerId
      ..fields['fieldname'] = fieldName
      ..fields['filename'] = file.path.split('/').last
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    if (response.statusCode != 200) {
      throw 'Failed to upload attachment: ${response.statusCode}';
    }
  }

  /// Main function to handle the creation of a new customer.
  Future<void> _addNewCustomer() async {
    if (!_formKey.currentState!.validate()) {
      showErrorDialog(
        context,
        'Validation Error',
        'Please fill all required fields.',
      );
      return;
    }

    setState(() => _isLoading = true);

    final String enteredBankName = bankNameController.text.trim();
    if (enteredBankName.isNotEmpty && !bankNames.contains(enteredBankName)) {
      final bool bankCreated = await _createBank(enteredBankName);
      if (!bankCreated) {
        showApiErrorDialog(context,
            message:
                'Failed to create new bank "$enteredBankName". Customer not saved.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    try {
      // 1. Create Customer
      final customMapLink = _generateMapLink(latitude, longitude);
      final customerData = {
        'customer_name': customerNameController.text,
        'customer_type': selectedCustomerType,
        'custom_date_of_estd': dateOfEstdController.text,
        'custom_brand_dealing': brandDealingController.text,
        'custom_annual_turnover': annualTurnoverController.text,
        'custom_msme_cat': msmeCatController.text,
        'custom_classification': classificationController.text,
        'custom_account_no': accountNoController.text,
        'custom_bank_name': bankNameController.text,
        'custom_branch': branchController.text,
        'custom_ifsc_code': ifscCodeController.text,
        'custom_remarks_by_sales_person': remarksBySalesPersonController.text,
        'custom_remarks_by_rm': remarksByRMController.text,
        'custom_remarks_by_gm': remarksByGMController.text,
        'account_manager': selectedAccountManager,
        'sales_team': [
          {
            'sales_person': selectedSalesPersonId,
            'allocated_percentage': 100.0,
          },
        ],
        'custom_country': selectedCountry,
        'custom_latitude': latitude,
        'custom_longtitude': longitude,
        'custom_map_link': customMapLink,
        'custom_gst_category': selectedGstCategory,
      };
      final customerResponse = await http.post(
        Uri.parse("${widget.serverUrl}/api/resource/Customer"),
        headers: {
          'Cookie': 'sid=${widget.sid}',
          'Content-Type': 'application/json',
        },
        body: json.encode(customerData),
      );
      if (customerResponse.statusCode != 200 &&
          customerResponse.statusCode != 201) {
        throw customerResponse.body;
      }
      final customerId = json.decode(customerResponse.body)['data']['name'];

      // 2. Create Address
      final addressId = await _createAddress(customerId);

      // 3. Create Contact
      final contactId = await _createContact(customerId);

      // 4. Update Customer with primary address and contact if created
      if (addressId != null || contactId != null) {
        final updateData = {
          if (addressId != null) 'customer_primary_address': addressId,
          if (contactId != null) 'customer_primary_contact': contactId,
        };
        final updateResponse = await http.put(
          Uri.parse("${widget.serverUrl}/api/resource/Customer/$customerId"),
          headers: {
            'Cookie': 'sid=${widget.sid}',
            'Content-Type': 'application/json',
          },
          body: json.encode(updateData),
        );
        if (updateResponse.statusCode != 200) {
          throw updateResponse.body;
        }
      }

      // 5. Upload Attachments
      for (var entry in attachments.entries) {
        if (entry.value != null) {
          await _uploadAttachment(customerId, entry.key, entry.value!);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return true to refresh the list
    } catch (e) {
      showApiErrorDialog(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Customer')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSection(
                      title: 'Basic Information',
                      children: [
                        _buildTextField(
                          controller: customerNameController,
                          label: 'Customer Name',
                          isRequired: true,
                        ),
                        _buildDropdownField(
                          label: 'Customer Type',
                          value: selectedCustomerType,
                          items: customerTypes,
                          onChanged: (val) =>
                              setState(() => selectedCustomerType = val),
                          isRequired: true,
                        ),
                        CustomSearchableDropdown<Map<String, dynamic>>(
                          label: 'Sales Person',
                          items: salesPersons,
                          value: salesPersons.firstWhere(
                            (sp) => sp['name'] == selectedSalesPersonId,
                            orElse: () => {},
                          ),
                          itemAsString: (sp) => sp['sales_person_name'] ?? '',
                          onChanged: (val) => setState(
                            () => selectedSalesPersonId = val?['name'],
                          ),
                          validatorMessage: 'Sales Person is required.',
                        ),
                        _buildDropdownField(
                          label: 'GST Category',
                          value: selectedGstCategory,
                          items: gstCategories,
                          onChanged: (val) =>
                              setState(() => selectedGstCategory = val),
                        ),
                        _buildTextField(
                          controller: dateOfEstdController,
                          label: 'Date of Establishment',
                          keyboardType: TextInputType.datetime,
                        ),
                        _buildTextField(
                          controller: brandDealingController,
                          label: 'Brand Dealing',
                        ),
                        _buildTextField(
                          controller: annualTurnoverController,
                          label: 'Annual Turnover',
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField(
                          controller: msmeCatController,
                          label: 'MSME Category',
                        ),
                        _buildTextField(
                          controller: classificationController,
                          label: 'Classification',
                        ),
                      ],
                    ),
                    _buildSection(
                      title: 'Address Information',
                      children: [
                        _buildDropdownField(
                          label: 'Address Type',
                          value: selectedAddressType,
                          items: addressTypes,
                          onChanged: (val) =>
                              setState(() => selectedAddressType = val),
                        ),
                        _buildTextField(
                          controller: addressLine1Controller,
                          label: 'Address Line 1',
                        ),
                        _buildTextField(
                          controller: addressLine2Controller,
                          label: 'Address Line 2',
                        ),
                        _buildTextField(
                          controller: cityController,
                          label: 'City',
                        ),
                        _buildTextField(
                          controller: districtController,
                          label: 'District',
                        ),
                        _buildDropdownField(
                          label: 'Country',
                          value: selectedCountry,
                          items: countries,
                          onChanged: (val) => setState(() {
                            selectedCountry = val;
                            selectedPhoneCode = countryISDCodes[val] ?? '+91';
                            selectedState = null;
                            selectedEmirate = null;
                          }),
                        ),
                        if (selectedCountry == 'United Arab Emirates')
                          _buildDropdownField(
                            label: 'Emirate',
                            value: selectedEmirate,
                            items:
                                statesByCountry['United Arab Emirates'] ?? [],
                            onChanged: (val) =>
                                setState(() => selectedEmirate = val),
                          ),
                        if (selectedCountry != null &&
                            selectedCountry != 'United Arab Emirates')
                          _buildDropdownField(
                            label: 'State',
                            value: selectedState,
                            items: statesByCountry[selectedCountry] ?? [],
                            onChanged: (val) =>
                                setState(() => selectedState = val),
                          ),
                        _buildTextField(
                          controller: pincodeController,
                          label: 'Pincode',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                    _buildSection(
                      title: 'Contact Information',
                      children: [
                        _buildPhoneField(),
                        _buildTextField(
                          controller: emailController,
                          label: 'Email Address',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _buildTextField(
                          controller: contactPersonNameController,
                          label: 'Contact Person',
                        ),
                        _buildDropdownField(
                          label: 'Account Manager Email',
                          value: selectedAccountManager,
                          items: accountManagerEmails,
                          onChanged: (val) =>
                              setState(() => selectedAccountManager = val),
                        ),
                      ],
                    ),
                    _buildSection(
                      title: 'Bank Details',
                      children: [
                        _buildTextField(
                          controller: accountNoController,
                          label: 'Account Number',
                          keyboardType: TextInputType.number,
                        ),
                        _buildBankAutocompleteField(),
                        _buildTextField(
                          controller: branchController,
                          label: 'Branch',
                        ),
                        _buildTextField(
                          controller: ifscCodeController,
                          label: 'IFSC Code',
                        ),
                      ],
                    ),
                    _buildSection(
                      title: 'Remarks Details',
                      children: [
                        _buildTextField(
                          controller: remarksBySalesPersonController,
                          label: 'Remarks by Sales Person',
                        ),
                        _buildTextField(
                          controller: remarksByRMController,
                          label: 'Remarks by RM',
                        ),
                        _buildTextField(
                          controller: remarksByGMController,
                          label: 'Remarks by GM',
                        ),
                      ],
                    ),
                    _buildSection(
                      title: 'Attachments',
                      children: [
                        _buildAttachmentField(
                            'Aadhar Card', 'custom_adhar_card'),
                        _buildAttachmentField(
                            'Other Document', 'custom_other_document'),
                        _buildAttachmentField(
                            'Bank Statement', 'custom_bank_statement'),
                        _buildAttachmentField('PAN Card', 'custom_pan_card'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _addNewCustomer,
                      child: const Text('Save Customer'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildBankAutocompleteField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: bankNameController.text),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          }
          return bankNames.where((String option) {
            return option
                .toLowerCase()
                .contains(textEditingValue.text.toLowerCase());
          });
        },
        onSelected: (String selection) {
          bankNameController.text = selection;
          _formKey.currentState?.validate();
        },
        fieldViewBuilder: (BuildContext context,
            TextEditingController fieldController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted) {
          fieldController.addListener(() {
            bankNameController.text = fieldController.text;
          });

          return TextFormField(
            controller: fieldController,
            focusNode: fieldFocusNode,
            decoration: const InputDecoration(
              labelText: 'Bank Name',
              hintText: 'Type to search or add new bank',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Bank Name is required';
              }
              return null;
            },
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return InkWell(
                      onTap: () {
                        onSelected(option);
                      },
                      child: ListTile(
                        title: Text(option),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhoneField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedPhoneCode,
              decoration: const InputDecoration(labelText: 'Code'),
              items: countryISDCodes.values
                  .map((code) => DropdownMenuItem(
                        value: code,
                        child: Text(
                          code,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => selectedPhoneCode = val),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 7,
            child: TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentField(String label, String fieldName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              ElevatedButton(
                onPressed: () => _pickFile(fieldName),
                child: const Text('Pick File'),
              ),
            ],
          ),
          if (attachments[fieldName] != null)
            ListTile(
              title: Text(attachments[fieldName]!.path.split('/').last),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () => _openFile(attachments[fieldName]!),
              ),
            ),
        ],
      ),
    );
  }
}

