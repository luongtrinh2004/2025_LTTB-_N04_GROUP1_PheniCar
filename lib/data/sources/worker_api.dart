import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/env.dart';

class WorkerApi {
  final String base;
  WorkerApi({String? base})
      : base = (base ?? Env.workerBase).replaceFirst(RegExp(r'/*$'), '');

  Uri _u(String path) {
    if (!path.startsWith('/')) path = '/$path';
    return Uri.parse('$base$path');
  }

  Future<Map<String, dynamic>> getPresence() async {
    final r = await http.get(_u(
        '/v1/vehicles/presence?ts=${DateTime.now().millisecondsSinceEpoch}'));
    if (r.statusCode != 200) throw Exception('presence ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
