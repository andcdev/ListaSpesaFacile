// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get save => 'Guardar';

  @override
  String get ok => 'Aceptar';

  @override
  String get retry => 'Reintentar';

  @override
  String get remove => 'Quitar';

  @override
  String get add => 'Añadir';

  @override
  String get confirm => 'Confirmar';

  @override
  String get edit => 'Editar';

  @override
  String get share => 'Compartir';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get name => 'Nombre';

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get yesterday => 'Ayer';

  @override
  String get canEdit => 'Puede editar';

  @override
  String get userCanEdit => 'puede editar';

  @override
  String get userReadOnly => 'solo lectura';

  @override
  String get invalidEmail => 'Introduce un correo válido';

  @override
  String get enterRegisteredEmail =>
      'Introduce el correo de un usuario registrado';

  @override
  String get atLeast8 => 'Al menos 8 caracteres';

  @override
  String get confirmPassword => 'Confirmar contraseña';

  @override
  String get passwordsDontMatch => 'Las contraseñas no coinciden';

  @override
  String get nobody => 'Nadie.';

  @override
  String get myLists => 'Mis listas';

  @override
  String get other => 'Otros';

  @override
  String get language => 'Idioma';

  @override
  String languageValue(String language) {
    return 'Idioma: $language';
  }

  @override
  String languageSystem(String language) {
    return 'Como el teléfono ($language)';
  }

  @override
  String get background => 'Fondo';

  @override
  String backgroundValue(String value) {
    return 'Fondo: $value';
  }

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeSystem => 'Como el teléfono';

  @override
  String get errTimeout => 'El servidor no responde. Inténtalo más tarde.';

  @override
  String get errNetwork =>
      'No se puede contactar con el servidor. Comprueba la conexión.';

  @override
  String get errSessionExpired =>
      'La sesión ha caducado. Vuelve a iniciar sesión.';

  @override
  String get errForbidden => 'No tienes permiso para esta operación.';

  @override
  String get errNotFound => 'Elemento no encontrado (quizá se ha eliminado).';

  @override
  String get errTooMany => 'Demasiados intentos. Espera un minuto.';

  @override
  String get errServer => 'Error del servidor. Inténtalo más tarde.';

  @override
  String errUnexpected(int status) {
    return 'Error inesperado ($status).';
  }

  @override
  String get checkYourEmail => 'Revisa tu correo.';

  @override
  String get enterPassword => 'Introduce la contraseña';

  @override
  String get forgotPasswordQuestion => '¿Has olvidado la contraseña?';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get noAccount => '¿No tienes cuenta? Regístrate';

  @override
  String socialNotActiveTitle(String provider) {
    return 'Acceso con $provider aún no activo';
  }

  @override
  String socialNotActiveBody(String provider) {
    return 'El servidor aún no está conectado a $provider. Quien gestiona el servidor debe registrar la app en $provider e introducir el ID y el secret en el archivo .env (ver el README, \"Accesso con Google e Amazon\").\n\nMientras tanto puedes registrarte con correo y contraseña.';
  }

  @override
  String get or => 'o';

  @override
  String continueWith(String provider) {
    return 'Continuar con $provider';
  }

  @override
  String socialOpenFailed(String provider) {
    return 'No se puede abrir el acceso con $provider.';
  }

  @override
  String get socialFailed => 'No se ha podido iniciar sesión.';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get createAccount => 'Crear una cuenta';

  @override
  String get enterYourName => 'Introduce tu nombre';

  @override
  String get signUp => 'Registrarse';

  @override
  String get forgotPasswordTitle => 'Contraseña olvidada';

  @override
  String get resetCodeSentInfo =>
      'Te hemos enviado un código de 6 cifras (revisa también el spam). Introdúcelo y elige una contraseña nueva.';

  @override
  String get resetInfo =>
      'Introduce el correo de tu cuenta: te enviaremos un código para elegir una contraseña nueva.';

  @override
  String get resetCodeLabel => 'Código recibido por correo';

  @override
  String get resetCodeInvalid => 'El código tiene 6 cifras';

  @override
  String get newPassword => 'Contraseña nueva';

  @override
  String get setNewPassword => 'Establecer la contraseña nueva';

  @override
  String get sendCode => 'Enviar el código';

  @override
  String get resendCode => '¿No ha llegado? Enviar de nuevo';

  @override
  String deleteListNamed(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get deleteListSharedInfo =>
      'La lista también desaparecerá para los usuarios con quienes se comparte.';

  @override
  String get profilePhotoTitle => 'Foto de perfil (visible en el chat)';

  @override
  String get profilePhotoUpdated => 'Foto de perfil actualizada.';

  @override
  String get globalSharing => 'Compartir todas las listas';

  @override
  String get profile => 'Perfil';

  @override
  String get logoutQuestion => '¿Cerrar sesión?';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountQuestion => '¿Eliminar tu cuenta?';

  @override
  String get deleteAccountMessage =>
      'La eliminación es definitiva y no se puede deshacer. Tus listas, con sus artículos, fotos y chats, también se borran para las personas con quienes las compartes, y sales de las listas de los demás.';

  @override
  String get deleteAccountConfirm => 'Eliminar definitivamente';

  @override
  String get accountDeleted => 'Cuenta eliminada.';

  @override
  String get addProfilePhoto => 'Añadir foto de perfil';

  @override
  String get changeProfilePhoto => 'Cambiar foto de perfil';

  @override
  String get newList => 'Nueva lista';

  @override
  String get noUpcoming => 'No hay compras programadas.';

  @override
  String get upcomingTab => 'Programadas';

  @override
  String pastTab(int count) {
    return 'Pasadas · $count';
  }

  @override
  String toBuyCount(int count) {
    return '$count por coger';
  }

  @override
  String get listCompleteBadge => 'Completa';

  @override
  String get listEmptyBadge => 'Vacía';

  @override
  String viewingNowShort(String names) {
    return 'aquí ahora: $names';
  }

  @override
  String byOwner(String name) {
    return 'de $name';
  }

  @override
  String get noLists => 'No hay listas.\nCrea una con el botón «Nueva lista».';

  @override
  String get realtimeOn => 'Actualizaciones en tiempo real activas';

  @override
  String get realtimeOff => 'Tiempo real no conectado';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get editList => 'Editar lista';

  @override
  String get alreadyAdded => 'Ya añadido';

  @override
  String get listNameHint => 'p. ej. Compra semanal';

  @override
  String get renameLocked => 'El propietario no permite cambiar el nombre';

  @override
  String get listNameRequired => 'Ponle un nombre a la lista';

  @override
  String get notesLabel => 'Notas (opcional)';

  @override
  String get notesHint => 'p. ej. supermercado, ofertas…';

  @override
  String get reminder => 'Recordatorio';

  @override
  String get noReminder => 'Sin recordatorio';

  @override
  String durationBefore(String duration) {
    return '$duration antes';
  }

  @override
  String get customReminderOption => 'Personalizado…';

  @override
  String get whoToNotify => 'A quién avisar';

  @override
  String get reminderOwner => 'Solo el creador';

  @override
  String get reminderMembers => 'Solo los destinatarios';

  @override
  String get reminderAll => 'Creador y destinatarios';

  @override
  String get shareWith => 'Compartir con';

  @override
  String get userEmail => 'Correo del usuario';

  @override
  String get userEmailOptional => 'Correo del usuario (opcional)';

  @override
  String get willBeNotified =>
      'Recibirá una notificación cuando crees la lista';

  @override
  String get permissions => 'Permisos';

  @override
  String get membersCanRenameTitle =>
      'Quien puede editar también puede cambiar el nombre';

  @override
  String get membersCanRenameOn =>
      'Los usuarios con permiso de edición pueden renombrar la lista';

  @override
  String get membersCanRenameOff =>
      'Solo tú puedes cambiar el nombre; los demás editan los artículos';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get createList => 'Crear lista';

  @override
  String get customReminder => 'Recordatorio personalizado';

  @override
  String get howEarly => 'Cuánto antes';

  @override
  String get unitMinutes => 'minutos';

  @override
  String get unitHours => 'horas';

  @override
  String get unitDays => 'días';

  @override
  String get reminderRange => 'De 1 minuto a 30 días';

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutos',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get durationMoments => 'unos instantes';

  @override
  String listAnd(String head, String last) {
    return '$head y $last';
  }

  @override
  String listSharedWith(String email) {
    return 'Lista compartida con $email';
  }

  @override
  String removeUserQuestion(String name) {
    return '¿Quitar a $name?';
  }

  @override
  String get removeUserInfo => 'Ya no verá esta lista.';

  @override
  String get sharedWith => 'Compartida con';

  @override
  String get nobodyYet => 'Nadie, por ahora.';

  @override
  String get globalShareHint =>
      'Para compartir todas tus listas con alguien, usa «Compartir todas las listas» en la pantalla principal.';

  @override
  String allListsSharedWith(String email) {
    return 'Todas tus listas se comparten ahora con $email';
  }

  @override
  String stopSharingWith(String name) {
    return '¿Dejar de compartir con $name?';
  }

  @override
  String stopReceivingFrom(String name) {
    return '¿Dejar de ver las listas de $name?';
  }

  @override
  String get globalShareInfo =>
      'Las personas indicadas aquí ven todas tus listas, incluidas las que crees en el futuro.';

  @override
  String get iShareWith => 'Comparto todas mis listas con';

  @override
  String get sharedWithMe => 'Comparten todas sus listas conmigo';

  @override
  String get stopReceiving => 'Dejar de recibir';

  @override
  String get deleteAllNotificationsQuestion =>
      '¿Eliminar todas las notificaciones?';

  @override
  String get markAllRead => 'Marcar todas como leídas';

  @override
  String get deleteAll => 'Eliminar todas';

  @override
  String get noNotifications => 'No hay notificaciones.';

  @override
  String get channelName => 'Listas de la compra';

  @override
  String get channelDescription =>
      'Recordatorios, comparticiones y mensajes de las listas';

  @override
  String get you => 'Tú';

  @override
  String get serviceChannelName => 'Conexión en segundo plano';

  @override
  String get serviceChannelDescription =>
      'Mantiene la app conectada para recibir listas y mensajes aunque esté cerrada';

  @override
  String reminderTitle(String name) {
    return 'Recordatorio: $name';
  }

  @override
  String reminderBody(String duration) {
    return 'La compra es dentro de $duration.';
  }

  @override
  String get sendPhoto => 'Enviar una foto';

  @override
  String get deleteMessageQuestion => '¿Eliminar el mensaje?';

  @override
  String get deleteMessageInfo => 'Desaparecerá para todos.';

  @override
  String get writeMessage => 'Escribe un mensaje';

  @override
  String get send => 'Enviar';

  @override
  String get deletedUser => 'Usuario';

  @override
  String get messageReceived => 'Recibido';

  @override
  String get messageSent => 'Enviado';

  @override
  String get emptyChat =>
      'No hay mensajes.\nEscribe, dicta con el micrófono o envía una foto a quienes comparten la lista: «Estoy en la zona de frescos, ¿falta algo?»';

  @override
  String get pickFromGallery => 'Elegir de la galería';

  @override
  String get takePhoto => 'Hacer una foto';

  @override
  String get removePhoto => 'Quitar la foto';

  @override
  String get imageUnavailable => 'Imagen no disponible';

  @override
  String get voiceUnavailable =>
      'Reconocimiento de voz no disponible en este teléfono: instala o activa la app de Google (reconocimiento de voz de Google).';

  @override
  String get voiceMicPermission =>
      'Para dictar, permite que la app use el micrófono en los ajustes del teléfono.';

  @override
  String get voiceNoMatch =>
      'No he oído nada: toca el micrófono y habla enseguida.';

  @override
  String get voiceNetwork =>
      'Reconocimiento de voz no disponible: comprueba la conexión.';

  @override
  String get voiceBusy => 'El micrófono está ocupado, inténtalo en un momento.';

  @override
  String voiceLanguageUnavailable(String language) {
    return '$language no está disponible para dictar: descárgalo en los ajustes de voz de Google.';
  }

  @override
  String get voiceNotUnderstood => 'No te he entendido, inténtalo de nuevo.';

  @override
  String get stopListening => 'Dejar de escuchar';

  @override
  String get dictate => 'Dictar';

  @override
  String get exportNotFound => 'no encontrado';

  @override
  String exportTaken(int taken, int total) {
    return '$taken de $total cogidos';
  }

  @override
  String pdfPage(int page, int total) {
    return 'página $page de $total';
  }

  @override
  String pdfSummary(int taken, int missing, int todo) {
    return 'Cogidos: $taken · No encontrados: $missing · Por coger: $todo';
  }

  @override
  String get numericDatePattern => 'dd/MM/y';

  @override
  String get listUnavailable => 'La lista ya no está disponible.';

  @override
  String get deleteListQuestion => '¿Eliminar la lista?';

  @override
  String get deleteListInfo =>
      'También se eliminará para quienes la comparten.';

  @override
  String get leaveListQuestion => '¿Abandonar la lista?';

  @override
  String get leaveListInfo =>
      'No la volverás a ver hasta que te la vuelvan a compartir.';

  @override
  String get leave => 'Abandonar';

  @override
  String get listPhotoUpdated => 'Foto de la lista actualizada.';

  @override
  String photoOf(String name) {
    return 'Foto de $name';
  }

  @override
  String deleteItemQuestion(String name) {
    return '¿Eliminar «$name» de la lista?';
  }

  @override
  String get deleteItemInfo =>
      'Desaparecerá de la lista para todos. Si solo lo has metido en el carro, márcalo como cogido.';

  @override
  String get putBackToBuy => 'Volver a pendiente';

  @override
  String get takenInCart => 'Cogido (en el carro)';

  @override
  String get notFound => 'No encontrado';

  @override
  String get addPhoto => 'Añadir una foto';

  @override
  String get changePhoto => 'Cambiar foto';

  @override
  String get deleteFromList => 'Eliminar de la lista';

  @override
  String get deleteFromListInfo =>
      'No es lo mismo que «cogido»: el artículo desaparece para todos';

  @override
  String get sendOrExportList => 'Enviar o exportar la lista';

  @override
  String get exportTextInfo => 'Texto con las marcas, tú eliges el chat';

  @override
  String get exportPdfInfo =>
      'Para imprimir o enviar (también por WhatsApp o Telegram)';

  @override
  String get otherApps => 'Otras apps';

  @override
  String appNotInstalled(String app) {
    return '$app no está instalado en este teléfono.';
  }

  @override
  String get list => 'Lista';

  @override
  String get closeChat => 'Cerrar el chat';

  @override
  String get chat => 'Chat';

  @override
  String get sendOrExport => 'Enviar o exportar';

  @override
  String get clearTaken => 'Quitar artículos cogidos';

  @override
  String get deleteList => 'Eliminar lista';

  @override
  String get leaveList => 'Abandonar lista';

  @override
  String get cannotLoadList => 'No se puede cargar la lista.';

  @override
  String reminderBefore(String duration) {
    return 'Recordatorio $duration antes';
  }

  @override
  String get readOnlyAccess => 'Tienes acceso de solo lectura';

  @override
  String get emptyList =>
      'La lista está vacía.\nAñade el primer artículo aquí abajo.';

  @override
  String inCart(int checked, int total) {
    return '$checked de $total en el carro';
  }

  @override
  String notFoundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count no encontrados',
      one: '1 no encontrado',
    );
    return '$_temp0';
  }

  @override
  String takenBy(String name) {
    return 'cogido por $name';
  }

  @override
  String get notFoundLower => 'no encontrado';

  @override
  String notFoundBy(String name) {
    return 'no encontrado ($name)';
  }

  @override
  String get markToBuyAgain => 'Marcar de nuevo como pendiente';

  @override
  String get markMissing => 'No cogido (no encontrado)';

  @override
  String get itemMenu => 'Editar, foto o eliminar';

  @override
  String get onlyYouViewing => 'Solo tú estás viendo esta lista';

  @override
  String viewingNow(String names) {
    return 'Aquí ahora: $names';
  }

  @override
  String typing(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names están escribiendo…',
      one: '$names está escribiendo…',
    );
    return '$_temp0';
  }

  @override
  String get listPhoto => 'Foto de la lista';

  @override
  String get listPhotoUploadFailed =>
      'Lista creada, pero la foto no se ha subido: añádela desde el menú de la lista.';

  @override
  String get productPhoto => 'Foto del producto';

  @override
  String get oftenBought => 'Compras a menudo:';

  @override
  String timesInList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ya añadido $count veces',
      one: 'Ya añadido 1 vez',
    );
    return '$_temp0';
  }

  @override
  String get addProductHint => 'Añadir prod...';

  @override
  String get amountExampleError => 'Escribe un número, p. ej. 500 o 1,5';

  @override
  String get quantity => 'Cantidad';

  @override
  String get less => 'Menos';

  @override
  String get more => 'Más';

  @override
  String get weightOrVolume => 'Peso o volumen';

  @override
  String get weight => 'Peso';

  @override
  String get packages => 'Paquetes';

  @override
  String packageSize(String size) {
    return 'Paquete de $size';
  }

  @override
  String get amountHint => 'p. ej. 500';

  @override
  String get clearMeasure => 'Quitar';

  @override
  String get done => 'Hecho';

  @override
  String get invalidImageUrl => 'Introduce un enlace que empiece por https://';

  @override
  String get invalidNumber => 'Número no válido';

  @override
  String get emojiTooLong => 'Como mucho uno o dos emojis';

  @override
  String get addProductPhoto => 'Añadir una foto del producto';

  @override
  String get changeOrRemovePhoto => 'Cambiar o quitar la foto';

  @override
  String get editItem => 'Editar artículo';

  @override
  String get product => 'Producto';

  @override
  String get quantityOptional => 'Cantidad (opcional)';

  @override
  String get weightOptional => 'Peso o volumen (opcional)';

  @override
  String get packagesOptional => 'Paquetes (opcional)';

  @override
  String get weightOnlyOptional => 'Peso (opcional)';

  @override
  String get department => 'Sección';

  @override
  String get departmentHelper =>
      'Reconocida por el nombre: cámbiala si no es correcta';

  @override
  String get emojiOptional => 'Emoji (opcional)';

  @override
  String recognizedEmoji(String emoji) {
    return 'Reconocido: $emoji';
  }

  @override
  String get fromName => 'por el nombre';

  @override
  String get useRecognizedEmoji => 'Usar el reconocido por el nombre';

  @override
  String get imageLinkOptional => 'Enlace a una imagen (opcional)';

  @override
  String get supermarketLabel => 'Supermercado (opcional)';

  @override
  String get supermarketHint => 'p. ej. Esselunga, Coop, Lidl';

  @override
  String get supermarketHelper => 'Dónde haces la compra (opcional)';

  @override
  String get close => 'Cerrar';

  @override
  String get perPiece => 'por envase';

  @override
  String get perKg => 'el kg';

  @override
  String get perLitre => 'el litro';

  @override
  String get priceLabel => 'Precio';

  @override
  String get invalidPrice => 'Escribe un precio, p. ej. 1,29';

  @override
  String get privacyRequired =>
      'Debes aceptar la política de privacidad para registrarte';

  @override
  String get acceptPrivacyPrefix => 'He leído y acepto la ';

  @override
  String get acceptPrivacySuffix => '';

  @override
  String get privacyPolicy => 'política de privacidad';

  @override
  String get termsRequired =>
      'Debes aceptar las condiciones de uso para registrarte';

  @override
  String get acceptTermsPrefix => 'Acepto las ';

  @override
  String get termsOfUse => 'condiciones de uso';

  @override
  String get acceptTermsSuffix => ': soy responsable del contenido que añado';

  @override
  String get newsletterConsent =>
      'Quiero recibir la newsletter de Lista Spesa Facile';

  @override
  String get newsletterOptional => 'Opcional';

  @override
  String get socialPrivacyNotice =>
      'Al continuar con Google o Amazon aceptas la ';

  @override
  String get socialTermsJoin => ' y las ';

  @override
  String get myPrices => 'Mis precios';

  @override
  String get myPrice => 'Mi precio';

  @override
  String get addMyPrice => 'Añadir precio';

  @override
  String get editMyPrice => 'Editar precio';

  @override
  String get productRequired => 'Escribe el producto';

  @override
  String get noteOptional => 'Nota (opcional)';

  @override
  String get myPricesPrivate => 'Solo tú ves tus precios.';

  @override
  String get myPriceSaved => 'Precio guardado en «Mis precios»';

  @override
  String get guide => 'Guía';

  @override
  String guideStep(int step, int count) {
    return 'Paso $step de $count';
  }

  @override
  String get guideNext => 'Siguiente';

  @override
  String get guideGotIt => 'Entendido';

  @override
  String get skipGuide => 'Saltar guía';

  @override
  String get guideNewListTitle => 'Crea tu primera lista';

  @override
  String get guideNewListText =>
      'Toca «Nueva lista»: elige el nombre, el día y la hora de la compra y, si quieres, una foto y con quién compartirla. Luego se abre la lista, lista para los productos.';

  @override
  String get guideAddTitle => 'Escribe un producto';

  @override
  String get guideAddText =>
      'Escribe aquí o dicta con el micrófono. Mientras escribes aparecen sugerencias: lo que más compras y productos de marca con foto. Toca una para elegirla.';

  @override
  String get guidePlusTitle => 'Añadir a la lista';

  @override
  String get guidePlusText =>
      'Toca + (o una sugerencia): elige cantidad, peso o volumen según el producto y pulsa «Hecho». El producto va a su sección y quien comparte la lista lo ve enseguida.';

  @override
  String get guideShareTitle => 'Haz la compra juntos';

  @override
  String get guideShareText =>
      'Desde aquí invitas a quien hace la compra contigo: veréis la misma lista, en tiempo real. En el súper, toca el círculo junto a un producto para marcarlo como cogido.';

  @override
  String get filterLists => 'Filtrar las listas';

  @override
  String get sortOrder => 'Orden';

  @override
  String get dateAscending => 'Fecha ascendente';

  @override
  String get dateDescending => 'Fecha descendente';

  @override
  String get filterPerson => 'Compartidas con';

  @override
  String get everyone => 'Todos';

  @override
  String get filterPeriod => 'Fecha del evento';

  @override
  String get allDates => 'Todas';

  @override
  String get last15Days => 'Últimos 15 días';

  @override
  String get last30Days => 'Últimos 30 días';

  @override
  String get next15Days => 'Próximos 15 días';

  @override
  String get next30Days => 'Próximos 30 días';

  @override
  String get chooseDates => 'Del … al …';

  @override
  String dateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get productInLists => 'Producto en la lista';

  @override
  String get productInListsHint => 'p. ej. leche';

  @override
  String containsProduct(String product) {
    return 'Con «$product»';
  }

  @override
  String get resetFilters => 'Restablecer';

  @override
  String get applyFilters => 'Aplicar';

  @override
  String get noListsMatch => 'Ninguna lista coincide con estos filtros.';

  @override
  String get searchMyPrices => 'Buscar producto o supermercado';

  @override
  String get noMyPrices =>
      'Ningún precio. Añádelo aquí o desde el menú ⋮ de un producto de la lista.';

  @override
  String get noMyPricesFound => 'No se han encontrado precios.';

  @override
  String deleteMyPriceQuestion(String product) {
    return '¿Eliminar el precio de $product?';
  }

  @override
  String get info => 'Info';

  @override
  String get noProductInfo =>
      'No se ha encontrado información para este producto.';

  @override
  String get sources => 'Fuentes';

  @override
  String sourceProductData(String licence) {
    return 'Datos del producto · licencia $licence';
  }

  @override
  String sourcePhotos(String licence) {
    return 'Fotos · licencia $licence';
  }

  @override
  String sourceAverageValues(String licence) {
    return 'Valores nutricionales medios · licencia $licence';
  }

  @override
  String get dataMayBeIncomplete =>
      'Los datos pueden estar incompletos: revisa siempre la etiqueta.';

  @override
  String get genericValuesNotice =>
      'Valores medios por 100 g de este alimento, de la tabla nutricional oficial CIQUAL.';

  @override
  String get similarProductNotice =>
      'Producto similar encontrado por el nombre: puede que no sea exactamente el tuyo.';

  @override
  String get barcode => 'Código de barras';

  @override
  String get copy => 'Copiar';

  @override
  String get copied => 'Copiado';

  @override
  String get forCoeliacs => 'Celíacos';

  @override
  String get glutenFree => 'sin gluten';

  @override
  String get containsGluten => 'contiene gluten';

  @override
  String get vegetarian => 'Vegetariano';

  @override
  String get vegan => 'Vegano';

  @override
  String get yes => 'sí';

  @override
  String get no => 'no';

  @override
  String get palmOil => 'Aceite de palma';

  @override
  String get palmOilFree => 'sin';

  @override
  String get containsPalmOil => 'contiene';

  @override
  String get lactose => 'Lactosa';

  @override
  String get lactoseFree => 'sin lactosa';

  @override
  String get nutritionPer100 => 'Valores nutricionales por 100 g';

  @override
  String get nutrientFat => 'Grasas';

  @override
  String get nutrientSaturatedFat => 'de las cuales saturadas';

  @override
  String get nutrientCarbohydrates => 'Hidratos de carbono';

  @override
  String get nutrientSugars => 'de los cuales azúcares';

  @override
  String get nutrientFiber => 'Fibra';

  @override
  String get nutrientProteins => 'Proteínas';

  @override
  String get nutrientSalt => 'Sal';

  @override
  String get noNutritionInfo => 'No hay información nutricional';

  @override
  String get waterMinerals => 'Composición por litro';

  @override
  String get mineralCalcium => 'Calcio';

  @override
  String get mineralMagnesium => 'Magnesio';

  @override
  String get mineralSodium => 'Sodio';

  @override
  String get mineralPotassium => 'Potasio';

  @override
  String get mineralBicarbonate => 'Bicarbonato';

  @override
  String get mineralChloride => 'Cloruros';

  @override
  String get mineralSulphate => 'Sulfatos';

  @override
  String get mineralNitrate => 'Nitratos';

  @override
  String get mineralFluoride => 'Fluoruros';

  @override
  String get mineralSilica => 'Sílice';

  @override
  String get allergens => 'Alérgenos';

  @override
  String mayContainTraces(String list) {
    return 'Puede contener trazas de: $list';
  }

  @override
  String get ingredients => 'Ingredientes';

  @override
  String get allergenGluten => 'Gluten';

  @override
  String get allergenCrustaceans => 'Crustáceos';

  @override
  String get allergenEggs => 'Huevos';

  @override
  String get allergenFish => 'Pescado';

  @override
  String get allergenPeanuts => 'Cacahuetes';

  @override
  String get allergenSoybeans => 'Soja';

  @override
  String get allergenMilk => 'Leche';

  @override
  String get allergenNuts => 'Frutos de cáscara';

  @override
  String get allergenCelery => 'Apio';

  @override
  String get allergenMustard => 'Mostaza';

  @override
  String get allergenSesame => 'Sésamo';

  @override
  String get allergenSulphites => 'Sulfitos';

  @override
  String get allergenLupin => 'Altramuces';

  @override
  String get allergenMolluscs => 'Moluscos';

  @override
  String get permission => 'Permiso';

  @override
  String get permissionRead => 'Solo lectura';

  @override
  String get permissionReadWrite => 'Lectura y edición';
}
