// lib/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'services/chat_service.dart';
import 'services/product_service.dart';
import 'product_model.dart';
import 'product_detail_page.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> _messages = []; // {'role':'user'|'assistant','content':'...'}
  final TextEditingController _ctrl = TextEditingController();
  bool _sending = false;

  /// Productos detectados por índice del mensaje del asistente (para linkificar)
  final Map<int, List<Product>> _assistantMatches = {};

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _sending = true;
      _ctrl.clear();
    });

    try {
      // 1) Llamar al backend RAG
      final reply = await ChatService.chat(
        prompt: text,
        history: _messages,
      );

      // Índice donde quedará el mensaje del asistente
      final assistantIndex = _messages.length;

      // 2) Insertar respuesta del asistente
      setState(() {
        _messages.add({'role': 'assistant', 'content': reply});
      });

      // 3) Buscar posibles coincidencias de productos en tu API (según la consulta del usuario)
      //    Si falla la búsqueda, simplemente no habrá enlaces.
      ProductService.search(text, limit: 8).then((products) {
        if (!mounted) return;
        if (products.isNotEmpty) {
          setState(() {
            _assistantMatches[assistantIndex] = products;
          });
        }
      }).catchError((_) {});
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Error: $e'});
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color customOrange = Color(0xFFF57C00);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asesor de camisetas'),
        actions: [
          IconButton(
            tooltip: 'Reindex',
            onPressed: () async {
              final ok = await ChatService.reindex();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Reindex OK' : 'Reindex falló')),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final m = _messages[i];
                final isUser = m['role'] == 'user';
                final msgText = m['content'] ?? '';

                Widget bubbleChild;
                if (!isUser) {
                  // Mensaje del asistente: intentamos linkificar nombres de productos
                  final matches = _assistantMatches[i] ?? const <Product>[];
                  bubbleChild = _buildLinkifiedAssistantText(msgText, matches, context);
                } else {
                  bubbleChild = Text(msgText);
                }

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: isUser ? customOrange.withOpacity(0.12) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: bubbleChild,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Pregunta por equipo, talla, precio…',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF57C00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye un RichText donde cualquier nombre de producto encontrado en `assistantText`
  /// (según la lista `products`) se vuelve clickeable y navega a ProductDetailPage.
  Widget _buildLinkifiedAssistantText(
    String assistantText,
    List<Product> products,
    BuildContext context,
  ) {
    if (assistantText.isEmpty || products.isEmpty) {
      return Text(assistantText);
    }

    final lower = assistantText.toLowerCase();
    final ranges = <_MatchRange>[];

    // Buscamos la primera ocurrencia de cada nombre de producto (case-insensitive)
    for (final p in products) {
      final name = p.name.trim();
      if (name.isEmpty) continue;
      final idx = lower.indexOf(name.toLowerCase());
      if (idx >= 0) {
        ranges.add(_MatchRange(
          start: idx,
          end: idx + name.length,
          product: p,
        ));
      }
    }

    if (ranges.isEmpty) {
      return Text(assistantText);
    }

    // Ordenamos por inicio para construir spans sin solapamientos
    ranges.sort((a, b) => a.start.compareTo(b.start));

    // Filtramos solapados (nos quedamos con el más largo o el primero)
    final filtered = <_MatchRange>[];
    int lastEnd = -1;
    for (final r in ranges) {
      if (r.start >= lastEnd) {
        filtered.add(r);
        lastEnd = r.end;
      } else {
        // solapado: si este es más largo que el último, reemplaza
        final prev = filtered.last;
        final prevLen = prev.end - prev.start;
        final curLen = r.end - r.start;
        if (curLen > prevLen) {
          filtered.removeLast();
          filtered.add(r);
          lastEnd = r.end;
        }
      }
    }

    final spans = <TextSpan>[];
    int cursor = 0;

    for (final r in filtered) {
      // Texto normal antes del match
      if (cursor < r.start) {
        spans.add(TextSpan(text: assistantText.substring(cursor, r.start)));
      }

      // Texto linkeado del match
      final tappedProduct = r.product;
      spans.add(
        TextSpan(
          text: assistantText.substring(r.start, r.end),
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailPage(product: tappedProduct),
                ),
              );
            },
        ),
      );

      cursor = r.end;
    }

    // Resto del texto luego del último match
    if (cursor < assistantText.length) {
      spans.add(TextSpan(text: assistantText.substring(cursor)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87, height: 1.2),
        children: spans,
      ),
    );
  }
}

class _MatchRange {
  final int start;
  final int end;
  final Product product;
  _MatchRange({required this.start, required this.end, required this.product});
}
