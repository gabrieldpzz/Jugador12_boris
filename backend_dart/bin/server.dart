// bin/server.dart

import 'dart:io';
import 'dart:convert';
import 'dart:math'; // <-- para generar OTP
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:postgres/postgres.dart';
import 'package:shelf_router/shelf_router.dart';

// --- Auth imports (NUEVO) ---
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:bcrypt/bcrypt.dart';

PostgreSQLConnection? _connection;

// ===========================
// ====== AUTH HELPERS =======
// ===========================

String _env(String k) {
  final v = Platform.environment[k];
  if (v == null || v.isEmpty) {
    throw StateError('Falta variable de entorno: $k');
  }
  return v;
}

String _genOtp() {
  final rnd = Random.secure();
  return List.generate(6, (_) => rnd.nextInt(10)).join(); // 6 dígitos
}

Future<int?> _userIdByEmail(String email) async {
  final r = await _connection!.query(
    'SELECT id FROM users WHERE email=@e LIMIT 1',
    substitutionValues: {'e': email},
  );
  if (r.isEmpty) return null;
  return r.first[0] as int;
}

Future<bool> _verifyPassword(String email, String password) async {
  final r = await _connection!.query(
    'SELECT password_hash FROM users WHERE email=@e LIMIT 1',
    substitutionValues: {'e': email},
  );
  if (r.isEmpty) return false;
  final hash = r.first[0] as String;
  return BCrypt.checkpw(password, hash);
}

Future<int> _createUser(String email, String password) async {
  final hash = BCrypt.hashpw(password, BCrypt.gensalt());
  final r = await _connection!.query(
    'INSERT INTO users(email, password_hash) VALUES(@e, @h) RETURNING id',
    substitutionValues: {'e': email, 'h': hash},
  );
  return r.first[0] as int;
}

Future<void> _storeOtp(int userId, String code, Duration ttl) async {
  await _connection!.query(
    '''
    INSERT INTO login_otps(user_id, code, expires_at)
    VALUES(@u, @c, NOW() + INTERVAL '@m minutes')
    ''',
    substitutionValues: {'u': userId, 'c': code, 'm': ttl.inMinutes},
  );
}

Future<bool> _consumeOtp(int userId, String code) async {
  final r = await _connection!.query(
    '''
    SELECT id, expires_at, used_at
    FROM login_otps
    WHERE user_id=@u AND code=@c
    ORDER BY id DESC
    LIMIT 1
    ''',
    substitutionValues: {'u': userId, 'c': code},
  );
  if (r.isEmpty) return false;
  final row = r.first;
  if (row[2] != null) return false; // usado
  final expiresAt = row[1] as DateTime;
  if (DateTime.now().isAfter(expiresAt)) return false;
  await _connection!.query(
    'UPDATE login_otps SET used_at=NOW() WHERE id=@id',
    substitutionValues: {'id': row[0]},
  );
  return true;
}

Future<void> _sendOtpEmail(String to, String code) async {
  final host = _env('SMTP_HOST');
  final port = int.tryParse(_env('SMTP_PORT')) ?? 587;
  final user = _env('SMTP_USERNAME');
  final pass = _env('SMTP_PASSWORD');
  final from = _env('SMTP_FROM');

  final smtp = SmtpServer(host, port: port, username: user, password: pass);
  final message = Message()
    ..from = Address(from, 'Soporte')
    ..recipients.add(to)
    ..subject = 'Tu código de verificación'
    ..text = 'Tu código es: $code (válido por pocos minutos).';

  await send(message, smtp);
}

String _issueJwt(int userId) {
  final secret = _env('JWT_SECRET');
  final jwt = JWT({'uid': userId}, issuer: 'backend_dart');
  return jwt.sign(SecretKey(secret), expiresIn: const Duration(days: 7));
}

