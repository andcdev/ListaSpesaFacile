import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Stile "Mercato": fondo crema caldo con i disegni dei prodotti, card bianche arrotondate, titoli in Fraunces e
/// testi in Figtree, verde bosco per le azioni e arancio pomodoro per l'aggiunta rapida. Con una variante scura.
/// Il colore di fondo (surface) è quello delle immagini dello sfondo, così barre e pagine si fondono con i disegni.
abstract final class AppTheme {
  static const bodyFont = 'Figtree';
  static const displayFont = 'Fraunces';

  static final light = _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF2F6B3A),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE3EFE2),
      onPrimaryContainer: Color(0xFF173B1F),
      secondary: Color(0xFFE4572E),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFBE6DD),
      onSecondaryContainer: Color(0xFF8A2E14),
      tertiary: Color(0xFF3A6EA5),
      onTertiary: Color(0xFFFFFFFF),
      error: Color(0xFFB23A1F),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFBE0D8),
      onErrorContainer: Color(0xFF6B1C0B),
      surface: Color(0xFFEFEAE2),
      onSurface: Color(0xFF20241F),
      onSurfaceVariant: Color(0xFF5E6459),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFBF8F2),
      surfaceContainer: Color(0xFFF1EBDF),
      surfaceContainerHigh: Color(0xFFEBE4D6),
      surfaceContainerHighest: Color(0xFFE6DECF),
      outline: Color(0xFF9C9486),
      outlineVariant: Color(0xFFE0D8C9),
      inverseSurface: Color(0xFF20241F),
      onInverseSurface: Color(0xFFF6F1E7),
      inversePrimary: Color(0xFF9ED3A6),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
  );

  static final dark = _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF8FCB98),
      onPrimary: Color(0xFF0F2A15),
      primaryContainer: Color(0xFF24422A),
      onPrimaryContainer: Color(0xFFCDEBD2),
      secondary: Color(0xFFF08A6A),
      onSecondary: Color(0xFF3A1206),
      secondaryContainer: Color(0xFF4A2418),
      onSecondaryContainer: Color(0xFFFFD9CC),
      tertiary: Color(0xFF9DC3EE),
      onTertiary: Color(0xFF0B2740),
      error: Color(0xFFFF9A80),
      onError: Color(0xFF4A1204),
      errorContainer: Color(0xFF5A2213),
      onErrorContainer: Color(0xFFFFDAD0),
      surface: Color(0xFF1E1F1F),
      onSurface: Color(0xFFECE8DF),
      onSurfaceVariant: Color(0xFFB4B0A4),
      surfaceContainerLowest: Color(0xFF282C27),
      surfaceContainerLow: Color(0xFF242723),
      surfaceContainer: Color(0xFF2C302B),
      surfaceContainerHigh: Color(0xFF323630),
      surfaceContainerHighest: Color(0xFF393E37),
      outline: Color(0xFF7D796E),
      outlineVariant: Color(0xFF3A3F38),
      inverseSurface: Color(0xFFECE8DF),
      onInverseSurface: Color(0xFF20241F),
      inversePrimary: Color(0xFF2F6B3A),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: bodyFont);
    TextStyle? display(TextStyle? s, double size, [FontWeight weight = FontWeight.w700]) =>
        s?.copyWith(fontFamily: displayFont, fontSize: size, fontWeight: weight, height: 1.1, letterSpacing: 0);
    final text = base.textTheme.copyWith(
      displaySmall: display(base.textTheme.displaySmall, 40),
      headlineLarge: display(base.textTheme.headlineLarge, 34),
      headlineMedium: display(base.textTheme.headlineMedium, 28),
      headlineSmall: display(base.textTheme.headlineSmall, 24, FontWeight.w600),
      titleLarge: display(base.textTheme.titleLarge, 21, FontWeight.w600),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    const stadium = StadiumBorder();
    final card = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: scheme.outlineVariant),
    );
    return base.copyWith(
      textTheme: text,
      // Le pagine sono trasparenti: sotto c'è lo sfondo con i disegni (vedi _WallpaperTransitions).
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _WallpaperTransitions(PredictiveBackPageTransitionsBuilder()),
          TargetPlatform.iOS: _WallpaperTransitions(CupertinoPageTransitionsBuilder()),
        },
      ),
      appBarTheme: AppBarTheme(
        // Trasparente sui disegni; quando la pagina ci scorre sotto diventa del colore di fondo.
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder) ? scheme.surface : Colors.transparent,
        ),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Barra trasparente: le icone di stato (ora, batteria) vanno scelte in base al fondo, non alla barra.
        systemOverlayStyle: scheme.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: card,
      ),
      // In tutti i campi di testo solo il bordo inferiore.
      inputDecorationTheme: InputDecorationTheme(
        border: const UnderlineInputBorder(),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: scheme.outline)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: stadium,
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontFamily: bodyFont, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: stadium,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: scheme.outlineVariant),
          backgroundColor: scheme.surfaceContainerLowest,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: stadium,
        elevation: 2,
        extendedTextStyle: const TextStyle(fontFamily: bodyFont, fontSize: 17, fontWeight: FontWeight.w700),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: scheme.onSurface,
        secondarySelectedColor: scheme.onSurface,
        labelStyle: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600, color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600, color: scheme.surface),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outlineVariant,
        linearMinHeight: 8,
        borderRadius: BorderRadius.circular(8),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}

