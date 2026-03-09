import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════
  // Controllers
  // ═══════════════════════════════════════
  late WebViewController _webController;

  // ═══════════════════════════════════════
  // State
  // ═══════════════════════════════════════
  bool _isLoading = true;
  bool _hasError = false;
  double _progress = 0;
  String _currentUrl = _homeUrl;
  String _pageTitle = 'المصطفى';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isConnected = true;
  DateTime? _lastBackPress;
  int _errorCode = 0;

  // ═══════════════════════════════════════
  // Connectivity
  // ═══════════════════════════════════════
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  // ═══════════════════════════════════════
  // Animation Controllers
  // ═══════════════════════════════════════
  late AnimationController _pulseController;
  late AnimationController _errorIconController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _errorIconAnimation;

  // ═══════════════════════════════════════
  // Color Palette
  // ═══════════════════════════════════════
  static const Color _darkGreen = Color(0xFF074424);
  static const Color _primaryGreen = Color(0xFF0F6B3C);
  static const Color _accentGreen = Color(0xFF1DB954);
  static const Color _lightGreen = Color(0xFFE8F5EE);
  static const Color _headerStart = Color(0xFF052E18);
  static const Color _headerEnd = Color(0xFF0F6B3C);

  static const String _homeUrl = 'https://almostfa.site';

  // ═══════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════
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

  // ═══════════════════════════════════════
  // Setup Methods
  // ═══════════════════════════════════════
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
        _showSnackBar(
            'انقطع الاتصال بالإنترنت', Icons.wifi_off_rounded);
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
            final title = await _webController.getTitle();
            final canBack = await _webController.canGoBack();
            final canForward = await _webController.canGoForward();
            setState(() {
              _isLoading = false;
              _progress = 1.0;
              _currentUrl = url;
              _canGoBack = canBack;
              _canGoForward = canForward;
              if (title != null && title.isNotEmpty) {
                _pageTitle = title;
              }
            });
            _injectCustomCSS();
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
              _launchExternal(url);
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
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..loadRequest(Uri.parse(_homeUrl));
  }

  // ═══════════════════════════════════════
  // WebView Helpers
  // ═══════════════════════════════════════
  Future<void> _injectCustomCSS() async {
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

  Future<void> _launchExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ═══════════════════════════════════════
  // User Actions
  // ═══════════════════════════════════════
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

  Future<void> _goBack() async {
    if (await _webController.canGoBack()) {
      HapticFeedback.lightImpact();
      await _webController.goBack();
    }
  }

  Future<void> _goForward() async {
    if (await _webController.canGoForward()) {
      HapticFeedback.lightImpact();
      await _webController.goForward();
    }
  }

  void _shareUrl() {
    HapticFeedback.lightImpact();
    Share.share(
      '$_pageTitle\n$_currentUrl',
      subject: _pageTitle,
    );
  }

  void _copyUrl() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _currentUrl));
    _showSnackBar('تم نسخ الرابط', Icons.copy_rounded);
  }

  Future<void> _clearCache() async {
    HapticFeedback.mediumImpact();
    await _webController.clearCache();
    await _webController.clearLocalStorage();
    if (mounted) {
      _showSnackBar('تم مسح ذاكرة التخزين المؤقت', Icons.cleaning_services_rounded);
      _refresh();
    }
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

  void _showMoreMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildMenuSheet(ctx),
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

  // ═══════════════════════════════════════
  // Build Methods
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackButton();
      },
      child: Scaffold(
        backgroundColor: _darkGreen,
        body: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(
              child: _hasError || !_isConnected
                  ? _buildErrorState()
                  : _buildWebView(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ───────────────────────────────────────
  // Header
  // ───────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_headerStart, _headerEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Logo with glow effect
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accentGreen.withOpacity(0.2),
                      _accentGreen.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: _accentGreen.withOpacity(0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentGreen.withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'م',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Title & URL
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'المصطفى',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          _isConnected
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          color: _isConnected
                              ? _accentGreen.withOpacity(0.7)
                              : Colors.orange.withOpacity(0.7),
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _currentUrl
                                .replaceAll('https://', '')
                                .replaceAll('http://', ''),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 10,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Connection status dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isConnected ? _accentGreen : Colors.red,
                  boxShadow: [
                    BoxShadow(
                      color: (_isConnected ? _accentGreen : Colors.red)
                          .withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Refresh / Loading button
              _buildHeaderButton(
                onTap: _refresh,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
              ),

              const SizedBox(width: 8),

              // More menu button
              _buildHeaderButton(
                onTap: _showMoreMenu,
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton(
      {required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
          ),
        ),
        child: Center(child: child),
      ),
    );
  }

  // ───────────────────────────────────────
  // Progress Bar
  // ───────────────────────────────────────
  Widget _buildProgressBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: (_isLoading && _progress < 1.0) ? 3 : 0,
      child: _isLoading && _progress < 1.0
          ? Stack(
              children: [
                Container(color: _lightGreen.withOpacity(0.3)),
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
                // Shimmer effect on progress
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
                            Colors.white.withOpacity(0.4),
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

  // ───────────────────────────────────────
  // WebView
  // ───────────────────────────────────────
  Widget _buildWebView() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refresh,
          color: _primaryGreen,
          backgroundColor: Colors.white,
          strokeWidth: 2.5,
          displacement: 50,
          child: WebViewWidget(controller: _webController),
        ),
        if (_isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  // ───────────────────────────────────────
  // Loading Overlay
  // ───────────────────────────────────────
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
              // Pulsating logo
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _accentGreen.withOpacity(0.15),
                        _lightGreen.withOpacity(0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 0.7, 1.0],
                    ),
                  ),
                  child: Center(
                    child: SpinKitPulse(
                      color: _primaryGreen,
                      size: 60,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Loading text
              Text(
                'جاري التحميل...',
                style: TextStyle(
                  color: _primaryGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                _currentUrl
                    .replaceAll('https://', '')
                    .replaceAll('http://', ''),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 20),

              // Mini progress bar
              Container(
                width: 220,
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
                                color: _accentGreen.withOpacity(0.4),
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

              const SizedBox(height: 10),

              // Percentage
              Text(
                '${(_progress * 100).toInt()}%',
                style: TextStyle(
                  color: _primaryGreen.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────
  // Error State
  // ───────────────────────────────────────
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
              // Animated error icon
              ScaleTransition(
                scale: _errorIconAnimation,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _lightGreen,
                    boxShadow: [
                      BoxShadow(
                        color: _primaryGreen.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 52, color: _primaryGreen),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _darkGreen,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              if (!isNoInternet && _errorCode != 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'رمز الخطأ: $_errorCode',
                    style: TextStyle(
                      fontSize: 11,
                      color: _primaryGreen.withOpacity(0.7),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 36),

              // Retry button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: _primaryGreen.withOpacity(0.4),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Home button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _goHome,
                  icon: const Icon(Icons.home_rounded, size: 20),
                  label: const Text(
                    'الصفحة الرئيسية',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                        color: _primaryGreen.withOpacity(0.3), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────
  // Bottom Navigation Bar
  // ───────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _darkGreen,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                icon: Icons.arrow_back_ios_rounded,
                label: 'رجوع',
                onTap: _goBack,
                enabled: _canGoBack,
              ),
              _buildNavItem(
                icon: Icons.arrow_forward_ios_rounded,
                label: 'تقدم',
                onTap: _goForward,
                enabled: _canGoForward,
              ),
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'الرئيسية',
                onTap: _goHome,
                enabled: true,
                isHome: true,
              ),
              _buildNavItem(
                icon: Icons.share_rounded,
                label: 'مشاركة',
                onTap: _shareUrl,
                enabled: true,
              ),
              _buildNavItem(
                icon: Icons.refresh_rounded,
                label: 'تحديث',
                onTap: _refresh,
                enabled: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool enabled,
    bool isHome = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: isHome
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accentGreen.withOpacity(0.15),
                      border: Border.all(
                        color: _accentGreen.withOpacity(0.3),
                      ),
                    )
                  : null,
              child: Icon(
                icon,
                color: enabled
                    ? (isHome ? _accentGreen : Colors.white70)
                    : Colors.white24,
                size: isHome ? 22 : 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: enabled
                    ? (isHome
                        ? _accentGreen.withOpacity(0.9)
                        : Colors.white54)
                    : Colors.white24,
                fontSize: 9,
                fontWeight: isHome ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────
  // Bottom Menu Sheet
  // ───────────────────────────────────────
  Widget _buildMenuSheet(BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _lightGreen,
                  ),
                  child: const Icon(Icons.settings_rounded,
                      color: _primaryGreen, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'خيارات إضافية',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _darkGreen,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Menu Items
          _buildMenuItem(
            icon: Icons.copy_rounded,
            title: 'نسخ الرابط',
            subtitle: _currentUrl,
            onTap: () {
              Navigator.pop(ctx);
              _copyUrl();
            },
          ),
          _buildMenuItem(
            icon: Icons.share_rounded,
            title: 'مشاركة الصفحة',
            subtitle: 'شارك هذه الصفحة مع الآخرين',
            onTap: () {
              Navigator.pop(ctx);
              _shareUrl();
            },
          ),
          _buildMenuItem(
            icon: Icons.home_rounded,
            title: 'الصفحة الرئيسية',
            subtitle: 'العودة إلى الصفحة الرئيسية',
            onTap: () {
              Navigator.pop(ctx);
              _goHome();
            },
          ),
          _buildMenuItem(
            icon: Icons.cleaning_services_rounded,
            title: 'مسح ذاكرة التخزين',
            subtitle: 'حذف الملفات المؤقتة والكاش',
            onTap: () {
              Navigator.pop(ctx);
              _clearCache();
            },
          ),
          _buildMenuItem(
            icon: Icons.open_in_browser_rounded,
            title: 'فتح في المتصفح',
            subtitle: 'فتح الصفحة في متصفح خارجي',
            onTap: () {
              Navigator.pop(ctx);
              _launchExternal(_currentUrl);
            },
          ),
          _buildMenuItem(
            icon: Icons.info_outline_rounded,
            title: 'حول التطبيق',
            subtitle: 'المصطفى - الإصدار 1.0.0',
            onTap: () {
              Navigator.pop(ctx);
              _showAboutDialog();
            },
            isLast: true,
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _lightGreen,
                  ),
                  child: Icon(icon, color: _primaryGreen, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _darkGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[300],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 74,
            color: Colors.grey[100],
          ),
      ],
    );
  }

  // ───────────────────────────────────────
  // About Dialog
  // ───────────────────────────────────────
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_darkGreen, _primaryGreen],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryGreen.withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'م',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'المصطفى',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _darkGreen,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'الإصدار 1.0.0',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'تطبيق المصطفى هو التطبيق الرسمي لموقع almostfa.site. يوفر تجربة تصفح سلسة وسريعة مع واجهة مستخدم احترافية وميزات متقدمة.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _darkGreen,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                            color: _primaryGreen.withOpacity(0.3)),
                      ),
                      child: const Text('إغلاق'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _launchExternal('https://almostfa.site');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text('زيارة الموقع'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
