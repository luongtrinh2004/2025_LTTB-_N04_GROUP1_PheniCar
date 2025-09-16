import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/env.dart';
import '../models/area.dart';
import '../models/station.dart';

/// Lưu token giống FE
class TokenStore {
  static String? _token;
  static String? get token => _token;
  static void set(String? t) => _token = t;

  static Map<String, String> bearer() =>
      _token == null ? {} : {'Authorization': 'Bearer $_token'};
}

/// DAPI: auth / maps / stations / rides (đúng flow FE mô phỏng)
class DapiService {
  final String base; // ví dụ: http://116.118.95.187:3000/api

  DapiService({String? base})
      : base = (base ?? Env.dapiBase).replaceFirst(RegExp(r'/*$'), '') {
    // ignore: avoid_print
    print('[ENV] DAPI_BASE=$base');
  }

  Uri _u(String path, [Map<String, String>? q]) {
    if (!path.startsWith('/')) path = '/$path';
    return Uri.parse('$base$path').replace(queryParameters: q);
  }

  // ---- Auth (FE: /dapi/v1/auth/login) ----
  Future<void> login({
    required String phone,
    required String password,
  }) async {
    final r = await http.post(
      _u('/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );

    // ✅ chấp nhận mọi 2xx
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Login ${r.statusCode}: ${r.body}');
    }

    final js = jsonDecode(r.body);
    final t = js['access']?['token'] ??
        js['accessToken'] ??
        js['tokens']?['access']?['token'] ??
        js['token'];

    if (t is! String || t.isEmpty) {
      throw Exception('Không tìm thấy access token trong response');
    }
    TokenStore.set(t);
  }

  // ---- Maps (FE phân trang) ----
  Future<List<MapArea>> getAllMaps({String status = 'published'}) async {
    const hardLimit = 100;
    var page = 1;
    final items = <MapArea>[];

    while (true) {
      final r = await http.get(
        _u('/v1/maps', {
          'status': status,
          'page': '$page',
          'limit': '$hardLimit',
        }),
        headers: TokenStore.bearer(),
      );
      if (r.statusCode != 200) throw Exception('get maps ${r.statusCode}');
      final js = jsonDecode(r.body);
      final list = (js is List
          ? js
          : (js['results'] ?? js['items'] ?? js['data'] ?? [])) as List;
      items.addAll(list.map((e) => MapArea.fromJson(e)));

      final totalPages = js is Map && js['totalPages'] is num
          ? (js['totalPages'] as num).toInt()
          : null;
      if (totalPages != null) {
        if (page >= totalPages) break;
        page++;
      } else {
        if (list.length < hardLimit) break;
        page++;
      }
    }

    // dedupe theo id
    final seen = <String>{};
    return items.where((m) => seen.add(m.id)).toList();
  }

  // ---- Stations (FE tải tất cả rồi lọc theo mapId ở client) ----
  Future<List<Station>> getAllStations({String status = 'published'}) async {
    const hardLimit = 100;
    var page = 1;
    final items = <Station>[];

    while (true) {
      final r = await http.get(
        _u('/v1/stations', {
          'status': status,
          'page': '$page',
          'limit': '$hardLimit',
        }),
        headers: TokenStore.bearer(),
      );
      if (r.statusCode != 200) throw Exception('get stations ${r.statusCode}');
      final js = jsonDecode(r.body);
      final list = (js is List
          ? js
          : (js['results'] ?? js['items'] ?? js['data'] ?? [])) as List;
      items.addAll(list.map((e) => Station.fromJson(e)));

      final totalPages = js is Map && js['totalPages'] is num
          ? (js['totalPages'] as num).toInt()
          : null;
      final totalResults = js is Map && js['totalResults'] is num
          ? (js['totalResults'] as num).toInt()
          : null;

      if (totalPages != null) {
        if (page >= totalPages) break;
        page++;
      } else {
        if (list.length < hardLimit) break;
        if (totalResults != null && items.length >= totalResults) break;
        page++;
      }
    }

    // dedupe
    final seen = <String>{};
    return items.where((s) => seen.add(s.id)).toList();
  }

  /// Lọc station theo mapId (payload có thể ở nhiều format khác nhau)
  Future<List<Station>> getStationsByMapSafe(String mapId) async {
    final all = await getAllStations();
    final want = _normId(mapId);
    final filtered = all.where((s) => _normId(s.mapIdRaw) == want).toList();

    // fallback giống FE: nếu BE không trả mapId rõ ràng -> trả toàn bộ
    if (want.isNotEmpty && filtered.isEmpty) return all;
    return filtered;
  }

  // ---- Ride ----
  Future<void> createRide({required List<String> stationIds}) async {
    if (stationIds.length < 2) {
      throw Exception('Cần ít nhất 2 điểm');
    }
    final r = await http.post(
      _u('/v1/rides'),
      headers: {'Content-Type': 'application/json', ...TokenStore.bearer()},
      body: jsonEncode({
        'orders': stationIds,
        'paymentMethod': 'cash',
        'vehicleType': 'dolphin',
      }),
    );
    if (r.statusCode >= 300) {
      throw Exception('createRide ${r.statusCode}: ${r.body}');
    }
  }
}

// ==================== helpers =====================

/// Chuẩn hoá id: nhận string/map/... và trả về chuỗi id 24-hex nếu có
String _normId(dynamic v) {
  if (v == null) return '';

  // String: có thể là "ObjectId('...')" hoặc plain id
  if (v is String) {
    var s = v.trim();
    // Nếu là "ObjectId('...')" hoặc "ObjectId("...")"
    if (s.startsWith('ObjectId(') && s.endsWith(')')) {
      s = s.substring(9, s.length - 1); // cắt ObjectId( ... )
      s = s.replaceAll('"', '').replaceAll("'", ''); // bỏ quote
    }
    return s;
  }

  // Map: { $oid | _id | id }
  if (v is Map) {
    final raw = v[r'$oid'] ?? v['_id'] ?? v['id'];
    return raw?.toString() ?? '';
  }

  // Khác: toString
  return v.toString();
}