/// Lector tolerante: acepta JSON, x-www-form-urlencoded o "{email:...,password:...}"
Future<Map<String, String>> _readBodyMap(Request req) async {
  final ctype = (req.headers['content-type'] ?? '').toLowerCase();
  final raw = await req.readAsString();

  // 1) JSON
  if (ctype.contains('application/json')) {
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        return m.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
    } catch (_) {/* sigue intentando */}
  }

  // 2) x-www-form-urlencoded
  if (ctype.contains('application/x-www-form-urlencoded')) {
    final params = Uri.splitQueryString(raw, encoding: utf8);
    return params.map((k, v) => MapEntry(k, v));
  }

  // 3) Fallback simple: "{email: foo, password: bar}"
  final s = raw.trim();
  if (s.startsWith('{') && s.endsWith('}')) {
    final inner = s.substring(1, s.length - 1);
    final parts = inner.split(',');
    final map = <String, String>{};
    for (final p in parts) {
      final kv = p.split(':');
      if (kv.length >= 2) {
        final k = kv[0].trim();
        final v = kv.sublist(1).join(':').trim();
        map[k] = v;
      }
    }
    if (map.isNotEmpty) return map;
  }

  throw FormatException('Unsupported body format');
}

// ===========================
// ====== TU CÓDIGO BASE =====
// ===========================

void main() async {
  // --- 1. CONECTAR A LA BASE DE DATOS ---
  try {
    print('Intentando conectar a la base de datos...');
    final dbHost = Platform.environment['DATABASE_HOST']!;
    final dbPort = 5432;
    final dbName = Platform.environment['DATABASE_NAME']!;
    final dbUser = Platform.environment['DATABASE_USER']!;
    final dbPass = Platform.environment['DATABASE_PASSWORD']!;
    _connection = PostgreSQLConnection(
      dbHost, dbPort, dbName,
      username: dbUser, password: dbPass,
    );
    await _connection!.open();
    print('✅ ¡Conexión a la BD exitosa!');
  } catch (e) {
    print('❌ Error en la inicialización de la BD: $e');
    return;
  }

  // --- 2. CONFIGURAR EL ROUTER ---
  final router = Router();

  // ===== RUTAS AUTH (NUEVO) =====

  // POST /auth/register  {email, password}
  router.post('/auth/register', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = (body['email'] ?? '').toString().trim().toLowerCase();
      final password = (body['password'] ?? '').toString();
      if (email.isEmpty || password.isEmpty) {
        return Response(
          400,
          body: jsonEncode({'error':'missing_fields','required':['email','password']}),
          headers: {'Content-Type':'application/json'},
        );
      }
      final exists = await _userIdByEmail(email);
      if (exists != null) {
        return Response(
          400,
          body: jsonEncode({'error':'email_in_use'}),
          headers: {'Content-Type':'application/json'},
        );
      }
      final uid = await _createUser(email, password);
      return Response.ok(
        jsonEncode({'ok': true, 'user_id': uid}),
        headers: {'Content-Type':'application/json'},
      );
    } catch (e, st) {
      print('❌ /auth/register: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error':'server_error','message': e.toString()}),
        headers: {'Content-Type':'application/json'},
      );
    }
  });

  // POST /auth/login  {email, password} -> otp_token + envía OTP
  router.post('/auth/login', (Request req) async {
    try {
      final body = await _readBodyMap(req); // <--- tolerante
      final email = (body['email'] ?? '').trim().toLowerCase();
      final password = (body['password'] ?? '');
      if (email.isEmpty || password.isEmpty) {
        return Response(
          400,
          body: jsonEncode({'error':'missing_fields','required':['email','password']}),
          headers: {'Content-Type':'application/json'},
        );
      }
      final uid = await _userIdByEmail(email);
      if (uid == null) {
        return Response(
          401,
          body: jsonEncode({'error':'invalid_credentials'}),
          headers: {'Content-Type':'application/json'},
        );
      }
      final okPass = await _verifyPassword(email, password);
      if (!okPass) {
        return Response(
          401,
          body: jsonEncode({'error':'invalid_credentials'}),
          headers: {'Content-Type':'application/json'},
        );
      }
      final code = _genOtp();
      final ttlMin = int.tryParse(Platform.environment['OTP_EXP_MINUTES'] ?? '10') ?? 10;
      await _storeOtp(uid, code, Duration(minutes: ttlMin));
      await _sendOtpEmail(email, code);

      final otpToken = base64Url.encode(utf8.encode('$uid|${DateTime.now().millisecondsSinceEpoch}'));
      return Response.ok(
        jsonEncode({'otp_token': otpToken}),
        headers: {'Content-Type':'application/json'},
      );
    } catch (e, st) {
      print('❌ /auth/login: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error':'server_error','message': e.toString()}),
        headers: {'Content-Type':'application/json'},
      );
    }
  });

  // POST /auth/verify-otp  {otp_token, code} -> token
  router.post('/auth/verify-otp', (Request req) async {
    try {
      final body = await _readBodyMap(req); // <--- tolerante
      final otpToken = (body['otp_token'] ?? '');
      final code = (body['code'] ?? '');
      if (otpToken.isEmpty || code.isEmpty) {
        return Response(
          400,
          body: jsonEncode({'error':'missing_fields','required':['otp_token','code']}),
          headers: {'Content-Type':'application/json'},
        );
      }
      int? uid;
      try {
        final decoded = utf8.decode(base64Url.decode(otpToken));
        uid = int.tryParse(decoded.split('|').first);
      } catch (_) {}
      if (uid == null) {
        return Response(
          400,
          body: jsonEncode({'error':'invalid_otp_token'}),
          headers: {'Content-Type':'application/json'},
        );
      }
      final ok = await _consumeOtp(uid, code);
      if (!ok) {
        return Response(
          401,
          body: jsonEncode({'error':'invalid_or_expired_code'}),
          headers: {'Content-Type':'application/json'},
        );
      }
      final token = _issueJwt(uid);
      return Response.ok(
        jsonEncode({'token': token}),
        headers: {'Content-Type':'application/json'},
      );
    } catch (e, st) {
      print('❌ /auth/verify-otp: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error':'server_error','message': e.toString()}),
        headers: {'Content-Type':'application/json'},
      );
    }
  });

  // ===== TUS RUTAS EXISTENTES (SIN TOCAR) =====
  router.get('/products', _getProductsHandler);
  router.get('/active-banner', _getActiveBannerHandler);
  router.get('/search/text', _searchTextHandler);
  router.get('/products/category/<category>', _getProductsByCategoryHandler);

  router.get('/', (Request request) {
    return Response.ok('API Endpoints: /products, /active-banner, /search/text?q=..., /products/category/<name>');
  });

  // --- 3. INICIAR EL SERVIDOR ---
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router);
  var port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  var server = await shelf_io.serve(handler, '0.0.0.0', port);
  print('🚀 Servidor API (con categorías) corriendo en http://0.0.0.0:${server.port}');
}

