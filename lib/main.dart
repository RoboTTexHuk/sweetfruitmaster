import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform, HttpHeaders, HttpClient;
import 'dart:ui';

import 'package:appsflyer_sdk/appsflyer_sdk.dart' as af_core;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, SystemChrome, SystemUiOverlayStyle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as r;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz_zone;

// ============================================================================
// Константы (фруктовые)
// ============================================================================
const String kFruitOnceKey = "fruit_once_event";
const String kFruitStatEndpoint = "https://api.gardencare.cfd/stat";
const String kFruitSeedCacheKey = "fruit_cached_seed";

// ============================================================================
// Сервисы (фруктовые)
// ============================================================================
class FruitCrate {
  static final FruitCrate _box = FruitCrate._();
  FruitCrate._();
  factory FruitCrate() => _box;

  final FlutterSecureStorage pit = const FlutterSecureStorage();
  final FruitLog pulp = FruitLog();
  final Connectivity grove = Connectivity();
}

class FruitLog {
  final Logger _lg = Logger();
  void i(Object msg) => _lg.i(msg);
  void w(Object msg) => _lg.w(msg);
  void e(Object msg) => _lg.e(msg);
}

// ============================================================================
// Сеть (фруктовая)
// ============================================================================
class FruitVine {
  final FruitCrate _crate = FruitCrate();
  Future<bool> hasSun() async {
    final c = await _crate.grove.checkConnectivity();
    return c != ConnectivityResult.none;
  }

  Future<void> postSyrup(String url, Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );
    } catch (e) {
      _crate.pulp.e("postSyrup error: $e");
    }
  }
}

// ============================================================================
// Досье устройства (фруктовое)
// ============================================================================
class FruitProfile {
  String? fruitId;
  String? basketId = "single-bite";
  String? fruitKind;
  String? peelBuild;
  String? jarVersion;
  String? locale;
  String? orchard;
  bool juiceAllowed = true; // placeholder вместо pushAllowed

  Future<void> ripen() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      fruitId = a.id;
      fruitKind = "android";
      peelBuild = a.version.release;
    } else if (Platform.isIOS) {
      final i = await info.iosInfo;
      fruitId = i.identifierForVendor;
      fruitKind = "ios";
      peelBuild = i.systemVersion;
    }
    final pkg = await PackageInfo.fromPlatform();
    jarVersion = pkg.version;
    locale = Platform.localeName.split('_')[0];
    orchard = tz_zone.local.name;
    basketId = "basket-${DateTime.now().millisecondsSinceEpoch}";
  }

  Map<String, dynamic> toMap({String? seed}) => {
    "fcm_token": seed ?? 'missing_seed',
    "device_id": fruitId ?? 'missing_id',
    "app_name": "fruitbasket",
    "instance_id": basketId ?? 'missing_basket',
    "platform": fruitKind ?? 'missing_kind',
    "os_version": peelBuild ?? 'missing_peel',
    "app_version": jarVersion ?? 'missing_jar',
    "language": locale ?? 'en',
    "timezone": orchard ?? 'UTC',
    "push_enabled": juiceAllowed,
  };
}

// ============================================================================
// AppsFlyer (фруктовый советник)
// ============================================================================
class FruitAdvisor with ChangeNotifier {
  af_core.AppsFlyerOptions? _opts;
  af_core.AppsflyerSdk? _sdk;

  String pitId = "";
  String nectar = "";

  void squeeze(VoidCallback splash) {
    final cfg = af_core.AppsFlyerOptions(
      afDevKey: "qsBLmy7dAXDQhowM8V3ca4",
      appId: "6753982615",
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );
    _opts = cfg;
    _sdk = af_core.AppsflyerSdk(cfg);

    _sdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );
    _sdk?.startSDK(
      onSuccess: () => FruitCrate().pulp.i("FruitAdvisor squeezed"),
      onError: (int c, String m) => FruitCrate().pulp.e("FruitAdvisor error $c: $m"),
    );
    _sdk?.onInstallConversionData((data) {
      nectar = data.toString();
      splash();
      notifyListeners();
    });
    _sdk?.getAppsFlyerUID().then((v) {
      pitId = v.toString();
      splash();
      notifyListeners();
    });
  }
}

// ============================================================================
// Providers (фруктовые)
// ============================================================================
final fruitProfileProvider = r.FutureProvider<FruitProfile>((ref) async {
  final p = FruitProfile();
  await p.ripen();
  return p;
});

final fruitAdvisorProvider = p.ChangeNotifierProvider<FruitAdvisor>(
  create: (_) => FruitAdvisor(),
);

// ============================================================================
// Новый лоадер: красно-оранжевая спираль на белом фоне + падающее FRUIT
// ============================================================================
class FruitSpiralLoader extends StatefulWidget {
  const FruitSpiralLoader({Key? key}) : super(key: key);

  @override
  State<FruitSpiralLoader> createState() => _FruitSpiralLoaderState();
}

