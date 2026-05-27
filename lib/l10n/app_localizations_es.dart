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
    return '¿Eliminar \"$tripTitle\"? Esta acción no se puede deshacer.';
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
  String get fullNameLabel => 'Nombre completo';

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
}