// --- HANDLER PARA OBTENER TODOS LOS PRODUCTOS ---
Future<Response> _getProductsHandler(Request request) async {
  if (_connection == null) return Response.internalServerError(body: 'Error: BD no conectada');
  try {
    final result = await _connection!.query('SELECT id, name, team, category, price, image_url, description FROM products;');
    final List<Map<String, dynamic>> productsList = [];
    for (final row in result) {
      productsList.add({
        'id': row[0], 'name': row[1], 'team': row[2], 'category': row[3],
        'price': double.parse(row[4] as String),
        'image_url': row[5], 'description': row[6],
      });
    }
    final jsonString = jsonEncode(productsList);
    return Response.ok(jsonString, headers: {'Content-Type': 'application/json'});
  } catch (e, stackTrace) {
    print('❌ ¡ERROR EN /products HANDLER!'); print(e); print(stackTrace);
    return Response.internalServerError(body: 'Error en la consulta: $e');
  }
}

// --- HANDLER PARA OBTENER BANNER ACTIVO ---
Future<Response> _getActiveBannerHandler(Request request) async {
   if (_connection == null) return Response.internalServerError(body: 'Error: BD no conectada');
  try {
    final result = await _connection!.query('SELECT id, title, subtitle, image_url FROM banners WHERE is_active = true LIMIT 1');
    if (result.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'No active banner found'}), headers: {'Content-Type': 'application/json'});
    }
    final row = result.first;
    final bannerJson = {'id': row[0], 'title': row[1], 'subtitle': row[2], 'image_url': row[3]};
    return Response.ok(jsonEncode(bannerJson), headers: {'Content-Type': 'application/json'});
  } catch (e, stackTrace) {
    print('❌ ¡ERROR EN /active-banner HANDLER!'); print(e); print(stackTrace);
    return Response.internalServerError(body: 'Error en la consulta: $e');
  }
}

