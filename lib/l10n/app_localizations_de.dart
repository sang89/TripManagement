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
  String get continueWithGoogle => 'Mit Google fortfahren';

  @override
  String get continueWithApple => 'Mit Apple fortfahren';

  @override
  String get orSignInWith => 'oder';

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
    return '$tripTitle löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get leave => 'Verlassen';

  @override
  String get leaveTripTooltip => 'Reise verlassen';

  @override
  String get thisTripFallback => 'diese Reise';

  @override
  String get leaveTripTitle => 'Reise verlassen?';

  @override
  String leaveTripMessage(String tripTitle) {
    return 'Sie werden aus $tripTitle entfernt und verlieren den Zugang.';
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
  String get selectFriendOptional => 'Einen Freund auswählen (optional)';

  @override
  String get searchFriends => 'Freunde suchen…';

  @override
  String get invitePending => 'Ausstehend';

  @override
  String get inviteAccepted => 'Akzeptiert';

  @override
  String get inviteDeclined => 'Abgelehnt';

  @override
  String get memberLeft => 'Verlassen';

  @override
  String invitedBy(String name) {
    return 'Eingeladen von $name';
  }

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

  @override
  String get blockReinviteLabel =>
      'Zukünftige Einladungen zu dieser Reise nicht erlauben';

  @override
  String get reinviteBlockedError =>
      'Dieser Nutzer hat zukünftige Einladungen zu dieser Reise abgelehnt';

  @override
  String get resendInvite => 'Einladung erneut senden';

  @override
  String inviteResentTo(String name) {
    return 'Einladung erneut gesendet an $name';
  }

  @override
  String get declineInviteConfirmTitle => 'Einladung ablehnen?';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return 'Einladung zu «$tripTitle» ablehnen? Du verlierst den Zugang.';
  }

  @override
  String get securitySectionTitle => 'Sicherheit';

  @override
  String get biometricToggleTitle => 'Face ID / Touch ID';

  @override
  String get biometricToggleSubtitle =>
      'Biometrie zum Entsperren der App verwenden';

  @override
  String get biometricLockTitle => 'Identität bestätigen';

  @override
  String get biometricLockSubtitle =>
      'Authentifizieren Sie sich für den Kontozugriff';

  @override
  String get biometricSignInWithFace => 'Mit Face ID anmelden';

  @override
  String get biometricSignInWithFingerprint => 'Mit Fingerabdruck anmelden';

  @override
  String get biometricSignInWithBiometrics => 'Mit Biometrie anmelden';

  @override
  String get biometricReason =>
      'Authentifizieren Sie sich für den Kontozugriff';

  @override
  String get biometricFailed =>
      'Authentifizierung fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get usePasswordInstead => 'Passwort verwenden';

  @override
  String get navFriends => 'Freunde';

  @override
  String get friendsTabFriends => 'Freunde';

  @override
  String get friendsTabRequests => 'Anfragen';

  @override
  String get friendsAddFriend => 'Freund hinzufügen';

  @override
  String get friendsSearchHint => 'Nach Name, E-Mail oder Telefon suchen';

  @override
  String get friendsNoResults => 'Keine Nutzer gefunden';

  @override
  String get friendsRequestSent => 'Freundschaftsanfrage gesendet';

  @override
  String get friendsAccept => 'Annehmen';

  @override
  String get friendsDecline => 'Ablehnen';

  @override
  String get friendsRemove => 'Freund entfernen';

  @override
  String friendsRemoveConfirm(String name) {
    return '$name aus Ihren Freunden entfernen?';
  }

  @override
  String get friendsNoFriends => 'Noch keine Freunde';

  @override
  String get friendsNoFriendsHint => 'Suchen Sie jemanden zum Hinzufügen.';

  @override
  String get friendsNoRequests => 'Keine ausstehenden Anfragen';

  @override
  String get friendsIncomingSection => 'Eingehend';

  @override
  String get friendsOutgoingSection => 'Gesendet';

  @override
  String get friendsCancelRequest => 'Anfrage abbrechen';

  @override
  String get chatTabLabel => 'Chat';

  @override
  String get chatSendHint => 'Nachricht…';

  @override
  String get chatNoMessages => 'Noch keine Nachrichten. Sagen Sie Hallo!';

  @override
  String get chatSend => 'Senden';

  @override
  String get notificationsSectionTitle => 'Benachrichtigungen';

  @override
  String get mentionNotifToggleTitle => 'Erwähnungs-Benachrichtigungen';

  @override
  String get mentionNotifToggleSubtitle =>
      'Benachrichtigt werden, wenn du in einem Reise-Chat @erwähnt wirst';

  @override
  String get privacySectionTitle => 'Datenschutz';

  @override
  String get blockedUsersTitle => 'Blockierte Nutzer';

  @override
  String get blockedUsersEmpty => 'Du hast niemanden blockiert';

  @override
  String get blockUser => 'Blockieren';

  @override
  String get unblockUser => 'Entsperren';

  @override
  String blockConfirmTitle(String name) {
    return '$name blockieren?';
  }

  @override
  String get blockConfirmBody =>
      'Diese Person kann dich nicht mehr zu Reisen hinzufügen oder dir Freundschaftsanfragen senden.';

  @override
  String blockSuccess(String name) {
    return '$name wurde blockiert';
  }

  @override
  String unblockSuccess(String name) {
    return '$name wurde entsperrt';
  }

  @override
  String get contactsButton => 'Aus Kontakten';

  @override
  String get contactsScreenTitle => 'Aus Kontakten suchen';

  @override
  String get contactsPermissionDenied =>
      'Kontaktzugriff ist erforderlich, um deine Freunde auf TripManagement zu finden.';

  @override
  String get contactsOpenSettings => 'Einstellungen öffnen';

  @override
  String get contactsOnApp => 'Auf TripManagement';

  @override
  String get contactsInviteSection => 'Zu TripManagement einladen';

  @override
  String get contactsEmpty =>
      'Keine Kontakte mit Telefon oder E-Mail gefunden.';

  @override
  String get contactsAddFriend => 'Hinzufügen';

  @override
  String get contactsPending => 'Ausstehend';

  @override
  String get contactsInvite => 'Einladen';

  @override
  String contactsInviteMessage(String name) {
    return 'Hey $name! Ich nutze TripManagement, um Reisen zu planen. Komm dazu: [APP_STORE_LINK]';
  }

  @override
  String get navEvents => 'Events';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get editEventSubtitle => 'Details, Datum oder Ort aktualisieren';

  @override
  String get saveEvent => 'Save event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventDescription => 'Description (optional)';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventCapacity => 'Max. Mitglieder (optional)';

  @override
  String get eventStartDateTime => 'Start date & time';

  @override
  String get eventEndDateTime => 'End date & time (optional)';

  @override
  String get noEventsYet => 'No events yet. Tap + to create one.';

  @override
  String get noUpcomingEvents => 'Keine bevorstehenden Ereignisse';

  @override
  String get noUpcomingEventsHint =>
      'Tippe + um dein nächstes Event zu planen.';

  @override
  String get noPastEvents => 'Noch keine vergangenen Events';

  @override
  String get noPastEventsHint =>
      'Events, an denen du teilgenommen hast, erscheinen hier.';

  @override
  String get filterAll => 'Alle';

  @override
  String get calendarViewToggle => 'Kalender';

  @override
  String get listViewToggle => 'Liste';

  @override
  String get noEventsOnDay => 'Keine Ereignisse an diesem Tag';

  @override
  String get myEvents => 'My events';

  @override
  String get invitedEvents => 'Invited';

  @override
  String get infoTab => 'Info';

  @override
  String get guestsTab => 'Mitglieder';

  @override
  String get noGuestsYet =>
      'Noch keine Mitglieder. Tippe auf +, um eines hinzuzufügen.';

  @override
  String get addGuest => 'Mitglied hinzufügen';

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
  String get noMemoriesYet => 'Noch keine Erinnerungen';

  @override
  String get addFirstPhoto => 'Tippe auf +, um dein erstes Foto hinzuzufügen!';

  @override
  String get slideshow => 'Diashow';

  @override
  String get captionHint => 'Beschriftung hinzufügen…';

  @override
  String get photoUploadLimit =>
      'Upload-Limit erreicht. Versuche es in einer Stunde erneut.';

  @override
  String get photoCapReached =>
      'Diese Veranstaltung hat ihr Fotolimit erreicht.';

  @override
  String get loadMore => 'Mehr laden';

  @override
  String get storiesEditCaption => 'Beschriftung bearbeiten';

  @override
  String get captionSaved => 'Beschriftung gespeichert';

  @override
  String get saveToGallery => 'Speichern';

  @override
  String get savedToGallery => 'In Galerie gespeichert';

  @override
  String get sharePhoto => 'Teilen';

  @override
  String uploadingProgress(int current, int total) {
    return 'Hochladen $current / $total…';
  }

  @override
  String get addExpense => 'Add expense';

  @override
  String get editExpense => 'Ausgabe bearbeiten';

  @override
  String get deleteExpenseTitle => 'Ausgabe loschen';

  @override
  String deleteExpenseMessage(String description) {
    return '\"$description\" loschen? Dies kann nicht ruckgangig gemacht werden.';
  }

  @override
  String get noExpensesYet => 'Noch keine Ausgaben';

  @override
  String get expenseDescription => 'What was paid for?';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get splitAmong => 'Unter Mitgliedern aufteilen';

  @override
  String get paidBy => 'Bezahlt von';

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get deselectAll => 'Alle abwählen';

  @override
  String totalOwed(String amount) {
    return 'You owe: $amount';
  }

  @override
  String youAreOwed(String amount) {
    return 'Dir wird geschuldet: $amount';
  }

  @override
  String get settleUp => 'Abrechnen';

  @override
  String get totalSpent => 'Gesamtausgaben';

  @override
  String get theScore => 'Das Ergebnis';

  @override
  String get settlementPlan => 'Zahlungsplan';

  @override
  String get allSquare => 'Alles ausgeglichen! 🎉';

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
  String get rsvpNoteHint => 'Notiz hinzufügen (optional)';

  @override
  String get organizeTab => 'Organisieren';

  @override
  String get detailsTab => 'Details';

  @override
  String get todoTab => 'Aufgaben';

  @override
  String get cravingsTab => 'Gelüste';

  @override
  String get pollsTab => 'Umfragen';

  @override
  String get pollsEmpty => 'Noch keine Umfragen.';

  @override
  String get pollsAddPoll => 'Umfrage hinzufügen';

  @override
  String get pollsQuestion => 'Frage';

  @override
  String pollsOptionHint(int n) {
    return 'Option $n';
  }

  @override
  String get pollsAddOption => '+ Option hinzufügen';

  @override
  String pollsVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stimmen',
      one: '1 Stimme',
    );
    return '$_temp0';
  }

  @override
  String get pollsDeletePoll => 'Umfrage löschen';

  @override
  String get bringListTitle => 'Aufgaben';

  @override
  String get bringListEmpty => 'Noch keine Aufgaben. Tippen Sie auf +.';

  @override
  String get bringListAddItem => 'Aufgabe hinzufügen';

  @override
  String get bringListEditItem => 'Aufgabe bearbeiten';

  @override
  String get bringListItemLabel => 'Was zu tun ist';

  @override
  String get bringListNote => 'Notiz (optional)';

  @override
  String get bringListAssignTo => 'Mitglied zuweisen';

  @override
  String get bringListNoAssignment => 'Nicht zugewiesen';

  @override
  String get bringListTake => 'Übernehmen';

  @override
  String get bringListUnassign => 'Zuweisung aufheben';

  @override
  String get rsvpNoteLabel => 'Ihre Notiz';

  @override
  String get confirmRsvp => 'Bestätigen';

  @override
  String get foodMoodTitle => 'Wie hungrig bist du?';

  @override
  String get foodMoodStarving => 'Ausgehungert';

  @override
  String get foodMoodCouldEat => 'Könnte essen';

  @override
  String get foodMoodDrinksOnly => 'Nur für Getränke';

  @override
  String get foodMoodNibble => 'Ein bisschen naschen';

  @override
  String get foodMoodDDMode => 'Fahrerdienst';

  @override
  String get cravingsPrompt => 'Worauf hast du Appetit?';

  @override
  String get cravingsHint =>
      'scharfes Ramen, gemütliche Atmosphäre, unter 20€...';

  @override
  String get cravingsPrivacyNote => 'Nur du kannst das sehen';

  @override
  String get cravingsFindButton => 'Finde mir einen Ort';

  @override
  String get cravingsEmpty => 'Keine Ergebnisse. Probiere andere Suchbegriffe.';

  @override
  String get cravingsPitchButton => 'Gruppe vorschlagen';

  @override
  String get cravingsPitched => 'Zur Gruppenabstimmung hinzugefügt!';

  @override
  String get exploreTab => 'Erkunden';

  @override
  String exploreTitle(String destination) {
    return 'Aktivitäten in $destination';
  }

  @override
  String get exploreSubtitle => 'Powered by Viator • GetYourGuide • Klook';

  @override
  String get exploreSortCheapest => 'Günstigste zuerst';

  @override
  String get exploreSortTopRated => 'Bestbewertet';

  @override
  String get exploreMorePlatforms => 'WEITERE PLATTFORMEN';

  @override
  String get bookOnViator => 'Bei Viator buchen';

  @override
  String get bookNow => 'Jetzt buchen';

  @override
  String get browseGetYourGuide => 'GetYourGuide durchsuchen';

  @override
  String get browseKlook => 'Klook durchsuchen';

  @override
  String exploreFromPrice(String price) {
    return 'Ab $price';
  }

  @override
  String get exploreNoResults => 'Keine Aktivitäten für dieses Ziel gefunden.';

  @override
  String get exploreLoadError =>
      'Vorschläge konnten nicht geladen werden. Tippen zum Wiederholen.';

  @override
  String get restaurantPollTitle => 'Einen Ort wählen';

  @override
  String get addRestaurantOption => 'Restaurant hinzufügen';

  @override
  String get restaurantSearchHint => 'Restaurants suchen...';

  @override
  String get setAsVenueButton => 'Als Veranstaltungsort festlegen';

  @override
  String organizedBy(String name) {
    return 'Organised by $name';
  }

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String get deleteEventSubtitle => 'Dieses Ereignis dauerhaft löschen';

  @override
  String deleteEventMessage(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get eventTypeTrip => 'Reise';

  @override
  String get eventTypeBirthday => 'Geburtstag';

  @override
  String get eventTypeWedding => 'Hochzeit';

  @override
  String get eventTypeSocial => 'Gesellig';

  @override
  String get eventTypeQuickBites => 'Schnelle Happen';

  @override
  String get eventTypeSignup => 'Anmeldung';

  @override
  String signupSpotsFilled(int filled, int total) {
    return '$filled / $total Plätze belegt';
  }

  @override
  String signupWaitlistCount(int count) {
    return '$count auf der Warteliste';
  }

  @override
  String get signupEventFull => 'Veranstaltung ausgebucht';

  @override
  String get signupSessionFull => 'Session ausgebucht';

  @override
  String get signupJoinWaitlist => 'Warteliste beitreten';

  @override
  String get signupClaimSpot => 'Platz reservieren';

  @override
  String signupConfirmedPosition(int pos) {
    return 'Du bist #$pos auf der Liste!';
  }

  @override
  String signupWaitlistPosition(int pos) {
    return 'Du bist #$pos auf der Warteliste';
  }

  @override
  String get signupWaitlistEnabled => 'Warteliste aktivieren';

  @override
  String get signupWaitlistDescription =>
      'Gäste über der Kapazität kommen auf eine Warteliste';

  @override
  String get signupRosterTab => 'Liste';

  @override
  String get signupInviteTab => 'Einladen';

  @override
  String get signupPromoteGuest => 'Hochstufen';

  @override
  String get signupRemoveGuest => 'Von Veranstaltung entfernen';

  @override
  String get signupCopyLink => 'Einladungslink kopieren';

  @override
  String get signupShowQr => 'QR-Code anzeigen';

  @override
  String get signupLocked => 'Anmeldungen gesperrt';

  @override
  String get signupLockedMessage =>
      'Anmeldungen sind gesperrt. Wende dich an den Organisator.';

  @override
  String get signupPendingReview => 'Ihre Anfrage wird überprüft';

  @override
  String get signupCancelSpot => 'Platz stornieren';

  @override
  String get signupMarkAttended => 'Anwesend';

  @override
  String get signupMarkNoShow => 'Nicht erschienen';

  @override
  String get signupAttendanceHeader => 'Anwesenheit';

  @override
  String get signupRepeat => 'Wiederholung';

  @override
  String get signupRepeatNone => 'Keine';

  @override
  String get signupRepeatWeekly => 'Wöchentlich';

  @override
  String get signupRepeatBiweekly => 'Alle 2 Wochen';

  @override
  String get signupRepeatMonthly => 'Monatlich';

  @override
  String get signupNextSession => 'Nächste Sitzung erstellen';

  @override
  String get signupCarryOverGuests =>
      'Bestätigte Gäste automatisch einschreiben';

  @override
  String get signupCarryOverGuestsHint =>
      'Gäste erhalten eine Benachrichtigung und können sich abmelden';

  @override
  String signupPartOfSeries(String interval) {
    return 'Teil einer $interval-Serie';
  }

  @override
  String get chooseEventType => 'Was planen Sie?';

  @override
  String get eventTypePicker => 'Ereignistyp';

  @override
  String get routeTab => 'Route';

  @override
  String get leaveEventTitle => 'Ereignis verlassen?';

  @override
  String leaveEventMessage(String eventTitle) {
    return 'Sie werden von $eventTitle entfernt und verlieren den Zugang.';
  }

  @override
  String get generateWithAi => 'AI Assistant';

  @override
  String get aiTripPlannerSubtitle =>
      'Stellen Sie Fragen zu Ihrem Reiseziel oder beschreiben Sie Ihren Stil, um Stopps hinzuzufügen.';

  @override
  String get aiChatHint => 'Stellen Sie beliebige Fragen zu Ihrer Reise...';

  @override
  String get tierFree => 'Basic';

  @override
  String get tierPro => 'Pro';

  @override
  String tierProTrial(String date) {
    return 'Pro Testphase · Endet $date';
  }

  @override
  String get cancelTrial => 'Testphase kündigen';

  @override
  String get cancelTrialConfirmTitle => 'Kostenlose Testphase kündigen?';

  @override
  String get cancelTrialConfirmMessage =>
      'Sie verlieren sofort den Zugriff auf Pro-Funktionen. Sie können später auf Pro upgraden.';

  @override
  String get cancelTrialSuccess =>
      'Ihre Testphase wurde gekündigt. Sie befinden sich jetzt im Basic-Tarif.';

  @override
  String get cancelTrialError =>
      'Testphase konnte nicht gekündigt werden. Bitte versuchen Sie es erneut.';

  @override
  String get upgradeToPro => 'Auf Pro upgraden';

  @override
  String get upgradeNow => 'Jetzt upgraden';

  @override
  String get proAnnualPrice => '39,99 \$ / Jahr';

  @override
  String get proMonthlyPrice => '4,99 \$ / Monat';

  @override
  String get proAnnualSavings => '33% sparen';

  @override
  String get comparePlans => 'Pläne vergleichen';

  @override
  String get restorePurchases => 'Käufe wiederherstellen';

  @override
  String get proFeatureAIPlanner => 'AI Event Assistant';

  @override
  String get proFeatureUnlimitedEvents => 'Unbegrenzte Veranstaltungen & Gäste';

  @override
  String get proFeatureExpenseExport => 'Expense export';

  @override
  String get proFeatureOfflineAccess => 'Offline-Zugang';

  @override
  String get proFeatureTemplates => 'Veranstaltungsvorlagen';

  @override
  String get freeEventsLimit => 'Veranstaltungen (max. 3)';

  @override
  String get freeGuestsLimit => 'Gäste (max. 10)';

  @override
  String get freeBasicPlanning => 'RSVP & Grundplanung';

  @override
  String get budgetPerHeadLabel => 'Budget pro Person (optional)';

  @override
  String get cuisineTagsLabel => 'Küche';

  @override
  String get rsvpDeadlineLabel => 'RSVP-Frist';

  @override
  String get rsvpDeadlineClosed => 'RSVP geschlossen';

  @override
  String get vibePickerLabel => 'Stimmung (optional)';

  @override
  String get honoreeNameLabel => 'Wessen Geburtstag ist es?';

  @override
  String get honoreeNameHint => 'Namen eingeben';

  @override
  String get birthYearLabel => 'Geburtsjahr (optional)';

  @override
  String get birthYearHint => 'z.B. 1996';

  @override
  String get celebrateTab => 'Party';

  @override
  String get giftsTab => 'Geschenke';

  @override
  String get memoriesTab => 'Erinnerungen';

  @override
  String birthdayHeroTitle(String name) {
    return '${name}s Geburtstag';
  }

  @override
  String turningAge(int age) {
    return 'Wird $age';
  }

  @override
  String birthdayCountdownDays(int count) {
    return 'Noch $count Tage';
  }

  @override
  String birthdayCountdownHours(int count) {
    return 'Noch $count Stunden';
  }

  @override
  String get birthdayToday => 'Heute ist der große Tag!';

  @override
  String activityVoteTitle(String name) {
    return 'Was machen wir auf ${name}s Party?';
  }

  @override
  String get activityVoteEmpty => 'Noch keine Aktivitäten.';

  @override
  String get addActivityOption => 'Aktivität hinzufügen';

  @override
  String cakeVoteTitle(String name) {
    return 'Welchen Kuchen möchte $name?';
  }

  @override
  String get cakeVoteEmpty => 'Noch keine Kuchenoptionen!';

  @override
  String get addCakeOption => 'Geschmack hinzufügen';

  @override
  String wishlistTitle(String name) {
    return '${name}s Wunschliste';
  }

  @override
  String wishlistEmpty(String name) {
    return 'Noch keine Einträge. Füge etwas hinzu, das $name liebt!';
  }

  @override
  String get addWishlistItem => 'Geschenkidee hinzufügen';

  @override
  String get wishlistItemLabel => 'Geschenkidee';

  @override
  String get wishlistPriceRange => 'Preisbereich (optional)';

  @override
  String get wishlistLink => 'Link (optional)';

  @override
  String get claimItem => 'Das übernehme ich!';

  @override
  String get unclaimItem => 'Zurücknehmen';

  @override
  String get itemClaimed => 'Jemand kümmert sich darum';

  @override
  String itemClaimedBy(String name) {
    return 'Übernommen von $name';
  }

  @override
  String get markReceived => 'Als erhalten markieren';

  @override
  String get giftPoolTitle => 'Gemeinschaftsgeschenk';

  @override
  String get giftPoolEmpty => 'Noch kein Gemeinschaftsgeschenk.';

  @override
  String get createGiftPool => 'Gemeinschaftsgeschenk starten';

  @override
  String get giftPoolName => 'Geschenkname';

  @override
  String get giftPoolTarget => 'Zielbetrag';

  @override
  String giftPoolProgress(String pledged, String target) {
    return '$pledged von $target zugesagt';
  }

  @override
  String giftPoolContributors(int count) {
    return '$count Beitragszahler';
  }

  @override
  String get pledgeAmount => 'Beitrag';

  @override
  String get addPledge => 'Zusagen';

  @override
  String get myPledge => 'Mein Beitrag';

  @override
  String get removePledge => 'Beitrag entfernen';

  @override
  String predictionsTitle(String name) {
    return 'Vorhersagen für $name';
  }

  @override
  String predictionsSealed(int count) {
    return '$count Vorhersagen versiegelt';
  }

  @override
  String get revealPredictions => 'Vorhersagen enthüllen';

  @override
  String get predictionsHowItWorks =>
      'Vorhersagen sind bis zum Veranstaltungsdatum gesperrt — dann sieht man, wer recht hatte!';

  @override
  String predictionsEmpty(String name) {
    return 'Noch keine Vorhersagen für $name.';
  }

  @override
  String get addPrediction => 'Vorhersage hinzufügen';

  @override
  String predictionHint(String name) {
    return 'Sag etwas über ${name}s nächstes Jahr vorher...';
  }

  @override
  String wishesTitle(String name) {
    return 'Wünsche für $name';
  }

  @override
  String wishesSealed(String name) {
    return '$name kann diese noch nicht sehen';
  }

  @override
  String get wishesHowItWorks =>
      'Wünsche bleiben geheim, bis der Organisator sie am großen Tag enthüllt!';

  @override
  String get wishesEmpty => 'Noch keine Wünsche. Sei der Erste!';

  @override
  String get addWish => 'Wunsch hinzufügen';

  @override
  String wishHint(String name) {
    return 'Schreibe deinen Wunsch für $name...';
  }

  @override
  String get blowOutCandles => 'Kerzen auspusten!';

  @override
  String get wishesRevealed => 'Wünsche enthüllt!';

  @override
  String memoryWallTitle(String name) {
    return '${name}s Erinnerungswand';
  }

  @override
  String memoryWallEmpty(String name) {
    return 'Teile Erinnerungen mit $name!';
  }

  @override
  String get addMemory => 'Erinnerung hinzufügen';

  @override
  String memoryCaptionHint(String name) {
    return 'Teile deine liebste Erinnerung mit $name...';
  }

  @override
  String get toastsTitle => 'Trinksprüche & Reden';

  @override
  String toastsEmpty(String name) {
    return 'Noch keine Trinksprüche für $name!';
  }

  @override
  String get addToast => 'Trinkspruch schreiben';

  @override
  String get toastTypeSweet => 'Herzlich';

  @override
  String get toastTypeFunny => 'Lustig';

  @override
  String get toastTypePoem => 'Gedicht';

  @override
  String get toastTextHint => 'Schreibe deine Rede hier...';

  @override
  String get exportToasts => 'Reden exportieren';

  @override
  String get wishesTab => 'Wünsche';

  @override
  String get predictionsTab => 'Vorhersagen';

  @override
  String get wallTab => 'Wand';

  @override
  String get pleaseSelectEventType => 'Bitte einen Veranstaltungstyp auswählen';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get notificationsEmpty => 'Alles erledigt!';

  @override
  String get notificationsMarkAllRead => 'Alle als gelesen markieren';

  @override
  String get sessionActivityTab => 'Aktivität';

  @override
  String get queueUp => 'Warteschlange';

  @override
  String get createQueue => 'Warteschlange erstellen';

  @override
  String get playersPerRound => 'Spieler pro Runde';

  @override
  String get maxRounds => 'Max. Runden';

  @override
  String get noLimit => 'Kein Limit';

  @override
  String get checkIn => 'Einchecken';

  @override
  String get checkOut => 'Auschecken';

  @override
  String get joinQueue => 'Schlange beitreten';

  @override
  String get leaveQueue => 'Schlange verlassen';

  @override
  String get startQueue => 'Starten';

  @override
  String get nextRound => 'Nächste Runde';

  @override
  String roundN(int n) {
    return 'Runde $n';
  }

  @override
  String get allRejoinQueue => 'Alle zurück in die Schlange';

  @override
  String get releaseToFreePool => 'In freien Pool entlassen';

  @override
  String get freePool => 'Freier Pool';

  @override
  String get nowPlaying => 'Jetzt spielend';

  @override
  String get waitingQueue => 'Wartend';

  @override
  String get queueEnded => 'Warteschlange beendet';

  @override
  String get noQueuesYet => 'Noch keine Aktivitäten';

  @override
  String get createFirstQueue => 'Erstelle die erste Warteschlange';

  @override
  String queueRoundComplete(int n) {
    return 'Runde $n abgeschlossen!';
  }

  @override
  String get setupQueues => 'Warteschlangen einrichten';

  @override
  String get numberOfQueues => 'Anzahl der Warteschlangen';

  @override
  String get spotsPerQueue => 'Plätze pro Warteschlange';

  @override
  String get clearQueue => 'Leeren';

  @override
  String get queueFull => 'Warteschlange voll';

  @override
  String get alreadyInQueue => 'Sie sind bereits in einer Warteschlange';

  @override
  String get addToSlot => 'Einen Platz schnappen!';

  @override
  String get addMyselfToQueue => 'Ich bin dabei!';

  @override
  String get addSomeoneElse => 'Teammitglied hinzufügen';

  @override
  String get selectAMember => 'Mitglied auswählen';

  @override
  String get searchMembersHint => 'Mitglieder suchen…';

  @override
  String get leaveSlotTitle => 'Slot verlassen?';

  @override
  String leaveSlotMessage(int number) {
    return 'Platz in Warteschlange #$number aufgeben?';
  }

  @override
  String get leaveSlotConfirm => 'Aufgeben';

  @override
  String get kickFromSlotTitle => 'Rausschmeißen?';

  @override
  String kickFromSlotMessage(String name, int number) {
    return '$name aus Warteschlange #$number entfernen?';
  }

  @override
  String get kickFromSlotConfirm => 'Raus damit!';

  @override
  String get allowDuplicates => 'Mehrere Warteschlangen erlauben';

  @override
  String get allowDuplicatesSubtitle =>
      'Mitglieder können in mehreren Warteschlangen gleichzeitig sein';

  @override
  String get customizeQueues => 'Warteschlangen anpassen';

  @override
  String get pollSpinButton => 'Drehen';

  @override
  String get pollWheelTitle => 'Dreh das Rad';

  @override
  String get pollWheelResult => 'Das Rad hat gewählt!';

  @override
  String get pollWheelSpin => 'Drehen';

  @override
  String get pollWheelSpinAgain => 'Nochmal drehen';

  @override
  String get pollsDeleteConfirmTitle => 'Umfrage löschen?';

  @override
  String get pollsDeleteConfirmBody =>
      'Damit werden die Umfrage und alle Stimmen gelöscht. Das kann nicht rückgängig gemacht werden.';

  @override
  String get pollWheelHeadline => 'Lass das Rad entscheiden!';

  @override
  String get pollWheelHeadlineFood => 'Zeit zum Schlemmen!';

  @override
  String get pollWheelSpinning => 'Dreht sich…';
}
