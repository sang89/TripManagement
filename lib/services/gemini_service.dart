import 'dart:convert';
import 'package:http/http.dart' as http;
import 'gemini_tools.dart';

class GeminiResult {
  final String text;
  final List<Map<String, dynamic>> intermediateHistory;

  const GeminiResult({required this.text, required this.intermediateHistory});
}

class GeminiService {
  GeminiService._();

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';
  static const _model = 'gemini-2.5-flash-lite';
  static const _maxToolRounds = 10;

  static Duration _parseRetryDelay(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final details = (data['error'] as Map?)?['details'] as List?;
      if (details != null) {
        for (final d in details) {
          final delay = (d as Map<String, dynamic>)['retryDelay'] as String?;
          if (delay != null) {
            final seconds = double.tryParse(delay.replaceAll('s', ''));
            if (seconds != null) {
              return Duration(seconds: seconds.ceil() + 2);
            }
          }
        }
      }
    } catch (_) {}
    return const Duration(seconds: 60);
  }

  static Future<GeminiResult> send({
    required String apiKey,
    required String systemContext,
    required List<Map<String, dynamic>> history,
    required String userMessage,
    required Future<Map<String, dynamic>> Function(
            String name, Map<String, dynamic> args)
        onToolCall,
    List<Map<String, dynamic>>? tools,
  }) async {
    final uri = Uri.parse('$_base/models/$_model:generateContent?key=$apiKey');

    final contents = <Map<String, dynamic>>[
      ...history,
      {
        'role': 'user',
        'parts': [
          {'text': userMessage}
        ],
      },
    ];

    final intermediateHistory = <Map<String, dynamic>>[];
    var toolRounds = 0;

    while (true) {
      final effectiveTools = tools ?? kGeminiTools;
      final body = jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': systemContext}
          ],
        },
        if (effectiveTools.isNotEmpty) 'tools': effectiveTools,
        'contents': contents,
      });

      Future<http.Response> doRequest() => http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          );

      var response = await doRequest();

      if (response.statusCode == 429) {
        final retryDelay = _parseRetryDelay(response.body);
        await Future.delayed(retryDelay);
        response = await doRequest();
      }

      if (response.statusCode != 200) {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = (err['error'] as Map?)?['message'] as String?;
        if (response.statusCode == 429) {
          throw Exception(
              'Gemini rate limit: ${msg ?? 'Please try again in a moment.'}');
        }
        throw Exception(msg ?? 'HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('No candidates returned');
      }

      final candidate = candidates[0] as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = (content?['parts'] as List?) ?? [];

      Map<String, dynamic>? fcPart;
      for (final p in parts) {
        if ((p as Map<String, dynamic>).containsKey('functionCall')) {
          fcPart = p;
          break;
        }
      }

      if (fcPart == null) {
        final text = parts
            .where((p) => (p as Map).containsKey('text'))
            .map((p) => p['text'] as String)
            .join('');
        if (text.isEmpty) {
          final finishReason =
              (candidate['finishReason'] as String?) ?? 'UNKNOWN';
          if (finishReason == 'STOP' && intermediateHistory.isNotEmpty) {
            return GeminiResult(
              text: 'Done! Your trip has been updated.',
              intermediateHistory: intermediateHistory,
            );
          }
          throw Exception(
              'No response from Gemini (finishReason: $finishReason). Please try again.');
        }
        return GeminiResult(
            text: text, intermediateHistory: intermediateHistory);
      }

      if (toolRounds >= _maxToolRounds) {
        throw Exception('Too many tool calls — please try a simpler request.');
      }
      toolRounds++;

      final fc = fcPart['functionCall'] as Map<String, dynamic>;
      final name = fc['name'] as String;
      final args = Map<String, dynamic>.from((fc['args'] as Map?) ?? {});

      final modelTurn = <String, dynamic>{'role': 'model', 'parts': parts};
      contents.add(modelTurn);
      intermediateHistory.add(modelTurn);

      final result = await onToolCall(name, args);

      final responseTurn = <String, dynamic>{
        'role': 'user',
        'parts': [
          {
            'functionResponse': {
              'name': name,
              'response': result,
            }
          }
        ],
      };
      contents.add(responseTurn);
      intermediateHistory.add(responseTurn);
    }
  }
}
