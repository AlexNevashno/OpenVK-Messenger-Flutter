import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/messenger_store.dart';
import '../../services/theme_manager.dart';

class LoginView extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginView({super.key, required this.onLoginSuccess});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _serverController = TextEditingController(text: 'https://openvk.org');
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _serverController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  String _cleanError(dynamic e) {
    String msg = e.toString().replaceAll('Exception: ', '').trim();
    if (msg.contains('SocketException') || msg.contains('Connection failed') || msg.contains('Operation not permitted')) {
      return 'Ошибка соединения с сервером. Проверьте доступ в интернет и адрес сервера.';
    }
    return msg;
  }

  Future<void> _loginWithPassword() async {
    final server = _serverController.text.trim();
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (server.isEmpty || login.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Заполните все поля');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final store = context.read<MessengerStore>();
      await store.loginWithPassword(
        serverURL: server,
        login: login,
        password: password,
      );
      widget.onLoginSuccess();
    } catch (e) {
      setState(() => _errorMessage = _cleanError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithToken() async {
    final server = _serverController.text.trim();
    final token = _tokenController.text.trim();

    if (server.isEmpty || token.isEmpty) {
      setState(() => _errorMessage = 'Укажите сервер и токен');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final store = context.read<MessengerStore>();
      await store.loginWithToken(
        serverURL: server,
        token: token,
      );
      widget.onLoginSuccess();
    } catch (e) {
      setState(() => _errorMessage = _cleanError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final isDark = theme.isDark(context);

    return Scaffold(
      backgroundColor: theme.getBackgroundColor(context),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222223) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'VK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'OpenVK Messenger',
                      style: TextStyle(
                        color: theme.getTextColor(context),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Server URL input
                TextField(
                  controller: _serverController,
                  style: TextStyle(color: theme.getTextColor(context)),
                  decoration: InputDecoration(
                    labelText: 'Адрес сервера',
                    labelStyle: TextStyle(color: theme.getSecondaryTextColor(context)),
                    prefixIcon: const Icon(Icons.dns_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // Tabs: Password / Token
                TabBar(
                  controller: _tabController,
                  labelColor: theme.accentColor,
                  unselectedLabelColor: theme.getSecondaryTextColor(context),
                  indicatorColor: theme.accentColor,
                  tabs: const [
                    Tab(text: 'Логин и пароль'),
                    Tab(text: 'По токену'),
                  ],
                ),
                const SizedBox(height: 16),

                // Tab Views
                SizedBox(
                  height: 150,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Login + Password
                      Column(
                        children: [
                          TextField(
                            controller: _loginController,
                            style: TextStyle(color: theme.getTextColor(context)),
                            decoration: InputDecoration(
                              labelText: 'Логин или E-mail',
                              labelStyle: TextStyle(color: theme.getSecondaryTextColor(context)),
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: TextStyle(color: theme.getTextColor(context)),
                            decoration: InputDecoration(
                              labelText: 'Пароль',
                              labelStyle: TextStyle(color: theme.getSecondaryTextColor(context)),
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onSubmitted: (_) => _loginWithPassword(),
                          ),
                        ],
                      ),

                      // Token
                      Column(
                        children: [
                          TextField(
                            controller: _tokenController,
                            style: TextStyle(color: theme.getTextColor(context)),
                            decoration: InputDecoration(
                              labelText: 'Access Token',
                              labelStyle: TextStyle(color: theme.getSecondaryTextColor(context)),
                              prefixIcon: const Icon(Icons.key_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onSubmitted: (_) => _loginWithToken(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_tabController.index == 0) {
                            _loginWithPassword();
                          } else {
                            _loginWithToken();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Войти',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
