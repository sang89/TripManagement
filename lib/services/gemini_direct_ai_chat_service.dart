import '../config/api_keys.dart';
import 'ai_chat_service.dart';
import 'gemini_service.dart';

/// Calls Gemini directly using the dev API key.
/// Only used in debug builds — production uses [EdgeFunctionAIChatService].
class GeminiDirectAIChatService implements AIChatService {
  const GeminiDirectAIChatService();

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
    final result = await GeminiService.send(
      apiKey: kGeminiApiKey,
      systemContext: systemContext,
      history: history,
      userMessage: userMessage,
      onToolCall: onToolCall,
    );
    return AIChatResult(
      text: result.text,
      intermediateHistory: result.intermediateHistory,
    );
  }
}
