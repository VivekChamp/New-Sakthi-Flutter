import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VisitEntryListScreen extends StatefulWidget {
  final String serverUrl;
  final String sid;

  const VisitEntryListScreen({
    Key? key,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _VisitEntryListScreenState createState() => _VisitEntryListScreenState();
}

class _VisitEntryListScreenState extends State<VisitEntryListScreen> {
  List<dynamic> _visitEntries = [];
  List<dynamic> _filteredVisitEntries = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVisitEntries();
    _searchController.addListener(() {
      _filterVisitEntries(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchVisitEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url =
        '${widget.serverUrl}/api/method/vps_mobile.vps_mobile.role_api.get_visit_entries';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message']['status'] == 'success') {
          setState(() {
            _visitEntries = List.from(data['message']['data'] ?? []);
            _filteredVisitEntries = List.from(_visitEntries);
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          throw Exception('API error: ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching visit entries: $error';
      });
    }
  }

  void _filterVisitEntries(String query) {
    setState(() {
      _filteredVisitEntries = query.isEmpty
          ? List.from(_visitEntries)
          : _visitEntries
              .where(
                (v) =>
                    (v['customer_name'] ?? '').toLowerCase().contains(
                          query.toLowerCase(),
                        ) ||
                    (v['name'] ?? '').toLowerCase().contains(
                          query.toLowerCase(),
                        ),
              )
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Visit Entries',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/createVisitEntry',
                arguments: {'serverUrl': widget.serverUrl, 'sid': widget.sid},
              ).then((_) => _fetchVisitEntries());
            },
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).colorScheme.background,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xff000000),
                  fontFamily: 'Poppins',
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name or customer',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontFamily: 'Poppins',
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xff65C18C),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xff65C18C),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchVisitEntries,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.white,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xff65C18C),
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _errorMessage!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        fontSize: 18,
                                        fontFamily: 'Poppins',
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchVisitEntries,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(fontFamily: 'Poppins'),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _filteredVisitEntries.isEmpty
                            ? Center(
                                child: Text(
                                  'No visit entries available',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        fontSize: 18,
                                        fontFamily: 'Poppins',
                                      ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredVisitEntries.length,
                                itemBuilder: (ctx, index) {
                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 4),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        child: Text(
                                          (_filteredVisitEntries[index]
                                                      ['customer_name'] ??
                                                  'N')[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        _filteredVisitEntries[index]['name'] ??
                                            'No name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onBackground,
                                          fontSize: 16,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      subtitle: Text(
                                        _filteredVisitEntries[index]
                                                ['customer_name'] ??
                                            'No customer',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onBackground
                                              .withOpacity(0.6),
                                          fontSize: 14,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.info_outline,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/visitEntryDetail',
                                          arguments: {
                                            'visitEntryName':
                                                _filteredVisitEntries[index]
                                                    ['name'],
                                            'serverUrl': widget.serverUrl,
                                            'sid': widget.sid,
                                          },
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