/// Mette lo sfondo con i disegni dei prodotti sotto ogni pagina, compresa la zona della barra in alto; durante
/// il passaggio da una pagina all'altra ognuna porta con sé il proprio sfondo.
class _WallpaperTransitions extends PageTransitionsBuilder {
  const _WallpaperTransitions(this.inner);

  final PageTransitionsBuilder inner;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => inner.delegatedTransition;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => inner.buildTransitions(route, context, animation, secondaryAnimation, ProductsWallpaper(child: child));
}

/// Sfondo "Carrelli e sacchetti": carrelli, buste e cestini a tratto sottile ripetuti, chiaro o scuro secondo il
/// tema. Le immagini (3x) sono generate da assets/backgrounds/sorgenti/, dove ci sono anche gli altri sfondi
/// proposti; i disegni dei prodotti usati prima sono in assets/backgrounds/precedente/.
class ProductsWallpaper extends StatelessWidget {
  const ProductsWallpaper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        image: DecorationImage(
          image: AssetImage(dark ? 'assets/backgrounds/carrelli_dark.png' : 'assets/backgrounds/carrelli_light.png'),
          repeat: ImageRepeat.repeat,
          // Disegni della stessa grandezza su ogni telefono (tessera da 170 punti).
          scale: 3,
        ),
      ),
      child: child,
    );
  }
}

/// Stile dei pulsanti tondi con fondo bianco sopra la pagina crema (indietro, chat, invia…).
ButtonStyle roundButtonStyle(BuildContext context) =>
    IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest);

/// Colore del reparto (pallino accanto al nome e fondo dell'icona dell'articolo).
Color categoryColor(String slug, Brightness brightness) {
  const light = {
    'frutta': Color(0xFFE4572E),
    'verdura': Color(0xFF3F8F4E),
    'pane': Color(0xFFB7791F),
    'latticini': Color(0xFF3A6EA5),
    'carne': Color(0xFFB5476B),
    'pesce': Color(0xFF2B8A9E),
    'pasta': Color(0xFFC9962B),
    'dispensa': Color(0xFF8A6D3B),
    'dolci': Color(0xFFC0508A),
    'bevande': Color(0xFF4F6BD8),
    'surgelati': Color(0xFF3B9BC7),
    'igiene': Color(0xFF7A5AC2),
    'casa': Color(0xFF5E7A8A),
    'animali': Color(0xFF9A6A3A),
  };
  final color = light[slug] ?? const Color(0xFF7D796E);
  return brightness == Brightness.dark ? Color.lerp(color, Colors.white, 0.3)! : color;
}
