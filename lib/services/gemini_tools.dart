// Default tool list for general AI chat (empty — no write tools in open chat).
const Set<String> kWriteToolNames = {};
const List<Map<String, dynamic>> kGeminiTools = [];

// ── AI Itinerary tools ────────────────────────────────────────────────────────

const Set<String> kItineraryWriteToolNames = {'create_stop', 'clear_stops'};

const List<Map<String, dynamic>> kItineraryTools = [
  {
    'functionDeclarations': [
      {
        'name': 'create_stop',
        'description':
            'Add one stop to the trip itinerary. Call once per stop.',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Short name (e.g. "Eiffel Tower", "Lunch at Café de Flore")',
            },
            'address': {
              'type': 'string',
              'description': 'Full address or descriptive location',
            },
            'notes': {
              'type': 'string',
              'description': 'What to do there, tips, suggested duration',
            },
            'arrive_day': {
              'type': 'integer',
              'description': 'Day number from trip start (1 = first day)',
            },
            'arrive_hour': {
              'type': 'integer',
              'description': 'Arrival hour 0-23 (24 h format)',
            },
            'arrive_minute': {
              'type': 'integer',
              'description': 'Arrival minute 0-59',
            },
            'depart_hour': {
              'type': 'integer',
              'description': 'Departure hour 0-23',
            },
            'depart_minute': {
              'type': 'integer',
              'description': 'Departure minute 0-59',
            },
          },
          'required': ['title', 'address'],
        },
      },
      {
        'name': 'clear_stops',
        'description':
            'Remove all existing stops before regenerating the itinerary.',
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      },
    ],
  },
];
