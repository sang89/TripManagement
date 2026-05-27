import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'config/api_keys.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/trip_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/shell/shell_scaffold.dart';
import 'screens/trips/trip_detail_screen.dart';
import 'screens/trips/trip_form_screen.dart';
import 'screens/trips/trips_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);

  final auth = AuthProvider();
  await auth.init();

  final settings = SettingsProvider();
  await settings.load();

  final trips = TripProvider();
  if (auth.isLoggedIn) await trips.load();

  runApp(TripManagementApp(auth: auth, settings: settings, trips: trips));
}

class TripManagementApp extends StatefulWidget {
  final AuthProvider auth;
  final SettingsProvider settings;
  final TripProvider trips;

  const TripManagementApp({
    super.key,
    required this.auth,
    required this.settings,
    required this.trips,
  });

  @override
  State<TripManagementApp> createState() => _TripManagementAppState();
}

class _TripManagementAppState extends State<TripManagementApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    widget.auth.addListener(_onAuthChanged);

    _router = GoRouter(
      refreshListenable: widget.auth,
      redirect: (context, state) {
        final loggedIn = widget.auth.isLoggedIn;
        final loc = state.matchedLocation;
        final onAuth = loc == '/login' || loc == '/register';
        if (!loggedIn && !onAuth) return '/login';
        if (loggedIn && onAuth) return '/trips';
        return null;
      },
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/trips'),
        GoRoute(path: '/home', redirect: (_, _) => '/trips'),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => ShellScaffold(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/trips',
                builder: (_, _) => const TripsScreen(),
              ),
              GoRoute(
                path: '/trip/new',
                builder: (_, _) => const TripFormScreen(),
              ),
              GoRoute(
                path: '/trip/:id',
                builder: (_, state) =>
                    TripDetailScreen(tripId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: '/trip/:id/edit',
                builder: (_, state) =>
                    TripFormScreen(tripId: state.pathParameters['id']),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/journal',
                builder: (_, _) => const Scaffold(
                  body: Center(child: Text('Journal coming soon')),
                ),
              ),
            ]),
          ],
        ),
      ],
    );
  }

  void _onAuthChanged() {
    if (widget.auth.isLoggedIn) {
      widget.trips.load();
    } else {
      widget.trips.clear();
    }
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.auth),
        ChangeNotifierProvider.value(value: widget.settings),
        ChangeNotifierProvider.value(value: widget.trips),
      ],
      child: Consumer<SettingsProvider>(
        builder: (_, settings, _) => MaterialApp.router(
          title: 'Trip Planner',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
