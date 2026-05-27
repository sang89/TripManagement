import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import '../services/trip_places_service.dart';

class DestinationSearchDialog extends StatefulWidget {
  final TripPlacesService placesService;
  final String initialQuery;
  final ValueChanged<TripPlaceDetails> onSelected;

  const DestinationSearchDialog({
    super.key,
    required this.placesService,
    required this.onSelected,
    this.initialQuery = '',
  });

  @override
  State<DestinationSearchDialog> createState() =>
      _DestinationSearchDialogState();
}

class _DestinationSearchDialogState extends State<DestinationSearchDialog> {
  late final TextEditingController _ctrl;
  Timer? _debounce;
  bool _loading = false;
  List<PlacePrediction> _suggestions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.length >= 3) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _search(widget.initialQuery));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.length < 3) {
      setState(() { _suggestions = []; _error = null; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value) async {
    setState(() { _loading = true; _error = null; });
    final result = await widget.placesService.fetchSuggestions(value);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.hasError) {
        _suggestions = [];
        _error = result.errorMessage;
      } else if (result.predictions.isEmpty) {
        _suggestions = [];
        _error = 'No results found.';
      } else {
        _suggestions = result.predictions;
        _error = null;
      }
    });
  }

  Future<void> _select(PlacePrediction prediction) async {
    setState(() { _loading = true; _suggestions = []; });

    final details = await widget.placesService
        .fetchDetails(prediction.placeId, prediction.description);
    if (!mounted) return;

    if (details == null) {
      setState(() {
        _loading = false;
        _error = 'Could not load location details.';
      });
      return;
    }

    Navigator.of(context).pop();
    widget.onSelected(details);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.travel_explore,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Search destination',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'City, address, or place name…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary),
                        ))
                    : _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() { _suggestions = []; _error = null; });
                            },
                          )
                        : null,
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(_error!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ),
          if (_suggestions.isNotEmpty) ...[
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (ctx, i) {
                  final s = _suggestions[i];
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on,
                          color: AppTheme.primary, size: 18),
                    ),
                    title: Text(s.mainText,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: s.secondaryText.isNotEmpty
                        ? Text(s.secondaryText,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]))
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    onTap: () => _select(s),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
