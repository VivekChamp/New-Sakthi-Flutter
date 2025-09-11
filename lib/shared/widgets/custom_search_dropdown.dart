import 'package:flutter/material.dart';

/// A custom searchable dropdown widget.
class CustomSearchableDropdown<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<T> items;
  final Function(T?) onChanged;
  final String Function(T) itemAsString;
  final String? hintText;
  final String? validatorMessage;

  const CustomSearchableDropdown({
    super.key,
    required this.label,
    this.value,
    required this.items,
    required this.onChanged,
    required this.itemAsString,
    this.hintText,
    this.validatorMessage,
  });

  @override
  State<CustomSearchableDropdown<T>> createState() =>
      _CustomSearchableDropdownState<T>();
}

class _CustomSearchableDropdownState<T>
    extends State<CustomSearchableDropdown<T>> {
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textEditingController.text = widget.value != null
        ? widget.itemAsString(widget.value as T)
        : '';
  }

  @override
  void didUpdateWidget(covariant CustomSearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _textEditingController.text = widget.value != null
          ? widget.itemAsString(widget.value as T)
          : '';
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _SearchDialog(
          items: widget.items,
          itemAsString: widget.itemAsString,
          onChanged: (selectedValue) {
            widget.onChanged(selectedValue);
            if (selectedValue != null) {
              _textEditingController.text = widget.itemAsString(selectedValue);
            } else {
              _textEditingController.clear();
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _textEditingController,
          readOnly: true,
          onTap: _showSearchDialog,
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'Select ${widget.label}',
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          validator: (value) {
            if (widget.validatorMessage != null &&
                (value == null || value.isEmpty)) {
              return widget.validatorMessage;
            }
            return null;
          },
        ),
      ],
    );
  }
}

/// The dialog that handles the search functionality.
class _SearchDialog<T> extends StatefulWidget {
  final List<T> items;
  final Function(T?) onChanged;
  final String Function(T) itemAsString;

  const _SearchDialog({
    required this.items,
    required this.onChanged,
    required this.itemAsString,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  List<T> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = widget.items.where((item) {
        return widget.itemAsString(item).toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Select Item'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  return ListTile(
                    title: Text(widget.itemAsString(item)),
                    onTap: () {
                      widget.onChanged(item);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
