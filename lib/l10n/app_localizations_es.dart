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
}
