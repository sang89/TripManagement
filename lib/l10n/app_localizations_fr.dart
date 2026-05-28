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
  String get declineInviteConfirmTitle => 'Refuser l\'invitation ?';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return 'Refuser l\'invitation pour « $tripTitle » ? Vous perdrez l\'accès.';
  }
}
