// lib/services/chat_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ChatService {
  /// Envía el mensaje al backend RAG (Python) y devuelve el texto del asistente.
  /// history es opcional: [{'role':'user'|'assistant', 'content':'...'}]
  static Future<String> chat({
    required String prompt,
    List<Map<String, String>>? history,
  }) async {
    final uri = Uri.parse('$kRagBase/rag/chat');
    final payload = <String, dynamic>{
      'message': prompt,
      if (history != null && history.isNotEmpty) 'history': history,
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('RAG ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final answer = (data['answer'] as String?) ?? 'Sin respuesta.';
    return answer;
  }

  /// (Opcional) Dispara el reindex desde la app (por si cambian productos).
  static Future<bool> reindex() async {
    final uri = Uri.parse('$kRagBase/rag/reindex');
    final res = await http.post(uri);
    return res.statusCode == 200;
  }
}
