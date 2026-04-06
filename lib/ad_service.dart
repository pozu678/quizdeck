import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

/// Servicio de AdMob preparado para integración futura.
/// Los ads NO están activos en pantallas todavía.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ── Ad Unit IDs de PRUEBA (Google Test IDs) ──
  static const String bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  bool _inicializado = false;

  /// Inicializa el SDK de AdMob. Llamar en main() antes de runApp().
  Future<void> initialize() async {
    if (_inicializado) return;
    // TODO: await MobileAds.instance.initialize();
    _inicializado = true;
  }

  /// Carga un banner ad (no lo muestra aún).
  Future<void> loadBannerAd() async {
    // TODO: implementar con BannerAd de google_mobile_ads
  }

  /// Carga un interstitial ad.
  Future<void> loadInterstitialAd() async {
    // TODO: implementar con InterstitialAd de google_mobile_ads
  }

  /// Carga un rewarded ad.
  Future<void> loadRewardedAd() async {
    // TODO: implementar con RewardedAd de google_mobile_ads
  }

  /// Muestra el interstitial ad si está cargado.
  Future<void> showInterstitialAd() async {
    // TODO: implementar
  }

  /// Muestra el rewarded ad. La recompensa son +3 sesiones de estudio.
  Future<void> showRewardedAd() async {
    // TODO: implementar con RewardedAd.show(onUserEarnedReward: ...)
    // Al ganar la recompensa:
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirestoreService().agregarSesionesExtra(uid, 3);
    }
  }

  /// Libera recursos de ads cargados.
  void dispose() {
    // TODO: disponer los ads activos
  }
}
