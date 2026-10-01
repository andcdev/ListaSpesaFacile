// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get save => 'Enregistrer';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Réessayer';

  @override
  String get remove => 'Retirer';

  @override
  String get add => 'Ajouter';

  @override
  String get confirm => 'Confirmer';

  @override
  String get edit => 'Modifier';

  @override
  String get share => 'Partager';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get name => 'Nom';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get tomorrow => 'Demain';

  @override
  String get yesterday => 'Hier';

  @override
  String get canEdit => 'Peut modifier';

  @override
  String get userCanEdit => 'peut modifier';

  @override
  String get userReadOnly => 'lecture seule';

  @override
  String get invalidEmail => 'Saisissez un e-mail valide';

  @override
  String get enterRegisteredEmail =>
      'Saisissez l\'e-mail d\'un utilisateur inscrit';

  @override
  String get atLeast8 => 'Au moins 8 caractères';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get passwordsDontMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get nobody => 'Personne.';

  @override
  String get myLists => 'Mes listes';

  @override
  String get other => 'Autre';

  @override
  String get language => 'Langue';

  @override
  String languageValue(String language) {
    return 'Langue : $language';
  }

  @override
  String languageSystem(String language) {
    return 'Comme le téléphone ($language)';
  }

  @override
  String get background => 'Arrière-plan';

  @override
  String backgroundValue(String value) {
    return 'Arrière-plan : $value';
  }

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeSystem => 'Comme le téléphone';

  @override
  String get errTimeout => 'Le serveur ne répond pas. Réessayez plus tard.';

  @override
  String get errNetwork =>
      'Impossible de joindre le serveur. Vérifiez la connexion.';

  @override
  String get errSessionExpired => 'Session expirée. Reconnectez-vous.';

  @override
  String get errForbidden =>
      'Vous n\'avez pas l\'autorisation pour cette opération.';

  @override
  String get errNotFound =>
      'Élément introuvable (il a peut-être été supprimé).';

  @override
  String get errTooMany => 'Trop de tentatives. Patientez une minute.';

  @override
  String get errServer => 'Erreur du serveur. Réessayez plus tard.';

  @override
  String errUnexpected(int status) {
    return 'Erreur inattendue ($status).';
  }

  @override
  String get checkYourEmail => 'Consultez vos e-mails.';

  @override
  String get enterPassword => 'Saisissez le mot de passe';

  @override
  String get forgotPasswordQuestion => 'Mot de passe oublié ?';

  @override
  String get signIn => 'Se connecter';

  @override
  String get noAccount => 'Pas de compte ? Inscrivez-vous';

  @override
  String get server => 'Serveur';

  @override
  String get serverAddress => 'Adresse du serveur';

  @override
  String socialNotActiveTitle(String provider) {
    return 'Connexion avec $provider pas encore active';
  }

  @override
  String socialNotActiveBody(String provider) {
    return 'Le serveur n\'est pas encore relié à $provider. L\'administrateur du serveur doit enregistrer l\'application auprès de $provider et saisir l\'ID et le secret dans le fichier .env (voir le README, \"Accesso con Google e Amazon\").\n\nEn attendant, vous pouvez vous inscrire avec e-mail et mot de passe.';
  }

  @override
  String get or => 'ou';

  @override
  String continueWith(String provider) {
    return 'Continuer avec $provider';
  }

  @override
  String socialOpenFailed(String provider) {
    return 'Impossible d\'ouvrir la connexion avec $provider.';
  }

  @override
  String get socialFailed => 'Échec de la connexion.';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get enterYourName => 'Saisissez votre nom';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié';

  @override
  String get resetCodeSentInfo =>
      'Nous vous avons envoyé un code à 6 chiffres (vérifiez aussi les spams). Saisissez-le et choisissez un nouveau mot de passe.';

  @override
  String get resetInfo =>
      'Saisissez l\'e-mail de votre compte : nous vous enverrons un code pour choisir un nouveau mot de passe.';

  @override
  String get resetCodeLabel => 'Code reçu par e-mail';

  @override
  String get resetCodeInvalid => 'Le code comporte 6 chiffres';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get setNewPassword => 'Définir le nouveau mot de passe';

  @override
  String get sendCode => 'Envoyer le code';

  @override
  String get resendCode => 'Pas reçu ? Renvoyer';

  @override
  String deleteListNamed(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteListSharedInfo =>
      'La liste disparaîtra aussi pour les utilisateurs avec qui elle est partagée.';

  @override
  String get profilePhotoTitle => 'Photo de profil (visible dans le chat)';

  @override
  String get profilePhotoUpdated => 'Photo de profil mise à jour.';

  @override
  String get globalSharing => 'Partage global';

  @override
  String get profile => 'Profil';

  @override
  String get logoutQuestion => 'Se déconnecter ?';

  @override
  String get logout => 'Se déconnecter';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountQuestion => 'Supprimer votre compte ?';

  @override
  String get deleteAccountMessage =>
      'La suppression est définitive et irréversible. Vos listes, avec leurs articles, photos et discussions, sont aussi supprimées pour les personnes avec qui vous les partagez, et vous quittez les listes des autres.';

  @override
  String get deleteAccountConfirm => 'Supprimer définitivement';

  @override
  String get accountDeleted => 'Compte supprimé.';

  @override
  String get addProfilePhoto => 'Ajouter une photo de profil';

  @override
  String get changeProfilePhoto => 'Changer la photo de profil';

  @override
  String get newList => 'Nouvelle liste';

  @override
  String get noUpcoming => 'Aucune course prévue.';

  @override
  String get upcomingTab => 'À venir';

  @override
  String pastTab(int count) {
    return 'Passées · $count';
  }

  @override
  String toBuyCount(int count) {
    return '$count à prendre';
  }

  @override
  String get listCompleteBadge => 'Terminée';

  @override
  String get listEmptyBadge => 'Vide';

  @override
  String viewingNowShort(String names) {
    return 'ici : $names';
  }

  @override
  String byOwner(String name) {
    return 'de $name';
  }

  @override
  String get noLists =>
      'Aucune liste.\nCréez-en une avec le bouton « Nouvelle liste ».';

  @override
  String get realtimeOn => 'Mises à jour en temps réel actives';

  @override
  String get realtimeOff => 'Temps réel non connecté';

  @override
  String get notifications => 'Notifications';

  @override
  String get editList => 'Modifier la liste';

  @override
  String get alreadyAdded => 'Déjà ajouté';

  @override
  String get listNameHint => 'ex. Courses de la semaine';

  @override
  String get renameLocked =>
      'Le propriétaire n\'autorise pas le changement de nom';

  @override
  String get listNameRequired => 'Donnez un nom à la liste';

  @override
  String get notesLabel => 'Notes (facultatif)';

  @override
  String get notesHint => 'ex. supermarché, promotions…';

  @override
  String get reminder => 'Rappel';

  @override
  String get noReminder => 'Aucun rappel';

  @override
  String durationBefore(String duration) {
    return '$duration avant';
  }

  @override
  String get customReminderOption => 'Personnalisé…';

  @override
  String get whoToNotify => 'Qui prévenir';

  @override
  String get reminderOwner => 'Seulement le créateur';

  @override
  String get reminderMembers => 'Seulement les destinataires';

  @override
  String get reminderAll => 'Créateur et destinataires';

  @override
  String get shareWith => 'Partager avec';

  @override
  String get userEmail => 'E-mail de l\'utilisateur';

  @override
  String get userEmailOptional => 'E-mail de l\'utilisateur (facultatif)';

  @override
  String get willBeNotified =>
      'Il recevra une notification quand vous créerez la liste';

  @override
  String get permissions => 'Autorisations';

  @override
  String get membersCanRenameTitle =>
      'Ceux qui peuvent modifier peuvent aussi changer le nom';

  @override
  String get membersCanRenameOn =>
      'Les utilisateurs autorisés à modifier peuvent renommer la liste';

  @override
  String get membersCanRenameOff =>
      'Vous seul pouvez changer le nom ; les autres modifient les articles';

  @override
  String get saveChanges => 'Enregistrer';

  @override
  String get createList => 'Créer la liste';

  @override
  String get customReminder => 'Rappel personnalisé';

  @override
  String get howEarly => 'Combien de temps avant';

  @override
  String get unitMinutes => 'minutes';

  @override
  String get unitHours => 'heures';

  @override
  String get unitDays => 'jours';

  @override
  String get reminderRange => 'De 1 minute à 30 jours';

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '1 heure',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get durationMoments => 'quelques instants';

  @override
  String listAnd(String head, String last) {
    return '$head et $last';
  }

  @override
  String listSharedWith(String email) {
    return 'Liste partagée avec $email';
  }

  @override
  String removeUserQuestion(String name) {
    return 'Retirer $name ?';
  }

  @override
  String get removeUserInfo => 'Il ne verra plus cette liste.';

  @override
  String get sharedWith => 'Partagée avec';

  @override
  String get nobodyYet => 'Personne pour l\'instant.';

  @override
  String get globalShareHint =>
      'Pour partager toutes vos listes avec quelqu\'un, utilisez « Partage global » sur l\'écran principal.';

  @override
  String allListsSharedWith(String email) {
    return 'Toutes vos listes sont maintenant partagées avec $email';
  }

  @override
  String stopSharingWith(String name) {
    return 'Arrêter de partager avec $name ?';
  }

  @override
  String stopReceivingFrom(String name) {
    return 'Ne plus voir les listes de $name ?';
  }

  @override
  String get globalShareInfo =>
      'Les personnes indiquées ici voient toutes vos listes, y compris celles que vous créerez.';

  @override
  String get iShareWith => 'Je partage toutes mes listes avec';

  @override
  String get sharedWithMe => 'Partagent toutes leurs listes avec moi';

  @override
  String get stopReceiving => 'Ne plus recevoir';

  @override
  String get deleteAllNotificationsQuestion =>
      'Supprimer toutes les notifications ?';

  @override
  String get markAllRead => 'Tout marquer comme lu';

  @override
  String get deleteAll => 'Tout supprimer';

  @override
  String get noNotifications => 'Aucune notification.';

  @override
  String get channelName => 'Listes de courses';

  @override
  String get channelDescription => 'Rappels, partages et messages des listes';

  @override
  String get you => 'Vous';

  @override
  String get serviceChannelName => 'Connexion en arrière-plan';

  @override
  String get serviceChannelDescription =>
      'Garde l\'application connectée pour recevoir listes et messages même fermée';

  @override
  String reminderTitle(String name) {
    return 'Rappel : $name';
  }

  @override
  String reminderBody(String duration) {
    return 'Les courses sont dans $duration.';
  }

  @override
  String get sendPhoto => 'Envoyer une photo';

  @override
  String get deleteMessageQuestion => 'Supprimer le message ?';

  @override
  String get deleteMessageInfo => 'Il disparaîtra pour tout le monde.';

  @override
  String get writeMessage => 'Écrire un message';

  @override
  String get send => 'Envoyer';

  @override
  String get deletedUser => 'Utilisateur';

  @override
  String get messageReceived => 'Reçu';

  @override
  String get messageSent => 'Envoyé';

  @override
  String get emptyChat =>
      'Aucun message.\nÉcrivez, dictez avec le micro ou envoyez une photo à ceux qui partagent la liste : « Je suis au rayon frais, il manque quelque chose ? »';

  @override
  String get pickFromGallery => 'Choisir dans la galerie';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get removePhoto => 'Retirer la photo';

  @override
  String get imageUnavailable => 'Image non disponible';

  @override
  String get voiceUnavailable =>
      'Reconnaissance vocale indisponible sur ce téléphone : installez ou activez l\'application Google (reconnaissance vocale de Google).';

  @override
  String get voiceMicPermission =>
      'Pour dicter, autorisez l\'application à utiliser le micro dans les réglages du téléphone.';

  @override
  String get voiceNoMatch =>
      'Je n\'ai rien entendu : touchez le micro et parlez tout de suite.';

  @override
  String get voiceNetwork =>
      'Reconnaissance vocale injoignable : vérifiez la connexion.';

  @override
  String get voiceBusy => 'Le micro est occupé, réessayez dans un instant.';

  @override
  String voiceLanguageUnavailable(String language) {
    return '$language non disponible pour la dictée : téléchargez-le dans les réglages de la saisie vocale Google.';
  }

  @override
  String get voiceNotUnderstood => 'Je n\'ai pas compris, réessayez.';

  @override
  String get stopListening => 'Arrêter l\'écoute';

  @override
  String get dictate => 'Dicter';

  @override
  String get exportNotFound => 'introuvable';

  @override
  String exportTaken(int taken, int total) {
    return '$taken sur $total pris';
  }

  @override
  String pdfPage(int page, int total) {
    return 'page $page sur $total';
  }

  @override
  String pdfSummary(int taken, int missing, int todo) {
    return 'Pris : $taken · Introuvables : $missing · À prendre : $todo';
  }

  @override
  String get numericDatePattern => 'dd/MM/y';

  @override
  String get listUnavailable => 'La liste n\'est plus disponible.';

  @override
  String get deleteListQuestion => 'Supprimer la liste ?';

  @override
  String get deleteListInfo =>
      'Elle sera aussi supprimée pour ceux qui la partagent.';

  @override
  String get leaveListQuestion => 'Quitter la liste ?';

  @override
  String get leaveListInfo =>
      'Vous ne la verrez plus jusqu\'à ce qu\'elle soit à nouveau partagée avec vous.';

  @override
  String get leave => 'Quitter';

  @override
  String get listPhotoUpdated => 'Photo de la liste mise à jour.';

  @override
  String photoOf(String name) {
    return 'Photo de $name';
  }

  @override
  String deleteItemQuestion(String name) {
    return 'Supprimer « $name » de la liste ?';
  }

  @override
  String get deleteItemInfo =>
      'Il disparaîtra de la liste pour tout le monde. Si vous l\'avez juste mis dans le chariot, cochez-le comme pris.';

  @override
  String get putBackToBuy => 'Remettre à prendre';

  @override
  String get takenInCart => 'Pris (dans le chariot)';

  @override
  String get notFound => 'Introuvable';

  @override
  String get addPhoto => 'Ajouter une photo';

  @override
  String get changePhoto => 'Changer la photo';

  @override
  String get deleteFromList => 'Supprimer de la liste';

  @override
  String get deleteFromListInfo =>
      'Différent de « pris » : l\'article disparaît pour tout le monde';

  @override
  String get sendOrExportList => 'Envoyer ou exporter la liste';

  @override
  String get exportTextInfo =>
      'Texte avec les coches, vous choisissez la discussion';

  @override
  String get exportPdfInfo =>
      'À imprimer ou envoyer (aussi sur WhatsApp ou Telegram)';

  @override
  String get otherApps => 'Autres applications';

  @override
  String appNotInstalled(String app) {
    return '$app n\'est pas installé sur ce téléphone.';
  }

  @override
  String get list => 'Liste';

  @override
  String get closeChat => 'Fermer le chat';

  @override
  String get chat => 'Chat';

  @override
  String get sendOrExport => 'Envoyer ou exporter';

  @override
  String get clearTaken => 'Retirer les articles pris';

  @override
  String get deleteList => 'Supprimer la liste';

  @override
  String get leaveList => 'Quitter la liste';

  @override
  String get cannotLoadList => 'Impossible de charger la liste.';

  @override
  String reminderBefore(String duration) {
    return 'Rappel $duration avant';
  }

  @override
  String get readOnlyAccess => 'Vous avez un accès en lecture seule';

  @override
  String get emptyList =>
      'La liste est vide.\nAjoutez le premier article ci-dessous.';

  @override
  String inCart(int checked, int total) {
    return '$checked sur $total dans le chariot';
  }

  @override
  String notFoundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count introuvables',
      one: '1 introuvable',
    );
    return '$_temp0';
  }

  @override
  String takenBy(String name) {
    return 'pris par $name';
  }

  @override
  String get notFoundLower => 'introuvable';

  @override
  String notFoundBy(String name) {
    return 'introuvable ($name)';
  }

  @override
  String get markToBuyAgain => 'Remettre à prendre';

  @override
  String get markMissing => 'Pas pris (introuvable)';

  @override
  String get itemMenu => 'Modifier, photo ou supprimer';

  @override
  String get onlyYouViewing => 'Vous seul regardez cette liste';

  @override
  String viewingNow(String names) {
    return 'Ici maintenant : $names';
  }

  @override
  String typing(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names sont en train d\'écrire…',
      one: '$names est en train d\'écrire…',
    );
    return '$_temp0';
  }

  @override
  String get productPhoto => 'Photo du produit';

  @override
  String get oftenBought => 'Vous achetez souvent :';

  @override
  String timesInList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Déjà ajouté $count fois',
      one: 'Déjà ajouté 1 fois',
    );
    return '$_temp0';
  }

  @override
  String get addProductHint => 'Ajout. produit...';

  @override
  String get amountExampleError => 'Saisissez un nombre, ex. 500 ou 1,5';

  @override
  String get quantity => 'Quantité';

  @override
  String get less => 'Moins';

  @override
  String get more => 'Plus';

  @override
  String get weightOrVolume => 'Poids ou volume';

  @override
  String get weight => 'Poids';

  @override
  String get packages => 'Paquets';

  @override
  String packageSize(String size) {
    return 'Paquet de $size';
  }

  @override
  String get amountHint => 'ex. 500';

  @override
  String get clearMeasure => 'Effacer';

  @override
  String get done => 'OK';

  @override
  String get invalidImageUrl => 'Saisissez un lien commençant par https://';

  @override
  String get invalidNumber => 'Nombre non valide';

  @override
  String get emojiTooLong => 'Un ou deux emoji au maximum';

  @override
  String get addProductPhoto => 'Ajouter une photo du produit';

  @override
  String get changeOrRemovePhoto => 'Changer ou retirer la photo';

  @override
  String get editItem => 'Modifier l\'article';

  @override
  String get product => 'Produit';

  @override
  String get quantityOptional => 'Quantité (facultatif)';

  @override
  String get weightOptional => 'Poids ou volume (facultatif)';

  @override
  String get packagesOptional => 'Paquets (facultatif)';

  @override
  String get weightOnlyOptional => 'Poids (facultatif)';

  @override
  String get department => 'Rayon';

  @override
  String get departmentHelper =>
      'Reconnu d\'après le nom : changez-le s\'il est incorrect';

  @override
  String get emojiOptional => 'Emoji (facultatif)';

  @override
  String recognizedEmoji(String emoji) {
    return 'Reconnu : $emoji';
  }

  @override
  String get fromName => 'd\'après le nom';

  @override
  String get useRecognizedEmoji => 'Utiliser celui reconnu d\'après le nom';

  @override
  String get imageLinkOptional => 'Lien vers une image (facultatif)';

  @override
  String get supermarketLabel => 'Supermarché (facultatif)';

  @override
  String get supermarketHint => 'ex. Esselunga, Coop, Lidl';

  @override
  String get supermarketHelper => 'Où vous faites vos courses (facultatif)';

  @override
  String get close => 'Fermer';

  @override
  String get perPiece => 'le paquet';

  @override
  String get perKg => 'le kg';

  @override
  String get perLitre => 'le litre';

  @override
  String get priceLabel => 'Prix';

  @override
  String get invalidPrice => 'Saisissez un prix, ex. 1,29';

  @override
  String get privacyRequired =>
      'Vous devez accepter la politique de confidentialité pour vous inscrire';

  @override
  String get acceptPrivacyPrefix => 'J\'ai lu et j\'accepte la ';

  @override
  String get acceptPrivacySuffix => '';

  @override
  String get privacyPolicy => 'politique de confidentialité';

  @override
  String get termsRequired =>
      'Vous devez accepter les conditions d\'utilisation pour vous inscrire';

  @override
  String get acceptTermsPrefix => 'J\'accepte les ';

  @override
  String get termsOfUse => 'conditions d\'utilisation';

  @override
  String get acceptTermsSuffix =>
      ' : je suis responsable des contenus que j\'ajoute';

  @override
  String get newsletterConsent =>
      'Je veux recevoir la newsletter de Lista Spesa Facile';

  @override
  String get newsletterOptional => 'Facultatif';

  @override
  String get socialPrivacyNotice =>
      'En continuant avec Google ou Amazon, vous acceptez la ';

  @override
  String get socialTermsJoin => ' et les ';

  @override
  String get myPrices => 'Mes prix';

  @override
  String get myPrice => 'Mon prix';

  @override
  String get addMyPrice => 'Ajouter un prix';

  @override
  String get editMyPrice => 'Modifier le prix';

  @override
  String get productRequired => 'Saisissez le produit';

  @override
  String get noteOptional => 'Note (facultatif)';

  @override
  String get myPricesPrivate => 'Vous seul voyez vos prix.';

  @override
  String get myPriceSaved => 'Prix enregistré dans « Mes prix »';

  @override
  String get searchMyPrices => 'Rechercher un produit ou un magasin';

  @override
  String get noMyPrices =>
      'Aucun prix. Ajoutez-en un ici ou depuis le menu ⋮ d\'un produit de la liste.';

  @override
  String get noMyPricesFound => 'Aucun prix trouvé.';

  @override
  String deleteMyPriceQuestion(String product) {
    return 'Supprimer le prix de $product ?';
  }

  @override
  String get info => 'Infos';

  @override
  String get noProductInfo =>
      'Aucune information trouvée sur Open Food Facts pour ce produit.';

  @override
  String get similarProductNotice =>
      'Produit similaire trouvé d\'après le nom : ce n\'est peut-être pas exactement le vôtre.';

  @override
  String get barcode => 'Code-barres';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié';

  @override
  String get forCoeliacs => 'Cœliaques';

  @override
  String get glutenFree => 'sans gluten';

  @override
  String get containsGluten => 'contient du gluten';

  @override
  String get vegetarian => 'Végétarien';

  @override
  String get vegan => 'Végan';

  @override
  String get yes => 'oui';

  @override
  String get no => 'non';

  @override
  String get palmOil => 'Huile de palme';

  @override
  String get palmOilFree => 'sans';

  @override
  String get containsPalmOil => 'contient';

  @override
  String get lactose => 'Lactose';

  @override
  String get lactoseFree => 'sans lactose';

  @override
  String get nutritionPer100 => 'Valeurs nutritionnelles pour 100 g';

  @override
  String get nutrientFat => 'Matières grasses';

  @override
  String get nutrientSaturatedFat => 'dont acides gras saturés';

  @override
  String get nutrientCarbohydrates => 'Glucides';

  @override
  String get nutrientSugars => 'dont sucres';

  @override
  String get nutrientFiber => 'Fibres';

  @override
  String get nutrientProteins => 'Protéines';

  @override
  String get nutrientSalt => 'Sel';

  @override
  String get noNutritionInfo => 'Il n\'y a pas d\'informations nutritionnelles';

  @override
  String get waterMinerals => 'Composition par litre';

  @override
  String get mineralCalcium => 'Calcium';

  @override
  String get mineralMagnesium => 'Magnésium';

  @override
  String get mineralSodium => 'Sodium';

  @override
  String get mineralPotassium => 'Potassium';

  @override
  String get mineralBicarbonate => 'Bicarbonates';

  @override
  String get mineralChloride => 'Chlorures';

  @override
  String get mineralSulphate => 'Sulfates';

  @override
  String get mineralNitrate => 'Nitrates';

  @override
  String get mineralFluoride => 'Fluorures';

  @override
  String get mineralSilica => 'Silice';

  @override
  String get allergens => 'Allergènes';

  @override
  String mayContainTraces(String list) {
    return 'Peut contenir des traces de : $list';
  }

  @override
  String get ingredients => 'Ingrédients';

  @override
  String get openFoodFactsPage => 'Voir sur Open Food Facts';

  @override
  String get openFoodFactsSource =>
      'Données d\'Open Food Facts (licence ODbL) : elles peuvent être incomplètes, vérifiez toujours l\'étiquette.';

  @override
  String get allergenGluten => 'Gluten';

  @override
  String get allergenCrustaceans => 'Crustacés';

  @override
  String get allergenEggs => 'Œufs';

  @override
  String get allergenFish => 'Poisson';

  @override
  String get allergenPeanuts => 'Arachides';

  @override
  String get allergenSoybeans => 'Soja';

  @override
  String get allergenMilk => 'Lait';

  @override
  String get allergenNuts => 'Fruits à coque';

  @override
  String get allergenCelery => 'Céleri';

  @override
  String get allergenMustard => 'Moutarde';

  @override
  String get allergenSesame => 'Sésame';

  @override
  String get allergenSulphites => 'Sulfites';

  @override
  String get allergenLupin => 'Lupin';

  @override
  String get allergenMolluscs => 'Mollusques';

  @override
  String get permission => 'Autorisation';

  @override
  String get permissionRead => 'Lecture seule';

  @override
  String get permissionReadWrite => 'Lecture et modification';
}
