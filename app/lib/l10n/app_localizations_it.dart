// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get cancel => 'Annulla';

  @override
  String get delete => 'Elimina';

  @override
  String get save => 'Salva';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Riprova';

  @override
  String get remove => 'Rimuovi';

  @override
  String get add => 'Aggiungi';

  @override
  String get confirm => 'Conferma';

  @override
  String get edit => 'Modifica';

  @override
  String get share => 'Condividi';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get name => 'Nome';

  @override
  String get today => 'Oggi';

  @override
  String get tomorrow => 'Domani';

  @override
  String get yesterday => 'Ieri';

  @override
  String get canEdit => 'Può modificare';

  @override
  String get userCanEdit => 'può modificare';

  @override
  String get userReadOnly => 'sola lettura';

  @override
  String get invalidEmail => 'Inserisci un\'email valida';

  @override
  String get enterRegisteredEmail =>
      'Inserisci l\'email di un utente registrato';

  @override
  String get atLeast8 => 'Almeno 8 caratteri';

  @override
  String get confirmPassword => 'Conferma password';

  @override
  String get passwordsDontMatch => 'Le password non coincidono';

  @override
  String get nobody => 'Nessuno.';

  @override
  String get myLists => 'Le mie liste';

  @override
  String get other => 'Altro';

  @override
  String get language => 'Lingua';

  @override
  String languageValue(String language) {
    return 'Lingua: $language';
  }

  @override
  String languageSystem(String language) {
    return 'Come il telefono ($language)';
  }

  @override
  String get background => 'Sfondo';

  @override
  String backgroundValue(String value) {
    return 'Sfondo: $value';
  }

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get themeSystem => 'Come il telefono';

  @override
  String get errTimeout => 'Il server non risponde. Riprova più tardi.';

  @override
  String get errNetwork =>
      'Impossibile contattare il server. Controlla la connessione.';

  @override
  String get errSessionExpired => 'Sessione scaduta. Accedi di nuovo.';

  @override
  String get errForbidden => 'Non hai i permessi per questa operazione.';

  @override
  String get errNotFound => 'Elemento non trovato (forse è stato eliminato).';

  @override
  String get errTooMany => 'Troppi tentativi. Attendi un minuto.';

  @override
  String get errServer => 'Errore del server. Riprova più tardi.';

  @override
  String errUnexpected(int status) {
    return 'Errore imprevisto ($status).';
  }

  @override
  String get checkYourEmail => 'Controlla la tua email.';

  @override
  String get enterPassword => 'Inserisci la password';

  @override
  String get forgotPasswordQuestion => 'Password dimenticata?';

  @override
  String get signIn => 'Accedi';

  @override
  String get noAccount => 'Non hai un account? Registrati';

  @override
  String get server => 'Server';

  @override
  String get serverAddress => 'Indirizzo del server';

  @override
  String socialNotActiveTitle(String provider) {
    return 'Accesso con $provider non ancora attivo';
  }

  @override
  String socialNotActiveBody(String provider) {
    return 'Il server non è ancora collegato a $provider. Chi gestisce il server deve registrare l\'app presso $provider e inserire ID e secret nel file .env (vedi il README, \"Accesso con Google e Amazon\").\n\nNel frattempo puoi registrarti con email e password.';
  }

  @override
  String get or => 'oppure';

  @override
  String continueWith(String provider) {
    return 'Continua con $provider';
  }

  @override
  String socialOpenFailed(String provider) {
    return 'Impossibile aprire l\'accesso con $provider.';
  }

  @override
  String get socialFailed => 'Accesso non riuscito.';

  @override
  String get hidePassword => 'Nascondi la password';

  @override
  String get showPassword => 'Mostra la password';

  @override
  String get createAccount => 'Crea un account';

  @override
  String get enterYourName => 'Inserisci il tuo nome';

  @override
  String get signUp => 'Registrati';

  @override
  String get forgotPasswordTitle => 'Password dimenticata';

  @override
  String get resetCodeSentInfo =>
      'Ti abbiamo inviato un codice di 6 cifre (controlla anche lo spam). Inseriscilo e scegli la nuova password.';

  @override
  String get resetInfo =>
      'Inserisci l\'email del tuo account: ti invieremo un codice per scegliere una nuova password.';

  @override
  String get resetCodeLabel => 'Codice ricevuto via email';

  @override
  String get resetCodeInvalid => 'Il codice ha 6 cifre';

  @override
  String get newPassword => 'Nuova password';

  @override
  String get setNewPassword => 'Imposta la nuova password';

  @override
  String get sendCode => 'Invia il codice';

  @override
  String get resendCode => 'Non è arrivato? Invia di nuovo';

  @override
  String deleteListNamed(String name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get deleteListSharedInfo =>
      'La lista sparirà anche per gli utenti con cui è condivisa.';

  @override
  String get profilePhotoTitle => 'Foto profilo (visibile nella chat)';

  @override
  String get profilePhotoUpdated => 'Foto profilo aggiornata.';

  @override
  String get globalSharing => 'Condivisione globale';

  @override
  String get profile => 'Profilo';

  @override
  String get logoutQuestion => 'Vuoi uscire?';

  @override
  String get logout => 'Esci';

  @override
  String get deleteAccount => 'Elimina account';

  @override
  String get deleteAccountQuestion => 'Eliminare l\'account?';

  @override
  String get deleteAccountMessage =>
      'L\'eliminazione è definitiva e non si può annullare. Le tue liste, con articoli, foto e chat, vengono cancellate anche per chi le condivide con te, e sparisci dalle liste degli altri.';

  @override
  String get deleteAccountConfirm => 'Elimina definitivamente';

  @override
  String get accountDeleted => 'Account eliminato.';

  @override
  String get addProfilePhoto => 'Aggiungi foto profilo';

  @override
  String get changeProfilePhoto => 'Cambia foto profilo';

  @override
  String get newList => 'Nuova lista';

  @override
  String get noUpcoming => 'Nessuna spesa in programma.';

  @override
  String get upcomingTab => 'In programma';

  @override
  String pastTab(int count) {
    return 'Passate · $count';
  }

  @override
  String toBuyCount(int count) {
    return '$count da prendere';
  }

  @override
  String get listCompleteBadge => 'Completa';

  @override
  String get listEmptyBadge => 'Vuota';

  @override
  String viewingNowShort(String names) {
    return 'qui ora: $names';
  }

  @override
  String byOwner(String name) {
    return 'di $name';
  }

  @override
  String get noLists =>
      'Nessuna lista.\nCreane una con il pulsante \"Nuova lista\".';

  @override
  String get realtimeOn => 'Aggiornamenti in tempo reale attivi';

  @override
  String get realtimeOff => 'Tempo reale non connesso';

  @override
  String get notifications => 'Notifiche';

  @override
  String get editList => 'Modifica lista';

  @override
  String get alreadyAdded => 'Già aggiunto';

  @override
  String get listNameHint => 'es. Spesa settimanale';

  @override
  String get renameLocked => 'Il proprietario non consente di cambiare il nome';

  @override
  String get listNameRequired => 'Dai un nome alla lista';

  @override
  String get notesLabel => 'Note (facoltative)';

  @override
  String get notesHint => 'es. supermercato, promozioni…';

  @override
  String get reminder => 'Promemoria';

  @override
  String get noReminder => 'Nessun promemoria';

  @override
  String durationBefore(String duration) {
    return '$duration prima';
  }

  @override
  String get customReminderOption => 'Personalizzato…';

  @override
  String get whoToNotify => 'Chi avvisare';

  @override
  String get reminderOwner => 'Solo il creatore';

  @override
  String get reminderMembers => 'Solo i destinatari';

  @override
  String get reminderAll => 'Creatore e destinatari';

  @override
  String get shareWith => 'Condividi con';

  @override
  String get userEmail => 'Email dell\'utente';

  @override
  String get userEmailOptional => 'Email dell\'utente (facoltativo)';

  @override
  String get willBeNotified => 'Riceverà una notifica quando crei la lista';

  @override
  String get permissions => 'Permessi';

  @override
  String get membersCanRenameTitle =>
      'Chi può modificare può cambiare anche il nome';

  @override
  String get membersCanRenameOn =>
      'Gli utenti con permesso di modifica possono rinominare la lista';

  @override
  String get membersCanRenameOff =>
      'Solo tu puoi cambiare il nome; gli altri modificano gli articoli';

  @override
  String get saveChanges => 'Salva modifiche';

  @override
  String get createList => 'Crea lista';

  @override
  String get customReminder => 'Promemoria personalizzato';

  @override
  String get howEarly => 'Quanto prima';

  @override
  String get unitMinutes => 'minuti';

  @override
  String get unitHours => 'ore';

  @override
  String get unitDays => 'giorni';

  @override
  String get reminderRange => 'Da 1 minuto a 30 giorni';

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ore',
      one: '1 ora',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuti',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get durationMoments => 'pochi istanti';

  @override
  String listAnd(String head, String last) {
    return '$head e $last';
  }

  @override
  String listSharedWith(String email) {
    return 'Lista condivisa con $email';
  }

  @override
  String removeUserQuestion(String name) {
    return 'Rimuovere $name?';
  }

  @override
  String get removeUserInfo => 'Non vedrà più questa lista.';

  @override
  String get sharedWith => 'Condivisa con';

  @override
  String get nobodyYet => 'Nessuno, per ora.';

  @override
  String get globalShareHint =>
      'Per condividere tutte le tue liste con qualcuno, usa la \"Condivisione globale\" dalla schermata principale.';

  @override
  String allListsSharedWith(String email) {
    return 'Tutte le tue liste sono ora condivise con $email';
  }

  @override
  String stopSharingWith(String name) {
    return 'Smettere di condividere con $name?';
  }

  @override
  String stopReceivingFrom(String name) {
    return 'Non vedere più le liste di $name?';
  }

  @override
  String get globalShareInfo =>
      'Le persone indicate qui vedono tutte le tue liste, comprese quelle che creerai in futuro.';

  @override
  String get iShareWith => 'Condivido tutte le mie liste con';

  @override
  String get sharedWithMe => 'Condividono tutte le loro liste con me';

  @override
  String get stopReceiving => 'Non ricevere più';

  @override
  String get deleteAllNotificationsQuestion => 'Eliminare tutte le notifiche?';

  @override
  String get markAllRead => 'Segna tutte lette';

  @override
  String get deleteAll => 'Elimina tutte';

  @override
  String get noNotifications => 'Nessuna notifica.';

  @override
  String get channelName => 'Liste della spesa';

  @override
  String get channelDescription =>
      'Promemoria, condivisioni e messaggi delle liste';

  @override
  String get you => 'Tu';

  @override
  String get serviceChannelName => 'Collegamento in background';

  @override
  String get serviceChannelDescription =>
      'Tiene l\'app collegata per ricevere liste e messaggi anche quando è chiusa';

  @override
  String reminderTitle(String name) {
    return 'Promemoria: $name';
  }

  @override
  String reminderBody(String duration) {
    return 'La spesa è tra $duration.';
  }

  @override
  String get sendPhoto => 'Invia una foto';

  @override
  String get deleteMessageQuestion => 'Eliminare il messaggio?';

  @override
  String get deleteMessageInfo => 'Sparirà per tutti.';

  @override
  String get writeMessage => 'Scrivi un messaggio';

  @override
  String get send => 'Invia';

  @override
  String get deletedUser => 'Utente';

  @override
  String get messageReceived => 'Ricevuto';

  @override
  String get messageSent => 'Inviato';

  @override
  String get emptyChat =>
      'Nessun messaggio.\nScrivi, detta con il microfono o invia una foto a chi condivide la lista: \"Sono al banco frigo, manca qualcosa?\"';

  @override
  String get pickFromGallery => 'Scegli dalla galleria';

  @override
  String get takePhoto => 'Scatta una foto';

  @override
  String get removePhoto => 'Rimuovi la foto';

  @override
  String get imageUnavailable => 'Immagine non disponibile';

  @override
  String get voiceUnavailable =>
      'Riconoscimento vocale non disponibile su questo telefono: installa o attiva l\'app Google (riconoscimento vocale di Google).';

  @override
  String get voiceMicPermission =>
      'Per dettare consenti all\'app l\'uso del microfono nelle impostazioni del telefono.';

  @override
  String get voiceNoMatch =>
      'Non ho sentito nulla: tocca il microfono e parla subito.';

  @override
  String get voiceNetwork =>
      'Riconoscimento vocale non raggiungibile: controlla la connessione.';

  @override
  String get voiceBusy => 'Il microfono è occupato, riprova tra un attimo.';

  @override
  String voiceLanguageUnavailable(String language) {
    return '$language non disponibile per la dettatura: scaricalo nelle impostazioni della voce di Google.';
  }

  @override
  String get voiceNotUnderstood => 'Non ho capito, riprova.';

  @override
  String get stopListening => 'Smetti di ascoltare';

  @override
  String get dictate => 'Detta a voce';

  @override
  String get exportNotFound => 'non trovato';

  @override
  String exportTaken(int taken, int total) {
    return '$taken di $total presi';
  }

  @override
  String pdfPage(int page, int total) {
    return 'pagina $page di $total';
  }

  @override
  String pdfSummary(int taken, int missing, int todo) {
    return 'Presi: $taken · Non trovati: $missing · Da prendere: $todo';
  }

  @override
  String get numericDatePattern => 'dd/MM/y';

  @override
  String get listUnavailable => 'La lista non è più disponibile.';

  @override
  String get deleteListQuestion => 'Eliminare la lista?';

  @override
  String get deleteListInfo => 'Verrà eliminata anche per chi la condivide.';

  @override
  String get leaveListQuestion => 'Abbandonare la lista?';

  @override
  String get leaveListInfo =>
      'Non la vedrai più finché non ti verrà ricondivisa.';

  @override
  String get leave => 'Abbandona';

  @override
  String get listPhotoUpdated => 'Foto della lista aggiornata.';

  @override
  String photoOf(String name) {
    return 'Foto di $name';
  }

  @override
  String deleteItemQuestion(String name) {
    return 'Eliminare «$name» dalla lista?';
  }

  @override
  String get deleteItemInfo =>
      'Sparirà dalla lista per tutti. Se l\'hai solo messo nel carrello, spuntalo come preso.';

  @override
  String get putBackToBuy => 'Rimetti da prendere';

  @override
  String get takenInCart => 'Preso (nel carrello)';

  @override
  String get notFound => 'Non trovato';

  @override
  String get addPhoto => 'Aggiungi una foto';

  @override
  String get changePhoto => 'Cambia foto';

  @override
  String get deleteFromList => 'Elimina dalla lista';

  @override
  String get deleteFromListInfo =>
      'Diverso da \"preso\": l\'articolo sparisce per tutti';

  @override
  String get sendOrExportList => 'Invia o esporta la lista';

  @override
  String get exportTextInfo => 'Testo con le spunte, scegli tu la chat';

  @override
  String get exportPdfInfo =>
      'Da stampare o inviare (anche su WhatsApp o Telegram)';

  @override
  String get otherApps => 'Altre app';

  @override
  String appNotInstalled(String app) {
    return '$app non è installato su questo telefono.';
  }

  @override
  String get list => 'Lista';

  @override
  String get closeChat => 'Chiudi la chat';

  @override
  String get chat => 'Chat';

  @override
  String get sendOrExport => 'Invia o esporta';

  @override
  String get clearTaken => 'Rimuovi articoli presi';

  @override
  String get deleteList => 'Elimina lista';

  @override
  String get leaveList => 'Abbandona lista';

  @override
  String get cannotLoadList => 'Impossibile caricare la lista.';

  @override
  String reminderBefore(String duration) {
    return 'Promemoria $duration prima';
  }

  @override
  String get readOnlyAccess => 'Hai accesso in sola lettura';

  @override
  String get emptyList =>
      'La lista è vuota.\nAggiungi il primo articolo qui sotto.';

  @override
  String inCart(int checked, int total) {
    return '$checked di $total nel carrello';
  }

  @override
  String notFoundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non trovati',
      one: '1 non trovato',
    );
    return '$_temp0';
  }

  @override
  String takenBy(String name) {
    return 'preso da $name';
  }

  @override
  String get notFoundLower => 'non trovato';

  @override
  String notFoundBy(String name) {
    return 'non trovato ($name)';
  }

  @override
  String get markToBuyAgain => 'Segna di nuovo da prendere';

  @override
  String get markMissing => 'Non preso (non trovato)';

  @override
  String get itemMenu => 'Modifica, foto o elimina';

  @override
  String get onlyYouViewing => 'Solo tu stai guardando questa lista';

  @override
  String viewingNow(String names) {
    return 'Qui ora: $names';
  }

  @override
  String typing(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names stanno scrivendo…',
      one: '$names sta scrivendo…',
    );
    return '$_temp0';
  }

  @override
  String get listPhoto => 'Foto della lista';

  @override
  String get listPhotoUploadFailed =>
      'Lista creata, ma la foto non è stata caricata: aggiungila dal menu della lista.';

  @override
  String get productPhoto => 'Foto del prodotto';

  @override
  String get oftenBought => 'Compri spesso:';

  @override
  String timesInList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Già messo in lista $count volte',
      one: 'Già messo in lista 1 volta',
    );
    return '$_temp0';
  }

  @override
  String get addProductHint => 'Agg. prodotto...';

  @override
  String get amountExampleError => 'Scrivi un numero, es. 500 oppure 1,5';

  @override
  String get quantity => 'Quantità';

  @override
  String get less => 'Meno';

  @override
  String get more => 'Più';

  @override
  String get weightOrVolume => 'Peso o volume';

  @override
  String get weight => 'Peso';

  @override
  String get packages => 'Confezioni';

  @override
  String packageSize(String size) {
    return 'Confezione da $size';
  }

  @override
  String get amountHint => 'es. 500';

  @override
  String get clearMeasure => 'Togli';

  @override
  String get done => 'Fatto';

  @override
  String get invalidImageUrl => 'Inserisci un link che inizia con https://';

  @override
  String get invalidNumber => 'Numero non valido';

  @override
  String get emojiTooLong => 'Al massimo una o due emoji';

  @override
  String get addProductPhoto => 'Aggiungi una foto del prodotto';

  @override
  String get changeOrRemovePhoto => 'Cambia o rimuovi la foto';

  @override
  String get editItem => 'Modifica articolo';

  @override
  String get product => 'Prodotto';

  @override
  String get quantityOptional => 'Quantità (facoltativa)';

  @override
  String get weightOptional => 'Peso o volume (facoltativo)';

  @override
  String get packagesOptional => 'Confezioni (facoltativo)';

  @override
  String get weightOnlyOptional => 'Peso (facoltativo)';

  @override
  String get department => 'Reparto';

  @override
  String get departmentHelper =>
      'Riconosciuto dal nome: cambialo se non è giusto';

  @override
  String get emojiOptional => 'Emoji (facoltativa)';

  @override
  String recognizedEmoji(String emoji) {
    return 'Riconosciuta: $emoji';
  }

  @override
  String get fromName => 'dal nome';

  @override
  String get useRecognizedEmoji => 'Usa quella riconosciuta dal nome';

  @override
  String get imageLinkOptional => 'Link a un\'immagine (facoltativo)';

  @override
  String get supermarketLabel => 'Supermercato (facoltativo)';

  @override
  String get supermarketHint => 'es. Esselunga, Coop, Lidl';

  @override
  String get supermarketHelper => 'Dove fai la spesa (facoltativo)';

  @override
  String get close => 'Chiudi';

  @override
  String get perPiece => 'a confezione';

  @override
  String get perKg => 'al kg';

  @override
  String get perLitre => 'al litro';

  @override
  String get priceLabel => 'Prezzo';

  @override
  String get invalidPrice => 'Scrivi un prezzo, es. 1,29';

  @override
  String get privacyRequired =>
      'Per registrarti devi accettare l\'informativa privacy';

  @override
  String get acceptPrivacyPrefix => 'Ho letto e accetto l\'';

  @override
  String get acceptPrivacySuffix => '';

  @override
  String get privacyPolicy => 'informativa privacy';

  @override
  String get termsRequired =>
      'Per registrarti devi accettare le condizioni d\'uso';

  @override
  String get acceptTermsPrefix => 'Accetto le ';

  @override
  String get termsOfUse => 'condizioni d\'uso';

  @override
  String get acceptTermsSuffix =>
      ': i contenuti che aggiungo sono sotto la mia responsabilità';

  @override
  String get newsletterConsent =>
      'Voglio ricevere la newsletter di Lista Spesa Facile';

  @override
  String get newsletterOptional => 'Facoltativo';

  @override
  String get socialPrivacyNotice =>
      'Continuando con Google o Amazon accetti l\'';

  @override
  String get socialTermsJoin => ' e le ';

  @override
  String get myPrices => 'I miei prezzi';

  @override
  String get myPrice => 'Il mio prezzo';

  @override
  String get addMyPrice => 'Aggiungi prezzo';

  @override
  String get editMyPrice => 'Modifica prezzo';

  @override
  String get productRequired => 'Scrivi il prodotto';

  @override
  String get noteOptional => 'Nota (facoltativa)';

  @override
  String get myPricesPrivate => 'I tuoi prezzi li vedi solo tu.';

  @override
  String get myPriceSaved => 'Prezzo salvato in \"I miei prezzi\"';

  @override
  String get filterLists => 'Filtra le liste';

  @override
  String get sortOrder => 'Ordine';

  @override
  String get dateAscending => 'Data crescente';

  @override
  String get dateDescending => 'Data decrescente';

  @override
  String get filterPerson => 'Condivise con';

  @override
  String get everyone => 'Tutti';

  @override
  String get filterPeriod => 'Data dell\'evento';

  @override
  String get allDates => 'Tutte';

  @override
  String get last15Days => 'Ultimi 15 giorni';

  @override
  String get last30Days => 'Ultimi 30 giorni';

  @override
  String get next15Days => 'Prossimi 15 giorni';

  @override
  String get next30Days => 'Prossimi 30 giorni';

  @override
  String get chooseDates => 'Da … a …';

  @override
  String dateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get productInLists => 'Prodotto nella lista';

  @override
  String get productInListsHint => 'es. latte';

  @override
  String containsProduct(String product) {
    return 'Con «$product»';
  }

  @override
  String get resetFilters => 'Azzera';

  @override
  String get applyFilters => 'Applica';

  @override
  String get noListsMatch => 'Nessuna lista con questi filtri.';

  @override
  String get searchMyPrices => 'Cerca prodotto o supermercato';

  @override
  String get noMyPrices =>
      'Nessun prezzo. Aggiungilo da qui o dal menu ⋮ di un prodotto della lista.';

  @override
  String get noMyPricesFound => 'Nessun prezzo trovato.';

  @override
  String deleteMyPriceQuestion(String product) {
    return 'Eliminare il prezzo di $product?';
  }

  @override
  String get info => 'Info';

  @override
  String get noProductInfo =>
      'Nessuna informazione trovata su Open Food Facts per questo prodotto.';

  @override
  String get similarProductNotice =>
      'Prodotto simile trovato dal nome: potrebbe non essere esattamente il tuo.';

  @override
  String get barcode => 'Codice a barre';

  @override
  String get copy => 'Copia';

  @override
  String get copied => 'Copiato';

  @override
  String get forCoeliacs => 'Celiaci';

  @override
  String get glutenFree => 'senza glutine';

  @override
  String get containsGluten => 'contiene glutine';

  @override
  String get vegetarian => 'Vegetariano';

  @override
  String get vegan => 'Vegano';

  @override
  String get yes => 'sì';

  @override
  String get no => 'no';

  @override
  String get palmOil => 'Olio di palma';

  @override
  String get palmOilFree => 'senza';

  @override
  String get containsPalmOil => 'contiene';

  @override
  String get lactose => 'Lattosio';

  @override
  String get lactoseFree => 'senza lattosio';

  @override
  String get nutritionPer100 => 'Valori nutrizionali per 100 g';

  @override
  String get nutrientFat => 'Grassi';

  @override
  String get nutrientSaturatedFat => 'di cui saturi';

  @override
  String get nutrientCarbohydrates => 'Carboidrati';

  @override
  String get nutrientSugars => 'di cui zuccheri';

  @override
  String get nutrientFiber => 'Fibre';

  @override
  String get nutrientProteins => 'Proteine';

  @override
  String get nutrientSalt => 'Sale';

  @override
  String get noNutritionInfo => 'Non ci sono informazioni nutrizionali';

  @override
  String get waterMinerals => 'Composizione per litro';

  @override
  String get mineralCalcium => 'Calcio';

  @override
  String get mineralMagnesium => 'Magnesio';

  @override
  String get mineralSodium => 'Sodio';

  @override
  String get mineralPotassium => 'Potassio';

  @override
  String get mineralBicarbonate => 'Bicarbonato';

  @override
  String get mineralChloride => 'Cloruri';

  @override
  String get mineralSulphate => 'Solfati';

  @override
  String get mineralNitrate => 'Nitrati';

  @override
  String get mineralFluoride => 'Fluoro';

  @override
  String get mineralSilica => 'Silice';

  @override
  String get allergens => 'Allergeni';

  @override
  String mayContainTraces(String list) {
    return 'Può contenere tracce di: $list';
  }

  @override
  String get ingredients => 'Ingredienti';

  @override
  String get openFoodFactsPage => 'Vedi su Open Food Facts';

  @override
  String get openFoodFactsSource =>
      'Dati da Open Food Facts (licenza ODbL): possono essere incompleti, controlla sempre l\'etichetta.';

  @override
  String get allergenGluten => 'Glutine';

  @override
  String get allergenCrustaceans => 'Crostacei';

  @override
  String get allergenEggs => 'Uova';

  @override
  String get allergenFish => 'Pesce';

  @override
  String get allergenPeanuts => 'Arachidi';

  @override
  String get allergenSoybeans => 'Soia';

  @override
  String get allergenMilk => 'Latte';

  @override
  String get allergenNuts => 'Frutta a guscio';

  @override
  String get allergenCelery => 'Sedano';

  @override
  String get allergenMustard => 'Senape';

  @override
  String get allergenSesame => 'Sesamo';

  @override
  String get allergenSulphites => 'Solfiti';

  @override
  String get allergenLupin => 'Lupini';

  @override
  String get allergenMolluscs => 'Molluschi';

  @override
  String get permission => 'Permesso';

  @override
  String get permissionRead => 'Solo lettura';

  @override
  String get permissionReadWrite => 'Lettura e modifica';
}
