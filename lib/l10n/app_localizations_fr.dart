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
  String get close => 'Fermer';

  @override
  String get retry => 'Réessayer';

  @override
  String get save => 'Enregistrer';

  @override
  String get required => 'Obligatoire';

  @override
  String get notes => 'Notes';

  @override
  String get email => 'E-mail';

  @override
  String get phone => 'Téléphone';

  @override
  String get remove => 'Supprimer';

  @override
  String get notSet => 'Non défini';

  @override
  String failed(String error) {
    return 'Échec : $error';
  }

  @override
  String comingSoon(String feature) {
    return '$feature — Bientôt disponible';
  }

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get languageSectionTitle => 'Langue';

  @override
  String get selectLanguageTitle => 'Sélectionner la langue';

  @override
  String get systemDefault => 'Par défaut du système';

  @override
  String get themeSectionTitle => 'Apparence';

  @override
  String get themeSystem => 'Par défaut du système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get accountSectionTitle => 'Compte';

  @override
  String get changePasswordTitle => 'Changer le mot de passe';

  @override
  String get currentPassword => 'Mot de passe actuel';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get confirmNewPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get updatePassword => 'Mettre à jour le mot de passe';

  @override
  String get passwordUpdated => 'Mot de passe mis à jour';

  @override
  String get currentPasswordIncorrect => 'Le mot de passe actuel est incorrect';

  @override
  String get passwordMinLength => 'Au moins 8 caractères';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get deleteAccountTitle => 'Supprimer le compte';

  @override
  String get deleteAccountWarning =>
      'Cela supprimera définitivement votre compte et toutes les données. Cette action est irréversible.';

  @override
  String get deleteAccountInstructions =>
      'Pour supprimer votre compte, contactez le support. Nous traiterons votre demande sous 48 heures.';

  @override
  String get supportEmail => 'support@tripplanner.app';

  @override
  String get emailCopied => 'E-mail copié dans le presse-papiers';

  @override
  String get copyEmail => 'Copier l\'e-mail';

  @override
  String get aboutSectionTitle => 'À propos';

  @override
  String get appVersion => 'Version de l\'app';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String get myProfile => 'Mon profil';

  @override
  String get failedToLoadProfile => 'Impossible de charger le profil';

  @override
  String get settingsTooltip => 'Paramètres';

  @override
  String get editProfileTooltip => 'Modifier le profil';

  @override
  String get personalInfoSection => 'Informations personnelles';

  @override
  String get fullName => 'Nom complet';

  @override
  String get fullNameHint => 'Votre nom complet';

  @override
  String get jobTitle => 'Intitulé du poste';

  @override
  String get jobTitleHint => 'ex. Voyageur passionné';

  @override
  String get contactInfoSection => 'Informations de contact';

  @override
  String get managedByAccount => 'Géré par votre compte';

  @override
  String get memberSince => 'Membre depuis';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get chooseFromLibrary => 'Choisir depuis la bibliothèque';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get removePhoto => 'Supprimer la photo';

  @override
  String uploadFailed(String error) {
    return 'Échec du téléchargement : $error';
  }

  @override
  String get uploadRequiresConnection =>
      'Le téléchargement nécessite une connexion';

  @override
  String get photoUpdated => 'Photo mise à jour';

  @override
  String get removeRequiresConnection =>
      'Une connexion est nécessaire pour supprimer la photo';

  @override
  String removeFailed(String error) {
    return 'Impossible de supprimer : $error';
  }

  @override
  String get profileSaved => 'Profil enregistré';

  @override
  String profileSaveFailed(String error) {
    return 'Échec de l\'enregistrement : $error';
  }

  @override
  String get signOutConfirmTitle => 'Se déconnecter ?';

  @override
  String get signOutConfirmMessage =>
      'Vous serez redirigé vers l\'écran de connexion.';

  @override
  String get nameTooLong => 'Nom trop long';

  @override
  String get appTitle => 'Planificateur de voyages';

  @override
  String get signInToAccount => 'Connectez-vous à votre compte';

  @override
  String get planNextAdventure => 'Planifiez votre prochaine aventure';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get dontHaveAccount => 'Pas encore de compte ?';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte ?';

  @override
  String get password => 'Mot de passe';

  @override
  String get enterValidEmail => 'Saisissez un e-mail valide';

  @override
  String get passwordTooShort => 'Mot de passe trop court';

  @override
  String get enterYourName => 'Saisissez votre nom';

  @override
  String get passwordMinimum6 => 'Minimum 6 caractères';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get rememberMe => 'Se souvenir de moi';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get continueWithApple => 'Continuer avec Apple';

  @override
  String get orSignInWith => 'ou';

  @override
  String get myTrips => 'Mes voyages';

  @override
  String get all => 'Tous';

  @override
  String get upcoming => 'À venir';

  @override
  String get past => 'Passés';

  @override
  String get deleteTripTitle => 'Supprimer le voyage ?';

  @override
  String deleteTripMessage(String tripTitle) {
    return 'Supprimer $tripTitle ? Cette action est irréversible.';
  }

  @override
  String get leave => 'Quitter';

  @override
  String get leaveTripTooltip => 'Quitter le voyage';

  @override
  String get thisTripFallback => 'ce voyage';

  @override
  String get leaveTripTitle => 'Quitter le voyage ?';

  @override
  String leaveTripMessage(String tripTitle) {
    return 'Vous serez retiré de $tripTitle et perdrez l\'accès.';
  }

  @override
  String get couldNotLoadTrips => 'Impossible de charger les voyages';

  @override
  String get noTripsYet => 'Aucun voyage';

  @override
  String get noTripsHint => 'Appuyez sur + pour commencer.';

  @override
  String get noUpcomingTrips => 'Aucun voyage à venir';

  @override
  String get noUpcomingTripsHint =>
      'Appuyez sur + pour planifier votre prochaine aventure.';

  @override
  String get noPastTrips => 'Aucun voyage passé';

  @override
  String get noPastTripsHint => 'Vos voyages terminés apparaîtront ici.';

  @override
  String get editTrip => 'Modifier le voyage';

  @override
  String get newTrip => 'Nouveau voyage';

  @override
  String get tripTitle => 'Titre du voyage';

  @override
  String get startingFromLabel => 'Au départ de (facultatif)';

  @override
  String get destinationLabel => 'Destination';

  @override
  String get notesOptional => 'Notes (facultatif)';

  @override
  String get startLabel => 'Départ';

  @override
  String get endLabel => 'Fin';

  @override
  String get setStartDateTime => 'Définir la date et l\'heure de départ';

  @override
  String get setEndDateTime => 'Définir la date et l\'heure de fin';

  @override
  String get endDateAfterStart =>
      'La date de fin doit être après la date de départ.';

  @override
  String get stopsSection => 'Étapes';

  @override
  String get addStop => 'Ajouter une étape';

  @override
  String get noStopsYet => 'Aucune étape ajoutée.';

  @override
  String get mapSection => 'Carte';

  @override
  String get membersSection => 'Membres';

  @override
  String get addMember => 'Ajouter un membre';

  @override
  String get fullNameLabel => 'Nom';

  @override
  String get emailOptional => 'E-mail (facultatif)';

  @override
  String get phoneOptional => 'Téléphone (facultatif)';

  @override
  String get saveTrip => 'Enregistrer le voyage';

  @override
  String get you => 'Vous';

  @override
  String get organizer => 'Organisateur';

  @override
  String get member => 'Membre';

  @override
  String get tripNotFound => 'Voyage introuvable';

  @override
  String get editTripTooltip => 'Modifier le voyage';

  @override
  String get overview => 'Aperçu';

  @override
  String get itinerary => 'Itinéraire';

  @override
  String get mapTab => 'Carte';

  @override
  String get startingFrom => 'Au départ de';

  @override
  String get destination => 'Destination';

  @override
  String get noStopsInItinerary => 'Aucune étape';

  @override
  String get addFirstStop => 'Appuyez sur + pour ajouter votre première étape.';

  @override
  String get removeStopTitle => 'Supprimer l\'étape ?';

  @override
  String removeStopMessage(String stopTitle) {
    return 'Supprimer \"$stopTitle\" de l\'itinéraire ?';
  }

  @override
  String get arrive => 'Arrivée';

  @override
  String get depart => 'Départ';

  @override
  String get stopTitleLabel => 'Titre';

  @override
  String get addressOptional => 'Adresse (facultatif)';

  @override
  String get arriveLabel => 'Arrivée';

  @override
  String get departLabel => 'Départ';

  @override
  String get addStopButton => 'Ajouter une étape';

  @override
  String get editStop => 'Modifier l\'étape';

  @override
  String get navTrips => 'Voyages';

  @override
  String get navJournal => 'Journal';

  @override
  String get navProfile => 'Profil';

  @override
  String get journalComingSoon => 'Journal bientôt disponible';

  @override
  String get memberSearching => 'Recherche en cours…';

  @override
  String get memberAccountFound => 'Compte trouvé';

  @override
  String get memberNoAccountFound => 'Aucun compte trouvé';

  @override
  String get memberLinkedAccount => 'Compte lié';

  @override
  String get selectFriendOptional => 'Sélectionner un ami (optionnel)';

  @override
  String get searchFriends => 'Rechercher des amis…';

  @override
  String get invitePending => 'En attente';

  @override
  String get inviteAccepted => 'Accepté';

  @override
  String get inviteDeclined => 'Refusé';

  @override
  String get memberLeft => 'Parti';

  @override
  String invitedBy(String name) {
    return 'Invité par $name';
  }

  @override
  String tripInvitationsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations de voyage',
      one: '1 invitation de voyage',
    );
    return '$_temp0';
  }

  @override
  String get acceptInvite => 'Accepter';

  @override
  String get declineInvite => 'Refuser';

  @override
  String get inviteNotifTitle => 'Invitation de voyage';

  @override
  String inviteNotifBody(String tripTitle) {
    return 'Vous avez été invité à $tripTitle';
  }

  @override
  String get blockReinviteLabel =>
      'Ne plus autoriser les invitations à ce voyage';

  @override
  String get reinviteBlockedError =>
      'Cet utilisateur a refusé les futures invitations à ce voyage';

  @override
  String get resendInvite => 'Renvoyer l\'invitation';

  @override
  String inviteResentTo(String name) {
    return 'Invitation renvoyée à $name';
  }

  @override
  String get declineInviteConfirmTitle => 'Refuser l\'invitation ?';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return 'Refuser l\'invitation pour « $tripTitle » ? Vous perdrez l\'accès.';
  }

  @override
  String get securitySectionTitle => 'Sécurité';

  @override
  String get biometricToggleTitle => 'Face ID / Touch ID';

  @override
  String get biometricToggleSubtitle =>
      'Utiliser la biométrie pour déverrouiller l\'app';

  @override
  String get biometricLockTitle => 'Vérifiez votre identité';

  @override
  String get biometricLockSubtitle =>
      'Authentifiez-vous pour accéder à votre compte';

  @override
  String get biometricSignInWithFace => 'Se connecter avec Face ID';

  @override
  String get biometricSignInWithFingerprint => 'Se connecter avec l\'empreinte';

  @override
  String get biometricSignInWithBiometrics => 'Se connecter avec la biométrie';

  @override
  String get biometricReason => 'Authentifiez-vous pour accéder à votre compte';

  @override
  String get biometricFailed => 'Authentification échouée. Veuillez réessayer.';

  @override
  String get usePasswordInstead => 'Utiliser le mot de passe';

  @override
  String get navFriends => 'Amis';

  @override
  String get friendsTabFriends => 'Amis';

  @override
  String get friendsTabRequests => 'Demandes';

  @override
  String get friendsAddFriend => 'Ajouter un ami';

  @override
  String get friendsSearchHint => 'Rechercher par nom, e-mail ou téléphone';

  @override
  String get friendsNoResults => 'Aucun utilisateur trouvé';

  @override
  String get friendsRequestSent => 'Demande d\'ami envoyée';

  @override
  String get friendsAccept => 'Accepter';

  @override
  String get friendsDecline => 'Refuser';

  @override
  String get friendsRemove => 'Supprimer l\'ami';

  @override
  String friendsRemoveConfirm(String name) {
    return 'Supprimer $name de vos amis ?';
  }

  @override
  String get friendsNoFriends => 'Aucun ami pour l’instant';

  @override
  String get friendsNoFriendsHint =>
      'Recherchez quelqu’un à ajouter comme ami.';

  @override
  String get friendsNoRequests => 'Aucune demande en attente';

  @override
  String get friendsIncomingSection => 'Reçues';

  @override
  String get friendsOutgoingSection => 'Envoyées';

  @override
  String get friendsCancelRequest => 'Annuler la demande';

  @override
  String get chatTabLabel => 'Chat';

  @override
  String get chatSendHint => 'Message…';

  @override
  String get chatNoMessages => 'Aucun message pour l’instant. Dites bonjour !';

  @override
  String get chatSend => 'Envoyer';

  @override
  String get notificationsSectionTitle => 'Notifications';

  @override
  String get mentionNotifToggleTitle => 'Alertes de mention';

  @override
  String get mentionNotifToggleSubtitle =>
      'Soyez notifié quand quelqu’un vous @mentionne dans un chat de voyage';

  @override
  String get privacySectionTitle => 'Confidentialité';

  @override
  String get blockedUsersTitle => 'Utilisateurs bloqués';

  @override
  String get blockedUsersEmpty => 'Vous n’avez bloqué personne';

  @override
  String get blockUser => 'Bloquer';

  @override
  String get unblockUser => 'Débloquer';

  @override
  String blockConfirmTitle(String name) {
    return 'Bloquer $name ?';
  }

  @override
  String get blockConfirmBody =>
      'Cette personne ne pourra plus vous ajouter à des voyages ni vous envoyer de demande d’ami.';

  @override
  String blockSuccess(String name) {
    return '$name a été bloqué';
  }

  @override
  String unblockSuccess(String name) {
    return '$name a été débloqué';
  }

  @override
  String get contactsButton => 'Depuis les contacts';

  @override
  String get contactsScreenTitle => 'Trouver depuis les contacts';

  @override
  String get contactsPermissionDenied =>
      'L\'accès aux contacts est nécessaire pour trouver vos amis sur TripManagement.';

  @override
  String get contactsOpenSettings => 'Ouvrir les paramètres';

  @override
  String get contactsOnApp => 'Sur TripManagement';

  @override
  String get contactsInviteSection => 'Inviter sur TripManagement';

  @override
  String get contactsEmpty =>
      'Aucun contact avec un téléphone ou un e-mail n\'a été trouvé.';

  @override
  String get contactsAddFriend => 'Ajouter';

  @override
  String get contactsPending => 'En attente';

  @override
  String get contactsInvite => 'Inviter';

  @override
  String contactsInviteMessage(String name) {
    return 'Salut $name ! J\'\'utilise TripManagement pour planifier des voyages. Rejoins-moi ici : [APP_STORE_LINK]';
  }

  @override
  String get navEvents => 'Events';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get editEventSubtitle => 'Modifier les détails, la date ou le lieu';

  @override
  String get saveEvent => 'Save event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventDescription => 'Description (optional)';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventCapacity => 'Membres max (optionnel)';

  @override
  String get eventStartDateTime => 'Start date & time';

  @override
  String get eventEndDateTime => 'End date & time (optional)';

  @override
  String get noEventsYet => 'No events yet. Tap + to create one.';

  @override
  String get noUpcomingEvents => 'Aucun événement à venir';

  @override
  String get noUpcomingEventsHint =>
      'Appuyez sur + pour planifier votre prochain événement.';

  @override
  String get noPastEvents => 'Pas encore d\'événements passés';

  @override
  String get noPastEventsHint =>
      'Les événements auxquels vous avez participé apparaîtront ici.';

  @override
  String get filterAll => 'Tous';

  @override
  String get calendarViewToggle => 'Calendrier';

  @override
  String get listViewToggle => 'Liste';

  @override
  String get noEventsOnDay => 'Aucun événement ce jour';

  @override
  String get myEvents => 'My events';

  @override
  String get invitedEvents => 'Invited';

  @override
  String get infoTab => 'Infos';

  @override
  String get guestsTab => 'Membres';

  @override
  String get noGuestsYet =>
      'Aucun membre pour l\'instant. Appuyez sur + pour en ajouter un.';

  @override
  String get addGuest => 'Ajouter un membre';

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
  String get editExpense => 'Modifier la depense';

  @override
  String get deleteExpenseTitle => 'Supprimer la depense';

  @override
  String deleteExpenseMessage(String description) {
    return 'Supprimer \"$description\" ? Cette action est irreversible.';
  }

  @override
  String get noExpensesYet => 'Aucune dépense pour l\'instant';

  @override
  String get expenseDescription => 'What was paid for?';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get splitAmong => 'Diviser entre les membres';

  @override
  String get paidBy => 'Payé par';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get deselectAll => 'Tout désélectionner';

  @override
  String totalOwed(String amount) {
    return 'You owe: $amount';
  }

  @override
  String youAreOwed(String amount) {
    return 'On vous doit: $amount';
  }

  @override
  String get settleUp => 'Régler les comptes';

  @override
  String get totalSpent => 'Total dépensé';

  @override
  String get theScore => 'Le score';

  @override
  String get settlementPlan => 'Plan de règlement';

  @override
  String get allSquare => 'Tout est réglé ! 🎉';

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
  String get rsvpNoteHint => 'Ajouter une note (optionnel)';

  @override
  String get organizeTab => 'Organiser';

  @override
  String get detailsTab => 'Détails';

  @override
  String get todoTab => 'Tâches';

  @override
  String get cravingsTab => 'Envies';

  @override
  String get pollsTab => 'Sondages';

  @override
  String get pollsEmpty => 'Aucun sondage.';

  @override
  String get pollsAddPoll => 'Ajouter un sondage';

  @override
  String get pollsQuestion => 'Question';

  @override
  String pollsOptionHint(int n) {
    return 'Option $n';
  }

  @override
  String get pollsAddOption => '+ Ajouter une option';

  @override
  String pollsVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
    );
    return '$_temp0';
  }

  @override
  String get pollsDeletePoll => 'Supprimer le sondage';

  @override
  String get bringListTitle => 'Taches';

  @override
  String get bringListEmpty => 'Aucune tache. Appuyez sur +.';

  @override
  String get bringListAddItem => 'Ajouter une tache';

  @override
  String get bringListEditItem => 'Modifier la tâche';

  @override
  String get bringListItemLabel => 'Quoi faire';

  @override
  String get bringListNote => 'Note (optionnel)';

  @override
  String get bringListAssignTo => 'Assigner a un membre';

  @override
  String get bringListNoAssignment => 'Non assigne';

  @override
  String get bringListTake => 'Prendre';

  @override
  String get bringListUnassign => 'Desassigner';

  @override
  String get rsvpNoteLabel => 'Votre note';

  @override
  String get confirmRsvp => 'Confirmer';

  @override
  String get foodMoodTitle => 'Vous avez faim ?';

  @override
  String get foodMoodStarving => 'Affamé';

  @override
  String get foodMoodCouldEat => 'Je mangerais bien';

  @override
  String get foodMoodDrinksOnly => 'Juste pour boire';

  @override
  String get foodMoodNibble => 'Je grignoterais';

  @override
  String get foodMoodDDMode => 'Chauffeur désigné';

  @override
  String get cravingsPrompt => 'Qu\'est-ce qui vous fait envie ?';

  @override
  String get cravingsHint => 'ramen épicé, ambiance cosy, moins de 20€...';

  @override
  String get cravingsPrivacyNote => 'Seulement vous pouvez voir ça';

  @override
  String get cravingsFindButton => 'Trouve-moi un endroit';

  @override
  String get cravingsEmpty => 'Aucun résultat. Essayez d\'autres mots-clés.';

  @override
  String get cravingsPitchButton => 'Proposer au groupe';

  @override
  String get cravingsPitched => 'Ajouté au vote du groupe !';

  @override
  String get restaurantPollTitle => 'Choisir un resto';

  @override
  String get addRestaurantOption => 'Ajouter un restaurant';

  @override
  String get restaurantSearchHint => 'Rechercher des restaurants...';

  @override
  String get setAsVenueButton => 'Définir comme lieu';

  @override
  String organizedBy(String name) {
    return 'Organised by $name';
  }

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String get deleteEventSubtitle => 'Supprimer définitivement cet événement';

  @override
  String deleteEventMessage(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get eventTypeTrip => 'Voyage';

  @override
  String get eventTypeBirthday => 'Anniversaire';

  @override
  String get eventTypeWedding => 'Mariage';

  @override
  String get eventTypeSocial => 'Social';

  @override
  String get eventTypeQuickBites => 'Petites Bouchées';

  @override
  String get eventTypeSignup => 'Inscription';

  @override
  String signupSpotsFilled(int filled, int total) {
    return '$filled / $total places occupées';
  }

  @override
  String signupWaitlistCount(int count) {
    return '$count en liste d\'attente';
  }

  @override
  String get signupEventFull => 'Événement complet';

  @override
  String get signupJoinWaitlist => 'Rejoindre la liste d\'attente';

  @override
  String get signupClaimSpot => 'Réserver une place';

  @override
  String signupConfirmedPosition(int pos) {
    return 'Vous êtes #$pos sur la liste !';
  }

  @override
  String signupWaitlistPosition(int pos) {
    return 'Vous êtes #$pos sur la liste d\'attente';
  }

  @override
  String get signupWaitlistEnabled => 'Activer la liste d\'attente';

  @override
  String get signupWaitlistDescription =>
      'Les invités au-delà de la capacité rejoignent une liste d\'attente ordonnée';

  @override
  String get signupRosterTab => 'Liste';

  @override
  String get signupInviteTab => 'Inviter';

  @override
  String get signupPromoteGuest => 'Promouvoir';

  @override
  String get signupRemoveGuest => 'Retirer de l\'événement';

  @override
  String get signupCopyLink => 'Copier le lien d\'invitation';

  @override
  String get signupShowQr => 'Afficher le QR code';

  @override
  String get signupLocked => 'Les inscriptions sont fermées';

  @override
  String get signupLockedMessage =>
      'Les inscriptions sont fermées. Contactez l\'organisateur.';

  @override
  String get signupCancelSpot => 'Annuler ma place';

  @override
  String get signupMarkAttended => 'Présent';

  @override
  String get signupMarkNoShow => 'Absent';

  @override
  String get signupAttendanceHeader => 'Présence';

  @override
  String get signupRepeat => 'Répétition';

  @override
  String get signupRepeatNone => 'Aucune';

  @override
  String get signupRepeatWeekly => 'Hebdomadaire';

  @override
  String get signupRepeatBiweekly => 'Toutes les 2 semaines';

  @override
  String get signupRepeatMonthly => 'Mensuel';

  @override
  String get signupNextSession => 'Créer la prochaine session';

  @override
  String get signupCarryOverGuests =>
      'Inscrire automatiquement les participants';

  @override
  String get signupCarryOverGuestsHint =>
      'Les participants recevront une notification et pourront se désinscrire';

  @override
  String signupPartOfSeries(String interval) {
    return 'Partie d\'une série $interval';
  }

  @override
  String get eventTypePicker => 'Type d\'événement';

  @override
  String get routeTab => 'Itinéraire';

  @override
  String get leaveEventTitle => 'Quitter l\'événement ?';

  @override
  String leaveEventMessage(String eventTitle) {
    return 'Vous serez retiré de $eventTitle et perdrez l\'accès.';
  }

  @override
  String get generateWithAi => 'AI Assistant';

  @override
  String get aiTripPlannerSubtitle =>
      'Posez des questions sur votre destination, ou décrivez votre style pour ajouter des étapes.';

  @override
  String get aiChatHint =>
      'Posez n\'importe quelle question sur votre voyage...';

  @override
  String get tierFree => 'Basic';

  @override
  String get tierPro => 'Pro';

  @override
  String tierProTrial(String date) {
    return 'Pro Essai · Fin le $date';
  }

  @override
  String get cancelTrial => 'Annuler l\'essai';

  @override
  String get cancelTrialConfirmTitle => 'Annuler votre essai gratuit ?';

  @override
  String get cancelTrialConfirmMessage =>
      'Vous perdrez l’accès aux fonctionnalités Pro immédiatement. Vous pourrez upgrader plus tard.';

  @override
  String get cancelTrialSuccess =>
      'Votre essai a été annulé. Vous êtes maintenant sur le forfait Basic.';

  @override
  String get cancelTrialError =>
      'Impossible d’annuler l’essai. Veuillez réessayer.';

  @override
  String get upgradeToPro => 'Passer à Pro';

  @override
  String get upgradeNow => 'Passer maintenant';

  @override
  String get proAnnualPrice => '39,99 \$ / an';

  @override
  String get proMonthlyPrice => '4,99 \$ / mois';

  @override
  String get proAnnualSavings => 'Économisez 33%';

  @override
  String get comparePlans => 'Comparer les forfaits';

  @override
  String get restorePurchases => 'Restaurer les achats';

  @override
  String get proFeatureAIPlanner => 'AI Event Assistant';

  @override
  String get proFeatureUnlimitedEvents => 'Événements et invités illimités';

  @override
  String get proFeatureExpenseExport => 'Expense export';

  @override
  String get proFeatureOfflineAccess => 'Accès hors ligne';

  @override
  String get proFeatureTemplates => 'Modèles d\'événements';

  @override
  String get freeEventsLimit => 'Événements (3 max)';

  @override
  String get freeGuestsLimit => 'Invités (10 max)';

  @override
  String get freeBasicPlanning => 'RSVP et planification de base';

  @override
  String get budgetPerHeadLabel => 'Budget par personne (optionnel)';

  @override
  String get cuisineTagsLabel => 'Cuisine';

  @override
  String get rsvpDeadlineLabel => 'Date limite RSVP';

  @override
  String get rsvpDeadlineClosed => 'RSVP fermé';

  @override
  String get vibePickerLabel => 'Ambiance (optionnel)';

  @override
  String get honoreeNameLabel => 'C\'est l\'anniversaire de qui ?';

  @override
  String get honoreeNameHint => 'Entrez son prénom';

  @override
  String get birthYearLabel => 'Année de naissance (optionnel)';

  @override
  String get birthYearHint => 'ex. 1996';

  @override
  String get celebrateTab => 'Fête';

  @override
  String get giftsTab => 'Cadeaux';

  @override
  String get memoriesTab => 'Souvenirs';

  @override
  String birthdayHeroTitle(String name) {
    return 'Anniversaire de $name';
  }

  @override
  String turningAge(int age) {
    return '$age ans';
  }

  @override
  String birthdayCountdownDays(int count) {
    return 'Dans $count jours';
  }

  @override
  String birthdayCountdownHours(int count) {
    return 'Dans $count heures';
  }

  @override
  String get birthdayToday => 'C\'est le grand jour !';

  @override
  String activityVoteTitle(String name) {
    return 'Que faire à la fête de $name ?';
  }

  @override
  String get activityVoteEmpty =>
      'Pas encore d\'activités. L\'organisateur peut en ajouter.';

  @override
  String get addActivityOption => 'Ajouter une activité';

  @override
  String cakeVoteTitle(String name) {
    return 'Quel gâteau veut $name ?';
  }

  @override
  String get cakeVoteEmpty => 'Pas encore d\'options de gâteau !';

  @override
  String get addCakeOption => 'Ajouter une saveur';

  @override
  String wishlistTitle(String name) {
    return 'Liste de $name';
  }

  @override
  String wishlistEmpty(String name) {
    return 'Aucun article. Ajoutez quelque chose que $name aimerait !';
  }

  @override
  String get addWishlistItem => 'Ajouter une idée';

  @override
  String get wishlistItemLabel => 'Idée de cadeau';

  @override
  String get wishlistPriceRange => 'Fourchette de prix (optionnel)';

  @override
  String get wishlistLink => 'Lien (optionnel)';

  @override
  String get claimItem => 'Je m\'en charge !';

  @override
  String get unclaimItem => 'Annuler';

  @override
  String get itemClaimed => 'Quelqu\'un s\'en occupe';

  @override
  String itemClaimedBy(String name) {
    return 'Pris par $name';
  }

  @override
  String get markReceived => 'Marquer reçu';

  @override
  String get giftPoolTitle => 'Cadeau collectif';

  @override
  String get giftPoolEmpty => 'Pas encore de cadeau collectif.';

  @override
  String get createGiftPool => 'Créer un cadeau collectif';

  @override
  String get giftPoolName => 'Nom du cadeau';

  @override
  String get giftPoolTarget => 'Montant cible';

  @override
  String giftPoolProgress(String pledged, String target) {
    return '$pledged sur $target promis';
  }

  @override
  String giftPoolContributors(int count) {
    return '$count contributeurs';
  }

  @override
  String get pledgeAmount => 'Montant à promettre';

  @override
  String get addPledge => 'Promettre';

  @override
  String get myPledge => 'Ma promesse';

  @override
  String get removePledge => 'Retirer ma promesse';

  @override
  String predictionsTitle(String name) {
    return 'Prédictions pour $name';
  }

  @override
  String predictionsSealed(int count) {
    return '$count prédictions scellées';
  }

  @override
  String get revealPredictions => 'Révéler les prédictions';

  @override
  String get predictionsHowItWorks =>
      'Les prédictions sont verrouillées jusqu\'à la date de l\'événement — puis on découvre qui avait raison !';

  @override
  String predictionsEmpty(String name) {
    return 'Aucune prédiction. Que pensez-vous de l\'année de $name ?';
  }

  @override
  String get addPrediction => 'Ajouter une prédiction';

  @override
  String predictionHint(String name) {
    return 'Prédisez quelque chose pour $name...';
  }

  @override
  String wishesTitle(String name) {
    return 'Vœux pour $name';
  }

  @override
  String wishesSealed(String name) {
    return '$name ne peut pas encore les voir';
  }

  @override
  String get wishesHowItWorks =>
      'Les vœux restent secrets jusqu\'à ce que l\'organisateur les révèle le grand jour !';

  @override
  String get wishesEmpty => 'Aucun vœu. Soyez le premier !';

  @override
  String get addWish => 'Faire un vœu';

  @override
  String wishHint(String name) {
    return 'Écrivez votre vœu pour $name...';
  }

  @override
  String get blowOutCandles => 'Souffler les bougies !';

  @override
  String get wishesRevealed => 'Vœux révélés !';

  @override
  String memoryWallTitle(String name) {
    return 'Mur des souvenirs de $name';
  }

  @override
  String memoryWallEmpty(String name) {
    return 'Partagez vos souvenirs avec $name !';
  }

  @override
  String get addMemory => 'Ajouter un souvenir';

  @override
  String memoryCaptionHint(String name) {
    return 'Partagez votre souvenir préféré avec $name...';
  }

  @override
  String get toastsTitle => 'Toasts et discours';

  @override
  String toastsEmpty(String name) {
    return 'Aucun toast. Partagez quelque chose pour $name !';
  }

  @override
  String get addToast => 'Écrire un toast';

  @override
  String get toastTypeSweet => 'Touchant';

  @override
  String get toastTypeFunny => 'Drôle';

  @override
  String get toastTypePoem => 'Poème';

  @override
  String get toastTextHint => 'Écrivez votre discours ici...';

  @override
  String get exportToasts => 'Exporter les discours';

  @override
  String get wishesTab => 'Vœux';

  @override
  String get predictionsTab => 'Prédictions';

  @override
  String get wallTab => 'Mur';

  @override
  String get pleaseSelectEventType =>
      'Veuillez sélectionner un type d\'événement';
}
