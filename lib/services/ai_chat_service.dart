import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edge_function_ai_chat_service.dart';
import 'gemini_direct_ai_chat_service.dart';

class AIChatResult {
  final String text;
  final List<Map<String, dynamic>> intermediateHistory;

  const AIChatResult({required this.text, required this.intermediateHistory});
}

abstract interface class AIChatService {
  /// Release builds use [EdgeFunctionAIChatService] — API key lives server-side.
  /// Debug builds use [GeminiDirectAIChatService] — direct calls without Supabase CLI.
  /// Override in debug with: --dart-define=FORCE_EDGE_FUNCTION=true
  factory AIChatService.create() {
    const forceEdge = bool.fromEnvironment('FORCE_EDGE_FUNCTION');
    if (!kDebugMode || forceEdge) {
      return EdgeFunctionAIChatService(Supabase.instance.client);
    }
    return GeminiDirectAIChatService();
  }

  Future<AIChatResult> send({
    required String systemContext,
    required List<Map<String, dynamic>> history,
    required String userMessage,
    required Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> args,
    ) onToolCall,
    List<Map<String, dynamic>>? tools,
  });
}
