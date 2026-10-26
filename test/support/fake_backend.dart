import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Handles one Edge Function or RPC call. Return the JSON body to send back,
/// or throw [FakeHttpError] to send an error status.
typedef FakeHandler = Object? Function(Map<String, dynamic> body);

/// Thrown from a [FakeHandler] to make the fake backend answer with [status].
class FakeHttpError implements Exception {
  FakeHttpError(this.status, [this.body = const {'message': 'error'}]);

  final int status;
  final Object body;
}

/// In-memory stand-in for the Supabase HTTP API.
///
/// Serves PostgREST (`/rest/v1`), GoTrue (`/auth/v1`), and Edge Functions
/// (`/functions/v1`) so the real `supabase_flutter` client can run in tests
/// without a network. Gemini calls (`generativelanguage.googleapis.com`) are
/// answered by [geminiHandler].
class FakeBackend {
  static const userId = 'user-1';
  static const userEmail = 'ada@example.com';

  /// UUID-shaped, as in production: `SupabaseService.getTeamMembers` treats
  /// anything else as a team code.
  static const teamId = '6f1c2d3e-4a5b-4c6d-8e7f-901234567890';

  /// See [seedSecondTeam].
  static const secondTeamId = '7a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';
  static const secondTeamName = 'Difference Engines';
  static const secondTeamCode = 'XYZ789';

  /// Rows per table. Embedded selects (`teams(*)`) return the row as stored,
  /// so put any joined data on the row itself.
  final Map<String, List<Map<String, dynamic>>> tables = {};
  final Map<String, FakeHandler> rpcs = {};
  final Map<String, FakeHandler> functions = {};

  /// Answers Gemini `generateContent` requests.
  FakeHandler geminiHandler = (_) => geminiText('Hello from Gemini');

  /// Requests seen, as `METHOD /path` with the method upper-cased (the
  /// functions client sends it in lower case), newest last.
  final List<String> log = [];

  /// Bodies of non-GET requests, keyed like [log].
  final List<MapEntry<String, Object?>> sent = [];

  /// Tables whose next request fails with this status.
  final Map<String, int> failures = {};

  /// When set, every auth request fails with this status.
  int? authFailure;

  /// Auth paths (e.g. `/signup`) that fail with this status.
  final Map<String, int> authFailures = {};

  /// Message on failed auth responses; screens branch on its wording.
  String authFailureMessage = 'Auth failed';

  /// Returned for `/auth/v1/signup` and `/auth/v1/verify`.
  bool signUpReturnsSession = true;

