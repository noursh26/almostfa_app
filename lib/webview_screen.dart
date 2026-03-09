import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with TickerProviderStateMixin {
  late WebViewController _webController;

  bool _isLoading = true;
  bool _hasError = false;
  double _progress = 0;
  String _currentUrl = _homeUrl;
  bool _isConnected = true;
  DateTime? _lastBackPress;
  int _errorCode = 0;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  late AnimationController _pulseController;
  late AnimationController _errorIconController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _errorIconAnimation;

  static const Color _darkGreen = Color(0xFF074424);
  static const Color _primaryGreen = Color(0xFF0F6B3C);
  static const Color _accentGreen = Color(0xFF1DB954);
  static const Color _lightGreen = Color(0xFFE8F5EE);

  static const String _homeUrl = 'https://almostfa.site';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupConnectivity();
    _initWebView();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _errorIconController.dispose();
    _connectivitySub.cancel();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _errorIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _errorIconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _errorIconController, curve: Curves.elasticOut),
    );
  }

  void _setupConnectivity() {
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final connected = results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);

      if (connected && !_isConnected) {
        _showSnackBar('تم استعادة الاتصال بالإنترنت', Icons.wifi_rounded);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _refresh();
        });
      } else if (!connected && _isConnected) {
        _showSnackBar('انقطع الاتصال بالإنترنت', Icons.wifi_off_rounded);
      }

      if (mounted) setState(() => _isConnected = connected);
    });

    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(() {
          _isConnected = results.isNotEmpty &&
              !results.every((r) => r == ConnectivityResult.none);
        });
      }
    });
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _currentUrl = url;
                _progress = 0;
              });
            }
          },
          onProgress: (progress) {
            if (mounted) {
              setState(() => _progress = progress / 100.0);
            }
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _progress = 1.0;
              _currentUrl = url;
            });
            _injectViewportMeta();
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorCode = error.errorCode;
              });
              _errorIconController.forward(from: 0);
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (_isExternalUrl(url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onHttpError: (error) {
            if (error.response?.statusCode == 404) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorCode = 404;
                });
              }
            }
          },
        ),
      )
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36')
      ..loadRequest(Uri.parse(_homeUrl));
  }

  Future<void> _injectViewportMeta() async {
    try {
      await _webController.runJavaScript('''
        (function() {
          var meta = document.querySelector('meta[name="viewport"]');
          if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            document.head.appendChild(meta);
          }
          meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
        })();
      ''');
    } catch (_) {}
  }

  bool _isExternalUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return !host.contains('almostfa.site') &&
        !host.contains('almostfa') &&
        url.startsWith('http');
  }

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _hasError = false;
      _isLoading = true;
      _progress = 0;
    });
    await _webController.reload();
  }

  Future<void> _goHome() async {
    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    await _webController.loadRequest(Uri.parse(_homeUrl));
  }

  void _showSnackBar(String message, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: _accentGreen, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _darkGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: const Duration(seconds: 2),
        elevation: 8,
      ),
    );
  }

  Future<void> _handleBackButton() async {
    if (await _webController.canGoBack()) {
      await _webController.goBack();
      return;
    }

    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      _showSnackBar('اضغط مرة أخرى للخروج', Icons.exit_to_app_rounded);
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackButton();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                _buildProgressBar(),
                Expanded(
                  child: _hasError || !_isConnected
                      ? _buildErrorState()
                      : _buildWebView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: (_isLoading && _progress < 1.0) ? 3 : 0,
      child: _isLoading && _progress < 1.0
          ? Stack(
              children: [
                Container(color: _lightGreen.withValues(alpha: 0.3)),
                FractionallySizedBox(
                  widthFactor: _progress,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryGreen, _accentGreen],
                      ),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _progress,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refresh,
          color: _primaryGreen,
          backgroundColor: Colors.white,
          strokeWidth: 2.5,
          displacement: 50,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top - 3,
              child: WebViewWidget(controller: _webController),
            ),
          ),
        ),
        if (_isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return AnimatedOpacity(
      opacity: _isLoading ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.white,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _accentGreen.withValues(alpha: 0.15),
                        _lightGreen.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 0.7, 1.0],
                    ),
                  ),
                  child: const Center(
                    child: SpinKitPulse(
                      color: _primaryGreen,
                      size: 70,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'جاري التحميل...',
                style: TextStyle(
                  color: _primaryGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _currentUrl
                    .replaceAll('https://', '')
                    .replaceAll('http://', ''),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 24),

              Container(
                width: 240,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: _lightGreen,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: constraints.maxWidth * _progress,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              colors: [_primaryGreen, _accentGreen],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accentGreen.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              Text(
                '${(_progress * 100).toInt()}%',
                style: TextStyle(
                  color: _primaryGreen.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final bool isNoInternet = !_isConnected;
    final String title = isNoInternet
        ? 'لا يوجد اتصال بالإنترنت'
        : _errorCode == 404
            ? 'الصفحة غير موجودة'
            : 'حدث خطأ في التحميل';
    final String subtitle = isNoInternet
        ? 'تأكد من اتصالك بالإنترنت وحاول مجدداً'
        : _errorCode == 404
            ? 'الصفحة التي تبحث عنها غير متوفرة'
            : 'حدث خطأ أثناء تحميل الصفحة، حاول مجدداً';
    final IconData icon = isNoInternet
        ? Icons.wifi_off_rounded
        : _errorCode == 404
            ? Icons.search_off_rounded
            : Icons.error_outline_rounded;

    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _errorIconAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _lightGreen,
                    boxShadow: [
                      BoxShadow(
                        color: _primaryGreen.withValues(alpha: 0.1),
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 56, color: _primaryGreen),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _darkGreen,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              if (!isNoInternet && _errorCode != 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'رمز الخطأ: $_errorCode',
                    style: TextStyle(
                      fontSize: 12,
                      color: _primaryGreen.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: _primaryGreen.withValues(alpha: 0.4),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _goHome,
                  icon: const Icon(Icons.home_rounded, size: 22),
                  label: const Text(
                    'الصفحة الرئيسية',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                        color: _primaryGreen.withValues(alpha: 0.3), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
