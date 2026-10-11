import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../services/ads_service.dart';

/// Banner pubblicitario largo quanto lo schermo, fermo in fondo. Non occupa spazio finché non c'è un annuncio
/// (consenso non dato, pubblicità spenta, nessun annuncio disponibile, senza rete).
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Richiamato anche quando la pubblicità diventa pronta (dopo il consenso) e quando cambia la larghezza.
    final ready = Provider.of<AdsService>(context).ready;
    if (ready) _load();
  }

  Future<void> _load() async {
    final unitId = AdsService.bannerUnitId;
    if (unitId == null) return;
    // Nuovo annuncio solo se cambia la larghezza (es. telefono ruotato).
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width == _width) return;
    _width = width;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted || width != _width) return;
    await _ad?.dispose();
    _loaded = false;
    _ad = BannerAd(
      adUnitId: unitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner non caricato: ${error.message}');
          ad.dispose();
          if (mounted && _ad == ad) setState(() => _ad = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
