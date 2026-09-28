import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../l10n/l10n.dart';
import 'ui.dart';

/// Microfono per dettare invece di scrivere (riconoscimento vocale del telefono, nella lingua dell'app).
///
/// Mentre parli il testo compare in [controller]; con [append] si aggiunge a quello già scritto
/// (es. nella chat), altrimenti lo sostituisce. Al termine viene chiamato [onResult] con il testo finale.
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({
    super.key,
    required this.controller,
    this.onResult,
    this.append = false,
    this.compact = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onResult;
  final bool append;

  /// Icona più piccola, da usare dentro un campo di testo.
  final bool compact;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  /// Il riconoscimento si inizializza una sola volta per tutta l'app.
  static final _speech = SpeechToText();
  static bool _available = false;

  /// Lingue di riconoscimento installate sul telefono (es. it_IT, en_US).
  static List<String> _localeIds = [];

  /// Pulsante della dettatura in corso: riceve risultati e stati finché la sessione non è chiusa ("done").
  /// Attenzione: Android segnala "notListening" quando smetti di parlare, e il testo finale arriva DOPO;
  /// per questo la sessione resta aperta fino al risultato finale o a "done".
  static _VoiceInputButtonState? _active;

  bool _listening = false;
  String _prefix = '';
  String _lastWords = '';
  bool _delivered = false;

  @override
  void dispose() {
    if (_active == this) {
      _active = null;
      _speech.cancel();
    }
    super.dispose();
  }

  Future<bool> _init() async {
    if (_available) return true;
    _available = await _speech.initialize(
      onError: (error) => _active?._onError(error),
      onStatus: (status) => _active?._onStatus(status),
      options: [
        // Senza permesso Bluetooth (Android 12+) il plugin non deve provare a usare le cuffie.
        SpeechToText.androidNoBluetooth,
        // Alcuni telefoni non dichiarano bene il servizio di riconoscimento: lo si cerca nell'elenco.
        SpeechToText.androidIntentLookup,
      ],
    );
    if (_available) _localeIds = [for (final l in await _speech.locales()) l.localeId];
    return _available;
  }

  /// Riconoscimento nella lingua dell'app, preferendo la variante del paese principale (it_IT, fr_FR…).
  static String get _localeId {
    final language = currentLanguage;
    const preferred = {'it': 'it_IT', 'en': 'en_US', 'fr': 'fr_FR', 'de': 'de_DE', 'es': 'es_ES'};
    final main = preferred[language]!;
    String normalize(String id) => id.replaceAll('-', '_').toLowerCase();
    return _localeIds.firstWhere(
      (id) => normalize(id) == main.toLowerCase(),
      orElse: () => _localeIds.firstWhere((id) => normalize(id).startsWith(language), orElse: () => main),
    );
  }

  Future<void> _toggle() async {
    if (_listening) {
      // Fermandosi a mano arriva comunque il risultato finale.
      await _speech.stop();
      return;
    }
    if (!await _init()) {
      final permitted = await _speech.hasPermission;
      if (!mounted) return;
      showError(context, permitted ? context.l10n.voiceUnavailable : context.l10n.voiceMicPermission);
      return;
    }
    final previous = _active;
    if (previous != null && previous != this) {
      await _speech.cancel();
      previous._finish();
    }
    final current = widget.controller.text.trim();
    _prefix = widget.append && current.isNotEmpty ? '$current ' : '';
    _lastWords = '';
    _delivered = false;
    _active = this;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted || _active != this) return;
    if (result.recognizedWords.isNotEmpty) {
      _lastWords = result.recognizedWords;
      _write('$_prefix$_lastWords');
    }
    if (result.finalResult) _deliver();
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == SpeechToText.listeningStatus) {
      setState(() => _listening = true);
    } else if (status == SpeechToText.notListeningStatus) {
      // Smesso di ascoltare: il testo finale può ancora arrivare.
      setState(() => _listening = false);
    } else if (status == SpeechToText.doneStatus) {
      // Sessione chiusa: se il risultato "finale" non è arrivato si usa l'ultimo testo riconosciuto.
      if (_lastWords.isEmpty && _speech.lastRecognizedWords.isNotEmpty) {
        _lastWords = _speech.lastRecognizedWords;
        _write('$_prefix$_lastWords');
      }
      _deliver();
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (!mounted) return;
    final l = context.l10n;
    final message = switch (error.errorMsg) {
      'error_no_match' || 'error_speech_timeout' => l.voiceNoMatch,
      'error_network' || 'error_network_timeout' || 'error_server' || 'error_server_disconnected' => l.voiceNetwork,
      'error_permission' || 'error_insufficient_permissions' => l.voiceMicPermission,
      'error_busy' || 'error_recognizer_busy' => l.voiceBusy,
      'error_language_not_supported' ||
      'error_language_unavailable' => l.voiceLanguageUnavailable(appLanguages[currentLanguage]!),
      _ => l.voiceNotUnderstood,
    };
    if (_lastWords.isEmpty) showError(context, message);
    _deliver();
  }

  void _write(String text) {
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Fine della dettatura: una sola volta per sessione passa il testo a [VoiceInputButton.onResult].
  void _deliver() {
    if (_delivered) return;
    _delivered = true;
    final words = _lastWords.trim();
    _finish();
    if (words.isNotEmpty) widget.onResult?.call('$_prefix$words'.trim());
  }

  void _finish() {
    if (_active == this) _active = null;
    if (mounted && _listening) setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: _listening ? context.l10n.stopListening : context.l10n.dictate,
      visualDensity: widget.compact ? VisualDensity.compact : null,
      onPressed: _toggle,
      icon: _listening ? Icon(Icons.mic, color: scheme.error) : const Icon(Icons.mic_none),
    );
  }
}