class _FruitSpiralLoaderState extends State<FruitSpiralLoader> with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _fallCtrl;
  final List<_FallingLetter> _letters = [];
  final String _word = "FRUIT";
  final List<Color> _colors = const [
    Color(0xFFE53935), // красный
    Color(0xFFFF9800), // оранжевый
    Color(0xFF43A047), // зелёный
    Color(0xFF1E88E5), // синий
    Color(0xFF8E24AA), // фиолетовый
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    _spinCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _fallCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

    // Инициализируем падающие буквы
    final rnd = Random();
    for (int i = 0; i < _word.length; i++) {
      _letters.add(
        _FallingLetter(
          char: _word[i],
          color: _colors[i % _colors.length],
          x: 0.1 + 0.8 * rnd.nextDouble(),   // относительное положение по ширине (0..1)
          delay: i * 120,                    // небольшая лестница по времени
          swing: 14 + rnd.nextInt(10).toDouble(),       // амплитуда покачивания
        ),
      );
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _fallCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = min(constraints.maxWidth, 240.0);
          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

          return Stack(
            children: [
              // Спираль
              Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: AnimatedBuilder(
                    animation: _spinCtrl,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _SpiralPainter(progress: _spinCtrl.value),
                      );
                    },
                  ),
                ),
              ),
              // Падающие буквы FRUIT сверху
              AnimatedBuilder(
                animation: _fallCtrl,
                builder: (context, _) {
                  final t = _fallCtrl.value;
                  return Stack(
                    children: _letters.map((l) {
                      final fallT = ((t + (l.delay / 1400.0)) % 1.0);
                      final y = -60.0 + fallT * (constraints.maxHeight * 0.55);
                      final sway = sin(fallT * pi * 2) * l.swing;
                      final x = l.x * constraints.maxWidth + sway - 10;

                      return Positioned(
                        top: y.clamp(0.0, constraints.maxHeight * 0.55),
                        left: x.clamp(0.0, constraints.maxWidth - 20),
                        child: Text(
                          l.char,
                          style: TextStyle(
                            color: l.color,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              // Тонкая подпись снизу
              Positioned(
                bottom: max(24.0, constraints.maxHeight * 0.08),
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    "Loading garden...",
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FallingLetter {
  final String char;
  final Color color;
  final double x;     // относительная позиция по ширине
  final int delay;    // мс
  final double swing; // амплитуда покачивания

  _FallingLetter({
    required this.char,
    required this.color,
    required this.x,
    required this.delay,
    required this.swing,
  });
}

class _SpiralPainter extends CustomPainter {
  final double progress; // 0..1

  _SpiralPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.45;

    final path = Path();
    final turns = 3.0;
    final totalSteps = 420;
    for (int i = 0; i <= totalSteps; i++) {
      final t = i / totalSteps;
      // Красно-оранжевый градиент по окружности
      final hue = lerpDouble(5, 35, t)!; // 5..35 (красно-оранжевый диапазон)
      final color = HSVColor.fromAHSV(1, hue, 0.9, 0.98).toColor();

      final radius = t * maxRadius;
      final angle = (t * turns * 2 * pi) + (progress * 2 * pi);
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Обводка спирали
    final paintStroke = Paint()
      ..color = const Color(0xFFE53935) // красноватая обводка
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 0);

    // Светящийся след (полупрозрачная широкая)
    final paintGlow = Paint()
      ..color = const Color(0xFFFF7043).withOpacity(0.35) // оранжевое свечение
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(path, paintGlow);
    canvas.drawPath(path, paintStroke);
  }

  @override
  bool shouldRepaint(covariant _SpiralPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ============================================================================
// Заглушки пуш-фона (Firebase удалён)
// ============================================================================
@pragma('vm:entry-point')
Future<void> fruitBgJuiceHandler(Object msg) async {
  FruitCrate().pulp.i("bg-fruit: $msg");
}

// ============================================================================
// Мост семечка (раньше FCM), теперь локальная заглушка
// ============================================================================
class FruitSeedBridge extends ChangeNotifier {
  final FruitCrate _crate = FruitCrate();
  String? _seed;
  final List<void Function(String)> _awaiters = [];

  String? get seed => _seed;

  FruitSeedBridge() {
    const MethodChannel('com.example.fruit/seed').setMethodCallHandler((call) async {
      if (call.method == 'setSeed') {
        final String s = call.arguments as String;
        if (s.isNotEmpty) _setSeed(s);
      }
    });
    _restore();
    _ensureLocalSeed();
  }

  Future<void> _ensureLocalSeed() async {
    if (_seed != null && _seed!.isNotEmpty) return;
    final s = "seed-${DateTime.now().millisecondsSinceEpoch}";
    _setSeed(s, notifyNative: false);
  }

  Future<void> _restore() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final cached = sp.getString(kFruitSeedCacheKey);
      if (cached != null && cached.isNotEmpty) {
        _setSeed(cached, notifyNative: false);
      } else {
        final ss = await _crate.pit.read(key: kFruitSeedCacheKey);
        if (ss != null && ss.isNotEmpty) {
          _setSeed(ss, notifyNative: false);
        }
      }
    } catch (_) {}
  }

  void _setSeed(String t, {bool notifyNative = true}) async {
    _seed = t;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(kFruitSeedCacheKey, t);
      await _crate.pit.write(key: kFruitSeedCacheKey, value: t);
    } catch (_) {}
    for (final cb in List.of(_awaiters)) {
      try { cb(t); } catch (e) { _crate.pulp.w("fruit-seed waiter error: $e"); }
    }
    _awaiters.clear();
    notifyListeners();
  }

  Future<void> awaitSeed(Function(String t) onSeed) async {
    try {
      if (_seed != null && _seed!.isNotEmpty) {
        onSeed(_seed!);
        return;
      }
      _awaiters.add(onSeed);
    } catch (e) {
      _crate.pulp.e("FruitSeedBridge awaitSeed: $e");
    }
  }
}

// ============================================================================
// BLoC: Разрешения “сока” (заглушка)
// ============================================================================
abstract class FruitPermitEvent {}
class FruitAskPermit extends FruitPermitEvent {}

class FruitPermitState {
  final bool asked;
  final bool granted;
  final bool error;
  final String? note;

  FruitPermitState({
    required this.asked,
    required this.granted,
    required this.error,
    this.note,
  });

  FruitPermitState copyWith({
    bool? asked,
    bool? granted,
    bool? error,
    String? note,
  }) => FruitPermitState(
    asked: asked ?? this.asked,
    granted: granted ?? this.granted,
    error: error ?? this.error,
    note: note ?? this.note,
  );

  factory FruitPermitState.initial() => FruitPermitState(
    asked: false,
    granted: true,
    error: false,
    note: null,
  );
}

class FruitPermitBloc {
  final _stateCtrl = StreamController<FruitPermitState>.broadcast();
  final _eventCtrl = StreamController<FruitPermitEvent>();
  FruitPermitState _state = FruitPermitState.initial();

  Stream<FruitPermitState> get stream => _stateCtrl.stream;

  FruitPermitBloc() {
    _eventCtrl.stream.listen(_onEvent);
  }

  void add(FruitPermitEvent event) => _eventCtrl.add(event);

  Future<void> _onEvent(FruitPermitEvent event) async {
    if (event is FruitAskPermit) {
      _emit(_state.copyWith(asked: true, granted: true, error: false, note: null));
    }
  }

  void _emit(FruitPermitState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void dispose() {
    _stateCtrl.close();
    _eventCtrl.close();
  }
}

// ============================================================================
// MVVM/BLoC Comms c анти-спамом (фруктовые имена)
// ============================================================================
class FruitBosunModel with ChangeNotifier {
  final FruitProfile profile;
  final FruitAdvisor advisor;
  FruitBosunModel({required this.profile, required this.advisor});

  Map<String, dynamic> deviceCargo(String? seed) => profile.toMap(seed: seed);

  Map<String, dynamic> afCargo(String? seed) => {
    "content": {
      "af_data": advisor.nectar,
      "af_id": advisor.pitId,
      "fb_app_name": "bananzafruitmaster",
      "app_name": "bananzafruitmaster",
      "deep": null,
      "bundle_identifier": "com.fruit.masterfrui.fruitmaster",
      "app_version": "1.0.0",
      "apple_id": "6753982615",
      "fcm_token": seed ?? "no_seed",
      "device_id": profile.fruitId ?? "no_device",
      "instance_id": profile.basketId ?? "no_basket",
      "platform": profile.fruitKind ?? "no_kind",
      "os_version": profile.peelBuild ?? "no_peel",
      "app_version": profile.jarVersion ?? "no_jar",
      "language": profile.locale ?? "en",
      "timezone": profile.orchard ?? "UTC",
      "push_enabled": profile.juiceAllowed,
      "useruid": advisor.pitId,
    },
  };
}

class FruitHarborPorter {
  final FruitBosunModel model;
  final InAppWebViewController Function() tapWeb;

  String? _lastUrl;
  int _lastMs = 0;
  static const int _throttleMs = 2000;

  FruitHarborPorter({required this.model, required this.tapWeb});

  Future<void> dropDeviceIntoLocalStorage(String? seed) async {
    final m = model.deviceCargo(seed);
    await tapWeb().evaluateJavascript(source: '''
localStorage.setItem('app_data', JSON.stringify(${jsonEncode(m)}));
''');
  }

  Future<void> pourRawNectar(String? seed, {String? currentUrl}) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - _lastMs < _throttleMs) {
      FruitCrate().pulp.w("pourRawNectar throttled (time)");
      return;
    }
    if (currentUrl != null && _lastUrl == currentUrl) {
      FruitCrate().pulp.w("pourRawNectar skipped (same url)");
      return;
    }

    final payload = model.afCargo(seed);
    final jsonString = jsonEncode(payload);
    FruitCrate().pulp.i("pourRawNectar: $jsonString");

    await tapWeb().evaluateJavascript(source: "sendRawData(${jsonEncode(jsonString)});");

    _lastMs = now;
    if (currentUrl != null) _lastUrl = currentUrl;
  }
}

abstract class FruitCommsEvent {}
class FruitCommsAttachWeb extends FruitCommsEvent {
  final InAppWebViewController Function() webGetter;
  FruitCommsAttachWeb(this.webGetter);
}
class FruitCommsPushDevice extends FruitCommsEvent {
  final String? seed;
  FruitCommsPushDevice(this.seed);
}
class FruitCommsPushAF extends FruitCommsEvent {
  final String? seed;
  final String? currentUrl;
  FruitCommsPushAF(this.seed, {this.currentUrl});
}

class FruitCommsState {
  final bool ready;
  final bool pushingDevice;
  final bool pushingAF;
  final String? lastError;
  final int lastPayloadHash;

  FruitCommsState({
    required this.ready,
    required this.pushingDevice,
    required this.pushingAF,
    required this.lastPayloadHash,
    this.lastError,
  });

  factory FruitCommsState.initial() => FruitCommsState(
    ready: false,
    pushingDevice: false,
    pushingAF: false,
    lastPayloadHash: 0,
    lastError: null,
  );

  FruitCommsState copyWith({
    bool? ready,
    bool? pushingDevice,
    bool? pushingAF,
    String? lastError,
    int? lastPayloadHash,
  }) => FruitCommsState(
    ready: ready ?? this.ready,
    pushingDevice: pushingDevice ?? this.pushingDevice,
    pushingAF: pushingAF ?? this.pushingAF,
    lastError: lastError,
    lastPayloadHash: lastPayloadHash ?? this.lastPayloadHash,
  );
}

class FruitCommsBloc {
  final FruitBosunModel viewModel;
  FruitHarborPorter? _porter;

  final _stateCtrl = StreamController<FruitCommsState>.broadcast();
  final _eventCtrl = StreamController<FruitCommsEvent>();
  FruitCommsState _state = FruitCommsState.initial();

  Stream<FruitCommsState> get stream => _stateCtrl.stream;

  FruitCommsBloc({required this.viewModel}) {
    _eventCtrl.stream.listen(_onEvent);
  }

  void add(FruitCommsEvent e) => _eventCtrl.add(e);

  void _emit(FruitCommsState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  Future<void> _onEvent(FruitCommsEvent e) async {
    try {
      if (e is FruitCommsAttachWeb) {
        _porter = FruitHarborPorter(model: viewModel, tapWeb: e.webGetter);
        _emit(_state.copyWith(ready: true, lastError: null));
      } else if (e is FruitCommsPushDevice) {
        if (_porter == null) return;
        _emit(_state.copyWith(pushingDevice: true, lastError: null));
        await _porter!.dropDeviceIntoLocalStorage(e.seed);
        _emit(_state.copyWith(pushingDevice: false));
      } else if (e is FruitCommsPushAF) {
        if (_porter == null) return;
        final payload = viewModel.afCargo(e.seed);
        final hash = jsonEncode(payload).hashCode;
        if (hash == _state.lastPayloadHash) {
          FruitCrate().pulp.w("pourRawNectar skipped (same payload hash)");
          return;
        }
        _emit(_state.copyWith(pushingAF: true, lastError: null));
        await _porter!.pourRawNectar(e.seed, currentUrl: e.currentUrl);
        _emit(_state.copyWith(pushingAF: false, lastPayloadHash: hash));
      }
    } catch (err) {
      _emit(_state.copyWith(lastError: err.toString(), pushingAF: false, pushingDevice: false));
    }
  }

  void dispose() {
    _stateCtrl.close();
    _eventCtrl.close();
  }
}

// ============================================================================
// Статистика (фруктовая)
// ============================================================================
Future<String> fruitFinalUrl(String startUrl, {int maxHops = 10}) async {
  final client = HttpClient();
  client.userAgent = 'Mozilla/5.0 (Flutter; dart:io HttpClient)';
  try {
    var current = Uri.parse(startUrl);
    for (int i = 0; i < maxHops; i++) {
      final req = await client.getUrl(current);
      req.followRedirects = false;
      final res = await req.close();
      if (res.isRedirect) {
        final loc = res.headers.value(HttpHeaders.locationHeader);
        if (loc == null || loc.isEmpty) break;
        final next = Uri.parse(loc);
        current = next.hasScheme ? next : current.resolveUri(next);
        continue;
      }
      return current.toString();
    }
    return current.toString();
  } catch (e) {
    debugPrint("fruitFinalUrl error: $e");
    return startUrl;
  } finally {
    client.close(force: true);
  }
}

Future<void> postFruitStat({
  required String event,
  required int timeStart,
  required String url,
  required int timeFinish,
  required String appSeed,
  int? firstPageLoadTs,
}) async {
  try {
    final finalUrl = await fruitFinalUrl(url);
    final payload = {
      "event": event,
      "timestart": timeStart,
      "timefinsh": timeFinish,
      "url": finalUrl,
      "appleID": "6753982615",
      "open_count": "$appSeed/$timeStart",
    };

    print("fruitstat $payload");
    final res = await http.post(
      Uri.parse("$kFruitStatEndpoint/$appSeed"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    print(" fruit_post $kFruitStatEndpoint/$appSeed");
    debugPrint("postFruitStat status=${res.statusCode} body=${res.body}");
  } catch (e) {
    debugPrint("postFruitStat error: $e");
  }
}

// ============================================================================
// Главный WebView — FruitHarbor
// ============================================================================
class FruitHarbor extends StatefulWidget {
  final String? pip;
  const FruitHarbor({super.key, required this.pip});

  @override
  State<FruitHarbor> createState() => _FruitHarborState();
}

class _FruitHarborState extends State<FruitHarbor> with WidgetsBindingObserver {
  late InAppWebViewController _web;
  bool _busy = false;
  final String _home = "https://api.gardencare.cfd/";
  final FruitProfile _profile = FruitProfile();
  final FruitAdvisor _advisor = FruitAdvisor();

  DateTime? _napAt;
  bool _veil = false;
  double _warmProgress = 0.0;
  late Timer _warmTimer;
  final int _warmSecs = 6;
  bool _cover = true;

  bool _sentOnce = false;
  int? _firstPageTs;

  FruitHarborPorter? _porter;
  FruitBosunModel? _bosun;

  String _currentUrl = "";
  var _loadStartTs = 0;

  // BLoC
  late final FruitPermitBloc _permitBloc;
  FruitCommsBloc? _commsBloc;

  // Guards
  bool _handledServerResponse = false;
  bool _notificationHandlerBound = false;
  bool _bootAfSentOnce = false;
  final Map<String, bool> _afPushedForUrl = {};

  final Set<String> _schemes = {
    'tg', 'telegram',
    'whatsapp',
    'viber',
    'skype',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
    'bnl',
  };

  final Set<String> _externalHosts = {
    't.me', 'telegram.me', 'telegram.dog',
    'wa.me', 'api.whatsapp.com', 'chat.whatsapp.com',
    'm.me',
    'signal.me',
    'bnl.com', 'www.bnl.com',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _firstPageTs = DateTime.now().millisecondsSinceEpoch;

    _permitBloc = FruitPermitBloc();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _cover = false);
    });

    Future.delayed(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() => _veil = true);
    });

    _boot();
  }

  Future<void> _loadOnceFlag() async {
    final sp = await SharedPreferences.getInstance();
    _sentOnce = sp.getBool(kFruitOnceKey) ?? false;
  }

  Future<void> _saveOnceFlag() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(kFruitOnceKey, true);
    _sentOnce = true;
  }

  Future<void> sendFruitLoadedOnce({required String url, required int timestart}) async {
    if (_sentOnce) {
      print("Fruit Loaded already sent, skipping");
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await postFruitStat(
      event: "Loaded",
      timeStart: timestart,
      timeFinish: now,
      url: url,
      appSeed: _advisor.pitId,
      firstPageLoadTs: _firstPageTs,
    );
    await _saveOnceFlag();
  }

  void _boot() {
    _warmBar();
    _advisor.squeeze(() => setState(() {}));
    _bindNotificationTap();
    _prepareFruitProfile();

    _permitBloc.add(FruitAskPermit());

    Future.delayed(const Duration(seconds: 6), () async {
      if (!_bootAfSentOnce) {
        _bootAfSentOnce = true;
        await _pushAF(currentUrl: _currentUrl.isEmpty ? _home : _currentUrl);
      }
      await _pushDevice();
    });
  }

  void _bindNotificationTap() {
    if (_notificationHandlerBound) return;
    _notificationHandlerBound = true;

    MethodChannel('com.example.fruit/notification').setMethodCallHandler((call) async {
      if (call.method == "onNotificationTap") {
        final Map<String, dynamic> payload = Map<String, dynamic>.from(call.arguments);
        final uri = payload["uri"]?.toString();
        if (uri != null && !uri.contains("Нет URI")) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => FruitWatchtower(uri)),
                  (route) => false,
            );
          });
        }
      }
      return null;
    });
  }

  Future<void> _prepareFruitProfile() async {
    try {
      await _profile.ripen();
      _bosun = FruitBosunModel(profile: _profile, advisor: _advisor);
      _commsBloc = FruitCommsBloc(viewModel: _bosun!);
      _porter = FruitHarborPorter(model: _bosun!, tapWeb: () => _web);
      await _loadOnceFlag();
    } catch (e) {
      FruitCrate().pulp.e("prepare-fruit-profile fail: $e");
    }
  }

  void _bite(String link) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _web.loadUrl(urlRequest: URLRequest(url: WebUri(link)));
      } catch (_) {}
    });
  }

  void _resetHome() {
    Future.delayed(const Duration(seconds: 3), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _web.loadUrl(urlRequest: URLRequest(url: WebUri(_home)));
      });
    });
  }

  Future<void> _pushDevice() async {
    FruitCrate().pulp.i("SEED ship ${widget.pip}");
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      if (_commsBloc != null) {
        _commsBloc!.add(FruitCommsPushDevice(widget.pip));
      } else {
        await _porter?.dropDeviceIntoLocalStorage(widget.pip);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pushAF({String? currentUrl}) async {
    if (_commsBloc != null) {
      _commsBloc!.add(FruitCommsPushAF(widget.pip, currentUrl: currentUrl));
    } else {
      await _porter?.pourRawNectar(widget.pip, currentUrl: currentUrl);
    }
  }

  void _warmBar() {
    int n = 0;
    _warmProgress = 0.0;
    _warmTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      setState(() {
        n++;
        _warmProgress = n / (_warmSecs * 10);
        if (_warmProgress >= 1.0) {
          _warmProgress = 1.0;
          _warmTimer.cancel();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      _napAt = DateTime.now();
    }
    if (s == AppLifecycleState.resumed) {
      if (Platform.isIOS && _napAt != null) {
        final now = DateTime.now();
        final drift = now.difference(_napAt!);
        if (drift > const Duration(minutes: 25)) {
          _reboard();
        }
      }
      _napAt = null;
    }
  }

  void _reboard() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => FruitHarbor(pip: widget.pip)),
            (route) => false,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _warmTimer.cancel();
    _permitBloc.dispose();
    _commsBloc?.dispose();
    super.dispose();
  }

  // ================== URL helpers (фруктовые) ==================
  bool _isBareEmail(Uri u) {
    final s = u.scheme;
    if (s.isNotEmpty) return false;
    final raw = u.toString();
    return raw.contains('@') && !raw.contains(' ');
  }

  Uri _toMailto(Uri u) {
    final full = u.toString();
    final parts = full.split('?');
    final email = parts.first;
    final qp = parts.length > 1 ? Uri.splitQueryString(parts[1]) : <String, String>{};
    return Uri(scheme: 'mailto', path: email, queryParameters: qp.isEmpty ? null : qp);
  }

  bool _isPlatformish(Uri u) {
    final s = u.scheme.toLowerCase();
    if (_schemes.contains(s)) return true;

    if (s == 'http' || s == 'https') {
      final h = u.host.toLowerCase();
      if (_externalHosts.contains(h)) return true;
      if (h.endsWith('t.me')) return true;
      if (h.endsWith('wa.me')) return true;
      if (h.endsWith('m.me')) return true;
      if (h.endsWith('signal.me')) return true;
    }
    return false;
  }

  Uri _httpize(Uri u) {
    final s = u.scheme.toLowerCase();

    if (s == 'tg' || s == 'telegram') {
      final qp = u.queryParameters;
      final domain = qp['domain'];
      if (domain != null && domain.isNotEmpty) {
        return Uri.https('t.me', '/$domain', {if (qp['start'] != null) 'start': qp['start']!});
      }
      final path = u.path.isNotEmpty ? u.path : '';
      return Uri.https('t.me', '/$path', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    if ((s == 'http' || s == 'https') && u.host.toLowerCase().endsWith('t.me')) {
      return u;
    }

    if (s == 'viber') return u;

    if (s == 'whatsapp') {
      final qp = u.queryParameters;
      final phone = qp['phone'];
      final text = qp['text'];
      if (phone != null && phone.isNotEmpty) {
        return Uri.https('wa.me', '/${_digits(phone)}', {if (text != null && text.isNotEmpty) 'text': text});
      }
      return Uri.https('wa.me', '/', {if (text != null && text.isNotEmpty) 'text': text});
    }

    if ((s == 'http' || s == 'https') &&
        (u.host.toLowerCase().endsWith('wa.me') || u.host.toLowerCase().endsWith('whatsapp.com'))) {
      return u;
    }

    if (s == 'skype') return u;

    if (s == 'fb-messenger') {
      final path = u.pathSegments.isNotEmpty ? u.pathSegments.join('/') : '';
      final qp = u.queryParameters;
      final id = qp['id'] ?? qp['user'] ?? path;
      if (id.isNotEmpty) {
        return Uri.https('m.me', '/$id', u.queryParameters.isEmpty ? null : u.queryParameters);
      }
      return Uri.https('m.me', '/', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    if (s == 'sgnl') {
      final qp = u.queryParameters;
      final ph = qp['phone'];
      final un = u.queryParameters['username'];
      if (ph != null && ph.isNotEmpty) return Uri.https('signal.me', '/#p/${_digits(ph)}');
      if (un != null && un.isNotEmpty) return Uri.https('signal.me', '/#u/$un');
      final path = u.pathSegments.join('/');
      if (path.isNotEmpty) return Uri.https('signal.me', '/$path', u.queryParameters.isEmpty ? null : u.queryParameters);
      return u;
    }

    if (s == 'tel') return Uri.parse('tel:${_digits(u.path)}');
    if (s == 'mailto') return u;

    if (s == 'bnl') {
      final newPath = u.path.isNotEmpty ? u.path : '';
      return Uri.https('bnl.com', '/$newPath', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    return u;
  }

  Future<bool> _openMailWeb(Uri mailto) async {
    final u = _gmailize(mailto);
    return await _openWeb(u);
  }

  Uri _gmailize(Uri m) {
    final qp = m.queryParameters;
    final params = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (m.path.isNotEmpty) 'to': m.path,
      if ((qp['subject'] ?? '').isNotEmpty) 'su': qp['subject']!,
      if ((qp['body'] ?? '').isNotEmpty) 'body': qp['body']!,
      if ((qp['cc'] ?? '').isNotEmpty) 'cc': qp['cc']!,
      if ((qp['bcc'] ?? '').isNotEmpty) 'bcc': qp['bcc']!,
    };
    return Uri.https('mail.google.com', '/mail/', params);
  }

  Future<bool> _openWeb(Uri u) async {
    try {
      if (await launchUrl(u, mode: LaunchMode.inAppBrowserView)) return true;
      return await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('openInAppBrowser error: $e; url=$u');
      try {
        return await launchUrl(u, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');

  @override
  Widget build(BuildContext context) {
    _bindNotificationTap();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            if (_cover)
              const FruitSpiralLoader()
            else
              Container(
                color: Colors.white,
                child: Stack(
                  children: [
                    InAppWebView(
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        disableDefaultErrorPage: true,
                        mediaPlaybackRequiresUserGesture: false,
                        allowsInlineMediaPlayback: true,
                        allowsPictureInPictureMediaPlayback: true,
                        useOnDownloadStart: true,
                        javaScriptCanOpenWindowsAutomatically: true,
                        useShouldOverrideUrlLoading: true,
                        supportMultipleWindows: true,
                        transparentBackground: false,
                      ),
                      initialUrlRequest: URLRequest(url: WebUri(_home)),
                      onWebViewCreated: (c) {
                        _web = c;

                        _bosun ??= FruitBosunModel(profile: _profile, advisor: _advisor);
                        _porter ??= FruitHarborPorter(model: _bosun!, tapWeb: () => _web);

                        _commsBloc ??= FruitCommsBloc(viewModel: _bosun!);
                        _commsBloc!.add(FruitCommsAttachWeb(() => _web));

                        _web.addJavaScriptHandler(
                          handlerName: 'onServerResponse',
                          callback: (args) {
                            if (_handledServerResponse) {
                              if (args.isEmpty) return null;
                              try { return args.reduce((curr, next) => curr + next); } catch (_) { return args.first; }
                            }
                            try {
                              final saved = args.isNotEmpty &&
                                  args[0] is Map &&
                                  args[0]['savedata'].toString() == "false";
                              if (saved && !_handledServerResponse) {
                                _handledServerResponse = true;
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;

                                });
                              }
                            } catch (_) {}
                            if (args.isEmpty) return null;
                            try { return args.reduce((curr, next) => curr + next); } catch (_) { return args.first; }
                          },
                        );
                      },
                      onLoadStart: (c, u) async {
                        setState(() {
                          _loadStartTs = DateTime.now().millisecondsSinceEpoch;
                          _busy = true;
                        });
                        if (u != null) {
                          if (_isBareEmail(u)) {
                            try { await c.stopLoading(); } catch (_) {}
                            final mailto = _toMailto(u);
                            await _openMailWeb(mailto);
                            return;
                          }
                          final sch = u.scheme.toLowerCase();
                          if (sch != 'http' && sch != 'https') {
                            try { await c.stopLoading(); } catch (_) {}
                          }
                        }
                      },
                      onLoadError: (controller, url, code, message) async {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final ev = "InAppWebViewError(code=$code, message=$message)";
                        await postFruitStat(
                          event: ev,
                          timeStart: now,
                          timeFinish: now,
                          url: url?.toString() ?? '',
                          appSeed: _advisor.pitId,
                          firstPageLoadTs: _firstPageTs,
                        );
                        if (mounted) setState(() => _busy = false);
                      },
                      onReceivedHttpError: (controller, request, errorResponse) async {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final ev = "HTTPError(status=${errorResponse.statusCode}, reason=${errorResponse.reasonPhrase})";
                        await postFruitStat(
                          event: ev,
                          timeStart: now,
                          timeFinish: now,
                          url: request.url?.toString() ?? '',
                          appSeed: _advisor.pitId,
                          firstPageLoadTs: _firstPageTs,
                        );
                      },
                      onReceivedError: (controller, request, error) async {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final desc = (error.description ?? '').toString();
                        final ev = "WebResourceError(code=${error}, message=$desc)";
                        await postFruitStat(
                          event: ev,
                          timeStart: now,
                          timeFinish: now,
                          url: request.url?.toString() ?? '',
                          appSeed: _advisor.pitId,
                          firstPageLoadTs: _firstPageTs,
                        );
                      },
                      onLoadStop: (c, u) async {
                        await c.evaluateJavascript(source: "console.log('Fruit Harbor up!');");

                        final urlStr = u?.toString() ?? '';
                        setState(() => _currentUrl = urlStr);

                        await _pushDevice();

                        if (urlStr.isNotEmpty && _afPushedForUrl[urlStr] != true) {
                          _afPushedForUrl[urlStr] = true;
                          await _pushAF(currentUrl: urlStr);
                        }

                        Future.delayed(const Duration(seconds: 20), () {
                          sendFruitLoadedOnce(url: _currentUrl.toString(), timestart: _loadStartTs);
                        });

                        if (mounted) setState(() => _busy = false);
                      },
                      shouldOverrideUrlLoading: (c, action) async {
                        final uri = action.request.url;
                        if (uri == null) return NavigationActionPolicy.ALLOW;

                        if (_isBareEmail(uri)) {
                          final mailto = _toMailto(uri);
                          await _openMailWeb(mailto);
                          return NavigationActionPolicy.CANCEL;
                        }

                        final sch = uri.scheme.toLowerCase();

                        if (sch == 'mailto') {
                          await _openMailWeb(uri);
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (sch == 'tel') {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (_isPlatformish(uri)) {
                          final web = _httpize(uri);
                          if (web.scheme == 'http' || web == uri) {
                            await _openWeb(web);
                          } else {
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else if (web != uri && (web.scheme == 'http' || web.scheme == 'https')) {
                                await _openWeb(web);
                              }
                            } catch (_) {}
                          }
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (sch != 'http' && sch != 'https') {
                          return NavigationActionPolicy.CANCEL;
                        }

                        return NavigationActionPolicy.ALLOW;
                      },
                      onCreateWindow: (c, req) async {
                        final uri = req.request.url;
                        if (uri == null) return false;

                        if (_isBareEmail(uri)) {
                          final mailto = _toMailto(uri);
                          await _openMailWeb(mailto);
                          return false;
                        }

                        final sch = uri.scheme.toLowerCase();

                        if (sch == 'mailto') {
                          await _openMailWeb(uri);
                          return false;
                        }

                        if (sch == 'tel') {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          return false;
                        }

                        if (_isPlatformish(uri)) {
                          final web = _httpize(uri);
                          if (web.scheme == 'http' || web.scheme == 'https') {
                            await _openWeb(web);
                          } else {
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else if (web != uri && (web.scheme == 'http' || web.scheme == 'https')) {
                                await _openWeb(web);
                              }
                            } catch (_) {}
                          }
                          return false;
                        }

                        if (sch == 'http' || sch == 'https') {
                          c.loadUrl(urlRequest: URLRequest(url: uri));
                        }
                        return false;
                      },
                      onDownloadStartRequest: (c, req) async {
                        await _openWeb(req.url);
                      },
                    ),
                    Visibility(
                      visible: !_veil,
                      child: const FruitSpiralLoader(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Внешний WebView (фруктовый)
// ============================================================================
class FruitDeck extends StatefulWidget with WidgetsBindingObserver {
  final String url;
  const FruitDeck(this.url, {super.key});

  @override
  State<FruitDeck> createState() => _FruitDeckState();
}

class _FruitDeckState extends State<FruitDeck> with WidgetsBindingObserver {
  late InAppWebViewController _deck;

  @override
  Widget build(BuildContext context) {
    final night = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: night ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: InAppWebView(
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            disableDefaultErrorPage: true,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true,
            useOnDownloadStart: true,
            javaScriptCanOpenWindowsAutomatically: true,
            useShouldOverrideUrlLoading: true,
            supportMultipleWindows: true,
          ),
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          onWebViewCreated: (c) => _deck = c,
        ),
      ),
    );
  }
}

// ============================================================================
// Help (фруктовый)
// ============================================================================
class FruitHelp extends StatefulWidget {
  const FruitHelp({super.key});
  @override
  State<FruitHelp> createState() => _FruitHelpState();
}

class _FruitHelpState extends State<FruitHelp> with WidgetsBindingObserver {
  InAppWebViewController? _ctrl;
  bool _spin = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            InAppWebView(
              initialFile: 'assets/index.html',
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                supportZoom: false,
                disableHorizontalScroll: false,
                disableVerticalScroll: false,
              ),
              onWebViewCreated: (c) => _ctrl = c,
              onLoadStart: (c, u) => setState(() => _spin = true),
              onLoadStop: (c, u) async => setState(() => _spin = false),
              onLoadError: (c, u, code, msg) => setState(() => _spin = false),
            ),
            if (_spin) const FruitSpiralLoader(),
          ],
        ),
      ),
    );
  }
}



// ============================================================================
// Вышка-наблюдатель
// ============================================================================
class FruitWatchtower extends StatefulWidget {
  final String url;
  const FruitWatchtower(this.url, {super.key});

  @override
  State<FruitWatchtower> createState() => _FruitWatchtowerState();
}

class _FruitWatchtowerState extends State<FruitWatchtower> {
  @override
  Widget build(BuildContext context) {
    return FruitDeck(widget.url);
  }
}

// ============================================================================
// Стартовый экран (фруктовый)
// ============================================================================
class FruitFoyer extends StatefulWidget {
  const FruitFoyer({Key? key}) : super(key: key);

  @override
  State<FruitFoyer> createState() => _FruitFoyerState();
}

class _FruitFoyerState extends State<FruitFoyer> {
  final FruitSeedBridge _seedBridge = FruitSeedBridge();
  bool _once = false;
  Timer? _fallback;
  bool _coverMute = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    _seedBridge.awaitSeed((sig) => _go(sig));
    _fallback = Timer(const Duration(seconds: 8), () => _go(''));

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _coverMute = true);
    });
  }

  void _go(String sig) {
    if (_once) return;
    _once = true;
    _fallback?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => FruitHarbor(pip: sig)),
      );
    });
  }

  @override
  void dispose() {
    _fallback?.cancel();
    _seedBridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: const [
          Center(child: FruitSpiralLoader()),
        ],
      ),
    );
  }
}

// ============================================================================
// main() (фруктовый) — без Firebase
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  tz_data.initializeTimeZones();

  runApp(
    p.MultiProvider(
      providers: [
        fruitAdvisorProvider,
      ],
      child: r.ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: const FruitFoyer(),
        ),
      ),
    ),
  );
}