import 'package:flutter_test/flutter_test.dart';
import 'package:lista_spesa_facile/services/api_client.dart';
import 'package:lista_spesa_facile/services/realtime_client.dart';

void main() {
  test('le iscrizioni fatte prima della connessione restano (liste nuove visibili senza aggiornare)', () async {
    final realtime = RealtimeClient(ApiClient(baseUrl: 'http://127.0.0.1:9'));
    addTearDown(realtime.disconnect);
    // La schermata delle liste si iscrive al canale personale prima che arrivi la configurazione del server.
    realtime.subscribe('private-App.Models.User.1');
    await realtime.connect(const RealtimeConfig(key: 'k', host: '127.0.0.1', port: 9, scheme: 'http'));
    expect(realtime.subscribedChannels, {'private-App.Models.User.1'});
    // Riconnessione (es. rete tornata): nessuna iscrizione persa.
    await realtime.connect(const RealtimeConfig(key: 'k', host: '127.0.0.1', port: 9, scheme: 'http'));
    expect(realtime.subscribedChannels, {'private-App.Models.User.1'});
    // All'uscita dall'account si dimentica tutto.
    realtime.disconnect();
    expect(realtime.subscribedChannels, isEmpty);
  });
}
