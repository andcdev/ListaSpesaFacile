// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get save => 'Speichern';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get remove => 'Entfernen';

  @override
  String get add => 'Hinzufügen';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get share => 'Teilen';

  @override
  String get email => 'E-Mail';

  @override
  String get password => 'Passwort';

  @override
  String get name => 'Name';

  @override
  String get today => 'Heute';

  @override
  String get tomorrow => 'Morgen';

  @override
  String get yesterday => 'Gestern';

  @override
  String get canEdit => 'Darf bearbeiten';

  @override
  String get userCanEdit => 'darf bearbeiten';

  @override
  String get userReadOnly => 'nur lesen';

  @override
  String get invalidEmail => 'Gib eine gültige E-Mail-Adresse ein';

  @override
  String get enterRegisteredEmail =>
      'Gib die E-Mail-Adresse eines registrierten Nutzers ein';

  @override
  String get atLeast8 => 'Mindestens 8 Zeichen';

  @override
  String get confirmPassword => 'Passwort bestätigen';

  @override
  String get passwordsDontMatch => 'Die Passwörter stimmen nicht überein';

  @override
  String get nobody => 'Niemand.';

  @override
  String get myLists => 'Meine Listen';

  @override
  String get other => 'Sonstiges';

  @override
  String get language => 'Sprache';

  @override
  String languageValue(String language) {
    return 'Sprache: $language';
  }

  @override
  String languageSystem(String language) {
    return 'Wie das Telefon ($language)';
  }

  @override
  String get background => 'Hintergrund';

  @override
  String backgroundValue(String value) {
    return 'Hintergrund: $value';
  }

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeSystem => 'Wie das Telefon';

  @override
  String get errTimeout =>
      'Der Server antwortet nicht. Versuche es später erneut.';

  @override
  String get errNetwork => 'Server nicht erreichbar. Prüfe die Verbindung.';

  @override
  String get errSessionExpired =>
      'Sitzung abgelaufen. Bitte melde dich erneut an.';

  @override
  String get errForbidden => 'Dazu fehlt dir die Berechtigung.';

  @override
  String get errNotFound => 'Nicht gefunden (vielleicht wurde es gelöscht).';

  @override
  String get errTooMany => 'Zu viele Versuche. Warte eine Minute.';

  @override
  String get errServer => 'Serverfehler. Versuche es später erneut.';

  @override
  String errUnexpected(int status) {
    return 'Unerwarteter Fehler ($status).';
  }

  @override
  String get checkYourEmail => 'Sieh in deinen E-Mails nach.';

  @override
  String get enterPassword => 'Gib dein Passwort ein';

  @override
  String get forgotPasswordQuestion => 'Passwort vergessen?';

  @override
  String get signIn => 'Anmelden';

  @override
  String get noAccount => 'Noch kein Konto? Registrieren';

  @override
  String socialNotActiveTitle(String provider) {
    return 'Anmeldung mit $provider noch nicht aktiv';
  }

  @override
  String socialNotActiveBody(String provider) {
    return 'Der Server ist noch nicht mit $provider verbunden. Der Serveradministrator muss die App bei $provider registrieren und ID und Secret in die Datei .env eintragen (siehe README, \"Accesso con Google e Amazon\").\n\nBis dahin kannst du dich mit E-Mail und Passwort registrieren.';
  }

  @override
  String get or => 'oder';

  @override
  String continueWith(String provider) {
    return 'Weiter mit $provider';
  }

  @override
  String socialOpenFailed(String provider) {
    return 'Anmeldung mit $provider kann nicht geöffnet werden.';
  }

  @override
  String get socialFailed => 'Anmeldung fehlgeschlagen.';

  @override
  String get hidePassword => 'Passwort verbergen';

  @override
  String get showPassword => 'Passwort anzeigen';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get enterYourName => 'Gib deinen Namen ein';

  @override
  String get signUp => 'Registrieren';

  @override
  String get forgotPasswordTitle => 'Passwort vergessen';

  @override
  String get resetCodeSentInfo =>
      'Wir haben dir einen 6-stelligen Code geschickt (sieh auch im Spam nach). Gib ihn ein und wähle ein neues Passwort.';

  @override
  String get resetInfo =>
      'Gib die E-Mail-Adresse deines Kontos ein: Wir schicken dir einen Code, um ein neues Passwort zu wählen.';

  @override
  String get resetCodeLabel => 'Per E-Mail erhaltener Code';

  @override
  String get resetCodeInvalid => 'Der Code hat 6 Ziffern';

  @override
  String get newPassword => 'Neues Passwort';

  @override
  String get setNewPassword => 'Neues Passwort festlegen';

  @override
  String get sendCode => 'Code senden';

  @override
  String get resendCode => 'Nicht angekommen? Erneut senden';

  @override
  String deleteListNamed(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get deleteListSharedInfo =>
      'Die Liste verschwindet auch für alle, mit denen sie geteilt ist.';

  @override
  String get profilePhotoTitle => 'Profilbild (im Chat sichtbar)';

  @override
  String get profilePhotoUpdated => 'Profilbild aktualisiert.';

  @override
  String get globalSharing => 'Alle Listen teilen';

  @override
  String get profile => 'Profil';

  @override
  String get logoutQuestion => 'Abmelden?';

  @override
  String get logout => 'Abmelden';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountQuestion => 'Konto löschen?';

  @override
  String get deleteAccountMessage =>
      'Die Löschung ist endgültig und kann nicht rückgängig gemacht werden. Deine Listen mit Artikeln, Fotos und Chats werden auch für die Personen gelöscht, mit denen du sie teilst, und du verlässt die Listen der anderen.';

  @override
  String get deleteAccountConfirm => 'Endgültig löschen';

  @override
  String get accountDeleted => 'Konto gelöscht.';

  @override
  String get addProfilePhoto => 'Profilbild hinzufügen';

  @override
  String get changeProfilePhoto => 'Profilbild ändern';

  @override
  String get newList => 'Neue Liste';

  @override
  String get noUpcoming => 'Kein Einkauf geplant.';

  @override
  String get upcomingTab => 'Geplant';

  @override
  String pastTab(int count) {
    return 'Vergangen · $count';
  }

  @override
  String toBuyCount(int count) {
    return '$count offen';
  }

  @override
  String get listCompleteBadge => 'Erledigt';

  @override
  String get listEmptyBadge => 'Leer';

  @override
  String viewingNowShort(String names) {
    return 'gerade hier: $names';
  }

  @override
  String byOwner(String name) {
    return 'von $name';
  }

  @override
  String get noLists =>
      'Keine Listen.\nErstelle eine mit der Schaltfläche „Neue Liste“.';

  @override
  String get realtimeOn => 'Live-Aktualisierung aktiv';

  @override
  String get realtimeOff => 'Live-Aktualisierung nicht verbunden';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get editList => 'Liste bearbeiten';

  @override
  String get alreadyAdded => 'Bereits hinzugefügt';

  @override
  String get listNameHint => 'z. B. Wocheneinkauf';

  @override
  String get renameLocked => 'Der Eigentümer erlaubt keine Namensänderung';

  @override
  String get listNameRequired => 'Gib der Liste einen Namen';

  @override
  String get notesLabel => 'Notizen (optional)';

  @override
  String get notesHint => 'z. B. Supermarkt, Angebote…';

  @override
  String get reminder => 'Erinnerung';

  @override
  String get noReminder => 'Keine Erinnerung';

  @override
  String durationBefore(String duration) {
    return '$duration vorher';
  }

  @override
  String get customReminderOption => 'Benutzerdefiniert…';

  @override
  String get whoToNotify => 'Wen erinnern';

  @override
  String get reminderOwner => 'Nur der Ersteller';

  @override
  String get reminderMembers => 'Nur die Empfänger';

  @override
  String get reminderAll => 'Ersteller und Empfänger';

  @override
  String get shareWith => 'Teilen mit';

  @override
  String get userEmail => 'E-Mail des Nutzers';

  @override
  String get userEmailOptional => 'E-Mail des Nutzers (optional)';

  @override
  String get willBeNotified =>
      'Erhält eine Benachrichtigung, wenn du die Liste erstellst';

  @override
  String get permissions => 'Berechtigungen';

  @override
  String get membersCanRenameTitle =>
      'Wer bearbeiten darf, darf auch den Namen ändern';

  @override
  String get membersCanRenameOn =>
      'Nutzer mit Bearbeitungsrecht dürfen die Liste umbenennen';

  @override
  String get membersCanRenameOff =>
      'Nur du kannst den Namen ändern; die anderen bearbeiten die Artikel';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get createList => 'Liste erstellen';

  @override
  String get customReminder => 'Benutzerdefinierte Erinnerung';

  @override
  String get howEarly => 'Wie lange vorher';

  @override
  String get unitMinutes => 'Minuten';

  @override
  String get unitHours => 'Stunden';

  @override
  String get unitDays => 'Tage';

  @override
  String get reminderRange => '1 Minute bis 30 Tage';

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String get durationMoments => 'wenigen Augenblicken';

  @override
  String listAnd(String head, String last) {
    return '$head und $last';
  }

  @override
  String listSharedWith(String email) {
    return 'Liste geteilt mit $email';
  }

  @override
  String removeUserQuestion(String name) {
    return '$name entfernen?';
  }

  @override
  String get removeUserInfo => 'Die Person sieht diese Liste nicht mehr.';

  @override
  String get sharedWith => 'Geteilt mit';

  @override
  String get nobodyYet => 'Noch niemand.';

  @override
  String get globalShareHint =>
      'Um alle deine Listen mit jemandem zu teilen, nutze „Alle Listen teilen“ auf dem Hauptbildschirm.';

  @override
  String allListsSharedWith(String email) {
    return 'Alle deine Listen sind jetzt mit $email geteilt';
  }

  @override
  String stopSharingWith(String name) {
    return 'Nicht mehr mit $name teilen?';
  }

  @override
  String stopReceivingFrom(String name) {
    return 'Die Listen von $name nicht mehr sehen?';
  }

  @override
  String get globalShareInfo =>
      'Die hier genannten Personen sehen alle deine Listen, auch die, die du künftig erstellst.';

  @override
  String get iShareWith => 'Ich teile alle meine Listen mit';

  @override
  String get sharedWithMe => 'Teilen alle ihre Listen mit mir';

  @override
  String get stopReceiving => 'Nicht mehr empfangen';

  @override
  String get deleteAllNotificationsQuestion =>
      'Alle Benachrichtigungen löschen?';

  @override
  String get markAllRead => 'Alle als gelesen markieren';

  @override
  String get deleteAll => 'Alle löschen';

  @override
  String get noNotifications => 'Keine Benachrichtigungen.';

  @override
  String get channelName => 'Einkaufslisten';

  @override
  String get channelDescription => 'Erinnerungen, Freigaben und Nachrichten';

  @override
  String get you => 'Du';

  @override
  String get serviceChannelName => 'Verbindung im Hintergrund';

  @override
  String get serviceChannelDescription =>
      'Hält die App verbunden, um Listen und Nachrichten auch geschlossen zu empfangen';

  @override
  String reminderTitle(String name) {
    return 'Erinnerung: $name';
  }

  @override
  String reminderBody(String duration) {
    return 'Der Einkauf ist in $duration.';
  }

  @override
  String get sendPhoto => 'Foto senden';

  @override
  String get deleteMessageQuestion => 'Nachricht löschen?';

  @override
  String get deleteMessageInfo => 'Sie verschwindet für alle.';

  @override
  String get writeMessage => 'Nachricht schreiben';

  @override
  String get send => 'Senden';

  @override
  String get deletedUser => 'Nutzer';

  @override
  String get messageReceived => 'Empfangen';

  @override
  String get messageSent => 'Gesendet';

  @override
  String get emptyChat =>
      'Keine Nachrichten.\nSchreib, diktiere mit dem Mikrofon oder schick ein Foto an alle, die die Liste teilen: „Bin beim Kühlregal, fehlt noch was?“';

  @override
  String get pickFromGallery => 'Aus Galerie wählen';

  @override
  String get takePhoto => 'Foto aufnehmen';

  @override
  String get removePhoto => 'Foto entfernen';

  @override
  String get imageUnavailable => 'Bild nicht verfügbar';

  @override
  String get voiceUnavailable =>
      'Spracherkennung auf diesem Telefon nicht verfügbar: Installiere oder aktiviere die Google-App (Google-Spracherkennung).';

  @override
  String get voiceMicPermission =>
      'Zum Diktieren erlaube der App in den Telefoneinstellungen den Zugriff auf das Mikrofon.';

  @override
  String get voiceNoMatch =>
      'Ich habe nichts gehört: Tippe auf das Mikrofon und sprich sofort.';

  @override
  String get voiceNetwork =>
      'Spracherkennung nicht erreichbar: Prüfe die Verbindung.';

  @override
  String get voiceBusy =>
      'Das Mikrofon ist belegt, versuche es gleich noch einmal.';

  @override
  String voiceLanguageUnavailable(String language) {
    return '$language ist zum Diktieren nicht verfügbar: Lade es in den Einstellungen der Google-Spracheingabe herunter.';
  }

  @override
  String get voiceNotUnderstood => 'Nicht verstanden, versuche es noch einmal.';

  @override
  String get stopListening => 'Zuhören beenden';

  @override
  String get dictate => 'Diktieren';

  @override
  String get exportNotFound => 'nicht gefunden';

  @override
  String exportTaken(int taken, int total) {
    return '$taken von $total im Wagen';
  }

  @override
  String pdfPage(int page, int total) {
    return 'Seite $page von $total';
  }

  @override
  String pdfSummary(int taken, int missing, int todo) {
    return 'Im Wagen: $taken · Nicht gefunden: $missing · Noch zu kaufen: $todo';
  }

  @override
  String get numericDatePattern => 'dd.MM.y';

  @override
  String get listUnavailable => 'Die Liste ist nicht mehr verfügbar.';

  @override
  String get deleteListQuestion => 'Liste löschen?';

  @override
  String get deleteListInfo =>
      'Sie wird auch für alle gelöscht, die sie teilen.';

  @override
  String get leaveListQuestion => 'Liste verlassen?';

  @override
  String get leaveListInfo =>
      'Du siehst sie erst wieder, wenn sie erneut mit dir geteilt wird.';

  @override
  String get leave => 'Verlassen';

  @override
  String get listPhotoUpdated => 'Listenfoto aktualisiert.';

  @override
  String photoOf(String name) {
    return 'Foto von $name';
  }

  @override
  String deleteItemQuestion(String name) {
    return '„$name“ aus der Liste löschen?';
  }

  @override
  String get deleteItemInfo =>
      'Er verschwindet für alle aus der Liste. Wenn du ihn nur in den Wagen gelegt hast, hake ihn ab.';

  @override
  String get putBackToBuy => 'Wieder auf die Liste';

  @override
  String get takenInCart => 'Im Wagen';

  @override
  String get notFound => 'Nicht gefunden';

  @override
  String get addPhoto => 'Foto hinzufügen';

  @override
  String get changePhoto => 'Foto ändern';

  @override
  String get deleteFromList => 'Aus der Liste löschen';

  @override
  String get deleteFromListInfo =>
      'Nicht dasselbe wie „im Wagen“: Der Artikel verschwindet für alle';

  @override
  String get sendOrExportList => 'Liste senden oder exportieren';

  @override
  String get exportTextInfo => 'Text mit Häkchen, du wählst den Chat';

  @override
  String get exportPdfInfo =>
      'Zum Drucken oder Senden (auch per WhatsApp oder Telegram)';

  @override
  String get otherApps => 'Andere Apps';

  @override
  String appNotInstalled(String app) {
    return '$app ist auf diesem Telefon nicht installiert.';
  }

  @override
  String get list => 'Liste';

  @override
  String get closeChat => 'Chat schließen';

  @override
  String get chat => 'Chat';

  @override
  String get sendOrExport => 'Senden oder exportieren';

  @override
  String get clearTaken => 'Abgehakte Artikel entfernen';

  @override
  String get deleteList => 'Liste löschen';

  @override
  String get leaveList => 'Liste verlassen';

  @override
  String get cannotLoadList => 'Liste kann nicht geladen werden.';

  @override
  String reminderBefore(String duration) {
    return 'Erinnerung $duration vorher';
  }

  @override
  String get readOnlyAccess => 'Du hast nur Lesezugriff';

  @override
  String get emptyList =>
      'Die Liste ist leer.\nFüge unten den ersten Artikel hinzu.';

  @override
  String inCart(int checked, int total) {
    return '$checked von $total im Wagen';
  }

  @override
  String notFoundCount(int count) {
    return '$count nicht gefunden';
  }

  @override
  String takenBy(String name) {
    return 'von $name abgehakt';
  }

  @override
  String get notFoundLower => 'nicht gefunden';

  @override
  String notFoundBy(String name) {
    return 'nicht gefunden ($name)';
  }

  @override
  String get markToBuyAgain => 'Wieder als offen markieren';

  @override
  String get markMissing => 'Nicht genommen (nicht gefunden)';

  @override
  String get itemMenu => 'Bearbeiten, Foto oder löschen';

  @override
  String get onlyYouViewing => 'Nur du siehst dir diese Liste gerade an';

  @override
  String viewingNow(String names) {
    return 'Gerade hier: $names';
  }

  @override
  String typing(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names schreiben…',
      one: '$names schreibt…',
    );
    return '$_temp0';
  }

  @override
  String get listPhoto => 'Foto der Liste';

  @override
  String get listPhotoUploadFailed =>
      'Liste erstellt, aber das Foto wurde nicht hochgeladen: Füge es über das Listenmenü hinzu.';

  @override
  String get productPhoto => 'Produktfoto';

  @override
  String get oftenBought => 'Kaufst du oft:';

  @override
  String timesInList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Schon $count-mal auf der Liste',
      one: 'Schon 1-mal auf der Liste',
    );
    return '$_temp0';
  }

  @override
  String get addProductHint => 'Produkt hinzuf....';

  @override
  String get amountExampleError => 'Gib eine Zahl ein, z. B. 500 oder 1,5';

  @override
  String get quantity => 'Menge';

  @override
  String get less => 'Weniger';

  @override
  String get more => 'Mehr';

  @override
  String get weightOrVolume => 'Gewicht oder Volumen';

  @override
  String get weight => 'Gewicht';

  @override
  String get packages => 'Packungen';

  @override
  String packageSize(String size) {
    return 'Packung mit $size';
  }

  @override
  String get amountHint => 'z. B. 500';

  @override
  String get clearMeasure => 'Entfernen';

  @override
  String get done => 'Fertig';

  @override
  String get invalidImageUrl => 'Gib einen Link ein, der mit https:// beginnt';

  @override
  String get invalidNumber => 'Ungültige Zahl';

  @override
  String get emojiTooLong => 'Höchstens ein oder zwei Emojis';

  @override
  String get addProductPhoto => 'Produktfoto hinzufügen';

  @override
  String get changeOrRemovePhoto => 'Foto ändern oder entfernen';

  @override
  String get editItem => 'Artikel bearbeiten';

  @override
  String get product => 'Produkt';

  @override
  String get quantityOptional => 'Menge (optional)';

  @override
  String get weightOptional => 'Gewicht oder Volumen (optional)';

  @override
  String get packagesOptional => 'Packungen (optional)';

  @override
  String get weightOnlyOptional => 'Gewicht (optional)';

  @override
  String get department => 'Abteilung';

  @override
  String get departmentHelper =>
      'Am Namen erkannt: Ändere sie, falls sie nicht stimmt';

  @override
  String get emojiOptional => 'Emoji (optional)';

  @override
  String recognizedEmoji(String emoji) {
    return 'Erkannt: $emoji';
  }

  @override
  String get fromName => 'am Namen';

  @override
  String get useRecognizedEmoji => 'Die am Namen erkannte verwenden';

  @override
  String get imageLinkOptional => 'Link zu einem Bild (optional)';

  @override
  String get supermarketLabel => 'Supermarkt (optional)';

  @override
  String get supermarketHint => 'z. B. Esselunga, Coop, Lidl';

  @override
  String get supermarketHelper => 'Wo du einkaufst (optional)';

  @override
  String get close => 'Schließen';

  @override
  String get perPiece => 'pro Packung';

  @override
  String get perKg => 'pro kg';

  @override
  String get perLitre => 'pro Liter';

  @override
  String get priceLabel => 'Preis';

  @override
  String get invalidPrice => 'Gib einen Preis ein, z. B. 1,29';

  @override
  String get privacyRequired =>
      'Du musst die Datenschutzerklärung akzeptieren, um dich zu registrieren';

  @override
  String get acceptPrivacyPrefix => 'Ich habe die ';

  @override
  String get acceptPrivacySuffix => ' gelesen und akzeptiere sie';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get termsRequired =>
      'Du musst die Nutzungsbedingungen akzeptieren, um dich zu registrieren';

  @override
  String get acceptTermsPrefix => 'Ich akzeptiere die ';

  @override
  String get termsOfUse => 'Nutzungsbedingungen';

  @override
  String get acceptTermsSuffix =>
      ': Für die Inhalte, die ich hinzufüge, bin ich selbst verantwortlich';

  @override
  String get newsletterConsent =>
      'Ich möchte den Newsletter von Lista Spesa Facile erhalten';

  @override
  String get newsletterOptional => 'Optional';

  @override
  String get socialPrivacyNotice =>
      'Wenn du mit Google oder Amazon fortfährst, akzeptierst du die ';

  @override
  String get socialTermsJoin => ' und die ';

  @override
  String get myPrices => 'Meine Preise';

  @override
  String get myPrice => 'Mein Preis';

  @override
  String get addMyPrice => 'Preis hinzufügen';

  @override
  String get editMyPrice => 'Preis bearbeiten';

  @override
  String get productRequired => 'Gib das Produkt ein';

  @override
  String get noteOptional => 'Notiz (optional)';

  @override
  String get myPricesPrivate => 'Nur du siehst deine Preise.';

  @override
  String get myPriceSaved => 'Preis in „Meine Preise“ gespeichert';

  @override
  String get guide => 'Anleitung';

  @override
  String guideStep(int step, int count) {
    return 'Schritt $step von $count';
  }

  @override
  String get guideNext => 'Weiter';

  @override
  String get guideGotIt => 'Verstanden';

  @override
  String get skipGuide => 'Anleitung überspringen';

  @override
  String get guideNewListTitle => 'Erstelle deine erste Liste';

  @override
  String get guideNewListText =>
      'Tippe auf „Neue Liste“: Wähle Namen, Tag und Uhrzeit des Einkaufs und, wenn du willst, ein Foto und mit wem du sie teilst. Dann öffnet sich die Liste, bereit für die Produkte.';

  @override
  String get guideAddTitle => 'Schreib ein Produkt';

  @override
  String get guideAddText =>
      'Schreib hier oder diktiere mit dem Mikrofon. Beim Schreiben erscheinen Vorschläge: was du am häufigsten kaufst und Markenprodukte mit Foto. Tippe auf einen, um ihn zu wählen.';

  @override
  String get guidePlusTitle => 'Zur Liste hinzufügen';

  @override
  String get guidePlusText =>
      'Tippe auf + (oder einen Vorschlag): Wähle je nach Produkt Menge, Gewicht oder Volumen und drücke „Fertig“. Das Produkt landet in seiner Abteilung, und alle, die die Liste teilen, sehen es sofort.';

  @override
  String get guideShareTitle => 'Gemeinsam einkaufen';

  @override
  String get guideShareText =>
      'Lade hier ein, wer mit dir einkauft: Ihr seht dieselbe Liste in Echtzeit. Im Supermarkt tippst du auf den Kreis neben einem Produkt, um es als genommen zu markieren.';

  @override
  String get filterLists => 'Listen filtern';

  @override
  String get sortOrder => 'Reihenfolge';

  @override
  String get dateAscending => 'Datum aufsteigend';

  @override
  String get dateDescending => 'Datum absteigend';

  @override
  String get filterPerson => 'Geteilt mit';

  @override
  String get everyone => 'Alle';

  @override
  String get filterPeriod => 'Datum des Einkaufs';

  @override
  String get allDates => 'Alle';

  @override
  String get last15Days => 'Letzte 15 Tage';

  @override
  String get last30Days => 'Letzte 30 Tage';

  @override
  String get next15Days => 'Nächste 15 Tage';

  @override
  String get next30Days => 'Nächste 30 Tage';

  @override
  String get chooseDates => 'Von … bis …';

  @override
  String dateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get productInLists => 'Produkt in der Liste';

  @override
  String get productInListsHint => 'z. B. Milch';

  @override
  String containsProduct(String product) {
    return 'Mit „$product“';
  }

  @override
  String get resetFilters => 'Zurücksetzen';

  @override
  String get applyFilters => 'Anwenden';

  @override
  String get noListsMatch => 'Keine Liste passt zu diesen Filtern.';

  @override
  String get searchMyPrices => 'Produkt oder Supermarkt suchen';

  @override
  String get noMyPrices =>
      'Noch keine Preise. Füge hier einen hinzu oder über das ⋮-Menü eines Produkts.';

  @override
  String get noMyPricesFound => 'Keine Preise gefunden.';

  @override
  String deleteMyPriceQuestion(String product) {
    return 'Preis von $product löschen?';
  }

  @override
  String get info => 'Info';

  @override
  String get noProductInfo => 'Keine Informationen zu diesem Produkt gefunden.';

  @override
  String get sources => 'Quellen';

  @override
  String sourceProductData(String licence) {
    return 'Produktdaten · Lizenz $licence';
  }

  @override
  String sourcePhotos(String licence) {
    return 'Fotos · Lizenz $licence';
  }

  @override
  String sourceAverageValues(String licence) {
    return 'Durchschnittliche Nährwerte · Lizenz $licence';
  }

  @override
  String get dataMayBeIncomplete =>
      'Die Daten können unvollständig sein: Prüfe immer das Etikett.';

  @override
  String get genericValuesNotice =>
      'Durchschnittswerte pro 100 g für dieses Lebensmittel aus der offiziellen CIQUAL-Nährwerttabelle.';

  @override
  String get similarProductNotice =>
      'Ähnliches Produkt anhand des Namens gefunden: Es ist vielleicht nicht genau deins.';

  @override
  String get barcode => 'Barcode';

  @override
  String get copy => 'Kopieren';

  @override
  String get copied => 'Kopiert';

  @override
  String get forCoeliacs => 'Zöliakie';

  @override
  String get glutenFree => 'glutenfrei';

  @override
  String get containsGluten => 'enthält Gluten';

  @override
  String get vegetarian => 'Vegetarisch';

  @override
  String get vegan => 'Vegan';

  @override
  String get yes => 'ja';

  @override
  String get no => 'nein';

  @override
  String get palmOil => 'Palmöl';

  @override
  String get palmOilFree => 'ohne';

  @override
  String get containsPalmOil => 'enthalten';

  @override
  String get lactose => 'Laktose';

  @override
  String get lactoseFree => 'laktosefrei';

  @override
  String get nutritionPer100 => 'Nährwerte pro 100 g';

  @override
  String get nutrientFat => 'Fett';

  @override
  String get nutrientSaturatedFat => 'davon gesättigte Fettsäuren';

  @override
  String get nutrientCarbohydrates => 'Kohlenhydrate';

  @override
  String get nutrientSugars => 'davon Zucker';

  @override
  String get nutrientFiber => 'Ballaststoffe';

  @override
  String get nutrientProteins => 'Eiweiß';

  @override
  String get nutrientSalt => 'Salz';

  @override
  String get noNutritionInfo => 'Es gibt keine Nährwertangaben';

  @override
  String get waterMinerals => 'Zusammensetzung pro Liter';

  @override
  String get mineralCalcium => 'Calcium';

  @override
  String get mineralMagnesium => 'Magnesium';

  @override
  String get mineralSodium => 'Natrium';

  @override
  String get mineralPotassium => 'Kalium';

  @override
  String get mineralBicarbonate => 'Hydrogencarbonat';

  @override
  String get mineralChloride => 'Chlorid';

  @override
  String get mineralSulphate => 'Sulfat';

  @override
  String get mineralNitrate => 'Nitrat';

  @override
  String get mineralFluoride => 'Fluorid';

  @override
  String get mineralSilica => 'Kieselsäure';

  @override
  String get allergens => 'Allergene';

  @override
  String mayContainTraces(String list) {
    return 'Kann Spuren enthalten von: $list';
  }

  @override
  String get ingredients => 'Zutaten';

  @override
  String get allergenGluten => 'Gluten';

  @override
  String get allergenCrustaceans => 'Krebstiere';

  @override
  String get allergenEggs => 'Eier';

  @override
  String get allergenFish => 'Fisch';

  @override
  String get allergenPeanuts => 'Erdnüsse';

  @override
  String get allergenSoybeans => 'Soja';

  @override
  String get allergenMilk => 'Milch';

  @override
  String get allergenNuts => 'Schalenfrüchte';

  @override
  String get allergenCelery => 'Sellerie';

  @override
  String get allergenMustard => 'Senf';

  @override
  String get allergenSesame => 'Sesam';

  @override
  String get allergenSulphites => 'Sulfite';

  @override
  String get allergenLupin => 'Lupinen';

  @override
  String get allergenMolluscs => 'Weichtiere';

  @override
  String get permission => 'Berechtigung';

  @override
  String get permissionRead => 'Nur lesen';

  @override
  String get permissionReadWrite => 'Lesen und bearbeiten';
}
