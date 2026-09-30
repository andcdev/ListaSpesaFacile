// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Retry';

  @override
  String get remove => 'Remove';

  @override
  String get add => 'Add';

  @override
  String get confirm => 'Confirm';

  @override
  String get edit => 'Edit';

  @override
  String get share => 'Share';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get name => 'Name';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get canEdit => 'Can edit';

  @override
  String get readOnly => 'Read only';

  @override
  String get userCanEdit => 'can edit';

  @override
  String get userReadOnly => 'read only';

  @override
  String get invalidEmail => 'Enter a valid email';

  @override
  String get enterRegisteredEmail => 'Enter the email of a registered user';

  @override
  String get atLeast8 => 'At least 8 characters';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match';

  @override
  String get nobody => 'Nobody.';

  @override
  String get myLists => 'My lists';

  @override
  String get other => 'Other';

  @override
  String get language => 'Language';

  @override
  String languageValue(String language) {
    return 'Language: $language';
  }

  @override
  String languageSystem(String language) {
    return 'Same as phone ($language)';
  }

  @override
  String get background => 'Background';

  @override
  String backgroundValue(String value) {
    return 'Background: $value';
  }

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'Same as phone';

  @override
  String get errTimeout => 'The server is not responding. Try again later.';

  @override
  String get errNetwork => 'Cannot reach the server. Check your connection.';

  @override
  String get errSessionExpired => 'Session expired. Please sign in again.';

  @override
  String get errForbidden => 'You don\'t have permission to do this.';

  @override
  String get errNotFound => 'Not found (it may have been deleted).';

  @override
  String get errTooMany => 'Too many attempts. Wait a minute.';

  @override
  String get errServer => 'Server error. Try again later.';

  @override
  String errUnexpected(int status) {
    return 'Unexpected error ($status).';
  }

  @override
  String get checkYourEmail => 'Check your email.';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get forgotPasswordQuestion => 'Forgot password?';

  @override
  String get signIn => 'Sign in';

  @override
  String get noAccount => 'Don\'t have an account? Sign up';

  @override
  String get server => 'Server';

  @override
  String get serverAddress => 'Server address';

  @override
  String socialNotActiveTitle(String provider) {
    return 'Sign-in with $provider not active yet';
  }

  @override
  String socialNotActiveBody(String provider) {
    return 'The server is not connected to $provider yet. The server administrator must register the app with $provider and put its ID and secret in the .env file (see the README, \"Accesso con Google, Facebook e Amazon\").\n\nIn the meantime you can sign up with email and password.';
  }

  @override
  String get or => 'or';

  @override
  String continueWith(String provider) {
    return 'Continue with $provider';
  }

  @override
  String socialOpenFailed(String provider) {
    return 'Cannot open sign-in with $provider.';
  }

  @override
  String get socialFailed => 'Sign-in failed.';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get showPassword => 'Show password';

  @override
  String get createAccount => 'Create an account';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get signUp => 'Sign up';

  @override
  String get forgotPasswordTitle => 'Forgot password';

  @override
  String get resetCodeSentInfo =>
      'We sent you a 6-digit code (check your spam folder too). Enter it and choose a new password.';

  @override
  String get resetInfo => 'Enter your account\'s email: we\'ll send you a code to choose a new password.';

  @override
  String get resetCodeLabel => 'Code received by email';

  @override
  String get resetCodeInvalid => 'The code has 6 digits';

  @override
  String get newPassword => 'New password';

  @override
  String get setNewPassword => 'Set the new password';

  @override
  String get sendCode => 'Send the code';

  @override
  String get resendCode => 'Didn\'t get it? Send again';

  @override
  String deleteListNamed(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteListSharedInfo => 'The list will also disappear for the users it is shared with.';

  @override
  String get profilePhotoTitle => 'Profile photo (shown in the chat)';

  @override
  String get profilePhotoUpdated => 'Profile photo updated.';

  @override
  String get globalSharing => 'Share all lists';

  @override
  String get profile => 'Profile';

  @override
  String get logoutQuestion => 'Sign out?';

  @override
  String get logout => 'Sign out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountQuestion => 'Delete your account?';

  @override
  String get deleteAccountMessage =>
      'Deletion is permanent and can\'t be undone. Your lists, with their items, photos and chats, are deleted for the people you share them with too, and you leave other people\'s lists.';

  @override
  String get deleteAccountConfirm => 'Delete permanently';

  @override
  String get accountDeleted => 'Account deleted.';

  @override
  String get addProfilePhoto => 'Add profile photo';

  @override
  String get changeProfilePhoto => 'Change profile photo';

  @override
  String get newList => 'New list';

  @override
  String get noUpcoming => 'No shopping planned.';

  @override
  String get upcomingTab => 'Upcoming';

  @override
  String pastTab(int count) {
    return 'Past · $count';
  }

  @override
  String toBuyCount(int count) {
    return '$count to buy';
  }

  @override
  String get listCompleteBadge => 'Done';

  @override
  String get listEmptyBadge => 'Empty';

  @override
  String viewingNowShort(String names) {
    return 'here now: $names';
  }

  @override
  String byOwner(String name) {
    return 'by $name';
  }

  @override
  String get noLists => 'No lists.\nCreate one with the \"New list\" button.';

  @override
  String get realtimeOn => 'Live updates on';

  @override
  String get realtimeOff => 'Live updates not connected';

  @override
  String get notifications => 'Notifications';

  @override
  String get editList => 'Edit list';

  @override
  String get alreadyAdded => 'Already added';

  @override
  String get listNameHint => 'e.g. Weekly shopping';

  @override
  String get renameLocked => 'The owner doesn\'t allow renaming';

  @override
  String get listNameRequired => 'Give the list a name';

  @override
  String get notesLabel => 'Notes (optional)';

  @override
  String get notesHint => 'e.g. supermarket, offers…';

  @override
  String get reminder => 'Reminder';

  @override
  String get noReminder => 'No reminder';

  @override
  String durationBefore(String duration) {
    return '$duration before';
  }

  @override
  String get customReminderOption => 'Custom…';

  @override
  String get whoToNotify => 'Who to notify';

  @override
  String get reminderOwner => 'Only the creator';

  @override
  String get reminderMembers => 'Only the recipients';

  @override
  String get reminderAll => 'Creator and recipients';

  @override
  String get shareWith => 'Share with';

  @override
  String get userEmail => 'User\'s email';

  @override
  String get userEmailOptional => 'User\'s email (optional)';

  @override
  String get willBeNotified => 'They\'ll be notified when you create the list';

  @override
  String get permissions => 'Permissions';

  @override
  String get membersCanRenameTitle => 'Editors can also rename the list';

  @override
  String get membersCanRenameOn => 'Users who can edit can rename the list';

  @override
  String get membersCanRenameOff => 'Only you can rename it; the others edit the items';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get createList => 'Create list';

  @override
  String get customReminder => 'Custom reminder';

  @override
  String get howEarly => 'How early';

  @override
  String get unitMinutes => 'minutes';

  @override
  String get unitHours => 'hours';

  @override
  String get unitDays => 'days';

  @override
  String get reminderRange => 'From 1 minute to 30 days';

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count days', one: '1 day');
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count hours', one: '1 hour');
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count minutes', one: '1 minute');
    return '$_temp0';
  }

  @override
  String get durationMoments => 'a few moments';

  @override
  String listAnd(String head, String last) {
    return '$head and $last';
  }

  @override
  String get canEditSubtitle => 'Adds, checks off and deletes items';

  @override
  String listSharedWith(String email) {
    return 'List shared with $email';
  }

  @override
  String removeUserQuestion(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeUserInfo => 'They will no longer see this list.';

  @override
  String get sharedWith => 'Shared with';

  @override
  String get nobodyYet => 'Nobody yet.';

  @override
  String get globalShareHint => 'To share all your lists with someone, use \"Share all lists\" on the main screen.';

  @override
  String allListsSharedWith(String email) {
    return 'All your lists are now shared with $email';
  }

  @override
  String stopSharingWith(String name) {
    return 'Stop sharing with $name?';
  }

  @override
  String stopReceivingFrom(String name) {
    return 'Stop seeing $name\'s lists?';
  }

  @override
  String get globalShareInfo =>
      'The people listed here see all your lists, including the ones you create in the future.';

  @override
  String get iShareWith => 'I share all my lists with';

  @override
  String get sharedWithMe => 'They share all their lists with me';

  @override
  String get stopReceiving => 'Stop receiving';

  @override
  String get deleteAllNotificationsQuestion => 'Delete all notifications?';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get deleteAll => 'Delete all';

  @override
  String get noNotifications => 'No notifications.';

  @override
  String get channelName => 'Shopping lists';

  @override
  String get channelDescription => 'Reminders, shares and list messages';

  @override
  String get you => 'You';

  @override
  String get serviceChannelName => 'Background connection';

  @override
  String get serviceChannelDescription =>
      'Keeps the app connected to receive lists and messages even when it is closed';

  @override
  String get serviceNotificationText => 'Ready to receive lists and messages';

  @override
  String reminderTitle(String name) {
    return 'Reminder: $name';
  }

  @override
  String reminderBody(String duration) {
    return 'Shopping is in $duration.';
  }

  @override
  String get sendPhoto => 'Send a photo';

  @override
  String get deleteMessageQuestion => 'Delete the message?';

  @override
  String get deleteMessageInfo => 'It will disappear for everyone.';

  @override
  String get writeMessage => 'Write a message';

  @override
  String get send => 'Send';

  @override
  String get deletedUser => 'User';

  @override
  String get messageReceived => 'Received';

  @override
  String get messageSent => 'Sent';

  @override
  String get emptyChat =>
      'No messages.\nWrite, dictate with the microphone or send a photo to the people sharing the list: \"I\'m at the dairy aisle, anything missing?\"';

  @override
  String get pickFromGallery => 'Choose from gallery';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get imageUnavailable => 'Image not available';

  @override
  String get voiceUnavailable =>
      'Speech recognition is not available on this phone: install or enable the Google app (Google speech recognition).';

  @override
  String get voiceMicPermission => 'To dictate, allow the app to use the microphone in the phone settings.';

  @override
  String get voiceNoMatch => 'I didn\'t hear anything: tap the microphone and speak right away.';

  @override
  String get voiceNetwork => 'Speech recognition unreachable: check your connection.';

  @override
  String get voiceBusy => 'The microphone is busy, try again in a moment.';

  @override
  String voiceLanguageUnavailable(String language) {
    return '$language is not available for dictation: download it in the Google voice settings.';
  }

  @override
  String get voiceNotUnderstood => 'I didn\'t understand, try again.';

  @override
  String get stopListening => 'Stop listening';

  @override
  String get dictate => 'Dictate';

  @override
  String get exportNotFound => 'not found';

  @override
  String exportTaken(int taken, int total) {
    return '$taken of $total taken';
  }

  @override
  String pdfPage(int page, int total) {
    return 'page $page of $total';
  }

  @override
  String pdfSummary(int taken, int missing, int todo) {
    return 'Taken: $taken · Not found: $missing · To buy: $todo';
  }

  @override
  String get numericDatePattern => 'MM/dd/y';

  @override
  String get listUnavailable => 'The list is no longer available.';

  @override
  String get deleteListQuestion => 'Delete the list?';

  @override
  String get deleteListInfo => 'It will also be deleted for everyone sharing it.';

  @override
  String get leaveListQuestion => 'Leave the list?';

  @override
  String get leaveListInfo => 'You won\'t see it again until it is shared with you again.';

  @override
  String get leave => 'Leave';

  @override
  String get listPhotoUpdated => 'List photo updated.';

  @override
  String photoOf(String name) {
    return 'Photo of $name';
  }

  @override
  String deleteItemQuestion(String name) {
    return 'Delete \"$name\" from the list?';
  }

  @override
  String get deleteItemInfo =>
      'It will disappear from the list for everyone. If you just put it in the cart, check it off as taken.';

  @override
  String get putBackToBuy => 'Back to buy';

  @override
  String get takenInCart => 'Taken (in the cart)';

  @override
  String get notFound => 'Not found';

  @override
  String get addPhoto => 'Add a photo';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get deleteFromList => 'Delete from the list';

  @override
  String get deleteFromListInfo => 'Not the same as \"taken\": the item disappears for everyone';

  @override
  String get sendOrExportList => 'Send or export the list';

  @override
  String get exportTextInfo => 'Text with check marks, you choose the chat';

  @override
  String get exportPdfInfo => 'To print or send (also on WhatsApp or Telegram)';

  @override
  String get otherApps => 'Other apps';

  @override
  String appNotInstalled(String app) {
    return '$app is not installed on this phone.';
  }

  @override
  String get list => 'List';

  @override
  String get closeChat => 'Close the chat';

  @override
  String get chat => 'Chat';

  @override
  String get sendOrExport => 'Send or export';

  @override
  String get clearTaken => 'Remove taken items';

  @override
  String get deleteList => 'Delete list';

  @override
  String get leaveList => 'Leave list';

  @override
  String get cannotLoadList => 'Cannot load the list.';

  @override
  String reminderBefore(String duration) {
    return 'Reminder $duration before';
  }

  @override
  String get readOnlyAccess => 'You have read-only access';

  @override
  String get emptyList => 'The list is empty.\nAdd the first item below.';

  @override
  String inCart(int checked, int total) {
    return '$checked of $total in the cart';
  }

  @override
  String notFoundCount(int count) {
    return '$count not found';
  }

  @override
  String takenBy(String name) {
    return 'taken by $name';
  }

  @override
  String get notFoundLower => 'not found';

  @override
  String notFoundBy(String name) {
    return 'not found ($name)';
  }

  @override
  String get markToBuyAgain => 'Mark as to buy again';

  @override
  String get markMissing => 'Not taken (not found)';

  @override
  String get itemMenu => 'Edit, photo or delete';

  @override
  String get onlyYouViewing => 'Only you are viewing this list';

  @override
  String viewingNow(String names) {
    return 'Here now: $names';
  }

  @override
  String typing(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names are typing…',
      one: '$names is typing…',
    );
    return '$_temp0';
  }

  @override
  String get productPhoto => 'Product photo';

  @override
  String get oftenBought => 'You often buy:';

  @override
  String timesInList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Already added $count times',
      one: 'Already added once',
    );
    return '$_temp0';
  }

  @override
  String get addProductHint => 'Add product...';

  @override
  String get quantityAndWeight => 'Quantity and weight';

  @override
  String get changeQuantityAndWeight => 'Change quantity and weight';

  @override
  String get amountExampleError => 'Enter a number, e.g. 500 or 1.5';

  @override
  String get quantity => 'Quantity';

  @override
  String get less => 'Less';

  @override
  String get more => 'More';

  @override
  String get weightOrVolume => 'Weight or volume';

  @override
  String get amountHint => 'e.g. 500';

  @override
  String get clearMeasure => 'Clear';

  @override
  String get done => 'Done';

  @override
  String get invalidImageUrl => 'Enter a link starting with https://';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String get emojiTooLong => 'One or two emoji at most';

  @override
  String get addProductPhoto => 'Add a product photo';

  @override
  String get changeOrRemovePhoto => 'Change or remove the photo';

  @override
  String get editItem => 'Edit item';

  @override
  String get product => 'Product';

  @override
  String get quantityOptional => 'Quantity (optional)';

  @override
  String get weightOptional => 'Weight or volume (optional)';

  @override
  String get department => 'Aisle';

  @override
  String get departmentHelper => 'Recognized from the name: change it if it\'s wrong';

  @override
  String get emojiOptional => 'Emoji (optional)';

  @override
  String recognizedEmoji(String emoji) {
    return 'Recognized: $emoji';
  }

  @override
  String get fromName => 'from the name';

  @override
  String get useRecognizedEmoji => 'Use the one recognized from the name';

  @override
  String get imageLinkOptional => 'Image link (optional)';

  @override
  String get supermarketLabel => 'Supermarket (optional)';

  @override
  String get supermarketHint => 'e.g. Esselunga, Coop, Lidl';

  @override
  String get supermarketHelper => 'Where you shop (optional)';

  @override
  String get close => 'Close';

  @override
  String get perPiece => 'per pack';

  @override
  String get perKg => 'per kg';

  @override
  String get perLitre => 'per litre';

  @override
  String get priceLabel => 'Price';

  @override
  String get invalidPrice => 'Enter a price, e.g. 1.29';

  @override
  String get privacyRequired => 'You must accept the privacy policy to sign up';

  @override
  String get acceptPrivacyPrefix => 'I have read and accept the ';

  @override
  String get acceptPrivacySuffix => '';

  @override
  String get privacyPolicy => 'privacy policy';

  @override
  String get newsletterConsent => 'I want to receive the Lista Spesa Facile newsletter';

  @override
  String get newsletterOptional => 'Optional: you can change it anytime from the profile menu';

  @override
  String get socialPrivacyNotice => 'By continuing with Google or Facebook you accept the ';

  @override
  String get newsletter => 'Newsletter';

  @override
  String get myPrices => 'My prices';

  @override
  String get myPrice => 'My price';

  @override
  String get addMyPrice => 'Add price';

  @override
  String get editMyPrice => 'Edit price';

  @override
  String get productRequired => 'Enter the product';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get myPricesPrivate => 'Only you can see your prices.';

  @override
  String get myPriceSaved => 'Price saved in \"My prices\"';

  @override
  String get searchMyPrices => 'Search product or supermarket';

  @override
  String get noMyPrices => 'No prices yet. Add one here or from the ⋮ menu of a product in a list.';

  @override
  String get noMyPricesFound => 'No prices found.';

  @override
  String deleteMyPriceQuestion(String product) {
    return 'Delete the price of $product?';
  }

  @override
  String get info => 'Info';

  @override
  String get noProductInfo => 'No information found on Open Food Facts for this product.';

  @override
  String get similarProductNotice => 'Similar product found by name: it may not be exactly yours.';

  @override
  String get barcode => 'Barcode';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get forCoeliacs => 'Coeliacs';

  @override
  String get glutenFree => 'gluten free';

  @override
  String get containsGluten => 'contains gluten';

  @override
  String get vegetarian => 'Vegetarian';

  @override
  String get vegan => 'Vegan';

  @override
  String get yes => 'yes';

  @override
  String get no => 'no';

  @override
  String get palmOil => 'Palm oil';

  @override
  String get palmOilFree => 'none';

  @override
  String get containsPalmOil => 'contains';

  @override
  String get lactose => 'Lactose';

  @override
  String get lactoseFree => 'lactose free';

  @override
  String get notIndicated => 'not stated';

  @override
  String get nutritionPer100 => 'Nutrition facts per 100 g';

  @override
  String get nutrientFat => 'Fat';

  @override
  String get nutrientSaturatedFat => 'of which saturates';

  @override
  String get nutrientCarbohydrates => 'Carbohydrates';

  @override
  String get nutrientSugars => 'of which sugars';

  @override
  String get nutrientFiber => 'Fibre';

  @override
  String get nutrientProteins => 'Protein';

  @override
  String get nutrientSalt => 'Salt';

  @override
  String get allergens => 'Allergens';

  @override
  String mayContainTraces(String list) {
    return 'May contain traces of: $list';
  }

  @override
  String get ingredients => 'Ingredients';

  @override
  String get openFoodFactsPage => 'View on Open Food Facts';

  @override
  String get openFoodFactsSource =>
      'Data from Open Food Facts (ODbL licence): it may be incomplete, always check the label.';

  @override
  String get allergenGluten => 'Gluten';

  @override
  String get allergenCrustaceans => 'Crustaceans';

  @override
  String get allergenEggs => 'Eggs';

  @override
  String get allergenFish => 'Fish';

  @override
  String get allergenPeanuts => 'Peanuts';

  @override
  String get allergenSoybeans => 'Soy';

  @override
  String get allergenMilk => 'Milk';

  @override
  String get allergenNuts => 'Tree nuts';

  @override
  String get allergenCelery => 'Celery';

  @override
  String get allergenMustard => 'Mustard';

  @override
  String get allergenSesame => 'Sesame';

  @override
  String get allergenSulphites => 'Sulphites';

  @override
  String get allergenLupin => 'Lupin';

  @override
  String get allergenMolluscs => 'Molluscs';
}
