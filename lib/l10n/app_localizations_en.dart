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
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get required => 'Required';

  @override
  String get notes => 'Notes';

  @override
  String get email => 'Email';

  @override
  String get phone => 'Phone';

  @override
  String get remove => 'Remove';

  @override
  String get notSet => 'Not set';

  @override
  String failed(String error) {
    return 'Failed: $error';
  }

  @override
  String comingSoon(String feature) {
    return '$feature — Coming soon';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get selectLanguageTitle => 'Select Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get themeSectionTitle => 'Appearance';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accountSectionTitle => 'Account';

  @override
  String get changePasswordTitle => 'Change Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get updatePassword => 'Update Password';

  @override
  String get passwordUpdated => 'Password updated';

  @override
  String get currentPasswordIncorrect => 'Current password is incorrect';

  @override
  String get passwordMinLength => 'At least 8 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountWarning =>
      'This will permanently delete your account and all data. This cannot be undone.';

  @override
  String get deleteAccountInstructions =>
      'To delete your account, please contact support. We\'ll process your request within 48 hours.';

  @override
  String get supportEmail => 'support@tripplanner.app';

  @override
  String get emailCopied => 'Email copied to clipboard';

  @override
  String get copyEmail => 'Copy Email';

  @override
  String get aboutSectionTitle => 'About';

  @override
  String get appVersion => 'App Version';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get myProfile => 'My Profile';

  @override
  String get failedToLoadProfile => 'Failed to load profile';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get editProfileTooltip => 'Edit Profile';

  @override
  String get personalInfoSection => 'Personal Info';

  @override
  String get fullName => 'Full Name';

  @override
  String get fullNameHint => 'Your full name';

  @override
  String get jobTitle => 'Job Title';

  @override
  String get jobTitleHint => 'e.g. Travel Enthusiast';

  @override
  String get contactInfoSection => 'Contact Info';

  @override
  String get managedByAccount => 'Managed by your account';

  @override
  String get memberSince => 'Member since';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get signOut => 'Sign out';

  @override
  String get chooseFromLibrary => 'Choose from Library';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get removePhoto => 'Remove Photo';

  @override
  String uploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get uploadRequiresConnection => 'Upload requires a connection';

  @override
  String get photoUpdated => 'Photo updated';

  @override
  String get removeRequiresConnection =>
      'Requires a connection to remove photo';

  @override
  String removeFailed(String error) {
    return 'Remove failed: $error';
  }

  @override
  String get profileSaved => 'Profile saved';

  @override
  String profileSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmMessage =>
      'You will be returned to the login screen.';

  @override
  String get nameTooLong => 'Name is too long';

  @override
  String get appTitle => 'Trip Planner';

  @override
  String get signInToAccount => 'Sign in to your account';

  @override
  String get planNextAdventure => 'Plan your next adventure';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get createAccount => 'Create Account';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get password => 'Password';

  @override
  String get enterValidEmail => 'Enter a valid email';

  @override
  String get passwordTooShort => 'Password too short';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get passwordMinimum6 => 'Minimum 6 characters';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get myTrips => 'My Trips';

  @override
  String get all => 'All';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get past => 'Past';

  @override
  String get deleteTripTitle => 'Delete trip?';

  @override
  String deleteTripMessage(String tripTitle) {
    return 'Delete \"$tripTitle\"? This cannot be undone.';
  }

  @override
  String get couldNotLoadTrips => 'Could not load trips';

  @override
  String get noTripsYet => 'No trips yet';

  @override
  String get noTripsHint => 'Tap + to get started.';

  @override
  String get noUpcomingTrips => 'No upcoming trips';

  @override
  String get noUpcomingTripsHint => 'Tap + to plan your next adventure.';

  @override
  String get noPastTrips => 'No past trips';

  @override
  String get noPastTripsHint => 'Your completed trips will appear here.';

  @override
  String get editTrip => 'Edit trip';

  @override
  String get newTrip => 'New trip';

  @override
  String get tripTitle => 'Trip title';

  @override
  String get startingFromLabel => 'Starting from (optional)';

  @override
  String get destinationLabel => 'Destination';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get startLabel => 'Start';

  @override
  String get endLabel => 'End';

  @override
  String get setStartDateTime => 'Set start date & time';

  @override
  String get setEndDateTime => 'Set end date & time';

  @override
  String get endDateAfterStart => 'End date must be after start date.';

  @override
  String get stopsSection => 'Stops';

  @override
  String get addStop => 'Add stop';

  @override
  String get noStopsYet => 'No stops added yet.';

  @override
  String get mapSection => 'Map';

  @override
  String get membersSection => 'Members';

  @override
  String get addMember => 'Add member';

  @override
  String get fullNameLabel => 'Name';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get saveTrip => 'Save trip';

  @override
  String get you => 'You';

  @override
  String get organizer => 'Organizer';

  @override
  String get member => 'Member';

  @override
  String get tripNotFound => 'Trip not found';

  @override
  String get editTripTooltip => 'Edit trip';

  @override
  String get overview => 'Overview';

  @override
  String get itinerary => 'Itinerary';

  @override
  String get mapTab => 'Map';

  @override
  String get startingFrom => 'Starting from';

  @override
  String get destination => 'Destination';

  @override
  String get noStopsInItinerary => 'No stops yet';

  @override
  String get addFirstStop => 'Tap + to add your first stop.';

  @override
  String get removeStopTitle => 'Remove stop?';

  @override
  String removeStopMessage(String stopTitle) {
    return 'Remove \"$stopTitle\" from the itinerary?';
  }

  @override
  String get arrive => 'Arrive';

  @override
  String get depart => 'Depart';

  @override
  String get stopTitleLabel => 'Title';

  @override
  String get addressOptional => 'Address (optional)';

  @override
  String get arriveLabel => 'Arrive';

  @override
  String get departLabel => 'Depart';

  @override
  String get addStopButton => 'Add stop';

  @override
  String get editStop => 'Edit stop';

  @override
  String get navTrips => 'Trips';

  @override
  String get navJournal => 'Journal';

  @override
  String get navProfile => 'Profile';

  @override
  String get journalComingSoon => 'Journal coming soon';

  @override
  String get memberSearching => 'Searching…';

  @override
  String get memberAccountFound => 'Account found';

  @override
  String get memberNoAccountFound => 'No account found';

  @override
  String get memberLinkedAccount => 'Linked account';

  @override
  String get invitePending => 'Pending';

  @override
  String get inviteAccepted => 'Accepted';

  @override
  String get inviteDeclined => 'Declined';

  @override
  String tripInvitationsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trip invitations',
      one: '1 trip invitation',
    );
    return '$_temp0';
  }

  @override
  String get acceptInvite => 'Accept';

  @override
  String get declineInvite => 'Decline';

  @override
  String get inviteNotifTitle => 'Trip invitation';

  @override
  String inviteNotifBody(String tripTitle) {
    return 'You\'ve been invited to $tripTitle';
  }
}
