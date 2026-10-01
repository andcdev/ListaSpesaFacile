/// Come si indica quanto prendere di un prodotto, secondo come si vende (deciso dal server, vedi
/// ProductCatalog::measure): sfuso a peso (salumi, formaggi al banco, uva…), sfuso a peso e a pezzi
/// (mele, pomodori, melanzane…) o in confezione (Kinder, pasta, latte: si sceglie solo quante confezioni).
enum MeasureMode {
  weight,
  weightCount,
  count;

  /// Null se non si sa (server vecchio o senza rete): allora si mostrano tutti i campi.
  static MeasureMode? fromJson(Object? value) => switch (value) {
    'weight' => MeasureMode.weight,
    'weight_count' => MeasureMode.weightCount,
    'count' => MeasureMode.count,
    _ => null,
  };
}

extension MeasureModeFields on MeasureMode? {
  /// Numero di pezzi o confezioni.
  bool get asksQuantity => this != MeasureMode.weight;

  /// Peso o volume modificabile (per le confezioni è quello della confezione, solo da leggere).
  bool get asksWeight => this != MeasureMode.count;

  /// Sfuso: si pesa, quindi solo unità di peso.
  bool get isLoose => this == MeasureMode.weight || this == MeasureMode.weightCount;
}

/// Unità di peso, per gli sfusi.
const weightUnits = ['g', 'hg', 'kg'];
