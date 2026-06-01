import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:provider/provider.dart';
import 'package:shared_logging/shared_logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'config/api_keys.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/invitations_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/user_profile_provider.dart';
import 'screens/auth/biometric_lock_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'services/biometric_service.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/shell/shell_scaffold.dart';
import 'screens/trips/trip_detail_screen.dart';
import 'screens/trips/trip_form_screen.dart';
import 'screens/trips/trips_screen.dart';
import 'services/connectivity_service.dart';
import 'services/offline_queue.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppLogger.init();

  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);

  final connectivity = ConnectivityService();
  await connectivity.init();

  final offlineQueue = OfflineQueue(connectivity);
  await offlineQueue.init();

  final auth = AuthProvider();
  await auth.init();

  final settings = SettingsProvider();
  await settings.load();

  final trips = TripProvider(connectivity: connectivity, queue: offlineQueue);
  final profile = UserProfileProvider(
    connectivity: connectivity,
    queue: offlineQueue,
  );
  final invitations = InvitationsProvider();
  final friends = FriendsProvider();
  final biometricService = BiometricService();

  if (auth.isLoggedIn) {
    await trips.load();
    await profile.load();
    final uid = auth.userId;
    if (uid != null) {
      await invitations.init(uid);
      await friends.init(uid);
    }
  }

  runApp(TripManagementApp(
    auth: auth,
    settings: settings,
    trips: trips,
    profile: profile,
    invitations: invitations,
    friends: friends,
    connectivity: connectivity,
    offlineQueue: offlineQueue,
    biometricService: biometricService,
  ));
}

class TripManagementApp extends StatefulWidget {
  final AuthProvider auth;
  final SettingsProvider settings;
  final TripProvider trips;
  final UserProfileProvider profile;
  final InvitationsProvider invitations;
  final FriendsProvider friends;
  final ConnectivityService connectivity;
  final OfflineQueue offlineQueue;
  final BiometricService biometricService;

  const TripManagementApp({
    super.key,
    required this.auth,
    required this.settings,
    required this.trips,
    required this.profile,
    required this.invitations,
    required this.friends,
    required this.connectivity,
    required this.offlineQueue,
    required this.biometricService,
  });

  @override
  State<TripManagementApp> createState() => _TripManagementAppState();
}

class _TripManagementAppState extends State<TripManagementApp> {
  late final GoRouter _router;
  late final PushNotificationService _push;

  @override
  void initState() {
    super.initState();

    _push = PushNotificationService(
      onTripInviteTap: () => _router.go('/trips'),
    );

    widget.auth.addListener(_onAuthChanged);

    _router = GoRouter(
      refreshListenable: Listenable.merge([widget.auth, widget.settings]),
      redirect: (context, state) {
        final loggedIn = widget.auth.isLoggedIn;
        final loc = state.matchedLocation;
        final onAuth = loc == '/login' || loc == '/register';
        final onBiometricLock = loc == '/biometric-lock';

        if (!loggedIn && !onBiometricLock && !onAuth) return '/login';
        if (!loggedIn && onBiometricLock) return '/login';

        final needsBiometric = widget.settings.biometricLockEnabled &&
            !widget.auth.biometricVerified;

        if (loggedIn && onAuth) return needsBiometric ? '/biometric-lock' : '/trips';
        if (loggedIn && !onAuth && !onBiometricLock && needsBiometric) {
          return '/biometric-lock';
        }
        if (loggedIn && onBiometricLock && !needsBiometric) return '/trips';
        return null;
      },
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/trips'),
        GoRoute(path: '/home', redirect: (_, _) => '/trips'),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
        GoRoute(
          path: '/biometric-lock',
          builder: (_, _) => const BiometricLockScreen(),
        ),
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
                builder: (context, state) {
                  final tripId = state.pathParameters['id']!;
                  final userId =
                      context.read<AuthProvider>().userId ?? '';
                  return ChangeNotifierProvider(
                    create: (_) {
                      final p = ChatProvider(
                          tripId: tripId, userId: userId);
                      p.init();
                      return p;
                    },
                    child: TripDetailScreen(tripId: tripId),
                  );
                },
              ),
              GoRoute(
                path: '/trip/:id/edit',
                builder: (_, state) =>
                    TripFormScreen(tripId: state.pathParameters['id']),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/friends',
                builder: (_, _) => const FriendsScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => const SettingsScreen(),
                  ),
                ],
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
      widget.profile.load();
      final uid = widget.auth.userId;
      if (uid != null) {
        widget.invitations.init(uid);
        widget.friends.init(uid);
        _push.init();
      }
    } else {
      _push.removeToken();
      widget.invitations.clear();
      widget.friends.clear();
      widget.trips.clear();
      widget.profile.clear();
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
        ChangeNotifierProvider.value(value: widget.profile),
        ChangeNotifierProvider.value(value: widget.invitations),
        ChangeNotifierProvider.value(value: widget.friends),
        ChangeNotifierProvider.value(value: widget.connectivity),
        ChangeNotifierProvider.value(value: widget.offlineQueue),
        Provider<BiometricService>.value(value: widget.biometricService),
      ],
      child: Consumer<SettingsProvider>(
        builder: (_, settings, _) => MaterialApp.router(
          title: 'Trip Planner',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          locale: settings.locale,
          themeMode: settings.themeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            ...PhoneFieldLocalization.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