  /// The `postgrest` client reads the request back off each response.
  late final http.Client client = MockClient((request) async {
    final response = await _handle(request);
    return http.Response.bytes(
      response.bodyBytes,
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  });

  void reset() {
    tables.clear();
    rpcs.clear();
    functions.clear();
    log.clear();
    sent.clear();
    failures.clear();
    authFailures.clear();
    authFailure = null;
    authFailureMessage = 'Auth failed';
    signUpReturnsSession = true;
    geminiHandler = (_) => geminiText('Hello from Gemini');
  }

  List<Map<String, dynamic>> table(String name) =>
      tables.putIfAbsent(name, () => []);

  /// Bodies sent to [method] [path], oldest first.
  List<Object?> bodiesFor(String method, String path) => [
        for (final e in sent)
          if (e.key == '$method $path') e.value,
      ];

  /// Edge Functions called, by name, oldest first.
  List<String> get functionCalls => [
        for (final entry in log)
          if (entry.startsWith('POST /functions/v1/'))
            entry.substring('POST /functions/v1/'.length),
      ];

  /// Bodies sent to the Edge Function [name], oldest first.
  List<Object?> functionBodies(String name) =>
      bodiesFor('POST', '/functions/v1/$name');

  /// A standard team with the signed-in user as admin, plus one member.
  void seedTeam({String role = 'admin'}) {
    table('teams').add({
      'id': teamId,
      'name': 'Analytical Engines',
      'team_code': 'ABC123',
      'created_by': userId,
      'created_at': '2026-01-01T00:00:00Z',
    });
    table('users').addAll([
      {
        'id': userId,
        'full_name': 'Ada',
        'email': userEmail,
        'role': role,
        'team_id': teamId,
        'google_refresh_token': null,
        'teams': {'name': 'Analytical Engines', 'team_code': 'ABC123'},
        'created_at': '2026-01-01T00:00:00Z',
      },
      {
        'id': 'user-2',
        'full_name': 'Bob',
        'email': 'bob@example.com',
        'role': 'member',
        'team_id': teamId,
        'teams': {'name': 'Analytical Engines', 'team_code': 'ABC123'},
        'created_at': '2026-01-02T00:00:00Z',
      },
    ]);
  }

  /// A second team the signed-in user also belongs to, for team switching.
  /// Rows are keyed by id, so that membership is a separate user row found
  /// by email. With [withTeamRow] false, only the membership exists.
  void seedSecondTeam({bool withTeamRow = true}) {
    if (withTeamRow) {
      table('teams').add({
        'id': secondTeamId,
        'name': secondTeamName,
        'team_code': secondTeamCode,
      });
    }
    table('users').add({
      'id': '$userId-team-2',
      'full_name': 'Ada',
      'email': userEmail,
      'role': 'member',
      'team_id': secondTeamId,
      'teams': {'name': secondTeamName, 'team_code': secondTeamCode},
    });
  }

  /// What the server holds once the user's main row points at the second
  /// team: the other membership row now points at the first.
  void moveUserToSecondTeam() {
    final users = table('users');
    users.firstWhere((u) => u['id'] == userId)
      ..['team_id'] = secondTeamId
      ..['teams'] = {'name': secondTeamName, 'team_code': secondTeamCode};
    users.firstWhere((u) => u['id'] == '$userId-team-2')
      ..['team_id'] = teamId
      ..['teams'] = {'name': 'Analytical Engines', 'team_code': 'ABC123'};
  }

  static Map<String, dynamic> geminiText(String text) => {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': text}
              ]
            }
          }
        ]
      };

  static Map<String, dynamic> geminiCall(
    String name,
    Map<String, dynamic> args,
  ) =>
      {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'functionCall': {'name': name, 'args': args}
                }
              ]
            }
          }
        ]
      };

  static Map<String, dynamic> session({
    String id = userId,
    String email = userEmail,
  }) {
    String part(Map<String, dynamic> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final exp = DateTime.now().add(const Duration(hours: 1));
    final token = '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({
          'sub': id,
          'email': email,
          'role': 'authenticated',
          'exp': exp.millisecondsSinceEpoch ~/ 1000,
        })}.sig';
    return {
      'access_token': token,
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': exp.millisecondsSinceEpoch ~/ 1000,
      'refresh_token': 'refresh-token',
      'user': user(id: id, email: email),
    };
  }

  static Map<String, dynamic> user({
    String id = userId,
    String email = userEmail,
  }) =>
      {
        'id': id,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': email,
        'app_metadata': {'provider': 'email'},
        'user_metadata': {'full_name': 'Ada'},
        'created_at': '2026-01-01T00:00:00Z',
      };

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    final method = request.method.toUpperCase();
    final key = '$method $path';
    log.add(key);
    Object? body;
    if (request.body.isNotEmpty) {
      try {
        body = jsonDecode(request.body);
      } catch (_) {
        body = request.body;
      }
    }
    if (method != 'GET') sent.add(MapEntry(key, body));

    try {
      if (request.url.host == 'generativelanguage.googleapis.com') {
        return _json(geminiHandler(_asMap(body)));
      }
      if (path.startsWith('/rest/v1/rpc/')) {
        final name = path.substring('/rest/v1/rpc/'.length);
        final handler = rpcs[name];
        if (handler == null) {
          return _json({'message': 'unknown rpc $name'}, status: 404);
        }
        return _json(handler(_asMap(body)));
      }
      if (path.startsWith('/rest/v1/')) {
        return _rest(request, path.substring('/rest/v1/'.length), body);
      }
      if (path.startsWith('/functions/v1/')) {
        final name = path.substring('/functions/v1/'.length);
        final handler = functions[name];
        if (handler == null) {
          return _json({'error': 'unknown function $name'}, status: 404);
        }
        return _json(handler(_asMap(body)));
      }
      if (path.startsWith('/auth/v1/')) {
        return _auth(request, path.substring('/auth/v1'.length));
      }
    } on FakeHttpError catch (e) {
      return _json(e.body, status: e.status);
    }
    return _json({'message': 'not found'}, status: 404);
  }

  http.Response _auth(http.Request request, String path) {
    final status = authFailure ?? authFailures[path];
    if (status != null) {
      return _json(
        {'code': status, 'error_code': 'fake', 'msg': authFailureMessage},
        status: status,
      );
    }
    switch (path) {
      case '/token':
      case '/verify':
        return _json(session());
      case '/signup':
        return _json(signUpReturnsSession ? session() : user());
      case '/user':
        return _json(user());
      case '/logout':
        return http.Response('', 204);
      default:
        return _json(<String, dynamic>{});
    }
  }

  http.Response _rest(http.Request request, String name, Object? body) {
    final failure = failures.remove(name);
    if (failure != null) {
      return _json(
        {'message': 'forced failure', 'code': '$failure'},
        status: failure,
      );
    }
    final rows = table(name);
    final params = request.url.queryParametersAll;
    bool matches(Map<String, dynamic> row) {
      for (final entry in params.entries) {
        if (const {'select', 'order', 'limit', 'offset', 'columns'}
            .contains(entry.key)) {
          continue;
        }
        for (final filter in entry.value) {
          if (!_matchesFilter(row[entry.key], filter)) return false;
        }
      }
      return true;
    }

    final wantsObject =
        request.headers['Accept'] == 'application/vnd.pgrst.object+json' ||
            request.headers['accept'] == 'application/vnd.pgrst.object+json';
    final returnRows =
        (request.headers['Prefer'] ?? '').contains('return=representation');

    List<Map<String, dynamic>> result;
    switch (request.method) {
      case 'GET':
      case 'HEAD':
        result = rows.where(matches).toList();
        final order = params['order']?.first;
        if (order != null) {
          final parts = order.split('.');
          final column = parts.first;
          final desc = parts.contains('desc');
          result.sort((a, b) {
            final cmp = '${a[column] ?? ''}'.compareTo('${b[column] ?? ''}');
            return desc ? -cmp : cmp;
          });
        }
        final limit = int.tryParse(params['limit']?.first ?? '');
        if (limit != null && result.length > limit) {
          result = result.sublist(0, limit);
        }
        break;
      case 'POST':
        final inserted = [
          for (final row in body is List ? body : [body])
            {
              'id': 'gen-${rows.length + 1}-${log.length}',
              'created_at': DateTime.now().toUtc().toIso8601String(),
              ...Map<String, dynamic>.from(row as Map),
            }
        ];
        rows.addAll(inserted);
        result = inserted;
        if (!returnRows && !wantsObject) return http.Response('', 201);
        break;
      case 'PATCH':
        result = rows.where(matches).toList();
        for (final row in result) {
          row.addAll(Map<String, dynamic>.from(body as Map));
        }
        if (!returnRows && !wantsObject) return http.Response('', 204);
        break;
      case 'DELETE':
        result = rows.where(matches).toList();
        rows.removeWhere(result.contains);
        if (!returnRows && !wantsObject) return http.Response('', 204);
        break;
      default:
        return _json({'message': 'unsupported'}, status: 405);
    }

    if (wantsObject) {
      if (result.length != 1) {
        return _json(
          {
            'code': 'PGRST116',
            'details': 'The result contains ${result.length} rows',
            'hint': null,
            'message': 'JSON object requested, multiple (or no) rows returned',
          },
          status: 406,
        );
      }
      return _json(result.single);
    }
    return _json(result);
  }

  static bool _matchesFilter(Object? value, String filter) {
    final dot = filter.indexOf('.');
    if (dot < 0) return true;
    final op = filter.substring(0, dot);
    final operand = filter.substring(dot + 1);
    final text = value?.toString();
    switch (op) {
      case 'eq':
        return text == operand;
      case 'neq':
        return text != operand;
      case 'is':
        return operand == 'null' ? value == null : text == operand;
      case 'in':
        final items = operand
            .replaceAll(RegExp(r'^\(|\)$'), '')
            .split(',')
            .map((s) => s.replaceAll('"', ''));
        return items.contains(text);
      case 'gte':
        return text != null && text.compareTo(operand) >= 0;
      case 'lte':
        return text != null && text.compareTo(operand) <= 0;
      case 'gt':
        return text != null && text.compareTo(operand) > 0;
      case 'lt':
        return text != null && text.compareTo(operand) < 0;
      default:
        return true;
    }
  }

  static Map<String, dynamic> _asMap(Object? body) =>
      body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

  static http.Response _json(Object? body, {int status = 200}) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}
