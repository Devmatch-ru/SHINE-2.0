import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../services/auth/google_auth_service.dart';
import '../../services/auth_service.dart';

class OAuthTestScreen extends StatefulWidget {
  const OAuthTestScreen({super.key});

  @override
  State<OAuthTestScreen> createState() => _OAuthTestScreenState();
}

class _OAuthTestScreenState extends State<OAuthTestScreen> {
  final List<String> _logs = [];
  bool _isLoading = false;
  Map<String, dynamic> _userInfo = {};
  Map<String, dynamic> _storedData = {};

  @override
  void initState() {
    super.initState();
    _loadStoredData();
    _addLog('🚀 OAuth Test Screen initialized');
  }

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _logs.add('[$timestamp] $message');
    });
    print(message);
  }

  Future<void> _loadStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _storedData = {
          'is_logged_in': prefs.getBool('is_logged_in') ?? false,
          'user_email': prefs.getString('user_email') ?? 'Not set',
          'auth_type': prefs.getString('auth_type') ?? 'Not set',
          'google_id_token': prefs.getString('google_id_token') ?? 'Not set',
          'google_access_token': prefs.getString('google_access_token') ?? 'Not set',
          'google_pending_email': prefs.getString('google_pending_email') ?? 'Not set',
        };
      });
      _addLog('📱 Loaded stored data from SharedPreferences');
    } catch (e) {
      _addLog('❌ Error loading stored data: $e');
    }
  }

  Future<void> _testGoogleService() async {
    setState(() => _isLoading = true);
    _addLog('🔍 Testing Google Service directly...');

    try {
      // Проверяем текущее состояние
      final isSignedIn = await GoogleAuthService.instance.isSignedIn();
      _addLog('📊 Is signed in: $isSignedIn');

      final currentUser = GoogleAuthService.instance.currentUser;
      _addLog('👤 Current user: ${currentUser?.email ?? 'None'}');

      // Пытаемся получить пользователя
      final googleUser = await GoogleAuthService.instance.signInAndGetUser();

      if (googleUser != null) {
        setState(() {
          _userInfo = {
            'id': googleUser.id,
            'email': googleUser.email,
            'name': googleUser.name ?? 'Not provided',
            'photoUrl': googleUser.photoUrl ?? 'Not provided',
            'idToken': googleUser.idToken != null ? 'Present (${googleUser.idToken!.length} chars)' : 'Not present',
            'accessToken': googleUser.accessToken != null ? 'Present (${googleUser.accessToken!.length} chars)' : 'Not present',
          };
        });
        _addLog('✅ Google user retrieved successfully');
        _addLog('📧 Email: ${googleUser.email}');
        _addLog('👤 Name: ${googleUser.name}');
        _addLog('🆔 ID: ${googleUser.id}');
      } else {
        _addLog('❌ Google user is null (user cancelled or error)');
      }
    } catch (e) {
      _addLog('💥 Google Service error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAuthCubit() async {
    setState(() => _isLoading = true);
    _addLog('🔍 Testing AuthCubit Google sign in...');

    try {
      // Слушаем изменения состояния
      final subscription = context.read<AuthCubit>().stream.listen((state) {
        if (state is AuthLoading) {
          _addLog('⏳ AuthCubit: Loading state');
        } else if (state is Authenticated) {
          _addLog('✅ AuthCubit: Authenticated successfully');
          _addLog('📧 User: ${state.email}');
          _addLog('👤 Name: ${state.name ?? 'Not provided'}');
          _addLog('🆔 ID: ${state.id}');
        } else if (state is AuthError) {
          _addLog('❌ AuthCubit: Error - ${state.message}');
        } else if (state is Unauthenticated) {
          _addLog('🚫 AuthCubit: Unauthenticated');
        }
      });

      // Выполняем авторизацию
      context.read<AuthCubit>().signInWithGoogle();

      // Отменяем подписку через 10 секунд
      Future.delayed(const Duration(seconds: 10), () {
        subscription.cancel();
      });

    } catch (e) {
      _addLog('💥 AuthCubit error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAuthService() async {
    setState(() => _isLoading = true);
    _addLog('🔍 Testing AuthService directly...');

    try {
      final authService = AuthService.instance;

      // Проверяем текущее состояние
      final isLoggedIn = await authService.isLoggedIn();
      _addLog('📊 AuthService isLoggedIn: $isLoggedIn');

      // Пытаемся автоматический вход
      final autoUser = await authService.tryAutoSignIn();
      if (autoUser != null) {
        _addLog('🔄 Auto sign-in successful: ${autoUser.email}');
      } else {
        _addLog('🔄 Auto sign-in failed or not available');
      }

      // Пытаемся войти через Google
      final googleUser = await authService.signInWithGoogle();
      if (googleUser != null) {
        _addLog('✅ AuthService Google sign-in successful');
        _addLog('📧 Email: ${googleUser.email}');
      } else {
        _addLog('❌ AuthService Google sign-in failed');
      }

    } catch (e) {
      _addLog('💥 AuthService error: $e');
      if (e.toString().contains('google_verification_required')) {
        _addLog('📧 Email verification required detected');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    _addLog('🚪 Signing out...');

    try {
      await context.read<AuthCubit>().signOut();
      await _loadStoredData();
      setState(() {
        _userInfo.clear();
      });
      _addLog('✅ Sign out completed');
    } catch (e) {
      _addLog('❌ Sign out error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog('🧹 Logs cleared');
  }

  void _copyLogs() {
    final logsText = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: logsText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OAuth Test'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
            tooltip: 'Copy logs',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Current Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        String statusText = 'Unknown';
                        Color statusColor = Colors.grey;

                        if (state is AuthLoading) {
                          statusText = 'Loading...';
                          statusColor = Colors.orange;
                        } else if (state is Authenticated) {
                          statusText = 'Authenticated as ${state.email}';
                          statusColor = Colors.green;
                        } else if (state is Unauthenticated) {
                          statusText = 'Not authenticated';
                          statusColor = Colors.red;
                        } else if (state is AuthError) {
                          statusText = 'Error: ${state.message}';
                          statusColor = Colors.red;
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            border: Border.all(color: statusColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Test Functions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildTestButton(
                      'Test Google Service',
                      'Direct test of GoogleAuthService',
                      Icons.account_circle,
                      _testGoogleService,
                      Colors.red,
                    ),

                    const SizedBox(height: 8),

                    _buildTestButton(
                      'Test Auth Cubit',
                      'Test through AuthCubit (recommended)',
                      Icons.security,
                      _testAuthCubit,
                      Colors.blue,
                    ),

                    const SizedBox(height: 8),

                    _buildTestButton(
                      'Test Auth Service',
                      'Direct test of AuthService',
                      Icons.engineering,
                      _testAuthService,
                      Colors.purple,
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _loadStoredData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _signOut,
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // User Info
            if (_userInfo.isNotEmpty)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Text(
                            'User Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._userInfo.entries.map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                '${entry.key}:',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value.toString(),
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Stored Data
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Stored Data (SharedPreferences)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._storedData.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              '${entry.key}:',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value.toString(),
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Logs
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.terminal, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Logs (${_logs.length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const Spacer(),
                        if (_isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _logs.isEmpty ? 'No logs yet...' : _logs.join('\n'),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
      String title,
      String description,
      IconData icon,
      VoidCallback onPressed,
      Color color,
      ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          color: color.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.play_arrow, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}