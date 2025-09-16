import 'package:flutter/material.dart';
import '../features/auth/login_screen.dart';
import '../features/booking/pages/booking_page.dart';

final appRouter = _SimpleRouter();

class _SimpleRouter extends RouterConfig<Object> {
  _SimpleRouter()
      : super(
          routerDelegate: _Delegate(),
          routeInformationParser: _Parser(),
          routeInformationProvider: PlatformRouteInformationProvider(
            initialRouteInformation: const RouteInformation(location: '/login'),
          ),
        );
}

class _Parser extends RouteInformationParser<RouteSettings> {
  @override
  Future<RouteSettings> parseRouteInformation(RouteInformation ri) async {
    final loc = ri.location ?? '/login';
    switch (loc) {
      case '/booking':
        return const RouteSettings(name: '/booking');
      case '/login':
      default:
        return const RouteSettings(name: '/login');
    }
  }
}

class _Delegate extends RouterDelegate<RouteSettings>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<RouteSettings> {
  final _navKey = GlobalKey<NavigatorState>();
  String _path = '/login';

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navKey;

  @override
  RouteSettings? get currentConfiguration => RouteSettings(name: _path);

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navKey,
      pages: [
        if (_path == '/login')
          const MaterialPage(child: LoginScreen())
        else
          const MaterialPage(child: BookingPage()),
      ],
      onPopPage: (route, result) => route.didPop(result),
    );
  }

  @override
  Future<void> setNewRoutePath(RouteSettings configuration) async {
    _path = configuration.name ?? '/login';
  }

  void go(String p) {
    _path = p;
    notifyListeners();
  }
}

// đặt ở cuối file router.dart (ngoài class)
void routerGo(String path) {
  final del = appRouter.routerDelegate;
  if (del is _Delegate) {
    del.go(path);
  } else {
    // fallback: không có delegate đúng kiểu thì bỏ qua
  }
}
