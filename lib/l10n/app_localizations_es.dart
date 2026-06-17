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
  String get close => 'Cerrar';

  @override
  String get retry => 'Reintentar';

  @override
  String get save => 'Guardar';

  @override
  String get required => 'Obligatorio';

  @override
  String get notes => 'Notas';

  @override
  String get email => 'Correo electrónico';

  @override
  String get phone => 'Teléfono';

  @override
  String get remove => 'Eliminar';

  @override
  String get notSet => 'No establecido';

  @override
  String failed(String error) {
    return 'Error: $error';
  }

  @override
  String comingSoon(String feature) {
    return '$feature — Próximamente';
  }

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get languageSectionTitle => 'Idioma';

  @override
  String get selectLanguageTitle => 'Seleccionar idioma';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get themeSectionTitle => 'Apariencia';

  @override
  String get themeSystem => 'Predeterminado del sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get accountSectionTitle => 'Cuenta';

  @override
  String get changePasswordTitle => 'Cambiar contraseña';

  @override
  String get currentPassword => 'Contraseña actual';

  @override
  String get newPassword => 'Nueva contraseña';

  @override
  String get confirmNewPassword => 'Confirmar nueva contraseña';

  @override
  String get updatePassword => 'Actualizar contraseña';

  @override
  String get passwordUpdated => 'Contraseña actualizada';

  @override
  String get currentPasswordIncorrect => 'La contraseña actual es incorrecta';

  @override
  String get passwordMinLength => 'Al menos 8 caracteres';

  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get deleteAccountTitle => 'Eliminar cuenta';

  @override
  String get deleteAccountWarning =>
      'Esto eliminará permanentemente tu cuenta y todos los datos. Esta acción no se puede deshacer.';

  @override
  String get deleteAccountInstructions =>
      'Para eliminar tu cuenta, comunícate con soporte. Procesaremos tu solicitud en 48 horas.';

  @override
  String get supportEmail => 'support@tripplanner.app';

  @override
  String get emailCopied => 'Correo copiado al portapapeles';

  @override
  String get copyEmail => 'Copiar correo';

  @override
  String get aboutSectionTitle => 'Acerca de';

  @override
  String get appVersion => 'Versión de la app';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get termsOfService => 'Términos de servicio';

  @override
  String get myProfile => 'Mi perfil';

  @override
  String get failedToLoadProfile => 'Error al cargar el perfil';

  @override
  String get settingsTooltip => 'Configuración';

  @override
  String get editProfileTooltip => 'Editar perfil';

  @override
  String get personalInfoSection => 'Información personal';

  @override
  String get fullName => 'Nombre completo';

  @override
  String get fullNameHint => 'Tu nombre completo';

  @override
  String get jobTitle => 'Cargo';

  @override
  String get jobTitleHint => 'p. ej. Viajero entusiasta';

  @override
  String get contactInfoSection => 'Información de contacto';

  @override
  String get managedByAccount => 'Administrado por tu cuenta';

  @override
  String get memberSince => 'Miembro desde';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get chooseFromLibrary => 'Elegir de la biblioteca';

  @override
  String get takePhoto => 'Tomar foto';

  @override
  String get removePhoto => 'Eliminar foto';

  @override
  String uploadFailed(String error) {
    return 'Error al subir: $error';
  }

  @override
  String get uploadRequiresConnection => 'La subida requiere conexión';

  @override
  String get photoUpdated => 'Foto actualizada';

  @override
  String get removeRequiresConnection =>
      'Se requiere conexión para eliminar la foto';

  @override
  String removeFailed(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String get profileSaved => 'Perfil guardado';

  @override
  String profileSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get signOutConfirmTitle => '¿Cerrar sesión?';

  @override
  String get signOutConfirmMessage =>
      'Serás redirigido a la pantalla de inicio de sesión.';

  @override
  String get nameTooLong => 'Nombre demasiado largo';

  @override
  String get appTitle => 'Planificador de viajes';

  @override
  String get signInToAccount => 'Inicia sesión en tu cuenta';

  @override
  String get planNextAdventure => 'Planea tu próxima aventura';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signUp => 'Registrarse';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get dontHaveAccount => '¿No tienes cuenta?';

  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta?';

  @override
  String get password => 'Contraseña';

  @override
  String get enterValidEmail => 'Ingresa un correo válido';

  @override
  String get passwordTooShort => 'Contraseña muy corta';

  @override
  String get enterYourName => 'Ingresa tu nombre';

  @override
  String get passwordMinimum6 => 'Mínimo 6 caracteres';

  @override
  String get confirmPassword => 'Confirmar contraseña';

  @override
  String get rememberMe => 'Recordarme';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get orSignInWith => 'o';

  @override
  String get myTrips => 'Mis viajes';

  @override
  String get all => 'Todos';

  @override
  String get upcoming => 'Próximos';

  @override
  String get past => 'Pasados';

  @override
  String get deleteTripTitle => '¿Eliminar viaje?';

  @override
  String deleteTripMessage(String tripTitle) {
    return '¿Eliminar $tripTitle? Esta acción no se puede deshacer.';
  }

  @override
  String get leave => 'Salir';

  @override
  String get leaveTripTooltip => 'Salir del viaje';

  @override
  String get thisTripFallback => 'este viaje';

  @override
  String get leaveTripTitle => '¿Salir del viaje?';

  @override
  String leaveTripMessage(String tripTitle) {
    return 'Serás eliminado de $tripTitle y perderás el acceso.';
  }

  @override
  String get couldNotLoadTrips => 'No se pudieron cargar los viajes';

  @override
  String get noTripsYet => 'Sin viajes aún';

  @override
  String get noTripsHint => 'Toca + para comenzar.';

  @override
  String get noUpcomingTrips => 'Sin viajes próximos';

  @override
  String get noUpcomingTripsHint => 'Toca + para planear tu próxima aventura.';

  @override
  String get noPastTrips => 'Sin viajes pasados';

  @override
  String get noPastTripsHint => 'Tus viajes completados aparecerán aquí.';

  @override
  String get editTrip => 'Editar viaje';

  @override
  String get newTrip => 'Nuevo viaje';

  @override
  String get tripTitle => 'Título del viaje';

  @override
  String get startingFromLabel => 'Partiendo desde (opcional)';

  @override
  String get destinationLabel => 'Destino';

  @override
  String get notesOptional => 'Notas (opcional)';

  @override
  String get startLabel => 'Inicio';

  @override
  String get endLabel => 'Fin';

  @override
  String get setStartDateTime => 'Establecer fecha y hora de inicio';

  @override
  String get setEndDateTime => 'Establecer fecha y hora de fin';

  @override
  String get endDateAfterStart =>
      'La fecha de fin debe ser después de la de inicio.';

  @override
  String get stopsSection => 'Paradas';

  @override
  String get addStop => 'Agregar parada';

  @override
  String get noStopsYet => 'Sin paradas añadidas.';

  @override
  String get mapSection => 'Mapa';

  @override
  String get membersSection => 'Miembros';

  @override
  String get addMember => 'Agregar miembro';

  @override
  String get fullNameLabel => 'Nombre';

  @override
  String get emailOptional => 'Correo (opcional)';

  @override
  String get phoneOptional => 'Teléfono (opcional)';

  @override
  String get saveTrip => 'Guardar viaje';

  @override
  String get you => 'Tú';

  @override
  String get organizer => 'Organizador';

  @override
  String get member => 'Miembro';

  @override
  String get tripNotFound => 'Viaje no encontrado';

  @override
  String get editTripTooltip => 'Editar viaje';

  @override
  String get overview => 'Resumen';

  @override
  String get itinerary => 'Itinerario';

  @override
  String get mapTab => 'Mapa';

  @override
  String get startingFrom => 'Partiendo desde';

  @override
  String get destination => 'Destino';

  @override
  String get noStopsInItinerary => 'Sin paradas aún';

  @override
  String get addFirstStop => 'Toca + para agregar tu primera parada.';

  @override
  String get removeStopTitle => '¿Eliminar parada?';

  @override
  String removeStopMessage(String stopTitle) {
    return '¿Eliminar \"$stopTitle\" del itinerario?';
  }

  @override
  String get arrive => 'Llegada';

  @override
  String get depart => 'Salida';

  @override
  String get stopTitleLabel => 'Título';

  @override
  String get addressOptional => 'Dirección (opcional)';

  @override
  String get arriveLabel => 'Llegada';

  @override
  String get departLabel => 'Salida';

  @override
  String get addStopButton => 'Agregar parada';

  @override
  String get editStop => 'Editar parada';

  @override
  String get navTrips => 'Viajes';

  @override
  String get navJournal => 'Diario';

  @override
  String get navProfile => 'Perfil';

  @override
  String get journalComingSoon => 'Diario próximamente';

  @override
  String get memberSearching => 'Buscando…';

  @override
  String get memberAccountFound => 'Cuenta encontrada';

  @override
  String get memberNoAccountFound => 'No se encontró ninguna cuenta';

  @override
  String get memberLinkedAccount => 'Cuenta vinculada';

  @override
  String get selectFriendOptional => 'Seleccionar un amigo (opcional)';

  @override
  String get searchFriends => 'Buscar amigos…';

  @override
  String get invitePending => 'Pendiente';

  @override
  String get inviteAccepted => 'Aceptado';

  @override
  String get inviteDeclined => 'Rechazado';

  @override
  String get memberLeft => 'Salió';

  @override
  String invitedBy(String name) {
    return 'Invitado por $name';
  }

  @override
  String tripInvitationsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitaciones de viaje',
      one: '1 invitación de viaje',
    );
    return '$_temp0';
  }

  @override
  String get acceptInvite => 'Aceptar';

  @override
  String get declineInvite => 'Rechazar';

  @override
  String get inviteNotifTitle => 'Invitación de viaje';

  @override
  String inviteNotifBody(String tripTitle) {
    return 'Has sido invitado a $tripTitle';
  }

  @override
  String get blockReinviteLabel =>
      'No permitir futuras invitaciones a este viaje';

  @override
  String get reinviteBlockedError =>
      'Este usuario ha rechazado futuras invitaciones a este viaje';

  @override
  String get resendInvite => 'Reenviar invitación';

  @override
  String inviteResentTo(String name) {
    return 'Invitación reenviada a $name';
  }

  @override
  String get declineInviteConfirmTitle => '¿Rechazar invitación?';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return '¿Rechazar la invitación a «$tripTitle»? Perderás el acceso.';
  }

  @override
  String get securitySectionTitle => 'Seguridad';

  @override
  String get biometricToggleTitle => 'Face ID / Touch ID';

  @override
  String get biometricToggleSubtitle =>
      'Usar biometría para desbloquear la app';

  @override
  String get biometricLockTitle => 'Verifica tu identidad';

  @override
  String get biometricLockSubtitle => 'Autentícate para acceder a tu cuenta';

  @override
  String get biometricSignInWithFace => 'Iniciar sesión con Face ID';

  @override
  String get biometricSignInWithFingerprint =>
      'Iniciar sesión con huella dactilar';

  @override
  String get biometricSignInWithBiometrics => 'Iniciar sesión con biometría';

  @override
  String get biometricReason => 'Autentícate para acceder a tu cuenta';

  @override
  String get biometricFailed => 'Autenticación fallida. Inténtalo de nuevo.';

  @override
  String get usePasswordInstead => 'Usar contraseña';

  @override
  String get navFriends => 'Amigos';

  @override
  String get friendsTabFriends => 'Amigos';

  @override
  String get friendsTabRequests => 'Solicitudes';

  @override
  String get friendsAddFriend => 'Agregar amigo';

  @override
  String get friendsSearchHint => 'Buscar por nombre, correo o teléfono';

  @override
  String get friendsNoResults => 'No se encontraron usuarios';

  @override
  String get friendsRequestSent => 'Solicitud de amistad enviada';

  @override
  String get friendsAccept => 'Aceptar';

  @override
  String get friendsDecline => 'Rechazar';

  @override
  String get friendsRemove => 'Eliminar amigo';

  @override
  String friendsRemoveConfirm(String name) {
    return '¿Eliminar a $name de tus amigos?';
  }

  @override
  String get friendsNoFriends => 'Aún sin amigos';

  @override
  String get friendsNoFriendsHint => 'Busca a alguien para agregar como amigo.';

  @override
  String get friendsNoRequests => 'Sin solicitudes pendientes';

  @override
  String get friendsIncomingSection => 'Recibidas';

  @override
  String get friendsOutgoingSection => 'Enviadas';

  @override
  String get friendsCancelRequest => 'Cancelar solicitud';

  @override
  String get chatTabLabel => 'Chat';

  @override
  String get chatSendHint => 'Mensaje…';

  @override
  String get chatNoMessages => 'Aún sin mensajes. ¡Di hola!';

  @override
  String get chatSend => 'Enviar';

  @override
  String get notificationsSectionTitle => 'Notificaciones';

  @override
  String get mentionNotifToggleTitle => 'Alertas de mención';

  @override
  String get mentionNotifToggleSubtitle =>
      'Recibe notificaciones cuando te @mencionen en un chat de viaje';

  @override
  String get privacySectionTitle => 'Privacidad';

  @override
  String get blockedUsersTitle => 'Usuarios bloqueados';

  @override
  String get blockedUsersEmpty => 'No has bloqueado a nadie';

  @override
  String get blockUser => 'Bloquear';

  @override
  String get unblockUser => 'Desbloquear';

  @override
  String blockConfirmTitle(String name) {
    return '¿Bloquear a $name?';
  }

  @override
  String get blockConfirmBody =>
      'No podrán añadirte a viajes ni enviarte solicitudes de amistad.';

  @override
  String blockSuccess(String name) {
    return '$name ha sido bloqueado';
  }

  @override
  String unblockSuccess(String name) {
    return '$name ha sido desbloqueado';
  }

  @override
  String get contactsButton => 'Desde contactos';

  @override
  String get contactsScreenTitle => 'Buscar desde contactos';

  @override
  String get contactsPermissionDenied =>
      'Se necesita acceso a los contactos para encontrar tus amigos en TripManagement.';

  @override
  String get contactsOpenSettings => 'Abrir configuración';

  @override
  String get contactsOnApp => 'En TripManagement';

  @override
  String get contactsInviteSection => 'Invitar a TripManagement';

  @override
  String get contactsEmpty =>
      'No se encontraron contactos con teléfono o correo electrónico.';

  @override
  String get contactsAddFriend => 'Agregar';

  @override
  String get contactsPending => 'Pendiente';

  @override
  String get contactsInvite => 'Invitar';

  @override
  String contactsInviteMessage(String name) {
    return '¡Hola $name! Estoy usando TripManagement para planificar viajes. Únete aquí: [APP_STORE_LINK]';
  }

  @override
  String get navEvents => 'Events';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get editEventSubtitle => 'Actualizar detalles, fecha o ubicación';

  @override
  String get saveEvent => 'Save event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventDescription => 'Description (optional)';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventCapacity => 'Máximo de miembros (opcional)';

  @override
  String get eventStartDateTime => 'Start date & time';

  @override
  String get eventEndDateTime => 'End date & time (optional)';

  @override
  String get noEventsYet => 'No events yet. Tap + to create one.';

  @override
  String get noUpcomingEvents => 'No hay eventos próximos';

  @override
  String get noUpcomingEventsHint => 'Toca + para planear tu próximo evento.';

  @override
  String get noPastEvents => 'Aún no hay eventos pasados';

  @override
  String get noPastEventsHint =>
      'Los eventos a los que asististe aparecerán aquí.';

  @override
  String get filterAll => 'Todos';

  @override
  String get calendarViewToggle => 'Calendario';

  @override
  String get listViewToggle => 'Lista';

  @override
  String get noEventsOnDay => 'No hay eventos en este día';

  @override
  String get myEvents => 'My events';

  @override
  String get invitedEvents => 'Invited';

  @override
  String get infoTab => 'Info';

  @override
  String get guestsTab => 'Miembros';

  @override
  String get noGuestsYet => 'Aún no hay miembros. Toca + para añadir uno.';

  @override
  String get addGuest => 'Añadir miembro';

  @override
  String get photosTab => 'Photos';

  @override
  String get expensesTab => 'Expenses';

  @override
  String get rsvpGoing => 'Going';

  @override
  String get rsvpMaybe => 'Maybe';

  @override
  String get rsvpDeclined => 'Can\'t go';

  @override
  String get changeRsvp => 'Change RSVP';

  @override
  String goingCount(int count) {
    return '$count going';
  }

  @override
  String maybeCount(int count) {
    return '$count maybe';
  }

  @override
  String declinedCount(int count) {
    return '$count can\'t go';
  }

  @override
  String get shareEvent => 'Share event';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get noPhotosYet => 'No photos yet.';

  @override
  String get deletePhoto => 'Delete photo';

  @override
  String get deletePhotoConfirm => 'Delete this photo?';

  @override
  String get addExpense => 'Add expense';

  @override
  String get editExpense => 'Editar gasto';

  @override
  String get deleteExpenseTitle => 'Eliminar gasto';

  @override
  String deleteExpenseMessage(String description) {
    return 'Eliminar \"$description\"? Esta accion no se puede deshacer.';
  }

  @override
  String get noExpensesYet => 'Sin gastos aún';

  @override
  String get expenseDescription => 'What was paid for?';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get splitAmong => 'Dividir entre miembros';

  @override
  String get paidBy => 'Pagado por';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get deselectAll => 'Deseleccionar todo';

  @override
  String totalOwed(String amount) {
    return 'You owe: $amount';
  }

  @override
  String youAreOwed(String amount) {
    return 'Te deben: $amount';
  }

  @override
  String get settleUp => 'Saldar cuentas';

  @override
  String get totalSpent => 'Total gastado';

  @override
  String get theScore => 'El marcador';

  @override
  String get settlementPlan => 'Plan de liquidación';

  @override
  String get allSquare => '¡Todo en orden! 🎉';

  @override
  String get eventFull => 'This event is at capacity.';

  @override
  String get publicRsvpTitle => 'You\'re invited!';

  @override
  String get publicRsvpName => 'Your name';

  @override
  String get publicRsvpEmail => 'Email (optional)';

  @override
  String get publicRsvpPhone => 'Phone (optional)';

  @override
  String get rsvpSuccess => 'Your RSVP was saved!';

  @override
  String get rsvpNoteHint => 'Agregar una nota (opcional)';

  @override
  String get organizeTab => 'Organizar';

  @override
  String get detailsTab => 'Detalles';

  @override
  String get todoTab => 'Tareas';

  @override
  String get cravingsTab => 'Antojos';

  @override
  String get pollsTab => 'Encuestas';

  @override
  String get pollsEmpty => 'Sin encuestas aún.';

  @override
  String get pollsAddPoll => 'Agregar encuesta';

  @override
  String get pollsQuestion => 'Pregunta';

  @override
  String pollsOptionHint(int n) {
    return 'Opción $n';
  }

  @override
  String get pollsAddOption => '+ Agregar opción';

  @override
  String pollsVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
    );
    return '$_temp0';
  }

  @override
  String get pollsDeletePoll => 'Eliminar encuesta';

  @override
  String get bringListTitle => 'Tareas';

  @override
  String get bringListEmpty => 'Sin tareas aún. Toca + para añadir.';

  @override
  String get bringListAddItem => 'Añadir tarea';

  @override
  String get bringListEditItem => 'Editar tarea';

  @override
  String get bringListItemLabel => 'Qué hacer';

  @override
  String get bringListNote => 'Nota (opcional)';

  @override
  String get bringListAssignTo => 'Asignar a miembro';

  @override
  String get bringListNoAssignment => 'Sin asignar';

  @override
  String get bringListTake => 'Tomar';

  @override
  String get bringListUnassign => 'Desasignar';

  @override
  String get rsvpNoteLabel => 'Tu nota';

  @override
  String get confirmRsvp => 'Confirmar';

  @override
  String get foodMoodTitle => '¿Cuánta hambre tienes?';

  @override
  String get foodMoodStarving => 'Muerto de hambre';

  @override
  String get foodMoodCouldEat => 'Podría comer';

  @override
  String get foodMoodDrinksOnly => 'Solo para tomar algo';

  @override
  String get foodMoodNibble => 'Picaré algo';

  @override
  String get foodMoodDDMode => 'Conductor designado';

  @override
  String get cravingsPrompt => '¿Qué se te antoja?';

  @override
  String get cravingsHint =>
      'ramen picante, ambiente acogedor, menos de 20\$...';

  @override
  String get cravingsPrivacyNote => 'Solo tú puedes ver esto';

  @override
  String get cravingsFindButton => 'Encuéntrame un lugar';

  @override
  String get cravingsEmpty =>
      'Sin resultados. Prueba con otras palabras clave.';

  @override
  String get cravingsPitchButton => 'Proponer al grupo';

  @override
  String get cravingsPitched => '¡Añadido a la votación del grupo!';

  @override
  String get exploreTab => 'Explorar';

  @override
  String exploreTitle(String destination) {
    return 'Actividades en $destination';
  }

  @override
  String get exploreSubtitle => 'Powered by Viator • GetYourGuide • Klook';

  @override
  String get exploreSortCheapest => 'Más baratos';

  @override
  String get exploreSortTopRated => 'Mejor valorados';

  @override
  String get exploreMorePlatforms => 'MÁS PLATAFORMAS';

  @override
  String get bookOnViator => 'Reservar en Viator';

  @override
  String get bookNow => 'Reservar';

  @override
  String get browseGetYourGuide => 'Ver en GetYourGuide';

  @override
  String get browseKlook => 'Ver en Klook';

  @override
  String exploreFromPrice(String price) {
    return 'Desde $price';
  }

  @override
  String get exploreNoResults =>
      'No se encontraron actividades para este destino.';

  @override
  String get exploreLoadError =>
      'No se pudieron cargar las sugerencias. Toca para reintentar.';

  @override
  String get restaurantPollTitle => 'Elegir un lugar';

  @override
  String get addRestaurantOption => 'Añadir restaurante';

  @override
  String get restaurantSearchHint => 'Buscar restaurantes...';

  @override
  String get setAsVenueButton => 'Establecer como lugar';

  @override
  String organizedBy(String name) {
    return 'Organised by $name';
  }

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String get deleteEventSubtitle => 'Eliminar este evento permanentemente';

  @override
  String deleteEventMessage(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get eventTypeTrip => 'Viaje';

  @override
  String get eventTypeBirthday => 'Cumpleaños';

  @override
  String get eventTypeWedding => 'Boda';

  @override
  String get eventTypeSocial => 'Social';

  @override
  String get eventTypeQuickBites => 'Bocados Rápidos';

  @override
  String get eventTypeSignup => 'Inscripción';

  @override
  String signupSpotsFilled(int filled, int total) {
    return '$filled / $total plazas ocupadas';
  }

  @override
  String signupWaitlistCount(int count) {
    return '$count en lista de espera';
  }

  @override
  String get signupEventFull => 'Evento completo';

  @override
  String get signupJoinWaitlist => 'Unirse a la lista de espera';

  @override
  String get signupClaimSpot => 'Reservar un lugar';

  @override
  String signupConfirmedPosition(int pos) {
    return '¡Eres el #$pos en la lista!';
  }

  @override
  String signupWaitlistPosition(int pos) {
    return 'Eres el #$pos en la lista de espera';
  }

  @override
  String get signupWaitlistEnabled => 'Activar lista de espera';

  @override
  String get signupWaitlistDescription =>
      'Los invitados que superen la capacidad se unen a una lista de espera ordenada';

  @override
  String get signupRosterTab => 'Lista';

  @override
  String get signupInviteTab => 'Invitar';

  @override
  String get signupPromoteGuest => 'Promover';

  @override
  String get signupRemoveGuest => 'Eliminar del evento';

  @override
  String get signupCopyLink => 'Copiar enlace de invitación';

  @override
  String get signupShowQr => 'Mostrar código QR';

  @override
  String get signupLocked => 'Las inscripciones están cerradas';

  @override
  String get signupLockedMessage =>
      'Las inscripciones están cerradas. Contacta al organizador.';

  @override
  String get signupPendingReview => 'Tu solicitud está pendiente de aprobación';

  @override
  String get signupCancelSpot => 'Cancelar mi lugar';

  @override
  String get signupMarkAttended => 'Asistió';

  @override
  String get signupMarkNoShow => 'No se presentó';

  @override
  String get signupAttendanceHeader => 'Asistencia';

  @override
  String get signupRepeat => 'Repetir';

  @override
  String get signupRepeatNone => 'Ninguna';

  @override
  String get signupRepeatWeekly => 'Semanal';

  @override
  String get signupRepeatBiweekly => 'Cada 2 semanas';

  @override
  String get signupRepeatMonthly => 'Mensual';

  @override
  String get signupNextSession => 'Crear próxima sesión';

  @override
  String get signupCarryOverGuests =>
      'Inscribir automáticamente a los confirmados';

  @override
  String get signupCarryOverGuestsHint =>
      'Los invitados recibirán una notificación y podrán cancelar';

  @override
  String signupPartOfSeries(String interval) {
    return 'Parte de una serie $interval';
  }

  @override
  String get chooseEventType => '¿Qué estás planeando?';

  @override
  String get eventTypePicker => 'Tipo de evento';

  @override
  String get routeTab => 'Ruta';

  @override
  String get leaveEventTitle => '¿Salir del evento?';

  @override
  String leaveEventMessage(String eventTitle) {
    return 'Serás eliminado de $eventTitle y perderás el acceso.';
  }

  @override
  String get generateWithAi => 'AI Assistant';

  @override
  String get aiTripPlannerSubtitle =>
      'Haz preguntas sobre tu destino o describe tu estilo para añadir paradas al itinerario.';

  @override
  String get aiChatHint => 'Pregunta lo que quieras sobre tu viaje...';

  @override
  String get tierFree => 'Basic';

  @override
  String get tierPro => 'Pro';

  @override
  String tierProTrial(String date) {
    return 'Prueba Pro · Termina el $date';
  }

  @override
  String get cancelTrial => 'Cancelar prueba';

  @override
  String get cancelTrialConfirmTitle => '¿Cancelar tu prueba gratuita?';

  @override
  String get cancelTrialConfirmMessage =>
      'Perderás acceso inmediato a las funciones Pro. Puedes actualizar a Pro más tarde.';

  @override
  String get cancelTrialSuccess =>
      'Tu prueba ha sido cancelada. Ahora estás en el plan Básico.';

  @override
  String get cancelTrialError =>
      'No se pudo cancelar la prueba. Inténtalo de nuevo.';

  @override
  String get upgradeToPro => 'Actualizar a Pro';

  @override
  String get upgradeNow => 'Actualizar ahora';

  @override
  String get proAnnualPrice => '\$39.99 / año';

  @override
  String get proMonthlyPrice => '\$4.99 / mes';

  @override
  String get proAnnualSavings => 'Ahorra 33%';

  @override
  String get comparePlans => 'Comparar planes';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get proFeatureAIPlanner => 'AI Event Assistant';

  @override
  String get proFeatureUnlimitedEvents => 'Eventos e invitados ilimitados';

  @override
  String get proFeatureExpenseExport => 'Expense export';

  @override
  String get proFeatureOfflineAccess => 'Acceso sin conexión';

  @override
  String get proFeatureTemplates => 'Plantillas de eventos';

  @override
  String get freeEventsLimit => 'Eventos (máx. 3)';

  @override
  String get freeGuestsLimit => 'Invitados (máx. 10)';

  @override
  String get freeBasicPlanning => 'RSVP y planificación básica';

  @override
  String get budgetPerHeadLabel => 'Presupuesto por persona (opcional)';

  @override
  String get cuisineTagsLabel => 'Cocina';

  @override
  String get rsvpDeadlineLabel => 'Fecha límite RSVP';

  @override
  String get rsvpDeadlineClosed => 'RSVP cerrado';

  @override
  String get vibePickerLabel => 'Ambiente (opcional)';

  @override
  String get honoreeNameLabel => '¿De quién es el cumpleaños?';

  @override
  String get honoreeNameHint => 'Ingresa su nombre';

  @override
  String get birthYearLabel => 'Año de nacimiento (opcional)';

  @override
  String get birthYearHint => 'ej. 1996';

  @override
  String get celebrateTab => 'Fiesta';

  @override
  String get giftsTab => 'Regalos';

  @override
  String get memoriesTab => 'Recuerdos';

  @override
  String birthdayHeroTitle(String name) {
    return 'Cumpleaños de $name';
  }

  @override
  String turningAge(int age) {
    return 'Cumple $age';
  }

  @override
  String birthdayCountdownDays(int count) {
    return 'Faltan $count días';
  }

  @override
  String birthdayCountdownHours(int count) {
    return 'Faltan $count horas';
  }

  @override
  String get birthdayToday => '¡Hoy es el gran día!';

  @override
  String activityVoteTitle(String name) {
    return '¿Qué hacemos en la fiesta de $name?';
  }

  @override
  String get activityVoteEmpty => 'Sin actividades aún.';

  @override
  String get addActivityOption => 'Agregar actividad';

  @override
  String cakeVoteTitle(String name) {
    return '¿Qué pastel quiere $name?';
  }

  @override
  String get cakeVoteEmpty => 'Sin opciones de pastel aún.';

  @override
  String get addCakeOption => 'Agregar sabor';

  @override
  String wishlistTitle(String name) {
    return 'Lista de $name';
  }

  @override
  String wishlistEmpty(String name) {
    return 'Sin elementos. ¡Agrega algo que $name adoraría!';
  }

  @override
  String get addWishlistItem => 'Agregar idea de regalo';

  @override
  String get wishlistItemLabel => 'Idea de regalo';

  @override
  String get wishlistPriceRange => 'Rango de precio (opcional)';

  @override
  String get wishlistLink => 'Enlace (opcional)';

  @override
  String get claimItem => '¡Yo me encargo!';

  @override
  String get unclaimItem => 'Liberar';

  @override
  String get itemClaimed => 'Alguien está en ello';

  @override
  String itemClaimedBy(String name) {
    return 'Reclamado por $name';
  }

  @override
  String get markReceived => 'Marcar recibido';

  @override
  String get giftPoolTitle => 'Regalo grupal';

  @override
  String get giftPoolEmpty => 'Sin regalo grupal aún.';

  @override
  String get createGiftPool => 'Iniciar regalo grupal';

  @override
  String get giftPoolName => 'Nombre del regalo';

  @override
  String get giftPoolTarget => 'Monto objetivo';

  @override
  String giftPoolProgress(String pledged, String target) {
    return '$pledged de $target comprometido';
  }

  @override
  String giftPoolContributors(int count) {
    return '$count contribuyentes';
  }

  @override
  String get pledgeAmount => 'Monto a comprometer';

  @override
  String get addPledge => 'Comprometer';

  @override
  String get myPledge => 'Mi compromiso';

  @override
  String get removePledge => 'Quitar compromiso';

  @override
  String predictionsTitle(String name) {
    return 'Predicciones para $name';
  }

  @override
  String predictionsSealed(int count) {
    return '$count predicciones selladas';
  }

  @override
  String get revealPredictions => 'Revelar predicciones';

  @override
  String get predictionsHowItWorks =>
      'Las predicciones están bloqueadas hasta la fecha del evento — ¡luego descubrirás quién acertó!';

  @override
  String predictionsEmpty(String name) {
    return 'Sin predicciones aún para $name.';
  }

  @override
  String get addPrediction => 'Agregar predicción';

  @override
  String predictionHint(String name) {
    return 'Predice algo para el próximo año de $name...';
  }

  @override
  String wishesTitle(String name) {
    return 'Deseos para $name';
  }

  @override
  String wishesSealed(String name) {
    return '$name aún no puede verlos';
  }

  @override
  String get wishesHowItWorks =>
      'Los deseos se mantienen en secreto hasta que el organizador los revela el gran día.';

  @override
  String get wishesEmpty => 'Sin deseos aún. ¡Sé el primero!';

  @override
  String get addWish => 'Hacer un deseo';

  @override
  String wishHint(String name) {
    return 'Escribe tu deseo para $name...';
  }

  @override
  String get blowOutCandles => '¡Soplar las velas!';

  @override
  String get wishesRevealed => '¡Deseos revelados!';

  @override
  String memoryWallTitle(String name) {
    return 'Muro de recuerdos de $name';
  }

  @override
  String memoryWallEmpty(String name) {
    return '¡Comparte recuerdos con $name!';
  }

  @override
  String get addMemory => 'Agregar recuerdo';

  @override
  String memoryCaptionHint(String name) {
    return 'Comparte tu recuerdo favorito con $name...';
  }

  @override
  String get toastsTitle => 'Brindis y discursos';

  @override
  String toastsEmpty(String name) {
    return 'Sin brindis aún para $name.';
  }

  @override
  String get addToast => 'Escribir un brindis';

  @override
  String get toastTypeSweet => 'Dulce';

  @override
  String get toastTypeFunny => 'Gracioso';

  @override
  String get toastTypePoem => 'Poema';

  @override
  String get toastTextHint => 'Escribe tu discurso aquí...';

  @override
  String get exportToasts => 'Exportar discursos';

  @override
  String get wishesTab => 'Deseos';

  @override
  String get predictionsTab => 'Predicciones';

  @override
  String get wallTab => 'Muro';

  @override
  String get pleaseSelectEventType => 'Por favor selecciona un tipo de evento';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get notificationsEmpty => '¡Todo al día!';

  @override
  String get notificationsMarkAllRead => 'Marcar todo como leído';

  @override
  String get sessionActivityTab => 'Actividad';

  @override
  String get queueUp => 'Cola';

  @override
  String get createQueue => 'Crear cola';

  @override
  String get playersPerRound => 'Jugadores por ronda';

  @override
  String get maxRounds => 'Rondas máximas';

  @override
  String get noLimit => 'Sin límite';

  @override
  String get checkIn => 'Registrarse';

  @override
  String get checkOut => 'Salir';

  @override
  String get joinQueue => 'Unirse a la cola';

  @override
  String get leaveQueue => 'Salir de la cola';

  @override
  String get startQueue => 'Iniciar';

  @override
  String get nextRound => 'Siguiente ronda';

  @override
  String roundN(int n) {
    return 'Ronda $n';
  }

  @override
  String get allRejoinQueue => 'Todos vuelven a la cola';

  @override
  String get releaseToFreePool => 'Liberar al pool';

  @override
  String get freePool => 'Pool libre';

  @override
  String get nowPlaying => 'Jugando ahora';

  @override
  String get waitingQueue => 'En espera';

  @override
  String get queueEnded => 'Cola terminada';

  @override
  String get noQueuesYet => 'Sin actividades aún';

  @override
  String get createFirstQueue => 'Crea la primera cola para empezar';

  @override
  String queueRoundComplete(int n) {
    return '¡Ronda $n completada!';
  }

  @override
  String get setupQueues => 'Configurar colas';

  @override
  String get numberOfQueues => 'Número de colas';

  @override
  String get spotsPerQueue => 'Plazas por cola';

  @override
  String get clearQueue => 'Limpiar';

  @override
  String get queueFull => 'Cola llena';

  @override
  String get alreadyInQueue => 'Ya estás en una cola';

  @override
  String get addToSlot => '¡Agarra un lugar!';

  @override
  String get addMyselfToQueue => '¡Estoy dentro!';

  @override
  String get addSomeoneElse => 'Añadir compañero';

  @override
  String get selectAMember => 'Seleccionar un miembro';

  @override
  String get searchMembersHint => 'Buscar miembros…';

  @override
  String get leaveSlotTitle => '¿Salir del turno?';

  @override
  String leaveSlotMessage(int number) {
    return '¿Retirarte del turno en la cola #$number?';
  }

  @override
  String get leaveSlotConfirm => 'Retirar';

  @override
  String get kickFromSlotTitle => '¿Echarlo? 👢';

  @override
  String kickFromSlotMessage(String name, int number) {
    return '¿Quitar a $name de la cola #$number?';
  }

  @override
  String get kickFromSlotConfirm => '¡Fuera! 🦵';

  @override
  String get allowDuplicates => 'Permitir varias colas';

  @override
  String get allowDuplicatesSubtitle =>
      'Los miembros pueden estar en más de una cola a la vez';

  @override
  String get customizeQueues => 'Personalizar colas';
}
