import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_chat_service.dart';
import 'gemini_tools.dart';

/// Routes AI calls through the Supabase `ai-chat` Edge Function.
/// The Edge Function holds the Gemini API key and selects the model per user tier.
class EdgeFunctionAIChatService implements AIChatService {
  final SupabaseClient _supabase;
  static const _maxToolRounds = 10;

  const EdgeFunctionAIChatService(this._supabase);

  @override
  Future<AIChatResult> send({
    required String systemContext,
    required List<Map<String, dynamic>> history,
    required String userMessage,
    required Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> args,
    ) onToolCall,
  }) async {
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
      final round = await _callEdgeFunction(
        systemContext: systemContext,
        contents: contents,
      );

      final type = round['type'] as String;

      if (type == 'text') {
        return AIChatResult(
          text: round['text'] as String,
          intermediateHistory: intermediateHistory,
        );
      }

      if (toolRounds >= _maxToolRounds) {
        throw Exception('Too many tool calls — please try a simpler request.');
      }
      toolRounds++;

      final name = round['name'] as String;
      final args = Map<String, dynamic>.from((round['args'] as Map?) ?? {});
      final modelParts =
          (round['modelParts'] as List).cast<Map<String, dynamic>>();

      final modelTurn = <String, dynamic>{'role': 'model', 'parts': modelParts};
      contents.add(modelTurn);
      intermediateHistory.add(modelTurn);

      final toolResult = await onToolCall(name, args);

      final responseTurn = <String, dynamic>{
        'role': 'user',
        'parts': [
          {
            'functionResponse': {
              'name': name,
              'response': toolResult,
            }
          }
        ],
      };
      contents.add(responseTurn);
      intermediateHistory.add(responseTurn);
    }
  }

  Future<Map<String, dynamic>> _callEdgeFunction({
    required String systemContext,
    required List<Map<String, dynamic>> contents,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-chat',
        body: {
          'systemContext': systemContext,
          'contents': contents,
          'tools': kGeminiTools,
        },
      );
      return response.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        final msg = details['error'] as String;
        if (e.status == 429) throw Exception('AI rate limit: $msg');
        throw Exception(msg);
      }
      throw Exception(e.reasonPhrase ?? 'AI service error');
    }
  }
}
