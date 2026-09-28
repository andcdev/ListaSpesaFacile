/// Articolo dettato a voce, es. "2 kg di mele" → mele, 2 kg; "3 yogurt" → yogurt, quantità 3.
/// Capisce anche inglese, francese, tedesco e spagnolo ("2 kilos of apples", "500 grammes de farine",
/// "zwei Liter Milch", "un kilo de naranjas").
class SpokenItem {
  const SpokenItem(this.name, {this.quantity, this.amount, this.unit});

  final String name;
  final String? quantity;
  final double? amount;
  final String? unit;

  static const _numbers = {
    // Italiano
    'un': 1.0,
    'uno': 1.0,
    'una': 1.0,
    'mezzo': 0.5,
    'mezza': 0.5,
    'due': 2.0,
    'tre': 3.0,
    'quattro': 4.0,
    'cinque': 5.0,
    'sei': 6.0,
    'sette': 7.0,
    'otto': 8.0,
    'nove': 9.0,
    'dieci': 10.0,
    'dodici': 12.0,
    'venti': 20.0,
    'cento': 100.0,
    'duecento': 200.0,
    'trecento': 300.0,
    'cinquecento': 500.0,
    // English
    'a': 1.0,
    'an': 1.0,
    'one': 1.0,
    'half': 0.5,
    'two': 2.0,
    'three': 3.0,
    'four': 4.0,
    'five': 5.0,
    'six': 6.0,
    'seven': 7.0,
    'eight': 8.0,
    'nine': 9.0,
    'ten': 10.0,
    'twelve': 12.0,
    'twenty': 20.0,
    'hundred': 100.0,
    // Français
    'une': 1.0,
    'demi': 0.5,
    'demie': 0.5,
    'deux': 2.0,
    'trois': 3.0,
    'quatre': 4.0,
    'cinq': 5.0,
    'sept': 7.0,
    'huit': 8.0,
    'neuf': 9.0,
    'dix': 10.0,
    'douze': 12.0,
    'vingt': 20.0,
    'cent': 100.0,
    // Deutsch
    'ein': 1.0,
    'eine': 1.0,
    'einen': 1.0,
    'eins': 1.0,
    'halb': 0.5,
    'halbe': 0.5,
    'halbes': 0.5,
    'zwei': 2.0,
    'drei': 3.0,
    'vier': 4.0,
    'fünf': 5.0,
    'sechs': 6.0,
    'sieben': 7.0,
    'acht': 8.0,
    'neun': 9.0,
    'zehn': 10.0,
    'zwölf': 12.0,
    'zwanzig': 20.0,
    'hundert': 100.0,
    // Español
    'medio': 0.5,
    'media': 0.5,
    'dos': 2.0,
    'tres': 3.0,
    'cuatro': 4.0,
    'cinco': 5.0,
    'seis': 6.0,
    'siete': 7.0,
    'ocho': 8.0,
    'nueve': 9.0,
    'diez': 10.0,
    'doce': 12.0,
    'veinte': 20.0,
    'cien': 100.0,
  };

  /// Come si pronunciano le unità di misura → unità dell'app.
  static const _units = {
    'g': 'g',
    'gr': 'g',
    'grammo': 'g',
    'grammi': 'g',
    'hg': 'hg',
    'etto': 'hg',
    'etti': 'hg',
    'kg': 'kg',
    'chilo': 'kg',
    'chili': 'kg',
    'kilo': 'kg',
    'kili': 'kg',
    'chilogrammo': 'kg',
    'chilogrammi': 'kg',
    'ml': 'ml',
    'millilitro': 'ml',
    'millilitri': 'ml',
    'cl': 'cl',
    'centilitro': 'cl',
    'centilitri': 'cl',
    'l': 'l',
    'lt': 'l',
    'litro': 'l',
    'litri': 'l',
    // English, français, Deutsch, español
    'gram': 'g',
    'grams': 'g',
    'gramme': 'g',
    'grammes': 'g',
    'gramm': 'g',
    'gramo': 'g',
    'gramos': 'g',
    'kilos': 'kg',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'kilogramme': 'kg',
    'kilogrammes': 'kg',
    'kilogramm': 'kg',
    'kilogramo': 'kg',
    'kilogramos': 'kg',
    'milliliter': 'ml',
    'milliliters': 'ml',
    'millilitre': 'ml',
    'millilitres': 'ml',
    'mililitro': 'ml',
    'mililitros': 'ml',
    'centiliter': 'cl',
    'centilitre': 'cl',
    'centilitres': 'cl',
    'liter': 'l',
    'liters': 'l',
    'litre': 'l',
    'litres': 'l',
    'litros': 'l',
  };

  /// "di/of/de/von" tra unità e nome: "2 kg di mele", "1 litre de lait", "500 g von Mehl".
  static const _connectors = {'di', 'd', 'of', 'de', 'du', 'des', 'von', 'del'};

  static final _numberPattern = RegExp(r'^\d+(?:[.,]\d+)?$');

  /// Riconosce numero e unità all'inizio della frase; se non c'è nulla da riconoscere il testo resta il nome.
  static SpokenItem parse(String text, {List<String> units = const ['g', 'hg', 'kg', 'ml', 'cl', 'l']}) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2) return SpokenItem(_capitalize(text.trim()));

    final number = _number(words[0]);
    if (number == null) return SpokenItem(_capitalize(text.trim()));

    // "1 kg e mezzo"/"un chilo e mezzo" sono rari: basta numero + unità + (di) nome.
    final unit = _units[words[1].toLowerCase().replaceAll('.', '')];
    if (unit != null && units.contains(unit) && words.length > 2) {
      var rest = words.sublist(2);
      final first = rest.first.toLowerCase();
      if (rest.length > 1 && _connectors.contains(first)) {
        rest = rest.sublist(1);
      } else if (RegExp(r"^d['’]").hasMatch(first) && first.length > 2) {
        // Francese/italiano con apostrofo: "1 kg d'oranges".
        rest = [rest.first.substring(2), ...rest.sublist(1)];
      }
      return SpokenItem(_capitalize(rest.join(' ')), amount: number, unit: unit);
    }

    // "un/una/a/ein" all'inizio è un articolo ("una pizza"), non una quantità da mostrare.
    final rest = words.sublist(1).join(' ');
    if (number == 1 && !_numberPattern.hasMatch(words[0])) return SpokenItem(_capitalize(rest));
    if (number != number.roundToDouble()) return SpokenItem(_capitalize(text.trim()));
    return SpokenItem(_capitalize(rest), quantity: '${number.toInt()}');
  }

  static double? _number(String word) {
    final w = word.toLowerCase();
    if (_numberPattern.hasMatch(w)) return double.tryParse(w.replaceAll(',', '.'));
    return _numbers[w];
  }

  static String _capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
