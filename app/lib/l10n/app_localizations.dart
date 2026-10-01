import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
  ];

  /// No description provided for @cancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get save;

  /// No description provided for @ok.
  ///
  /// In it, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @retry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get retry;

  /// No description provided for @remove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get remove;

  /// No description provided for @add.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get add;

  /// No description provided for @confirm.
  ///
  /// In it, this message translates to:
  /// **'Conferma'**
  String get confirm;

  /// No description provided for @edit.
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In it, this message translates to:
  /// **'Condividi'**
  String get share;

  /// No description provided for @email.
  ///
  /// In it, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In it, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @name.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get name;

  /// No description provided for @today.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In it, this message translates to:
  /// **'Domani'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In it, this message translates to:
  /// **'Ieri'**
  String get yesterday;

  /// No description provided for @canEdit.
  ///
  /// In it, this message translates to:
  /// **'Può modificare'**
  String get canEdit;

  /// No description provided for @userCanEdit.
  ///
  /// In it, this message translates to:
  /// **'può modificare'**
  String get userCanEdit;

  /// No description provided for @userReadOnly.
  ///
  /// In it, this message translates to:
  /// **'sola lettura'**
  String get userReadOnly;

  /// No description provided for @invalidEmail.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un\'email valida'**
  String get invalidEmail;

  /// No description provided for @enterRegisteredEmail.
  ///
  /// In it, this message translates to:
  /// **'Inserisci l\'email di un utente registrato'**
  String get enterRegisteredEmail;

  /// No description provided for @atLeast8.
  ///
  /// In it, this message translates to:
  /// **'Almeno 8 caratteri'**
  String get atLeast8;

  /// No description provided for @confirmPassword.
  ///
  /// In it, this message translates to:
  /// **'Conferma password'**
  String get confirmPassword;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In it, this message translates to:
  /// **'Le password non coincidono'**
  String get passwordsDontMatch;

  /// No description provided for @nobody.
  ///
  /// In it, this message translates to:
  /// **'Nessuno.'**
  String get nobody;

  /// No description provided for @myLists.
  ///
  /// In it, this message translates to:
  /// **'Le mie liste'**
  String get myLists;

  /// No description provided for @other.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get other;

  /// No description provided for @language.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get language;

  /// No description provided for @languageValue.
  ///
  /// In it, this message translates to:
  /// **'Lingua: {language}'**
  String languageValue(String language);

  /// No description provided for @languageSystem.
  ///
  /// In it, this message translates to:
  /// **'Come il telefono ({language})'**
  String languageSystem(String language);

  /// No description provided for @background.
  ///
  /// In it, this message translates to:
  /// **'Sfondo'**
  String get background;

  /// No description provided for @backgroundValue.
  ///
  /// In it, this message translates to:
  /// **'Sfondo: {value}'**
  String backgroundValue(String value);

  /// No description provided for @themeLight.
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In it, this message translates to:
  /// **'Scuro'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In it, this message translates to:
  /// **'Come il telefono'**
  String get themeSystem;

  /// No description provided for @errTimeout.
  ///
  /// In it, this message translates to:
  /// **'Il server non risponde. Riprova più tardi.'**
  String get errTimeout;

  /// No description provided for @errNetwork.
  ///
  /// In it, this message translates to:
  /// **'Impossibile contattare il server. Controlla la connessione.'**
  String get errNetwork;

  /// No description provided for @errSessionExpired.
  ///
  /// In it, this message translates to:
  /// **'Sessione scaduta. Accedi di nuovo.'**
  String get errSessionExpired;

  /// No description provided for @errForbidden.
  ///
  /// In it, this message translates to:
  /// **'Non hai i permessi per questa operazione.'**
  String get errForbidden;

  /// No description provided for @errNotFound.
  ///
  /// In it, this message translates to:
  /// **'Elemento non trovato (forse è stato eliminato).'**
  String get errNotFound;

  /// No description provided for @errTooMany.
  ///
  /// In it, this message translates to:
  /// **'Troppi tentativi. Attendi un minuto.'**
  String get errTooMany;

  /// No description provided for @errServer.
  ///
  /// In it, this message translates to:
  /// **'Errore del server. Riprova più tardi.'**
  String get errServer;

  /// No description provided for @errUnexpected.
  ///
  /// In it, this message translates to:
  /// **'Errore imprevisto ({status}).'**
  String errUnexpected(int status);

  /// No description provided for @checkYourEmail.
  ///
  /// In it, this message translates to:
  /// **'Controlla la tua email.'**
  String get checkYourEmail;

  /// No description provided for @enterPassword.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la password'**
  String get enterPassword;

  /// No description provided for @forgotPasswordQuestion.
  ///
  /// In it, this message translates to:
  /// **'Password dimenticata?'**
  String get forgotPasswordQuestion;

  /// No description provided for @signIn.
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get signIn;

  /// No description provided for @noAccount.
  ///
  /// In it, this message translates to:
  /// **'Non hai un account? Registrati'**
  String get noAccount;

  /// No description provided for @server.
  ///
  /// In it, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @serverAddress.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo del server'**
  String get serverAddress;

  /// No description provided for @socialNotActiveTitle.
  ///
  /// In it, this message translates to:
  /// **'Accesso con {provider} non ancora attivo'**
  String socialNotActiveTitle(String provider);

  /// No description provided for @socialNotActiveBody.
  ///
  /// In it, this message translates to:
  /// **'Il server non è ancora collegato a {provider}. Chi gestisce il server deve registrare l\'app presso {provider} e inserire ID e secret nel file .env (vedi il README, \"Accesso con Google e Amazon\").\n\nNel frattempo puoi registrarti con email e password.'**
  String socialNotActiveBody(String provider);

  /// No description provided for @or.
  ///
  /// In it, this message translates to:
  /// **'oppure'**
  String get or;

  /// No description provided for @continueWith.
  ///
  /// In it, this message translates to:
  /// **'Continua con {provider}'**
  String continueWith(String provider);

  /// No description provided for @socialOpenFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile aprire l\'accesso con {provider}.'**
  String socialOpenFailed(String provider);

  /// No description provided for @socialFailed.
  ///
  /// In it, this message translates to:
  /// **'Accesso non riuscito.'**
  String get socialFailed;

  /// No description provided for @hidePassword.
  ///
  /// In it, this message translates to:
  /// **'Nascondi la password'**
  String get hidePassword;

  /// No description provided for @showPassword.
  ///
  /// In it, this message translates to:
  /// **'Mostra la password'**
  String get showPassword;

  /// No description provided for @createAccount.
  ///
  /// In it, this message translates to:
  /// **'Crea un account'**
  String get createAccount;

  /// No description provided for @enterYourName.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il tuo nome'**
  String get enterYourName;

  /// No description provided for @signUp.
  ///
  /// In it, this message translates to:
  /// **'Registrati'**
  String get signUp;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In it, this message translates to:
  /// **'Password dimenticata'**
  String get forgotPasswordTitle;

  /// No description provided for @resetCodeSentInfo.
  ///
  /// In it, this message translates to:
  /// **'Ti abbiamo inviato un codice di 6 cifre (controlla anche lo spam). Inseriscilo e scegli la nuova password.'**
  String get resetCodeSentInfo;

  /// No description provided for @resetInfo.
  ///
  /// In it, this message translates to:
  /// **'Inserisci l\'email del tuo account: ti invieremo un codice per scegliere una nuova password.'**
  String get resetInfo;

  /// No description provided for @resetCodeLabel.
  ///
  /// In it, this message translates to:
  /// **'Codice ricevuto via email'**
  String get resetCodeLabel;

  /// No description provided for @resetCodeInvalid.
  ///
  /// In it, this message translates to:
  /// **'Il codice ha 6 cifre'**
  String get resetCodeInvalid;

  /// No description provided for @newPassword.
  ///
  /// In it, this message translates to:
  /// **'Nuova password'**
  String get newPassword;

  /// No description provided for @setNewPassword.
  ///
  /// In it, this message translates to:
  /// **'Imposta la nuova password'**
  String get setNewPassword;

  /// No description provided for @sendCode.
  ///
  /// In it, this message translates to:
  /// **'Invia il codice'**
  String get sendCode;

  /// No description provided for @resendCode.
  ///
  /// In it, this message translates to:
  /// **'Non è arrivato? Invia di nuovo'**
  String get resendCode;

  /// No description provided for @deleteListNamed.
  ///
  /// In it, this message translates to:
  /// **'Eliminare \"{name}\"?'**
  String deleteListNamed(String name);

  /// No description provided for @deleteListSharedInfo.
  ///
  /// In it, this message translates to:
  /// **'La lista sparirà anche per gli utenti con cui è condivisa.'**
  String get deleteListSharedInfo;

  /// No description provided for @profilePhotoTitle.
  ///
  /// In it, this message translates to:
  /// **'Foto profilo (visibile nella chat)'**
  String get profilePhotoTitle;

  /// No description provided for @profilePhotoUpdated.
  ///
  /// In it, this message translates to:
  /// **'Foto profilo aggiornata.'**
  String get profilePhotoUpdated;

  /// No description provided for @globalSharing.
  ///
  /// In it, this message translates to:
  /// **'Condivisione globale'**
  String get globalSharing;

  /// No description provided for @profile.
  ///
  /// In it, this message translates to:
  /// **'Profilo'**
  String get profile;

  /// No description provided for @logoutQuestion.
  ///
  /// In it, this message translates to:
  /// **'Vuoi uscire?'**
  String get logoutQuestion;

  /// No description provided for @logout.
  ///
  /// In it, this message translates to:
  /// **'Esci'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In it, this message translates to:
  /// **'Elimina account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In it, this message translates to:
  /// **'Eliminare l\'account?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In it, this message translates to:
  /// **'L\'eliminazione è definitiva e non si può annullare. Le tue liste, con articoli, foto e chat, vengono cancellate anche per chi le condivide con te, e sparisci dalle liste degli altri.'**
  String get deleteAccountMessage;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In it, this message translates to:
  /// **'Elimina definitivamente'**
  String get deleteAccountConfirm;

  /// No description provided for @accountDeleted.
  ///
  /// In it, this message translates to:
  /// **'Account eliminato.'**
  String get accountDeleted;

  /// No description provided for @addProfilePhoto.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi foto profilo'**
  String get addProfilePhoto;

  /// No description provided for @changeProfilePhoto.
  ///
  /// In it, this message translates to:
  /// **'Cambia foto profilo'**
  String get changeProfilePhoto;

  /// No description provided for @newList.
  ///
  /// In it, this message translates to:
  /// **'Nuova lista'**
  String get newList;

  /// No description provided for @noUpcoming.
  ///
  /// In it, this message translates to:
  /// **'Nessuna spesa in programma.'**
  String get noUpcoming;

  /// No description provided for @upcomingTab.
  ///
  /// In it, this message translates to:
  /// **'In programma'**
  String get upcomingTab;

  /// No description provided for @pastTab.
  ///
  /// In it, this message translates to:
  /// **'Passate · {count}'**
  String pastTab(int count);

  /// No description provided for @toBuyCount.
  ///
  /// In it, this message translates to:
  /// **'{count} da prendere'**
  String toBuyCount(int count);

  /// No description provided for @listCompleteBadge.
  ///
  /// In it, this message translates to:
  /// **'Completa'**
  String get listCompleteBadge;

  /// No description provided for @listEmptyBadge.
  ///
  /// In it, this message translates to:
  /// **'Vuota'**
  String get listEmptyBadge;

  /// No description provided for @viewingNowShort.
  ///
  /// In it, this message translates to:
  /// **'qui ora: {names}'**
  String viewingNowShort(String names);

  /// No description provided for @byOwner.
  ///
  /// In it, this message translates to:
  /// **'di {name}'**
  String byOwner(String name);

  /// No description provided for @noLists.
  ///
  /// In it, this message translates to:
  /// **'Nessuna lista.\nCreane una con il pulsante \"Nuova lista\".'**
  String get noLists;

  /// No description provided for @realtimeOn.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamenti in tempo reale attivi'**
  String get realtimeOn;

  /// No description provided for @realtimeOff.
  ///
  /// In it, this message translates to:
  /// **'Tempo reale non connesso'**
  String get realtimeOff;

  /// No description provided for @notifications.
  ///
  /// In it, this message translates to:
  /// **'Notifiche'**
  String get notifications;

  /// No description provided for @editList.
  ///
  /// In it, this message translates to:
  /// **'Modifica lista'**
  String get editList;

  /// No description provided for @alreadyAdded.
  ///
  /// In it, this message translates to:
  /// **'Già aggiunto'**
  String get alreadyAdded;

  /// No description provided for @listNameHint.
  ///
  /// In it, this message translates to:
  /// **'es. Spesa settimanale'**
  String get listNameHint;

  /// No description provided for @renameLocked.
  ///
  /// In it, this message translates to:
  /// **'Il proprietario non consente di cambiare il nome'**
  String get renameLocked;

  /// No description provided for @listNameRequired.
  ///
  /// In it, this message translates to:
  /// **'Dai un nome alla lista'**
  String get listNameRequired;

  /// No description provided for @notesLabel.
  ///
  /// In it, this message translates to:
  /// **'Note (facoltative)'**
  String get notesLabel;

  /// No description provided for @notesHint.
  ///
  /// In it, this message translates to:
  /// **'es. supermercato, promozioni…'**
  String get notesHint;

  /// No description provided for @reminder.
  ///
  /// In it, this message translates to:
  /// **'Promemoria'**
  String get reminder;

  /// No description provided for @noReminder.
  ///
  /// In it, this message translates to:
  /// **'Nessun promemoria'**
  String get noReminder;

  /// No description provided for @durationBefore.
  ///
  /// In it, this message translates to:
  /// **'{duration} prima'**
  String durationBefore(String duration);

  /// No description provided for @customReminderOption.
  ///
  /// In it, this message translates to:
  /// **'Personalizzato…'**
  String get customReminderOption;

  /// No description provided for @whoToNotify.
  ///
  /// In it, this message translates to:
  /// **'Chi avvisare'**
  String get whoToNotify;

  /// No description provided for @reminderOwner.
  ///
  /// In it, this message translates to:
  /// **'Solo il creatore'**
  String get reminderOwner;

  /// No description provided for @reminderMembers.
  ///
  /// In it, this message translates to:
  /// **'Solo i destinatari'**
  String get reminderMembers;

  /// No description provided for @reminderAll.
  ///
  /// In it, this message translates to:
  /// **'Creatore e destinatari'**
  String get reminderAll;

  /// No description provided for @shareWith.
  ///
  /// In it, this message translates to:
  /// **'Condividi con'**
  String get shareWith;

  /// No description provided for @userEmail.
  ///
  /// In it, this message translates to:
  /// **'Email dell\'utente'**
  String get userEmail;

  /// No description provided for @userEmailOptional.
  ///
  /// In it, this message translates to:
  /// **'Email dell\'utente (facoltativo)'**
  String get userEmailOptional;

  /// No description provided for @willBeNotified.
  ///
  /// In it, this message translates to:
  /// **'Riceverà una notifica quando crei la lista'**
  String get willBeNotified;

  /// No description provided for @permissions.
  ///
  /// In it, this message translates to:
  /// **'Permessi'**
  String get permissions;

  /// No description provided for @membersCanRenameTitle.
  ///
  /// In it, this message translates to:
  /// **'Chi può modificare può cambiare anche il nome'**
  String get membersCanRenameTitle;

  /// No description provided for @membersCanRenameOn.
  ///
  /// In it, this message translates to:
  /// **'Gli utenti con permesso di modifica possono rinominare la lista'**
  String get membersCanRenameOn;

  /// No description provided for @membersCanRenameOff.
  ///
  /// In it, this message translates to:
  /// **'Solo tu puoi cambiare il nome; gli altri modificano gli articoli'**
  String get membersCanRenameOff;

  /// No description provided for @saveChanges.
  ///
  /// In it, this message translates to:
  /// **'Salva modifiche'**
  String get saveChanges;

  /// No description provided for @createList.
  ///
  /// In it, this message translates to:
  /// **'Crea lista'**
  String get createList;

  /// No description provided for @customReminder.
  ///
  /// In it, this message translates to:
  /// **'Promemoria personalizzato'**
  String get customReminder;

  /// No description provided for @howEarly.
  ///
  /// In it, this message translates to:
  /// **'Quanto prima'**
  String get howEarly;

  /// No description provided for @unitMinutes.
  ///
  /// In it, this message translates to:
  /// **'minuti'**
  String get unitMinutes;

  /// No description provided for @unitHours.
  ///
  /// In it, this message translates to:
  /// **'ore'**
  String get unitHours;

  /// No description provided for @unitDays.
  ///
  /// In it, this message translates to:
  /// **'giorni'**
  String get unitDays;

  /// No description provided for @reminderRange.
  ///
  /// In it, this message translates to:
  /// **'Da 1 minuto a 30 giorni'**
  String get reminderRange;

  /// No description provided for @durationDays.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 giorno} other{{count} giorni}}'**
  String durationDays(int count);

  /// No description provided for @durationHours.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 ora} other{{count} ore}}'**
  String durationHours(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 minuto} other{{count} minuti}}'**
  String durationMinutes(int count);

  /// No description provided for @durationMoments.
  ///
  /// In it, this message translates to:
  /// **'pochi istanti'**
  String get durationMoments;

  /// No description provided for @listAnd.
  ///
  /// In it, this message translates to:
  /// **'{head} e {last}'**
  String listAnd(String head, String last);

  /// No description provided for @listSharedWith.
  ///
  /// In it, this message translates to:
  /// **'Lista condivisa con {email}'**
  String listSharedWith(String email);

  /// No description provided for @removeUserQuestion.
  ///
  /// In it, this message translates to:
  /// **'Rimuovere {name}?'**
  String removeUserQuestion(String name);

  /// No description provided for @removeUserInfo.
  ///
  /// In it, this message translates to:
  /// **'Non vedrà più questa lista.'**
  String get removeUserInfo;

  /// No description provided for @sharedWith.
  ///
  /// In it, this message translates to:
  /// **'Condivisa con'**
  String get sharedWith;

  /// No description provided for @nobodyYet.
  ///
  /// In it, this message translates to:
  /// **'Nessuno, per ora.'**
  String get nobodyYet;

  /// No description provided for @globalShareHint.
  ///
  /// In it, this message translates to:
  /// **'Per condividere tutte le tue liste con qualcuno, usa la \"Condivisione globale\" dalla schermata principale.'**
  String get globalShareHint;

  /// No description provided for @allListsSharedWith.
  ///
  /// In it, this message translates to:
  /// **'Tutte le tue liste sono ora condivise con {email}'**
  String allListsSharedWith(String email);

  /// No description provided for @stopSharingWith.
  ///
  /// In it, this message translates to:
  /// **'Smettere di condividere con {name}?'**
  String stopSharingWith(String name);

  /// No description provided for @stopReceivingFrom.
  ///
  /// In it, this message translates to:
  /// **'Non vedere più le liste di {name}?'**
  String stopReceivingFrom(String name);

  /// No description provided for @globalShareInfo.
  ///
  /// In it, this message translates to:
  /// **'Le persone indicate qui vedono tutte le tue liste, comprese quelle che creerai in futuro.'**
  String get globalShareInfo;

  /// No description provided for @iShareWith.
  ///
  /// In it, this message translates to:
  /// **'Condivido tutte le mie liste con'**
  String get iShareWith;

  /// No description provided for @sharedWithMe.
  ///
  /// In it, this message translates to:
  /// **'Condividono tutte le loro liste con me'**
  String get sharedWithMe;

  /// No description provided for @stopReceiving.
  ///
  /// In it, this message translates to:
  /// **'Non ricevere più'**
  String get stopReceiving;

  /// No description provided for @deleteAllNotificationsQuestion.
  ///
  /// In it, this message translates to:
  /// **'Eliminare tutte le notifiche?'**
  String get deleteAllNotificationsQuestion;

  /// No description provided for @markAllRead.
  ///
  /// In it, this message translates to:
  /// **'Segna tutte lette'**
  String get markAllRead;

  /// No description provided for @deleteAll.
  ///
  /// In it, this message translates to:
  /// **'Elimina tutte'**
  String get deleteAll;

  /// No description provided for @noNotifications.
  ///
  /// In it, this message translates to:
  /// **'Nessuna notifica.'**
  String get noNotifications;

  /// No description provided for @channelName.
  ///
  /// In it, this message translates to:
  /// **'Liste della spesa'**
  String get channelName;

  /// No description provided for @channelDescription.
  ///
  /// In it, this message translates to:
  /// **'Promemoria, condivisioni e messaggi delle liste'**
  String get channelDescription;

  /// No description provided for @you.
  ///
  /// In it, this message translates to:
  /// **'Tu'**
  String get you;

  /// No description provided for @serviceChannelName.
  ///
  /// In it, this message translates to:
  /// **'Collegamento in background'**
  String get serviceChannelName;

  /// No description provided for @serviceChannelDescription.
  ///
  /// In it, this message translates to:
  /// **'Tiene l\'app collegata per ricevere liste e messaggi anche quando è chiusa'**
  String get serviceChannelDescription;

  /// No description provided for @reminderTitle.
  ///
  /// In it, this message translates to:
  /// **'Promemoria: {name}'**
  String reminderTitle(String name);

  /// No description provided for @reminderBody.
  ///
  /// In it, this message translates to:
  /// **'La spesa è tra {duration}.'**
  String reminderBody(String duration);

  /// No description provided for @sendPhoto.
  ///
  /// In it, this message translates to:
  /// **'Invia una foto'**
  String get sendPhoto;

  /// No description provided for @deleteMessageQuestion.
  ///
  /// In it, this message translates to:
  /// **'Eliminare il messaggio?'**
  String get deleteMessageQuestion;

  /// No description provided for @deleteMessageInfo.
  ///
  /// In it, this message translates to:
  /// **'Sparirà per tutti.'**
  String get deleteMessageInfo;

  /// No description provided for @writeMessage.
  ///
  /// In it, this message translates to:
  /// **'Scrivi un messaggio'**
  String get writeMessage;

  /// No description provided for @send.
  ///
  /// In it, this message translates to:
  /// **'Invia'**
  String get send;

  /// No description provided for @deletedUser.
  ///
  /// In it, this message translates to:
  /// **'Utente'**
  String get deletedUser;

  /// No description provided for @messageReceived.
  ///
  /// In it, this message translates to:
  /// **'Ricevuto'**
  String get messageReceived;

  /// No description provided for @messageSent.
  ///
  /// In it, this message translates to:
  /// **'Inviato'**
  String get messageSent;

  /// No description provided for @emptyChat.
  ///
  /// In it, this message translates to:
  /// **'Nessun messaggio.\nScrivi, detta con il microfono o invia una foto a chi condivide la lista: \"Sono al banco frigo, manca qualcosa?\"'**
  String get emptyChat;

  /// No description provided for @pickFromGallery.
  ///
  /// In it, this message translates to:
  /// **'Scegli dalla galleria'**
  String get pickFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In it, this message translates to:
  /// **'Scatta una foto'**
  String get takePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi la foto'**
  String get removePhoto;

  /// No description provided for @imageUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Immagine non disponibile'**
  String get imageUnavailable;

  /// No description provided for @voiceUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Riconoscimento vocale non disponibile su questo telefono: installa o attiva l\'app Google (riconoscimento vocale di Google).'**
  String get voiceUnavailable;

  /// No description provided for @voiceMicPermission.
  ///
  /// In it, this message translates to:
  /// **'Per dettare consenti all\'app l\'uso del microfono nelle impostazioni del telefono.'**
  String get voiceMicPermission;

  /// No description provided for @voiceNoMatch.
  ///
  /// In it, this message translates to:
  /// **'Non ho sentito nulla: tocca il microfono e parla subito.'**
  String get voiceNoMatch;

  /// No description provided for @voiceNetwork.
  ///
  /// In it, this message translates to:
  /// **'Riconoscimento vocale non raggiungibile: controlla la connessione.'**
  String get voiceNetwork;

  /// No description provided for @voiceBusy.
  ///
  /// In it, this message translates to:
  /// **'Il microfono è occupato, riprova tra un attimo.'**
  String get voiceBusy;

  /// No description provided for @voiceLanguageUnavailable.
  ///
  /// In it, this message translates to:
  /// **'{language} non disponibile per la dettatura: scaricalo nelle impostazioni della voce di Google.'**
  String voiceLanguageUnavailable(String language);

  /// No description provided for @voiceNotUnderstood.
  ///
  /// In it, this message translates to:
  /// **'Non ho capito, riprova.'**
  String get voiceNotUnderstood;

  /// No description provided for @stopListening.
  ///
  /// In it, this message translates to:
  /// **'Smetti di ascoltare'**
  String get stopListening;

  /// No description provided for @dictate.
  ///
  /// In it, this message translates to:
  /// **'Detta a voce'**
  String get dictate;

  /// No description provided for @exportNotFound.
  ///
  /// In it, this message translates to:
  /// **'non trovato'**
  String get exportNotFound;

  /// No description provided for @exportTaken.
  ///
  /// In it, this message translates to:
  /// **'{taken} di {total} presi'**
  String exportTaken(int taken, int total);

  /// No description provided for @pdfPage.
  ///
  /// In it, this message translates to:
  /// **'pagina {page} di {total}'**
  String pdfPage(int page, int total);

  /// No description provided for @pdfSummary.
  ///
  /// In it, this message translates to:
  /// **'Presi: {taken} · Non trovati: {missing} · Da prendere: {todo}'**
  String pdfSummary(int taken, int missing, int todo);

  /// No description provided for @numericDatePattern.
  ///
  /// In it, this message translates to:
  /// **'dd/MM/y'**
  String get numericDatePattern;

  /// No description provided for @listUnavailable.
  ///
  /// In it, this message translates to:
  /// **'La lista non è più disponibile.'**
  String get listUnavailable;

  /// No description provided for @deleteListQuestion.
  ///
  /// In it, this message translates to:
  /// **'Eliminare la lista?'**
  String get deleteListQuestion;

  /// No description provided for @deleteListInfo.
  ///
  /// In it, this message translates to:
  /// **'Verrà eliminata anche per chi la condivide.'**
  String get deleteListInfo;

  /// No description provided for @leaveListQuestion.
  ///
  /// In it, this message translates to:
  /// **'Abbandonare la lista?'**
  String get leaveListQuestion;

  /// No description provided for @leaveListInfo.
  ///
  /// In it, this message translates to:
  /// **'Non la vedrai più finché non ti verrà ricondivisa.'**
  String get leaveListInfo;

  /// No description provided for @leave.
  ///
  /// In it, this message translates to:
  /// **'Abbandona'**
  String get leave;

  /// No description provided for @listPhotoUpdated.
  ///
  /// In it, this message translates to:
  /// **'Foto della lista aggiornata.'**
  String get listPhotoUpdated;

  /// No description provided for @photoOf.
  ///
  /// In it, this message translates to:
  /// **'Foto di {name}'**
  String photoOf(String name);

  /// No description provided for @deleteItemQuestion.
  ///
  /// In it, this message translates to:
  /// **'Eliminare «{name}» dalla lista?'**
  String deleteItemQuestion(String name);

  /// No description provided for @deleteItemInfo.
  ///
  /// In it, this message translates to:
  /// **'Sparirà dalla lista per tutti. Se l\'hai solo messo nel carrello, spuntalo come preso.'**
  String get deleteItemInfo;

  /// No description provided for @putBackToBuy.
  ///
  /// In it, this message translates to:
  /// **'Rimetti da prendere'**
  String get putBackToBuy;

  /// No description provided for @takenInCart.
  ///
  /// In it, this message translates to:
  /// **'Preso (nel carrello)'**
  String get takenInCart;

  /// No description provided for @notFound.
  ///
  /// In it, this message translates to:
  /// **'Non trovato'**
  String get notFound;

  /// No description provided for @addPhoto.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una foto'**
  String get addPhoto;

  /// No description provided for @changePhoto.
  ///
  /// In it, this message translates to:
  /// **'Cambia foto'**
  String get changePhoto;

  /// No description provided for @deleteFromList.
  ///
  /// In it, this message translates to:
  /// **'Elimina dalla lista'**
  String get deleteFromList;

  /// No description provided for @deleteFromListInfo.
  ///
  /// In it, this message translates to:
  /// **'Diverso da \"preso\": l\'articolo sparisce per tutti'**
  String get deleteFromListInfo;

  /// No description provided for @sendOrExportList.
  ///
  /// In it, this message translates to:
  /// **'Invia o esporta la lista'**
  String get sendOrExportList;

  /// No description provided for @exportTextInfo.
  ///
  /// In it, this message translates to:
  /// **'Testo con le spunte, scegli tu la chat'**
  String get exportTextInfo;

  /// No description provided for @exportPdfInfo.
  ///
  /// In it, this message translates to:
  /// **'Da stampare o inviare (anche su WhatsApp o Telegram)'**
  String get exportPdfInfo;

  /// No description provided for @otherApps.
  ///
  /// In it, this message translates to:
  /// **'Altre app'**
  String get otherApps;

  /// No description provided for @appNotInstalled.
  ///
  /// In it, this message translates to:
  /// **'{app} non è installato su questo telefono.'**
  String appNotInstalled(String app);

  /// No description provided for @list.
  ///
  /// In it, this message translates to:
  /// **'Lista'**
  String get list;

  /// No description provided for @closeChat.
  ///
  /// In it, this message translates to:
  /// **'Chiudi la chat'**
  String get closeChat;

  /// No description provided for @chat.
  ///
  /// In it, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @sendOrExport.
  ///
  /// In it, this message translates to:
  /// **'Invia o esporta'**
  String get sendOrExport;

  /// No description provided for @clearTaken.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi articoli presi'**
  String get clearTaken;

  /// No description provided for @deleteList.
  ///
  /// In it, this message translates to:
  /// **'Elimina lista'**
  String get deleteList;

  /// No description provided for @leaveList.
  ///
  /// In it, this message translates to:
  /// **'Abbandona lista'**
  String get leaveList;

  /// No description provided for @cannotLoadList.
  ///
  /// In it, this message translates to:
  /// **'Impossibile caricare la lista.'**
  String get cannotLoadList;

  /// No description provided for @reminderBefore.
  ///
  /// In it, this message translates to:
  /// **'Promemoria {duration} prima'**
  String reminderBefore(String duration);

  /// No description provided for @readOnlyAccess.
  ///
  /// In it, this message translates to:
  /// **'Hai accesso in sola lettura'**
  String get readOnlyAccess;

  /// No description provided for @emptyList.
  ///
  /// In it, this message translates to:
  /// **'La lista è vuota.\nAggiungi il primo articolo qui sotto.'**
  String get emptyList;

  /// No description provided for @inCart.
  ///
  /// In it, this message translates to:
  /// **'{checked} di {total} nel carrello'**
  String inCart(int checked, int total);

  /// No description provided for @notFoundCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 non trovato} other{{count} non trovati}}'**
  String notFoundCount(int count);

  /// No description provided for @takenBy.
  ///
  /// In it, this message translates to:
  /// **'preso da {name}'**
  String takenBy(String name);

  /// No description provided for @notFoundLower.
  ///
  /// In it, this message translates to:
  /// **'non trovato'**
  String get notFoundLower;

  /// No description provided for @notFoundBy.
  ///
  /// In it, this message translates to:
  /// **'non trovato ({name})'**
  String notFoundBy(String name);

  /// No description provided for @markToBuyAgain.
  ///
  /// In it, this message translates to:
  /// **'Segna di nuovo da prendere'**
  String get markToBuyAgain;

  /// No description provided for @markMissing.
  ///
  /// In it, this message translates to:
  /// **'Non preso (non trovato)'**
  String get markMissing;

  /// No description provided for @itemMenu.
  ///
  /// In it, this message translates to:
  /// **'Modifica, foto o elimina'**
  String get itemMenu;

  /// No description provided for @onlyYouViewing.
  ///
  /// In it, this message translates to:
  /// **'Solo tu stai guardando questa lista'**
  String get onlyYouViewing;

  /// No description provided for @viewingNow.
  ///
  /// In it, this message translates to:
  /// **'Qui ora: {names}'**
  String viewingNow(String names);

  /// No description provided for @typing.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{{names} sta scrivendo…} other{{names} stanno scrivendo…}}'**
  String typing(int count, String names);

  /// No description provided for @productPhoto.
  ///
  /// In it, this message translates to:
  /// **'Foto del prodotto'**
  String get productPhoto;

  /// No description provided for @oftenBought.
  ///
  /// In it, this message translates to:
  /// **'Compri spesso:'**
  String get oftenBought;

  /// No description provided for @timesInList.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Già messo in lista 1 volta} other{Già messo in lista {count} volte}}'**
  String timesInList(int count);

  /// No description provided for @addProductHint.
  ///
  /// In it, this message translates to:
  /// **'Agg. prodotto...'**
  String get addProductHint;

  /// No description provided for @amountExampleError.
  ///
  /// In it, this message translates to:
  /// **'Scrivi un numero, es. 500 oppure 1,5'**
  String get amountExampleError;

  /// No description provided for @quantity.
  ///
  /// In it, this message translates to:
  /// **'Quantità'**
  String get quantity;

  /// No description provided for @less.
  ///
  /// In it, this message translates to:
  /// **'Meno'**
  String get less;

  /// No description provided for @more.
  ///
  /// In it, this message translates to:
  /// **'Più'**
  String get more;

  /// No description provided for @weightOrVolume.
  ///
  /// In it, this message translates to:
  /// **'Peso o volume'**
  String get weightOrVolume;

  /// No description provided for @weight.
  ///
  /// In it, this message translates to:
  /// **'Peso'**
  String get weight;

  /// No description provided for @packages.
  ///
  /// In it, this message translates to:
  /// **'Confezioni'**
  String get packages;

  /// No description provided for @packageSize.
  ///
  /// In it, this message translates to:
  /// **'Confezione da {size}'**
  String packageSize(String size);

  /// No description provided for @amountHint.
  ///
  /// In it, this message translates to:
  /// **'es. 500'**
  String get amountHint;

  /// No description provided for @clearMeasure.
  ///
  /// In it, this message translates to:
  /// **'Togli'**
  String get clearMeasure;

  /// No description provided for @done.
  ///
  /// In it, this message translates to:
  /// **'Fatto'**
  String get done;

  /// No description provided for @invalidImageUrl.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un link che inizia con https://'**
  String get invalidImageUrl;

  /// No description provided for @invalidNumber.
  ///
  /// In it, this message translates to:
  /// **'Numero non valido'**
  String get invalidNumber;

  /// No description provided for @emojiTooLong.
  ///
  /// In it, this message translates to:
  /// **'Al massimo una o due emoji'**
  String get emojiTooLong;

  /// No description provided for @addProductPhoto.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una foto del prodotto'**
  String get addProductPhoto;

  /// No description provided for @changeOrRemovePhoto.
  ///
  /// In it, this message translates to:
  /// **'Cambia o rimuovi la foto'**
  String get changeOrRemovePhoto;

  /// No description provided for @editItem.
  ///
  /// In it, this message translates to:
  /// **'Modifica articolo'**
  String get editItem;

  /// No description provided for @product.
  ///
  /// In it, this message translates to:
  /// **'Prodotto'**
  String get product;

  /// No description provided for @quantityOptional.
  ///
  /// In it, this message translates to:
  /// **'Quantità (facoltativa)'**
  String get quantityOptional;

  /// No description provided for @weightOptional.
  ///
  /// In it, this message translates to:
  /// **'Peso o volume (facoltativo)'**
  String get weightOptional;

  /// No description provided for @packagesOptional.
  ///
  /// In it, this message translates to:
  /// **'Confezioni (facoltativo)'**
  String get packagesOptional;

  /// No description provided for @weightOnlyOptional.
  ///
  /// In it, this message translates to:
  /// **'Peso (facoltativo)'**
  String get weightOnlyOptional;

  /// No description provided for @department.
  ///
  /// In it, this message translates to:
  /// **'Reparto'**
  String get department;

  /// No description provided for @departmentHelper.
  ///
  /// In it, this message translates to:
  /// **'Riconosciuto dal nome: cambialo se non è giusto'**
  String get departmentHelper;

  /// No description provided for @emojiOptional.
  ///
  /// In it, this message translates to:
  /// **'Emoji (facoltativa)'**
  String get emojiOptional;

  /// No description provided for @recognizedEmoji.
  ///
  /// In it, this message translates to:
  /// **'Riconosciuta: {emoji}'**
  String recognizedEmoji(String emoji);

  /// No description provided for @fromName.
  ///
  /// In it, this message translates to:
  /// **'dal nome'**
  String get fromName;

  /// No description provided for @useRecognizedEmoji.
  ///
  /// In it, this message translates to:
  /// **'Usa quella riconosciuta dal nome'**
  String get useRecognizedEmoji;

  /// No description provided for @imageLinkOptional.
  ///
  /// In it, this message translates to:
  /// **'Link a un\'immagine (facoltativo)'**
  String get imageLinkOptional;

  /// No description provided for @supermarketLabel.
  ///
  /// In it, this message translates to:
  /// **'Supermercato (facoltativo)'**
  String get supermarketLabel;

  /// No description provided for @supermarketHint.
  ///
  /// In it, this message translates to:
  /// **'es. Esselunga, Coop, Lidl'**
  String get supermarketHint;

  /// No description provided for @supermarketHelper.
  ///
  /// In it, this message translates to:
  /// **'Dove fai la spesa (facoltativo)'**
  String get supermarketHelper;

  /// No description provided for @close.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get close;

  /// No description provided for @perPiece.
  ///
  /// In it, this message translates to:
  /// **'a confezione'**
  String get perPiece;

  /// No description provided for @perKg.
  ///
  /// In it, this message translates to:
  /// **'al kg'**
  String get perKg;

  /// No description provided for @perLitre.
  ///
  /// In it, this message translates to:
  /// **'al litro'**
  String get perLitre;

  /// No description provided for @priceLabel.
  ///
  /// In it, this message translates to:
  /// **'Prezzo'**
  String get priceLabel;

  /// No description provided for @invalidPrice.
  ///
  /// In it, this message translates to:
  /// **'Scrivi un prezzo, es. 1,29'**
  String get invalidPrice;

  /// No description provided for @privacyRequired.
  ///
  /// In it, this message translates to:
  /// **'Per registrarti devi accettare l\'informativa privacy'**
  String get privacyRequired;

  /// No description provided for @acceptPrivacyPrefix.
  ///
  /// In it, this message translates to:
  /// **'Ho letto e accetto l\''**
  String get acceptPrivacyPrefix;

  /// No description provided for @acceptPrivacySuffix.
  ///
  /// In it, this message translates to:
  /// **''**
  String get acceptPrivacySuffix;

  /// No description provided for @privacyPolicy.
  ///
  /// In it, this message translates to:
  /// **'informativa privacy'**
  String get privacyPolicy;

  /// No description provided for @termsRequired.
  ///
  /// In it, this message translates to:
  /// **'Per registrarti devi accettare le condizioni d\'uso'**
  String get termsRequired;

  /// No description provided for @acceptTermsPrefix.
  ///
  /// In it, this message translates to:
  /// **'Accetto le '**
  String get acceptTermsPrefix;

  /// No description provided for @termsOfUse.
  ///
  /// In it, this message translates to:
  /// **'condizioni d\'uso'**
  String get termsOfUse;

  /// No description provided for @acceptTermsSuffix.
  ///
  /// In it, this message translates to:
  /// **': i contenuti che aggiungo sono sotto la mia responsabilità'**
  String get acceptTermsSuffix;

  /// No description provided for @newsletterConsent.
  ///
  /// In it, this message translates to:
  /// **'Voglio ricevere la newsletter di Lista Spesa Facile'**
  String get newsletterConsent;

  /// No description provided for @newsletterOptional.
  ///
  /// In it, this message translates to:
  /// **'Facoltativo'**
  String get newsletterOptional;

  /// No description provided for @socialPrivacyNotice.
  ///
  /// In it, this message translates to:
  /// **'Continuando con Google o Amazon accetti l\''**
  String get socialPrivacyNotice;

  /// No description provided for @socialTermsJoin.
  ///
  /// In it, this message translates to:
  /// **' e le '**
  String get socialTermsJoin;

  /// No description provided for @myPrices.
  ///
  /// In it, this message translates to:
  /// **'I miei prezzi'**
  String get myPrices;

  /// No description provided for @myPrice.
  ///
  /// In it, this message translates to:
  /// **'Il mio prezzo'**
  String get myPrice;

  /// No description provided for @addMyPrice.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi prezzo'**
  String get addMyPrice;

  /// No description provided for @editMyPrice.
  ///
  /// In it, this message translates to:
  /// **'Modifica prezzo'**
  String get editMyPrice;

  /// No description provided for @productRequired.
  ///
  /// In it, this message translates to:
  /// **'Scrivi il prodotto'**
  String get productRequired;

  /// No description provided for @noteOptional.
  ///
  /// In it, this message translates to:
  /// **'Nota (facoltativa)'**
  String get noteOptional;

  /// No description provided for @myPricesPrivate.
  ///
  /// In it, this message translates to:
  /// **'I tuoi prezzi li vedi solo tu.'**
  String get myPricesPrivate;

  /// No description provided for @myPriceSaved.
  ///
  /// In it, this message translates to:
  /// **'Prezzo salvato in \"I miei prezzi\"'**
  String get myPriceSaved;

  /// No description provided for @searchMyPrices.
  ///
  /// In it, this message translates to:
  /// **'Cerca prodotto o supermercato'**
  String get searchMyPrices;

  /// No description provided for @noMyPrices.
  ///
  /// In it, this message translates to:
  /// **'Nessun prezzo. Aggiungilo da qui o dal menu ⋮ di un prodotto della lista.'**
  String get noMyPrices;

  /// No description provided for @noMyPricesFound.
  ///
  /// In it, this message translates to:
  /// **'Nessun prezzo trovato.'**
  String get noMyPricesFound;

  /// No description provided for @deleteMyPriceQuestion.
  ///
  /// In it, this message translates to:
  /// **'Eliminare il prezzo di {product}?'**
  String deleteMyPriceQuestion(String product);

  /// No description provided for @info.
  ///
  /// In it, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @noProductInfo.
  ///
  /// In it, this message translates to:
  /// **'Nessuna informazione trovata su Open Food Facts per questo prodotto.'**
  String get noProductInfo;

  /// No description provided for @similarProductNotice.
  ///
  /// In it, this message translates to:
  /// **'Prodotto simile trovato dal nome: potrebbe non essere esattamente il tuo.'**
  String get similarProductNotice;

  /// No description provided for @barcode.
  ///
  /// In it, this message translates to:
  /// **'Codice a barre'**
  String get barcode;

  /// No description provided for @copy.
  ///
  /// In it, this message translates to:
  /// **'Copia'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In it, this message translates to:
  /// **'Copiato'**
  String get copied;

  /// No description provided for @forCoeliacs.
  ///
  /// In it, this message translates to:
  /// **'Celiaci'**
  String get forCoeliacs;

  /// No description provided for @glutenFree.
  ///
  /// In it, this message translates to:
  /// **'senza glutine'**
  String get glutenFree;

  /// No description provided for @containsGluten.
  ///
  /// In it, this message translates to:
  /// **'contiene glutine'**
  String get containsGluten;

  /// No description provided for @vegetarian.
  ///
  /// In it, this message translates to:
  /// **'Vegetariano'**
  String get vegetarian;

  /// No description provided for @vegan.
  ///
  /// In it, this message translates to:
  /// **'Vegano'**
  String get vegan;

  /// No description provided for @yes.
  ///
  /// In it, this message translates to:
  /// **'sì'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In it, this message translates to:
  /// **'no'**
  String get no;

  /// No description provided for @palmOil.
  ///
  /// In it, this message translates to:
  /// **'Olio di palma'**
  String get palmOil;

  /// No description provided for @palmOilFree.
  ///
  /// In it, this message translates to:
  /// **'senza'**
  String get palmOilFree;

  /// No description provided for @containsPalmOil.
  ///
  /// In it, this message translates to:
  /// **'contiene'**
  String get containsPalmOil;

  /// No description provided for @lactose.
  ///
  /// In it, this message translates to:
  /// **'Lattosio'**
  String get lactose;

  /// No description provided for @lactoseFree.
  ///
  /// In it, this message translates to:
  /// **'senza lattosio'**
  String get lactoseFree;

  /// No description provided for @nutritionPer100.
  ///
  /// In it, this message translates to:
  /// **'Valori nutrizionali per 100 g'**
  String get nutritionPer100;

  /// No description provided for @nutrientFat.
  ///
  /// In it, this message translates to:
  /// **'Grassi'**
  String get nutrientFat;

  /// No description provided for @nutrientSaturatedFat.
  ///
  /// In it, this message translates to:
  /// **'di cui saturi'**
  String get nutrientSaturatedFat;

  /// No description provided for @nutrientCarbohydrates.
  ///
  /// In it, this message translates to:
  /// **'Carboidrati'**
  String get nutrientCarbohydrates;

  /// No description provided for @nutrientSugars.
  ///
  /// In it, this message translates to:
  /// **'di cui zuccheri'**
  String get nutrientSugars;

  /// No description provided for @nutrientFiber.
  ///
  /// In it, this message translates to:
  /// **'Fibre'**
  String get nutrientFiber;

  /// No description provided for @nutrientProteins.
  ///
  /// In it, this message translates to:
  /// **'Proteine'**
  String get nutrientProteins;

  /// No description provided for @nutrientSalt.
  ///
  /// In it, this message translates to:
  /// **'Sale'**
  String get nutrientSalt;

  /// No description provided for @noNutritionInfo.
  ///
  /// In it, this message translates to:
  /// **'Non ci sono informazioni nutrizionali'**
  String get noNutritionInfo;

  /// No description provided for @waterMinerals.
  ///
  /// In it, this message translates to:
  /// **'Composizione per litro'**
  String get waterMinerals;

  /// No description provided for @mineralCalcium.
  ///
  /// In it, this message translates to:
  /// **'Calcio'**
  String get mineralCalcium;

  /// No description provided for @mineralMagnesium.
  ///
  /// In it, this message translates to:
  /// **'Magnesio'**
  String get mineralMagnesium;

  /// No description provided for @mineralSodium.
  ///
  /// In it, this message translates to:
  /// **'Sodio'**
  String get mineralSodium;

  /// No description provided for @mineralPotassium.
  ///
  /// In it, this message translates to:
  /// **'Potassio'**
  String get mineralPotassium;

  /// No description provided for @mineralBicarbonate.
  ///
  /// In it, this message translates to:
  /// **'Bicarbonato'**
  String get mineralBicarbonate;

  /// No description provided for @mineralChloride.
  ///
  /// In it, this message translates to:
  /// **'Cloruri'**
  String get mineralChloride;

  /// No description provided for @mineralSulphate.
  ///
  /// In it, this message translates to:
  /// **'Solfati'**
  String get mineralSulphate;

  /// No description provided for @mineralNitrate.
  ///
  /// In it, this message translates to:
  /// **'Nitrati'**
  String get mineralNitrate;

  /// No description provided for @mineralFluoride.
  ///
  /// In it, this message translates to:
  /// **'Fluoro'**
  String get mineralFluoride;

  /// No description provided for @mineralSilica.
  ///
  /// In it, this message translates to:
  /// **'Silice'**
  String get mineralSilica;

  /// No description provided for @allergens.
  ///
  /// In it, this message translates to:
  /// **'Allergeni'**
  String get allergens;

  /// No description provided for @mayContainTraces.
  ///
  /// In it, this message translates to:
  /// **'Può contenere tracce di: {list}'**
  String mayContainTraces(String list);

  /// No description provided for @ingredients.
  ///
  /// In it, this message translates to:
  /// **'Ingredienti'**
  String get ingredients;

  /// No description provided for @openFoodFactsPage.
  ///
  /// In it, this message translates to:
  /// **'Vedi su Open Food Facts'**
  String get openFoodFactsPage;

  /// No description provided for @openFoodFactsSource.
  ///
  /// In it, this message translates to:
  /// **'Dati da Open Food Facts (licenza ODbL): possono essere incompleti, controlla sempre l\'etichetta.'**
  String get openFoodFactsSource;

  /// No description provided for @allergenGluten.
  ///
  /// In it, this message translates to:
  /// **'Glutine'**
  String get allergenGluten;

  /// No description provided for @allergenCrustaceans.
  ///
  /// In it, this message translates to:
  /// **'Crostacei'**
  String get allergenCrustaceans;

  /// No description provided for @allergenEggs.
  ///
  /// In it, this message translates to:
  /// **'Uova'**
  String get allergenEggs;

  /// No description provided for @allergenFish.
  ///
  /// In it, this message translates to:
  /// **'Pesce'**
  String get allergenFish;

  /// No description provided for @allergenPeanuts.
  ///
  /// In it, this message translates to:
  /// **'Arachidi'**
  String get allergenPeanuts;

  /// No description provided for @allergenSoybeans.
  ///
  /// In it, this message translates to:
  /// **'Soia'**
  String get allergenSoybeans;

  /// No description provided for @allergenMilk.
  ///
  /// In it, this message translates to:
  /// **'Latte'**
  String get allergenMilk;

  /// No description provided for @allergenNuts.
  ///
  /// In it, this message translates to:
  /// **'Frutta a guscio'**
  String get allergenNuts;

  /// No description provided for @allergenCelery.
  ///
  /// In it, this message translates to:
  /// **'Sedano'**
  String get allergenCelery;

  /// No description provided for @allergenMustard.
  ///
  /// In it, this message translates to:
  /// **'Senape'**
  String get allergenMustard;

  /// No description provided for @allergenSesame.
  ///
  /// In it, this message translates to:
  /// **'Sesamo'**
  String get allergenSesame;

  /// No description provided for @allergenSulphites.
  ///
  /// In it, this message translates to:
  /// **'Solfiti'**
  String get allergenSulphites;

  /// No description provided for @allergenLupin.
  ///
  /// In it, this message translates to:
  /// **'Lupini'**
  String get allergenLupin;

  /// No description provided for @allergenMolluscs.
  ///
  /// In it, this message translates to:
  /// **'Molluschi'**
  String get allergenMolluscs;

  /// No description provided for @permission.
  ///
  /// In it, this message translates to:
  /// **'Permesso'**
  String get permission;

  /// No description provided for @permissionRead.
  ///
  /// In it, this message translates to:
  /// **'Solo lettura'**
  String get permissionRead;

  /// No description provided for @permissionReadWrite.
  ///
  /// In it, this message translates to:
  /// **'Lettura e modifica'**
  String get permissionReadWrite;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
