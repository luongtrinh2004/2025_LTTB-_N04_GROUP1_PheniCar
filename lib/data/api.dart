// lib/data/api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'package:mobile/core/env.dart';
import 'models.dart';
import 'package:mobile/services/mqtt_service.dart';

class Api {
  final http.Client _http = http.Client();
  String? _token;

  // expose MQTT thành service riêng
  final MqttService mqtt = MqttService();

  // ---------------- Helpers ----------------
  Uri _dapi(String pathWithLeadingSlash) {
    // Env.dapiBase = http://116.118.95.187:3000/api  -> /api/v1/<path>
    final base = Env.dapiBase.replaceFirst(RegExp(r'/*$'), '');
    if (base.endsWith('/v1')) return Uri.parse('$base$pathWithLeadingSlash');
    return Uri.parse('$base/v1$pathWithLeadingSlash');
  }

  Uri _worker(String pathWithLeadingSlash) {
    // Env.workerBase = http://116.118.95.187:3002/api
    final base = Env.workerBase.replaceFirst(RegExp(r'/*$'), '');
    return Uri.parse('$base$pathWithLeadingSlash');
  }

  Map<String, String> _jsonHeaders({bool auth = true, bool noCache = false}) {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth && _token != null) h['Authorization'] = 'Bearer $_token';
    if (noCache) {
      h['Cache-Control'] = 'no-cache, no-store, must-revalidate';
      h['Pragma'] = 'no-cache';
      h['Expires'] = '0';
    }
    return h;
  }

  T _safe<T>(T fallback, T Function() fn) {
    try {
      return fn();
    } catch (_) {
      return fallback;
    }
  }

  List<dynamic> _extractListDeep(
    dynamic decoded, {
    List<String> preferKeys = const [
      'results',
      'stations',
      'maps',
      'data',
      'items',
      'rows'
    ],
  }) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      for (final k in preferKeys) {
        if (decoded.containsKey(k)) {
          final got = _extractListDeep(decoded[k], preferKeys: preferKeys);
          if (got.isNotEmpty) return got;
        }
      }
      for (final v in decoded.values) {
        final got = _extractListDeep(v, preferKeys: preferKeys);
        if (got.isNotEmpty) return got;
      }
    }
    if (decoded is String) {
      final s = decoded.trim();
      if (s.isNotEmpty && (s.startsWith('[') || s.startsWith('{'))) {
        try {
          final d = jsonDecode(s);
          return _extractListDeep(d, preferKeys: preferKeys);
        } catch (_) {}
      }
    }
    return const [];
  }

  // ---------------- LOGIN ----------------
  Future<void> login({required String phone, required String password}) async {
    final url = _dapi('/auth/login');
    debugPrint('LOGIN URL => $url');

    final res = await _http.post(
      url,
      headers: _jsonHeaders(auth: false),
      body: jsonEncode({'phone': phone, 'password': password}),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      debugPrint('Login FAILED ${res.statusCode}: ${res.body}');
      throw Exception('Login failed ${res.statusCode}');
    }

    final js = _safe<Map<String, dynamic>>({}, () => jsonDecode(res.body));
    final token = js['access']?['token'] ??
        js['accessToken'] ??
        js['tokens']?['access']?['token'] ??
        js['token'];

    if (token is! String || token.isEmpty) {
      debugPrint('Login response missing token: ${res.body}');
      throw Exception('Invalid login response');
    }

    _token = token;
    debugPrint('Login OK → token len=${_token!.length}');
  }

  // ===================== MAPS =====================
  Future<List<Area>> getMaps() async {
    final out = <Area>[];
    int page = 1;
    const limit = 100;

    while (true) {
      final url = _dapi('/maps?page=$page&limit=$limit&status=published');
      final res = await _http.get(url, headers: _jsonHeaders(noCache: true));
      if (res.statusCode == 304 || res.body.isEmpty) break;
      if (res.statusCode != 200) {
        debugPrint('getMaps ${res.statusCode}: ${res.body}');
        break;
      }

      final decoded = _safe<dynamic>({}, () => jsonDecode(res.body));
      final list = _extractListDeep(decoded,
          preferKeys: const ['results', 'maps', 'data', 'items', 'rows']);

      final batch = <Area>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) batch.add(Area.fromJson(e));
      }
      out.addAll(batch);

      if (batch.length < limit) break;
      page++;
      if (page > 10) break;
    }
    debugPrint('getMaps -> ${out.length}');
    return out;
  }

  // ===================== STATIONS =====================
  Future<List<Station>> getStationsByMap(String mapId) async {
    String _norm24(String s) {
      final m = RegExp(r'[0-9a-fA-F]{24}').firstMatch(s);
      return m?.group(0) ?? s;
    }

    final mapIdNorm = _norm24(mapId);
    final all = <Station>[];
    int page = 1;
    const limit = 100;

    while (true) {
      final url = _dapi('/stations?page=$page&limit=$limit');
      final res = await _http.get(url, headers: _jsonHeaders(noCache: true));
      if (res.statusCode == 304 || res.body.isEmpty) break;
      if (res.statusCode != 200) {
        debugPrint('getStations ${res.statusCode}: ${res.body}');
        break;
      }

      final decoded = _safe<dynamic>({}, () => jsonDecode(res.body));
      final list = _extractListDeep(decoded,
          preferKeys: const ['results', 'stations', 'data', 'items', 'rows']);

      final batch = <Station>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) batch.add(Station.fromJson(e));
      }
      all.addAll(batch);

      if (batch.length < limit) break;
      page++;
      if (page > 20) break;
    }

    final filtered = all.where((s) {
      final mid = s.mapIdRaw ?? '';
      return _norm24(mid) == mapIdNorm;
    }).toList();

    final out = filtered.isNotEmpty ? filtered : all;
    debugPrint('getStations(map=$mapIdNorm) -> ${out.length} '
        '(${filtered.isNotEmpty ? "filtered" : "no-match, show all"})');
    return out;
  }

  // ---------------- CREATE RIDE ----------------
  Future<void> createRide(List<String> stationIds) async {
    final url = _dapi('/rides');
    final body = jsonEncode({'orders': stationIds});
    final res = await _http.post(url, headers: _jsonHeaders(), body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      debugPrint('createRide ${res.statusCode}: ${res.body}');
      throw Exception('createRide ${res.statusCode}');
    }
  }

  // ---------------- WORKER ----------------
  Future<List<Vehicle>> getVehicles() async {
    final url =
        _worker('/vehicles?ts=${DateTime.now().millisecondsSinceEpoch}');
    final res =
        await _http.get(url, headers: _jsonHeaders(noCache: true, auth: false));
    if (res.statusCode != 200) {
      throw Exception('getVehicles ${res.statusCode}: ${res.body}');
    }
    final list =
        _safe<List<dynamic>>(<dynamic>[], () => jsonDecode(res.body) as List);
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => Vehicle.fromJson(e))
        .toList();
  }

  Future<List<Vehicle>> getDrivers() async {
    final url = _worker('/drivers?ts=${DateTime.now().millisecondsSinceEpoch}');
    final res =
        await _http.get(url, headers: _jsonHeaders(noCache: true, auth: false));
    if (res.statusCode != 200) {
      throw Exception('getDrivers ${res.statusCode}: ${res.body}');
    }
    final list =
        _safe<List<dynamic>>(<dynamic>[], () => jsonDecode(res.body) as List);
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => Vehicle.fromJson(e))
        .toList();
  }

  Future<void> toggleDriver(String id, bool online) async {
    final url = _worker('/toggle-driver');
    final res = await _http.post(
      url,
      headers: _jsonHeaders(auth: false),
      body: jsonEncode({'id': id, 'online': online}),
    );
    if (res.statusCode != 200) {
      throw Exception('toggleDriver ${res.statusCode}: ${res.body}');
    }
  }

  // ---------------- OSRM ----------------
  Future<List<List<double>>> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final url =
        '${Env.osrmBase}/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson&ts=${DateTime.now().millisecondsSinceEpoch}';
    final res = await _http
        .get(Uri.parse(url), headers: _jsonHeaders(noCache: true, auth: false))
        .timeout(Duration(milliseconds: Env.routeTimeoutMs));
    if (res.statusCode != 200) {
      throw Exception('routing ${res.statusCode}');
    }
    final js = _safe<Map<String, dynamic>>({}, () => jsonDecode(res.body));
    final coords =
        js['routes']?[0]?['geometry']?['coordinates'] as List<dynamic>? ?? [];
    return coords
        .map((c) => [(c[1] as num).toDouble(), (c[0] as num).toDouble()])
        .toList();
  }

  Future<void> dispose() async {
    await mqtt.dispose();
    _http.close();
  }
}
