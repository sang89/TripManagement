import 'package:intl/intl.dart';
import '../models/event.dart';
import 'ai_chat_service.dart';

final _timeFmt = DateFormat('EEEE, MMM d yyyy');

class AiTripChatResult {
  final String text;
  final List<Map<String, dynamic>> updatedHistory;
  const AiTripChatResult({required this.text, required this.updatedHistory});
}

class AiItineraryService {
  final AIChatService _ai;

  AiItineraryService() : _ai = AIChatService.create();

  Future<AiTripChatResult> chat({
    required Event event,
    required String message,
    required List<Map<String, dynamic>> history,
  }) async {
    final result = await _ai.send(
      systemContext: _buildSystemPrompt(event),
      history: history,
      userMessage: message,
      tools: const [],
      onToolCall: (name, args) async => {},
    );

    final updatedHistory = [
      ...history,
      {'role': 'user', 'parts': [{'text': message}]},
      ...result.intermediateHistory,
      {'role': 'model', 'parts': [{'text': result.text}]},
    ];
    return AiTripChatResult(text: result.text, updatedHistory: updatedHistory);
  }

  String _buildSystemPrompt(Event event) {
    final going = event.guests
        .where((g) => ['going', 'accepted', 'maybe'].contains(g.status))
        .toList();

    final duration = event.endAt != null
        ? '${event.startAt.difference(event.endAt!).inDays.abs() + 1} days'
        : 'duration unknown';

    final sb = StringBuffer();
    sb.writeln(
        'You are a helpful travel assistant for this trip. Answer questions about '
        'the destination, local food, culture, weather, activities, logistics, '
        'and anything else relevant. Be specific and practical.');
    sb.writeln();
    sb.writeln('── TRIP INFO ──────────────────────────────────');
    sb.writeln('Name: ${event.title}');
    sb.writeln('Destination: ${event.location}');
    sb.writeln('Start: ${_timeFmt.format(event.startAt)}');
    if (event.endAt != null) sb.writeln('End: ${_timeFmt.format(event.endAt!)}');
    sb.writeln('Duration: $duration');
    if (event.startLocation != null) {
      sb.writeln('Departing from: ${event.startLocation}');
    }
    if (event.description.trim().isNotEmpty) {
      sb.writeln('Description: ${event.description.trim()}');
    }

    if (going.isNotEmpty) {
      sb.writeln();
      sb.writeln('── GROUP (${going.length} people) ──────────────────────');
      for (final g in going) {
        final note = g.rsvpNote?.trim();
        sb.writeln('• ${g.displayName}${note != null && note.isNotEmpty ? " — $note" : ""}');
      }
    }

    if (event.stops.isNotEmpty) {
      sb.writeln();
      sb.writeln('── CURRENT ITINERARY ──────────────────────────');
      for (var i = 0; i < event.stops.length; i++) {
        final s = event.stops[i];
        sb.write('${i + 1}. ${s.title}');
        if (s.address.isNotEmpty) sb.write(' — ${s.address}');
        if (s.arriveAt != null) sb.write(' | arrive ${_timeFmt.format(s.arriveAt!)}');
        if (s.departAt != null) sb.write(' → depart ${_timeFmt.format(s.departAt!)}');
        sb.writeln();
        if (s.notes.trim().isNotEmpty) sb.writeln('   Notes: ${s.notes.trim()}');
      }
    } else {
      sb.writeln();
      sb.writeln('── CURRENT ITINERARY ──────────────────────────');
      sb.writeln('No stops planned yet.');
    }

    return sb.toString();
  }
}
