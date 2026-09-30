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
  String get readOnly => 'Lecture seule';

  @override
  String get userCanEdit => 'peut modifier';

  @override
  String get userReadOnly => 'lecture seule';

  @override
  String get invalidEmail => 'Saisissez un e-mail valide';

  @override
  String get enterRegisteredEmail => 'Saisissez l\'e-mail d\'un utilisateur inscrit';

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
  String get errNetwork => 'Impossible de joindre le serveur. Vérifiez la connexion.';

  @override
  String get errSessionExpired => 'Session expirée. Reconnectez-vous.';

  @override
  String get errForbidden => 'Vous n\'avez pas l\'autorisation pour cette opération.';

  @override
  String get errNotFound => 'Élément introuvable (il a peut-être été supprimé).';

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
    return 'Le serveur n\'est pas encore relié à $provider. L\'administrateur du serveur doit enregistrer l\'application auprès de $provider et saisir l\'ID et le secret dans le fichier .env (voir le README, \"Accesso con Google, Facebook e Amazon\").\n\nEn attendant, vous pouvez vous inscrire avec e-mail et mot de passe.';
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
  String get deleteListSharedInfo => 'La liste disparaîtra aussi pour les utilisateurs avec qui elle est partagée.';

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
  String get noLists => 'Aucune liste.\nCréez-en une avec le bouton « Nouvelle liste ».';

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
  String get renameLocked => 'Le propriétaire n\'autorise pas le changement de nom';

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
  String get willBeNotified => 'Il recevra une notification quand vous créerez la liste';

  @override
  String get permissions => 'Autorisations';

  @override
  String get membersCanRenameTitle => 'Ceux qui peuvent modifier peuvent aussi changer le nom';

  @override
  String get membersCanRenameOn => 'Les utilisateurs autorisés à modifier peuvent renommer la liste';

  @override
  String get membersCanRenameOff => 'Vous seul pouvez changer le nom ; les autres modifient les articles';

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
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count jours', one: '1 jour');
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count heures', one: '1 heure');
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count minutes', one: '1 minute');
    return '$_temp0';
  }

  @override
  String get durationMoments => 'quelques instants';

  @override
  String listAnd(String head, String last) {
    return '$head et $last';
  }

  @override
  String get canEditSubtitle => 'Ajoute, coche et supprime des articles';

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
  String get deleteAllNotificationsQuestion => 'Supprimer toutes les notifications ?';

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
  String get serviceChannelDescription => 'Garde l\'application connectée pour recevoir listes et messages même fermée';

  @override
  String get serviceNotificationText => 'Prête à recevoir listes et messages';

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
  String get voiceNoMatch => 'Je n\'ai rien entendu : touchez le micro et parlez tout de suite.';

  @override
  String get voiceNetwork => 'Reconnaissance vocale injoignable : vérifiez la connexion.';

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
  String get deleteListInfo => 'Elle sera aussi supprimée pour ceux qui la partagent.';

  @override
  String get leaveListQuestion => 'Quitter la liste ?';

  @override
  String get leaveListInfo => 'Vous ne la verrez plus jusqu\'à ce qu\'elle soit à nouveau partagée avec vous.';

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
  String get deleteFromListInfo => 'Différent de « pris » : l\'article disparaît pour tout le monde';

  @override
  String get sendOrExportList => 'Envoyer ou exporter la liste';

  @override
  String get exportTextInfo => 'Texte avec les coches, vous choisissez la discussion';

  @override
  String get exportPdfInfo => 'À imprimer ou envoyer (aussi sur WhatsApp ou Telegram)';

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
  String get emptyList => 'La liste est vide.\nAjoutez le premier article ci-dessous.';

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
  String get quantityAndWeight => 'Quantité et poids';

  @override
  String get changeQuantityAndWeight => 'Changer quantité et poids';

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
  String get department => 'Rayon';

  @override
  String get departmentHelper => 'Reconnu d\'après le nom : changez-le s\'il est incorrect';

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
  String get supermarketHelper => 'S\'il s\'agit d\'une enseigne connue, la liste affiche des prix indicatifs';

  @override
  String estimatedTotal(String chain) {
    return 'Total estimé chez $chain*';
  }

  @override
  String get pricesIndicativeNote =>
      '* Prix indicatifs selon l\'enseigne : ils peuvent varier d\'un magasin à l\'autre et selon les promotions.';

  @override
  String pricedOf(int priced, int total) {
    return 'Prix pour $priced produits sur $total';
  }

  @override
  String noPricesForChain(String chain) {
    return 'Aucun prix disponible chez $chain pour ces produits';
  }

  @override
  String get compareChains => 'Comparer les enseignes';

  @override
  String get currentChain => 'choisie';

  @override
  String get noChainPrices => 'Il n\'y a pas encore de prix pour les produits de cette liste.';

  @override
  String get close => 'Fermer';

  @override
  String get country => 'Pays';

  @override
  String get cityLabel => 'Ville';

  @override
  String get cityHint => 'ex. Milan';

  @override
  String get localityLabel => 'Quartier ou localité (facultatif)';

  @override
  String get localityHint => 'ex. Città Studi';

  @override
  String get zoneHelper => 'Les prix signalés dans cette zone sont prioritaires';

  @override
  String get perPiece => 'le paquet';

  @override
  String get perKg => 'le kg';

  @override
  String get perLitre => 'le litre';

  @override
  String get listPrice => 'Tarif indicatif';

  @override
  String get priceMenu => 'Prix';

  @override
  String get priceLabel => 'Prix';

  @override
  String get addPrice => 'Ajouter le prix';

  @override
  String get correctPrice => 'Corriger le prix';

  @override
  String get priceCorrected => 'Prix mis à jour : merci !';

  @override
  String get noPriceYet => 'Pas encore de prix pour ce produit dans cette enseigne.';

  @override
  String get chooseKnownSupermarket => 'Pour les prix, choisissez dans la liste le supermarché d\'une enseigne connue.';

  @override
  String get previousReports => 'Signalements précédents';

  @override
  String get invalidPrice => 'Saisissez un prix, ex. 1,29';

  @override
  String get priceReportPrivacy =>
      'Le prix s\'appliquera à tous ceux qui font leurs courses dans cette enseigne. Les autres verront votre nom et l\'heure, pas votre e-mail.';
}
