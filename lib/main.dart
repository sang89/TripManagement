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
import 'models/event.dart';
import 'providers/auth_provider.dart';
import 'providers/blocked_users_provider.dart';
import 'providers/event_chat_provider.dart';
import 'providers/event_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/invitations_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/user_profile_provider.dart';
import 'screens/auth/biometric_lock_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/subscription/paywall_screen.dart';
import 'screens/auth/register_screen.dart';
import 'services/biometric_service.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/events/event_form_screen.dart';
import 'screens/events/event_invite_screen.dart';
import 'screens/events/session_invite_screen.dart';
import 'screens/events/session_scan_screen.dart';
import 'screens/events/event_type_list_screen.dart';
import 'screens/events/events_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/blocked_users_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/shell/shell_scaffold.dart';
import 'services/connectivity_service.dart';
import 'services/offline_queue.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter framework bug (still present in 3.44): _InkResponseState receives
  // a _HighlightModeManager callback while its element is deactivated-but-not-
  // disposed, so `mounted` is still true but ancestor lookup asserts. This only
  // fires in debug mode and has no effect on release builds or user-visible
  // behaviour. Filter it so it doesn't flood the debug console.
  assert(() {
    final original = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains("deactivated widget's ancestor")) {
        return;
      }
      original?.call(details);
    };
    return true;
  }());
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

  final profile = UserProfileProvider(
    connectivity: connectivity,
    queue: offlineQueue,
  );
  final invitations = InvitationsProvider();
  final friends = FriendsProvider();
  final blockedUsers = BlockedUsersProvider();
  final events = EventProvider();
  final subscription = SubscriptionProvider();
  final biometricService = BiometricService();

  if (auth.isLoggedIn) {
    await profile.load();
    await blockedUsers.load();
    final uid = auth.userId;
    if (uid != null) {
      await invitations.init(uid);
      await friends.init(uid);
      await subscription.load(uid);
    }
    await events.load();
  }

  runApp(TripManagementApp(
    auth: auth,
    settings: settings,
    profile: profile,
    invitations: invitations,
    friends: friends,
    blockedUsers: blockedUsers,
    events: events,
    subscription: subscription,
    connectivity: connectivity,
    offlineQueue: offlineQueue,
    biometricService: biometricService,
  ));
}

class TripManagementApp extends StatefulWidget {
  final AuthProvider auth;
  final SettingsProvider settings;
  final UserProfileProvider profile;
  final InvitationsProvider invitations;
  final FriendsProvider friends;
  final BlockedUsersProvider blockedUsers;
  final EventProvider events;
  final SubscriptionProvider subscription;
  final ConnectivityService connectivity;
  final OfflineQueue offlineQueue;
  final BiometricService biometricService;

