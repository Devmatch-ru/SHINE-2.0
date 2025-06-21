// lib/main.dart (Updated with service integration)
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shine/blocs/auth/auth_cubit.dart';
import 'package:shine/blocs/auth/auth_state.dart';
import 'package:shine/blocs/role/role_cubit.dart';
import 'package:shine/blocs/role/role_state.dart';
import 'package:shine/blocs/onboarding/onboarding_cubit.dart' as onb;
import 'package:shine/blocs/wifi/wifi_cubit.dart';
import 'package:shine/screens/onboarding_screen.dart';
import 'package:shine/screens/roles/role_select.dart';
import 'package:shine/screens/saver_screen.dart';
import 'package:shine/services/auth_service.dart';
import 'package:shine/utils/new_organize/service/error_handling_service.dart';
import 'package:shine/utils/new_organize/service/logging_service.dart';
import 'package:shine/utils/new_organize/service/permission_manager.dart';

// Import new services

import '../../theme/app_constant.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPaintBaselinesEnabled = false;

  // Initialize services
  await _initializeServices();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit(AuthService.instance)),
        BlocProvider(create: (_) => WifiCubit(connectivity: Connectivity())),
        BlocProvider(create: (_) => onb.OnboardingCubit()),
        BlocProvider(create: (_) => RoleCubit()),
      ],
      child: const ShineApp(),
    ),
  );
}

Future<void> _initializeServices() async {
  final loggingService = LoggingService();
  final errorService = ErrorHandlingService();

  try {
    loggingService.info('App', 'Initializing Shine application...');

    // Setup error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      errorService.handleError(
        'Flutter',
        details.exception,
        details: details.context?.toString(),
        severity: ErrorSeverity.high,
        stackTrace: details.stack,
      );
    };

    loggingService.info('App', 'Services initialized successfully');
  } catch (e, stackTrace) {
    errorService.handleError(
      'App',
      e,
      details: 'Failed to initialize services',
      severity: ErrorSeverity.critical,
      stackTrace: stackTrace,
    );
  }
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class ShineApp extends StatelessWidget {
  const ShineApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Request permissions asynchronously
    Future.microtask(() => _requestPermissions(context));

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'SHINE',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: AppColors.primaryLight,
          secondary: AppColors.accentLight,
          onSecondary: Colors.white,
          error: AppColors.error,
          onError: Colors.white,
          background: AppColors.bgMain,
          onBackground: AppColors.primary,
          surface: Colors.white,
          onSurface: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.bgMain,
        textTheme: const TextTheme(
          displayLarge: AppTextStyles.h1,
          displayMedium: AppTextStyles.h2,
          titleLarge: AppTextStyles.lead,
          bodyLarge: AppTextStyles.body,
          bodySmall: AppTextStyles.hintAccent,
          bodyMedium: AppTextStyles.hintMain,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.primaryLight,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s, vertical: AppSpacing.m),
          border: OutlineInputBorder(
            borderRadius: AppBorderRadius.m,
            borderSide: BorderSide.none,
          ),
          hintStyle: AppTextStyles.hintMain,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 32,
            color: AppColors.primary,
            fontWeight: FontWeight.w400,
          ),
          iconTheme: IconThemeData(color: AppColors.primary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryLight,
            shape: RoundedRectangleBorder(
              borderRadius: AppBorderRadius.xs,
            ),
            textStyle: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 17,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.s,
            ),
          ),
        ),
      ),
      home: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          if (authState is AuthLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (authState is Unauthenticated) {
            return const SaverScreen();
          }

          if (authState is Authenticated) {
            return BlocBuilder<onb.OnboardingCubit, onb.OnboardingState>(
              builder: (context, onbState) {
                if (onbState is onb.OnboardingRequired) {
                  return const OnboardingScreen();
                }
                return BlocBuilder<RoleCubit, RoleState>(
                  builder: (context, roleState) {
                    return const RoleSelectScreen();
                  },
                );
              },
            );
          }

          return const SaverScreen();
        },
      ),
    );
  }

  Future<void> _requestPermissions(BuildContext context) async {
    try {
      final permissionManager = PermissionManager();
      final shouldRequest = await permissionManager.shouldRequestPermissions();

      if (shouldRequest) {
        await permissionManager.requestPermissionsWithUI(context);
      }
    } catch (e) {
      final errorService = ErrorHandlingService();
      errorService.handlePermissionError('Main', e);
    }
  }
}

// Example of how to use services in a widget
class ExampleServiceUsage extends StatefulWidget {
  @override
  _ExampleServiceUsageState createState() => _ExampleServiceUsageState();
}

class _ExampleServiceUsageState extends State<ExampleServiceUsage>
    with LoggerMixin, ErrorHandlerMixin {

  @override
  String get loggerContext => 'ExampleWidget';

  final LoggingService _loggingService = LoggingService();
  final ErrorHandlingService _errorService = ErrorHandlingService();

  @override
  void initState() {
    super.initState();
    _initializeExample();
  }

  Future<void> _initializeExample() async {
    try {
      logInfo('Initializing example widget...');

      // Example of using services
      await _performSomeOperation();

      logInfo('Example widget initialized successfully');
    } catch (e, stackTrace) {
      handleError('_initializeExample', e, stackTrace: stackTrace);
    }
  }

  Future<void> _performSomeOperation() async {
    // Example operation that might fail
    await Future.delayed(Duration(milliseconds: 100));
    // throw Exception('Example error'); // Uncomment to test error handling
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Service Usage Example'),
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report),
            onPressed: _showDebugInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Listen to error stream
          StreamBuilder<AppError>(
            stream: _errorService.errorStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final error = snapshot.data!;
                return Container(
                  margin: EdgeInsets.all(8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Error: ${error.userFriendlyMessage}',
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),

          // Listen to log entries
          Expanded(
            child: ValueListenableBuilder<List<LogEntry>>(
              valueListenable: _loggingService.entriesNotifier,
              builder: (context, entries, child) {
                return ListView.builder(
                  itemCount: entries.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    final entry = entries[entries.length - 1 - index];
                    return ListTile(
                      dense: true,
                      leading: _getLogIcon(entry.level),
                      title: Text(
                        entry.message,
                        style: TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        '${entry.context} • ${entry.timestamp.toString().split('.').first}',
                        style: TextStyle(fontSize: 10),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Test error handling
          handleUserError('ExampleWidget', 'This is a test user error');
        },
        child: Icon(Icons.error),
      ),
    );
  }

  Widget _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Icon(Icons.bug_report, size: 16, color: Colors.grey);
      case LogLevel.info:
        return Icon(Icons.info, size: 16, color: Colors.blue);
      case LogLevel.warning:
        return Icon(Icons.warning, size: 16, color: Colors.orange);
      case LogLevel.error:
        return Icon(Icons.error, size: 16, color: Colors.red);
    }
  }

  void _showDebugInfo() {
    final report = _errorService.generateErrorReport();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Debug Information'),
        content: SingleChildScrollView(
          child: Text(
            report,
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}