import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/app_env.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_scope.dart';
import 'dashboard/shell.dart';
import 'dashboard/shimmer.dart';
import 'locale/locale_controller.dart';
import 'onboarding/onboarding_flow.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/landing_screen.dart';
import 'theme/app_theme.dart';
import 'variations/models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.load();

  if (AppEnv.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      publishableKey: AppEnv.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  final auth = AuthController.supabase();
  await auth.init();

  final locale = LocaleController();
  await locale.load();

  runApp(FinanceAiApp(auth: auth, locale: locale));
}

class FinanceAiApp extends StatefulWidget {
  const FinanceAiApp({super.key, this.auth, this.locale});

  /// When null (widget tests), a fake controller is created.
  final AuthController? auth;
  final LocaleController? locale;

  @override
  State<FinanceAiApp> createState() => _FinanceAiAppState();
}

class _FinanceAiAppState extends State<FinanceAiApp> {
  late final VariationController _variations = VariationController();
  late final AuthController _auth =
      widget.auth ?? AuthController.fake();
  late final LocaleController _locale =
      widget.locale ?? LocaleController();
  var _ownedFake = false;
  var _ownedLocale = false;

  @override
  void initState() {
    super.initState();
    if (widget.auth == null) {
      _ownedFake = true;
      // ignore: discarded_futures
      _auth.init();
    }
    if (widget.locale == null) {
      _ownedLocale = true;
      // ignore: discarded_futures
      _locale.load();
    }
  }

  @override
  void dispose() {
    _variations.dispose();
    if (_ownedFake) _auth.dispose();
    if (_ownedLocale) _locale.dispose();
    super.dispose();
  }

  Widget get _home {
    if (!_auth.ready || _auth.loading || _auth.profilePending) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: const [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 160, height: 28, borderRadius: 8),
                    SizedBox(height: 10),
                    ShimmerBox(width: 220, height: 12),
                  ],
                ),
              ),
              DashLoadingBody(kpiCount: 2, listRows: 5),
            ],
          ),
        ),
      );
    }
    return switch (_auth.destinationForSession()) {
      AuthDestination.resetPassword => const ResetPasswordScreen(),
      AuthDestination.dashboard => const DashboardShell(),
      AuthDestination.onboarding => const OnboardingFlow(),
      AuthDestination.landing => const LandingScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: LocaleScope(
        controller: _locale,
        child: VariationScope(
          controller: _variations,
          child: ListenableBuilder(
            listenable: Listenable.merge([_variations, _auth, _locale]),
            builder: (context, _) {
              return MaterialApp(
                // Remount once on sign-in/out so the auth stack can't sit under the dashboard.
                key: ValueKey<bool>(_auth.isSignedIn),
                title: 'FinanceAI',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: _variations.appearance.themeMode,
                locale: _locale.locale,
                supportedLocales: const [
                  Locale('en'),
                  Locale('fr'),
                ],
                home: _home,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Exposed for tests that assert dotenv is optional.
bool get dotenvIsEmpty => dotenv.env.isEmpty;