  const TripManagementApp({
    super.key,
    required this.auth,
    required this.settings,
    required this.profile,
    required this.invitations,
    required this.friends,
    required this.blockedUsers,
    required this.events,
    required this.subscription,
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
      onTripInviteTap: () => _router.go('/events'),
      onMentionTap: (eventId) => _router.go('/event/$eventId'),
    );

    widget.auth.addListener(_onAuthChanged);

    _router = GoRouter(
      refreshListenable: Listenable.merge([widget.auth, widget.settings]),
      redirect: (context, state) {
        final loggedIn = widget.auth.isLoggedIn;
        final loc = state.matchedLocation;
        final onAuth = loc == '/login' || loc == '/register';
        final onBiometricLock = loc == '/biometric-lock';
        final isPublic = loc.startsWith('/event/invite/') ||
            loc.startsWith('/session/invite/') ||
            loc == '/scan';

        if (!loggedIn && !onBiometricLock && !onAuth && !isPublic) return '/login';
        if (!loggedIn && onBiometricLock) return '/login';

        final needsBiometric = widget.settings.biometricLockEnabled &&
            !widget.auth.biometricVerified;

        if (loggedIn && onAuth) return needsBiometric ? '/biometric-lock' : '/events';
        if (loggedIn && !onAuth && !onBiometricLock && needsBiometric) {
          return '/biometric-lock';
        }
        if (loggedIn && onBiometricLock && !needsBiometric) return '/events';
        return null;
      },
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/events'),
        GoRoute(path: '/home', redirect: (_, _) => '/events'),
        GoRoute(path: '/trips', redirect: (_, _) => '/events'),
        GoRoute(
            path: '/trip/:id',
            redirect: (_, state) =>
                '/event/${state.pathParameters['id']}'),
        GoRoute(
            path: '/trip/:id/edit',
            redirect: (_, state) =>
                '/event/${state.pathParameters['id']}/edit'),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
        GoRoute(path: '/paywall', builder: (_, _) => const PaywallScreen()),
        GoRoute(
          path: '/biometric-lock',
          builder: (_, _) => const BiometricLockScreen(),
        ),
        GoRoute(
          path: '/event/invite/:code',
          builder: (_, state) =>
              EventInviteScreen(inviteCode: state.pathParameters['code']!),
        ),
        GoRoute(
          path: '/session/invite/:code',
          builder: (_, state) =>
              SessionInviteScreen(inviteCode: state.pathParameters['code']!),
        ),
        GoRoute(
          path: '/scan',
          builder: (_, _) => const SessionScanScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => ShellScaffold(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/events',
                builder: (_, _) => const EventsScreen(),
              ),
              GoRoute(
                path: '/events/trip',
                builder: (_, _) =>
                    const EventTypeListScreen(eventType: EventType.trip),
              ),
              GoRoute(
                path: '/events/birthday',
                builder: (_, _) =>
                    const EventTypeListScreen(eventType: EventType.birthday),
              ),
              GoRoute(
                path: '/events/wedding',
                builder: (_, _) =>
                    const EventTypeListScreen(eventType: EventType.wedding),
              ),
              GoRoute(
                path: '/events/social',
                builder: (_, _) =>
                    const EventTypeListScreen(eventType: EventType.social),
              ),
              GoRoute(
                path: '/events/quick_bites',
                builder: (_, _) =>
                    const EventTypeListScreen(eventType: EventType.quickBites),
              ),
              GoRoute(
                path: '/event/new',
                builder: (_, state) {
                  final typeStr =
                      state.uri.queryParameters['type'];
                  final defaultType = typeStr != null
                      ? EventType.fromString(typeStr)
                      : null;
                  return EventFormScreen(
                      defaultEventType: defaultType);
                },
              ),
              GoRoute(
                path: '/event/:id',
                builder: (context, state) {
                  final eventId = state.pathParameters['id']!;
                  final userId =
                      context.read<AuthProvider>().userId ?? '';
                  return ChangeNotifierProvider(
                    create: (_) {
                      final p = EventChatProvider(
                          eventId: eventId, userId: userId);
                      p.init();
                      return p;
                    },
                    child: EventDetailScreen(eventId: eventId),
                  );
                },
              ),
              GoRoute(
                path: '/event/:id/edit',
                builder: (_, state) =>
                    EventFormScreen(eventId: state.pathParameters['id']),
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
                    routes: [
                      GoRoute(
                        path: 'blocked',
                        builder: (_, _) => const BlockedUsersScreen(),
                      ),
                    ],
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
      widget.profile.load();
      widget.blockedUsers.load();
      widget.events.load();
      final uid = widget.auth.userId;
      if (uid != null) {
        widget.invitations.init(uid);
        widget.friends.init(uid);
        widget.subscription.load(uid);
        _push.init();
      }
    } else {
      _push.removeToken();
      widget.invitations.clear();
      widget.friends.clear();
      widget.blockedUsers.clear();
      widget.profile.clear();
      widget.events.clear();
      widget.subscription.clear();
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
        ChangeNotifierProvider.value(value: widget.profile),
        ChangeNotifierProvider.value(value: widget.invitations),
        ChangeNotifierProvider.value(value: widget.friends),
        ChangeNotifierProvider.value(value: widget.blockedUsers),
        ChangeNotifierProvider.value(value: widget.events),
        ChangeNotifierProvider.value(value: widget.subscription),
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
