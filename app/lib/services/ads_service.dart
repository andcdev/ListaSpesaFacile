import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Pubblicità AdMob con il consenso privacy di Google (UMP): in Europa il modulo del consenso compare al primo
/// avvio e la pubblicità parte solo dopo la risposta.
///
/// L'unità del banner arriva da config/produzione.json (ADMOB_BANNER_ID). Senza, le build di sviluppo mostrano i
/// banner di prova di Google e le release non mostrano pubblicità.
class AdsService extends ChangeNotifier {
  /// Banner adattivo di prova di Google per Android: si può cliccare senza rischi per l'account AdMob.
  static const _testBannerId = 'ca-app-pub-3940256099942544/9214589741';

  static const _configuredBannerId = String.fromEnvironment('ADMOB_BANNER_ID');

  /// Unità del banner, o null se in questa build la pubblicità è spenta. Per ora solo Android: su iOS
  /// mancano ancora l'app AdMob e GADApplicationIdentifier in Info.plist.
  static String? get bannerUnitId {
    if (!Platform.isAndroid) return null;
    if (_configuredBannerId.isNotEmpty) return _configuredBannerId;
    return kReleaseMode ? null : _testBannerId;
  }

  /// Consenso raccolto (o non richiesto) e SDK avviato: si possono caricare i banner.
  bool ready = false;

  /// L'utente deve poter cambiare il consenso dal menu del profilo (utenti europei).
  bool privacyOptionsRequired = false;

  bool _started = false;

  /// Chiede il consenso se serve, poi avvia l'SDK. Da chiamare una volta, con l'app già a schermo.
  void start() {
    if (_started || bannerUnitId == null) return;
    _started = true;
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) debugPrint('Consenso pubblicità: ${error.message}');
        _afterConsent();
      }),
      (error) {
        // Senza rete il consenso non si aggiorna: vale quello salvato l'ultima volta, se c'è.
        debugPrint('Consenso pubblicità non aggiornato: ${error.message}');
        _afterConsent();
      },
    );
  }

  Future<void> _afterConsent() async {
    final consent = ConsentInformation.instance;
    privacyOptionsRequired =
        await consent.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;
    if (!ready && await consent.canRequestAds()) {
      await MobileAds.instance.initialize();
      ready = true;
    }
    notifyListeners();
  }

  /// Modulo di Google per cambiare le scelte sulla privacy della pubblicità.
  void showPrivacyOptions() => ConsentForm.showPrivacyOptionsForm((error) {
    if (error != null) debugPrint('Opzioni privacy: ${error.message}');
    _afterConsent();
  });
}
