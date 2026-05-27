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
  String get close => 'Schließen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get save => 'Speichern';

  @override
  String get required => 'Pflichtfeld';

  @override
  String get notes => 'Notizen';

  @override
  String get email => 'E-Mail';

  @override
  String get phone => 'Telefon';

  @override
  String get remove => 'Entfernen';

  @override
  String get notSet => 'Nicht festgelegt';

  @override
  String failed(String error) {
    return 'Fehler: $error';
  }

  @override
  String comingSoon(String feature) {
    return '$feature — Demnächst';
  }

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get languageSectionTitle => 'Sprache';

  @override
  String get selectLanguageTitle => 'Sprache auswählen';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get themeSectionTitle => 'Erscheinungsbild';

  @override
  String get themeSystem => 'Systemstandard';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get accountSectionTitle => 'Konto';

  @override
  String get changePasswordTitle => 'Passwort ändern';

  @override
  String get currentPassword => 'Aktuelles Passwort';

  @override
  String get newPassword => 'Neues Passwort';

  @override
  String get confirmNewPassword => 'Neues Passwort bestätigen';

  @override
  String get updatePassword => 'Passwort aktualisieren';

  @override
  String get passwordUpdated => 'Passwort aktualisiert';

  @override
  String get currentPasswordIncorrect => 'Das aktuelle Passwort ist falsch';

  @override
  String get passwordMinLength => 'Mindestens 8 Zeichen';

  @override
  String get passwordsDoNotMatch => 'Passwörter stimmen nicht überein';

  @override
  String get deleteAccountTitle => 'Konto löschen';

  @override
  String get deleteAccountWarning =>
      'Dadurch wird Ihr Konto und alle Daten dauerhaft gelöscht. Dieser Vorgang kann nicht rückgängig gemacht werden.';

  @override
  String get deleteAccountInstructions =>
      'Um Ihr Konto zu löschen, wenden Sie sich bitte an den Support. Wir bearbeiten Ihre Anfrage innerhalb von 48 Stunden.';

  @override
  String get supportEmail => 'support@tripplanner.app';

  @override
  String get emailCopied => 'E-Mail in die Zwischenablage kopiert';

  @override
  String get copyEmail => 'E-Mail kopieren';

  @override
  String get aboutSectionTitle => 'Über';

  @override
  String get appVersion => 'App-Version';

  @override
  String get privacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get termsOfService => 'Nutzungsbedingungen';

  @override
  String get myProfile => 'Mein Profil';

  @override
  String get failedToLoadProfile => 'Profil konnte nicht geladen werden';

  @override
  String get settingsTooltip => 'Einstellungen';

  @override
  String get editProfileTooltip => 'Profil bearbeiten';

  @override
  String get personalInfoSection => 'Persönliche Informationen';

  @override
  String get fullName => 'Vollständiger Name';

  @override
  String get fullNameHint => 'Ihr vollständiger Name';

  @override
  String get jobTitle => 'Berufsbezeichnung';

  @override
  String get jobTitleHint => 'z. B. Reisebegeisterter';

  @override
  String get contactInfoSection => 'Kontaktinformationen';

  @override
  String get managedByAccount => 'Wird von Ihrem Konto verwaltet';

  @override
  String get memberSince => 'Mitglied seit';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get signOut => 'Abmelden';

  @override
  String get chooseFromLibrary => 'Aus Bibliothek auswählen';

  @override
  String get takePhoto => 'Foto aufnehmen';

  @override
  String get removePhoto => 'Foto entfernen';

  @override
  String uploadFailed(String error) {
    return 'Upload fehlgeschlagen: $error';
  }

  @override
  String get uploadRequiresConnection => 'Upload erfordert eine Verbindung';

  @override
  String get photoUpdated => 'Foto aktualisiert';

  @override
  String get removeRequiresConnection =>
      'Zum Entfernen des Fotos ist eine Verbindung erforderlich';

  @override
  String removeFailed(String error) {
    return 'Entfernen fehlgeschlagen: $error';
  }

  @override
  String get profileSaved => 'Profil gespeichert';

  @override
  String profileSaveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get signOutConfirmTitle => 'Abmelden?';

  @override
  String get signOutConfirmMessage =>
      'Sie werden zum Anmeldebildschirm weitergeleitet.';

  @override
  String get nameTooLong => 'Name zu lang';

  @override
  String get appTitle => 'Reiseplaner';

  @override
  String get signInToAccount => 'Bei Ihrem Konto anmelden';

  @override
  String get planNextAdventure => 'Planen Sie Ihr nächstes Abenteuer';

  @override
  String get signIn => 'Anmelden';

  @override
  String get signUp => 'Registrieren';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get dontHaveAccount => 'Noch kein Konto?';

  @override
  String get alreadyHaveAccount => 'Bereits ein Konto?';

  @override
  String get password => 'Passwort';

  @override
  String get enterValidEmail => 'Gültige E-Mail eingeben';

  @override
  String get passwordTooShort => 'Passwort zu kurz';

  @override
  String get enterYourName => 'Namen eingeben';

  @override
  String get passwordMinimum6 => 'Mindestens 6 Zeichen';

  @override
  String get confirmPassword => 'Passwort bestätigen';

  @override
  String get rememberMe => 'Angemeldet bleiben';

  @override
  String get myTrips => 'Meine Reisen';

  @override
  String get all => 'Alle';

  @override
  String get upcoming => 'Bevorstehend';

  @override
  String get past => 'Vergangen';

  @override
  String get deleteTripTitle => 'Reise löschen?';

  @override
  String deleteTripMessage(String tripTitle) {
    return '\"$tripTitle\" löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get couldNotLoadTrips => 'Reisen konnten nicht geladen werden';

  @override
  String get noTripsYet => 'Noch keine Reisen';

  @override
  String get noTripsHint => 'Tippe + um zu starten.';

  @override
  String get noUpcomingTrips => 'Keine bevorstehenden Reisen';

  @override
  String get noUpcomingTripsHint =>
      'Tippe + um dein nächstes Abenteuer zu planen.';

  @override
  String get noPastTrips => 'Keine vergangenen Reisen';

  @override
  String get noPastTripsHint => 'Abgeschlossene Reisen erscheinen hier.';

  @override
  String get editTrip => 'Reise bearbeiten';

  @override
  String get newTrip => 'Neue Reise';

  @override
  String get tripTitle => 'Reisetitel';

  @override
  String get startingFromLabel => 'Abfahrt von (optional)';

  @override
  String get destinationLabel => 'Reiseziel';

  @override
  String get notesOptional => 'Notizen (optional)';

  @override
  String get startLabel => 'Start';

  @override
  String get endLabel => 'Ende';

  @override
  String get setStartDateTime => 'Startdatum und -uhrzeit festlegen';

  @override
  String get setEndDateTime => 'Enddatum und -uhrzeit festlegen';

  @override
  String get endDateAfterStart => 'Enddatum muss nach dem Startdatum liegen.';

  @override
  String get stopsSection => 'Stopps';

  @override
  String get addStop => 'Stopp hinzufügen';

  @override
  String get noStopsYet => 'Noch keine Stopps hinzugefügt.';

  @override
  String get mapSection => 'Karte';

  @override
  String get membersSection => 'Mitglieder';

  @override
  String get addMember => 'Mitglied hinzufügen';

  @override
  String get fullNameLabel => 'Name';

  @override
  String get emailOptional => 'E-Mail (optional)';

  @override
  String get phoneOptional => 'Telefon (optional)';

  @override
  String get saveTrip => 'Reise speichern';

  @override
  String get you => 'Sie';

  @override
  String get organizer => 'Organisator';

  @override
  String get member => 'Mitglied';

  @override
  String get tripNotFound => 'Reise nicht gefunden';

  @override
  String get editTripTooltip => 'Reise bearbeiten';

  @override
  String get overview => 'Übersicht';

  @override
  String get itinerary => 'Reiseplan';

  @override
  String get mapTab => 'Karte';

  @override
  String get startingFrom => 'Abfahrt von';

  @override
  String get destination => 'Reiseziel';

  @override
  String get noStopsInItinerary => 'Noch keine Stopps';

  @override
  String get addFirstStop => 'Tippe + um deinen ersten Stopp hinzuzufügen.';

  @override
  String get removeStopTitle => 'Stopp entfernen?';

  @override
  String removeStopMessage(String stopTitle) {
    return '\"$stopTitle\" aus dem Reiseplan entfernen?';
  }

  @override
  String get arrive => 'Ankunft';

  @override
  String get depart => 'Abfahrt';

  @override
  String get stopTitleLabel => 'Titel';

  @override
  String get addressOptional => 'Adresse (optional)';

  @override
  String get arriveLabel => 'Ankunft';

  @override
  String get departLabel => 'Abfahrt';

  @override
  String get addStopButton => 'Stopp hinzufügen';

  @override
  String get editStop => 'Stopp bearbeiten';

  @override
  String get navTrips => 'Reisen';

  @override
  String get navJournal => 'Tagebuch';

  @override
  String get navProfile => 'Profil';

  @override
  String get journalComingSoon => 'Tagebuch demnächst';

  @override
  String get memberSearching => 'Suche läuft…';

  @override
  String get memberAccountFound => 'Konto gefunden';

  @override
  String get memberNoAccountFound => 'Kein Konto gefunden';

  @override
  String get memberLinkedAccount => 'Verknüpftes Konto';

  @override
  String get invitePending => 'Ausstehend';

  @override
  String get inviteAccepted => 'Akzeptiert';

  @override
  String get inviteDeclined => 'Abgelehnt';

  @override
  String tripInvitationsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Reiseeinladungen',
      one: '1 Reiseeinladung',
    );
    return '$_temp0';
  }

  @override
  String get acceptInvite => 'Annehmen';

  @override
  String get declineInvite => 'Ablehnen';

  @override
  String get inviteNotifTitle => 'Reiseeinladung';

  @override
  String inviteNotifBody(String tripTitle) {
    return 'Sie wurden zu $tripTitle eingeladen';
  }
}
