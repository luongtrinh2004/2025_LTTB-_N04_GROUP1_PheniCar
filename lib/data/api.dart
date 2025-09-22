// lib/data/api.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_browser_client.dart' as b;
import 'package:mqtt_client/mqtt_client.dart';

import 'package:mobile/core/env.dart';
import 'package:mobile/data/models.dart';

class Api {
  final http.Client _http = http.Client();
  String? _token;

  // ---------------- Helpers ----------------
  Uri _dapi(String pathWithLeadingSlash) {
    final base = Env.dapiBase.replaceFirst(RegExp(r'/*$'), '');
    // base có thể là .../api hoặc .../api/v1
    if (base.endsWith('/v1')) return Uri.parse('$base$pathWithLeadingSlash');
    return Uri.parse('$base/v1$pathWithLeadingSlash');
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

  // Trả về list từ body JSON (top-level list / object chứa các keys hay gặp)
  List<dynamic> _extractListFromBody(
    String body, {
    List<String> preferKeys = const [
      'results',
      'data',
      'items',
      'maps',
      'stations',
      'rows'
    ],
  }) {
    final b = body.trim();
    if (b.isEmpty) return const [];
    dynamic decoded;
    try {
      decoded = jsonDecode(b);
    } catch (_) {
      return const [];
    }
    return _extractListFromJson(decoded, preferKeys: preferKeys);
  }

  // Trích list từ object đã decode
  List<dynamic> _extractListFromJson(
    dynamic decoded, {
    List<String> preferKeys = const [
      'results',
      'data',
      'items',
      'maps',
      'stations',
      'rows'
    ],
  }) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      for (final k in preferKeys) {
        if (decoded.containsKey(k)) {
          var v = decoded[k];
          if (v is String) {
            final s = v.trim();
            if (s.startsWith('[') || s.startsWith('{')) {
              try {
                v = jsonDecode(s);
              } catch (_) {
                v = const [];
              }
            } else {
              v = const [];
            }
          }
          if (v is List) return v;
          if (v is Map) return [v];
        }
      }
    }
    return const [];
  }

  // Đệ quy: moi list ở mọi độ sâu
  List<dynamic> _extractListDeep(
    dynamic decoded, {
    List<String> preferKeys = const [
      'results',
      'stations',
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

  // ===================== MAPS (no ts, limit ≤ 100, robust) =====================
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

      final list = _extractListFromBody(
        res.body,
        preferKeys: const ['results', 'maps', 'data', 'items', 'rows'],
      );

      final batch = <Area>[];
      for (final e in list) {
        if (e is Map) batch.add(Area.fromJson(Map<String, dynamic>.from(e)));
      }
      out.addAll(batch);

      if (batch.length < limit) break; // hết trang
      page++;
      if (page > 10) break; // chặn vô hạn
    }

    debugPrint('getMaps -> ${out.length}');
    return out;
  }

// ===================== STATIONS (no ts, limit ≤ 100, paginate + deep parse) =====================
  Future<List<Station>> getStationsByMap(String mapId) async {
    // Chuẩn hoá 24-hex để so sánh
    String _norm(String s) {
      final m = RegExp(r'[0-9a-fA-F]{24}').firstMatch(s);
      return m?.group(0) ?? s;
    }

    final mapIdNorm = _norm(mapId);

    final all = <Station>[];
    int page = 1;
    const limit = 100;

    while (true) {
      // backend không cho ts và không nhận limit > 100
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
        if (e is Map) batch.add(Station.fromJson(Map<String, dynamic>.from(e)));
      }
      all.addAll(batch);

      if (batch.length < limit) break; // hết trang
      page++;
      if (page > 20) break; // chặn vô hạn (2k bản ghi)
    }

    // lọc client theo mapId đã normalize
    final filtered = all.where((s) {
      final mid = s.mapIdRaw ?? '';
      return _norm(mid) == mapIdNorm;
    }).toList();

    final out = filtered.isNotEmpty
        ? filtered
        : all; // nếu không match, show all để debug
    debugPrint('getStations(map=$mapIdNorm) -> ${out.length} '
        '(${filtered.isNotEmpty ? "filtered" : "no-match, show all"})');
    return out;
  }

  // ---------------- CREATE RIDE ----------------
  Future<void> createRide(List<String> stationIds) async {
    final url = _dapi('/rides');
    // theo yêu cầu: chỉ gửi orders
    final body = jsonEncode({'orders': stationIds});

    final res = await _http.post(url, headers: _jsonHeaders(), body: body);

    if (res.statusCode != 200 && res.statusCode != 201) {
      debugPrint('createRide ${res.statusCode}: ${res.body}');
      throw Exception('createRide ${res.statusCode}');
    }
  }

  // ---------------- WORKER ----------------
  Future<List<Vehicle>> getVehicles() async {
    final url = Uri.parse(
        '${Env.workerBase}/api/vehicles?ts=${DateTime.now().millisecondsSinceEpoch}');
    final res =
        await _http.get(url, headers: _jsonHeaders(noCache: true, auth: false));
    if (res.statusCode != 200) {
      throw Exception('getVehicles ${res.statusCode}');
    }
    final list = _safe<List<dynamic>>(
        <dynamic>[], () => jsonDecode(res.body) as List<dynamic>);
    return list
        .whereType<Map>()
        .map((e) => Vehicle.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> toggleDriver(String id, bool online) async {
    final url = Uri.parse('${Env.workerBase}/api/toggle-driver');
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

  // ---------------- MQTT (Web) ----------------
  MqttClient? _mq;
  final _telemetryCtrl = StreamController<Telemetry>.broadcast();
  Stream<Telemetry> get telemetryStream => _telemetryCtrl.stream;

  Future<void> connectMqtt({void Function(String status)? onStatus}) async {
    if (!kIsWeb) {
      onStatus?.call('unsupported: non-web MQTT not implemented');
      return;
    }
    final clientId =
        'flutter_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
    final c = b.MqttBrowserClient(Env.mqttWs, clientId);
    c.keepAlivePeriod = 20;
    c.onConnected = () => onStatus?.call('connected');
    c.onDisconnected = () => onStatus?.call('disconnected');
    c.onSubscribed = (t) => onStatus?.call('sub:$t');
    _mq = c;

    var msg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    if (Env.mqttUsername.isNotEmpty || Env.mqttPassword.isNotEmpty) {
      msg = msg.authenticateAs(Env.mqttUsername, Env.mqttPassword);
    }
    _mq!.connectionMessage = msg;

    await _mq!.connect();

    _mq?.updates?.listen((events) {
      for (final ev in events) {
        final rec = ev.payload as MqttPublishMessage;
        final payload =
            MqttPublishPayload.bytesToStringAsString(rec.payload.message);
        if (ev.topic.endsWith('/telemetry')) {
          final js = _safe<Map<String, dynamic>>({}, () => jsonDecode(payload));
          if (js.isNotEmpty) {
            _telemetryCtrl.add(Telemetry.fromJson(js));
          }
        }
      }
    });

    await subscribe('car/+/telemetry');
    await subscribe('car/+/status');
  }

  Future<void> subscribe(String topic) async {
    if (_mq == null ||
        _mq!.connectionStatus?.state != MqttConnectionState.connected) return;
    _mq!.subscribe(topic, MqttQos.atLeastOnce);
  }

  Future<void> dispose() async {
    try {
      await _telemetryCtrl.close();
    } catch (_) {}
    try {
      _mq?.disconnect();
    } catch (_) {}
    _http.close();
  }
}