// --- HANDLER PARA BÚSQUEDA POR TEXTO ---
Future<Response> _searchTextHandler(Request request) async {
  if (_connection == null) return Response.internalServerError(body: 'Error: BD no conectada');

  final query = request.url.queryParameters['q'];
  if (query == null || query.isEmpty) {
    return Response.badRequest(body: jsonEncode({'error': 'Parámetro "q" (query) es requerido'}), headers: {'Content-Type': 'application/json'});
  }
  print('🔍 Recibida búsqueda de texto para: "$query"');
  final searchQuery = '%${query.trim()}%';

  try {
    final result = await _connection!.query(
      '''
      SELECT id, name, team, category, price, image_url, description
      FROM products
      WHERE name ILIKE @search_query OR team ILIKE @search_query OR category ILIKE @search_query OR description ILIKE @search_query
      LIMIT 20
      ''',
      substitutionValues: {'search_query': searchQuery},
    );

    final List<Map<String, dynamic>> productsList = [];
    for (final row in result) {
      productsList.add({
        'id': row[0], 'name': row[1], 'team': row[2], 'category': row[3],
        'price': double.parse(row[4] as String),
        'image_url': row[5], 'description': row[6],
      });
    }
    final jsonString = jsonEncode(productsList);
    print('✅ Búsqueda de texto encontró ${productsList.length} resultados.');
    return Response.ok(jsonString, headers: {'Content-Type': 'application/json'});
  } catch (e, stackTrace) {
    print('❌ ¡ERROR EN /search/text HANDLER!'); print(e); print(stackTrace);
    return Response.internalServerError(body: 'Error en la consulta de búsqueda: $e');
  }
}

// --- HANDLER PARA OBTENER PRODUCTOS POR CATEGORÍA ---
// --- HANDLER PARA OBTENER PRODUCTOS POR CATEGORÍA/EQUIPO ---
Future<Response> _getProductsByCategoryHandler(Request request) async {
  if (_connection == null) {
    return Response.internalServerError(body: 'Error: BD no conectada');
  }

  final name = request.params['category']; // We get 'Barcelona', 'Retro', etc. here
  if (name == null || name.isEmpty) {
     return Response.badRequest(body: 'Category or Team name is required.');
  }

  print('🔍 Buscando productos para categoría o equipo: "$name"');

  try {
    // --- MODIFIED QUERY: Search in EITHER category OR team column ---
    final result = await _connection!.query(
      '''
      SELECT id, name, team, category, price, image_url, description
      FROM products
      WHERE category ILIKE @search_name OR team ILIKE @search_name
      ORDER BY id DESC
      LIMIT 50
      ''',
      substitutionValues: {
        'search_name': name, // Use the name from the URL for both checks
      },
    );
    // -----------------------------------------------------------------

    final List<Map<String, dynamic>> productsList = [];
    for (final row in result) {
      productsList.add({
        'id': row[0], 'name': row[1], 'team': row[2], 'category': row[3],
        'price': double.parse(row[4] as String),
        'image_url': row[5], 'description': row[6],
      });
    }

    final jsonString = jsonEncode(productsList);
    print('✅ Búsqueda "$name" encontró ${productsList.length} resultados.');
    return Response.ok(
      jsonString,
      headers: {'Content-Type': 'application/json'},
    );

  } catch (e, stackTrace) {
    print('❌ ¡ERROR EN /products/category HANDLER!');
    print(e);
    print(stackTrace);
    return Response.internalServerError(body: 'Error en la consulta por categoría/equipo: $e');
  }
}

// --- (Función _generateEmbeddings sigue eliminada temporalmente) ---
