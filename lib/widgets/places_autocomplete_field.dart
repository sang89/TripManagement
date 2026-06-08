import 'dart:async';

import 'package:flutter/material.dart';
import '../services/trip_places_service.dart';

/// A TextFormField that shows live Google Places suggestions as a dropdown
/// while the user types, but also accepts free-form text.
///
/// [controller] — external controller; its text is updated when a suggestion
/// is selected, so the parent's save logic can read it normally.
///
/// [onCoordinatesChanged] — called with (lat, lng) when a suggestion is
/// selected, or with (null, null) when the user types freely.
class PlacesAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final TripPlacesService placesService;
  final void Function(double? lat, double? lng) onCoordinatesChanged;
  final String? Function(String?)? validator;
  final bool required;

  const PlacesAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    required this.placesService,
    required this.onCoordinatesChanged,
    this.validator,
    this.required = false,
  });

  @override
  State<PlacesAutocompleteField> createState() =>
      _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  Timer? _debounce;
  List<PlacePrediction> _suggestions = [];
  bool _selecting = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _debounce?.cancel();
        // On web, mousedown on a suggestion causes the text field to lose focus
        // (browser blur) BEFORE the pointer-up event fires ListTile.onTap.
        // Clearing the dropdown immediately removes the widget from the tree,
        // so the tap is never delivered and the selection is lost.
        // A short delay keeps the dropdown alive long enough for onTap to run.
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && !_selecting) setState(() => _suggestions = []);
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    if (_selecting) return;
    widget.onCoordinatesChanged(null, null);
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result =
            await widget.placesService.fetchSuggestions(value.trim());
        if (mounted) setState(() => _suggestions = result.predictions);
      } catch (_) {
        if (mounted) setState(() => _suggestions = []);
      }
    });
  }

  Future<void> _select(PlacePrediction prediction) async {
    _debounce?.cancel();
    _selecting = true;
    widget.controller.text = prediction.description;
    setState(() => _suggestions = []);

    final details = await widget.placesService
        .fetchDetails(prediction.placeId, prediction.description);
    if (mounted) {
      widget.onCoordinatesChanged(details?.lat, details?.lng);
    }
    _selecting = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            label: widget.required
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.label),
                    const Text(' *', style: TextStyle(color: Colors.red)),
                  ])
                : Text(widget.label),
            prefixIcon: Icon(widget.prefixIcon),
          ),
          onChanged: _onTextChanged,
          onFieldSubmitted: (_) => setState(() => _suggestions = []),
          validator: widget.validator,
        ),
        if (_suggestions.isNotEmpty)
          Material(
            elevation: 3,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.grey),
                    title: Text(
                      s.mainText,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: s.secondaryText.isNotEmpty
                        ? Text(
                            s.secondaryText,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    dense: true,
                    onTap: () => _select(s),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
