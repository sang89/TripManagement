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
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get orSignInWith => 'or';

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
    return 'Delete $tripTitle? This cannot be undone.';
  }

  @override
  String get leave => 'Leave';

  @override
  String get leaveTripTooltip => 'Leave trip';

  @override
  String get thisTripFallback => 'this trip';

  @override
  String get leaveTripTitle => 'Leave trip?';

  @override
  String leaveTripMessage(String tripTitle) {
    return 'You will be removed from $tripTitle and lose access.';
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
  String get memberLeft => 'Left';

  @override
  String invitedBy(String name) {
    return 'Invited by $name';
  }

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

  @override
  String get blockReinviteLabel =>
      'Don\'t allow future invitations to this trip';

  @override
  String get reinviteBlockedError =>
      'This user has opted out of future invitations to this trip';

  @override
  String get resendInvite => 'Resend invite';

  @override
  String inviteResentTo(String name) {
    return 'Invite resent to $name';
  }

  @override
  String get declineInviteConfirmTitle => 'Decline invitation?';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return 'Decline the invitation to $tripTitle? You will lose access.';
  }

  @override
  String get securitySectionTitle => 'Security';

  @override
  String get biometricToggleTitle => 'Face ID / Touch ID';

  @override
  String get biometricToggleSubtitle => 'Use biometrics to unlock the app';

  @override
  String get biometricLockTitle => 'Verify It\'s You';

  @override
  String get biometricLockSubtitle => 'Authenticate to access your account';

  @override
  String get biometricSignInWithFace => 'Sign in with Face ID';

  @override
  String get biometricSignInWithFingerprint => 'Sign in with Fingerprint';

  @override
  String get biometricSignInWithBiometrics => 'Sign in with Biometrics';

  @override
  String get biometricReason => 'Authenticate to access your account';

  @override
  String get biometricFailed => 'Authentication failed. Please try again.';

  @override
  String get usePasswordInstead => 'Use password instead';

  @override
  String get navFriends => 'Friends';

  @override
  String get friendsTabFriends => 'Friends';

  @override
  String get friendsTabRequests => 'Requests';

  @override
  String get friendsAddFriend => 'Add Friend';

  @override
  String get friendsSearchHint => 'Search by name, email or phone';

  @override
  String get friendsNoResults => 'No users found';

  @override
  String get friendsRequestSent => 'Friend request sent';

  @override
  String get friendsAccept => 'Accept';

  @override
  String get friendsDecline => 'Decline';

  @override
  String get friendsRemove => 'Remove Friend';

  @override
  String friendsRemoveConfirm(String name) {
    return 'Remove $name from your friends?';
  }

  @override
  String get friendsNoFriends => 'No friends yet';

  @override
  String get friendsNoFriendsHint => 'Search for someone to add as a friend.';

  @override
  String get friendsNoRequests => 'No pending requests';

  @override
  String get friendsIncomingSection => 'Incoming';

  @override
  String get friendsOutgoingSection => 'Sent';

  @override
  String get friendsCancelRequest => 'Cancel Request';

  @override
  String get chatTabLabel => 'Chat';

  @override
  String get chatSendHint => 'Message…';

  @override
  String get chatNoMessages => 'No messages yet. Say hello!';

  @override
  String get chatSend => 'Send';

  @override
  String get notificationsSectionTitle => 'Notifications';

  @override
  String get mentionNotifToggleTitle => 'Mention alerts';

  @override
  String get mentionNotifToggleSubtitle =>
      'Get notified when you\'re @mentioned in a trip chat';

  @override
  String get privacySectionTitle => 'Privacy';

  @override
  String get blockedUsersTitle => 'Blocked Users';

  @override
  String get blockedUsersEmpty => 'You haven\'t blocked anyone';

  @override
  String get blockUser => 'Block';

  @override
  String get unblockUser => 'Unblock';

  @override
  String blockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockConfirmBody =>
      'They won\'t be able to add you to trips or send you friend requests.';

  @override
  String blockSuccess(String name) {
    return '$name has been blocked';
  }

  @override
  String unblockSuccess(String name) {
    return '$name has been unblocked';
  }

  @override
  String get contactsButton => 'From Contacts';

  @override
  String get contactsScreenTitle => 'Find from Contacts';

  @override
  String get contactsPermissionDenied =>
      'Contacts access is required to find your friends on TripManagement.';

  @override
  String get contactsOpenSettings => 'Open Settings';

  @override
  String get contactsOnApp => 'On TripManagement';

  @override
  String get contactsInviteSection => 'Invite to TripManagement';

  @override
  String get contactsEmpty => 'No contacts with a phone or email were found.';

  @override
  String get contactsAddFriend => 'Add';

  @override
  String get contactsPending => 'Pending';

  @override
  String get contactsInvite => 'Invite';

  @override
  String contactsInviteMessage(String name) {
    return 'Hey $name! I\'\'m using TripManagement to plan trips together. Join me here: [APP_STORE_LINK]';
  }

  @override
  String get navEvents => 'Events';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get saveEvent => 'Save event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventDescription => 'Description (optional)';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventCapacity => 'Max guests (optional)';

  @override
  String get eventStartDateTime => 'Start date & time';

  @override
  String get eventEndDateTime => 'End date & time (optional)';

  @override
  String get noEventsYet => 'No events yet. Tap + to create one.';

  @override
  String get myEvents => 'My events';

  @override
  String get invitedEvents => 'Invited';

  @override
  String get infoTab => 'Info';

  @override
  String get guestsTab => 'Guests';

  @override
  String get noGuestsYet => 'No guests yet. Tap + to add one.';

  @override
  String get addGuest => 'Add guest';

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
  String get editExpense => 'Edit expense';

  @override
  String get deleteExpenseTitle => 'Delete expense';

  @override
  String deleteExpenseMessage(String description) {
    return 'Delete \"$description\"? This cannot be undone.';
  }

  @override
  String get noExpensesYet => 'No expenses yet';

  @override
  String get expenseDescription => 'What was paid for?';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get splitAmong => 'Split among guests';

  @override
  String get paidBy => 'Paid by';

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String totalOwed(String amount) {
    return 'You owe: $amount';
  }

  @override
  String youAreOwed(String amount) {
    return 'You are owed: $amount';
  }

  @override
  String get settleUp => 'Settle Up';

  @override
  String get totalSpent => 'Total spent';

  @override
  String get theScore => 'The Score';

  @override
  String get settlementPlan => 'Settlement plan';

  @override
  String get allSquare => 'All square! Everyone\'s even 🎉';

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
  String get rsvpNoteHint => 'Add a note (optional)';

  @override
  String get organizeTab => 'Organize';

  @override
  String get detailsTab => 'Details';

  @override
  String get todoTab => 'Todo';

  @override
  String get pollsTab => 'Polls';

  @override
  String get pollsEmpty => 'No polls yet.';

  @override
  String get pollsAddPoll => 'Add poll';

  @override
  String get pollsQuestion => 'Question';

  @override
  String pollsOptionHint(int n) {
    return 'Option $n';
  }

  @override
  String get pollsAddOption => '+ Add option';

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
  String get pollsDeletePoll => 'Delete poll';

  @override
  String get bringListTitle => 'Todo';

  @override
  String get bringListEmpty => 'No tasks yet. Tap + to add one.';

  @override
  String get bringListAddItem => 'Add task';

  @override
  String get bringListEditItem => 'Edit task';

  @override
  String get bringListItemLabel => 'What to do';

  @override
  String get bringListNote => 'Note (optional)';

  @override
  String get bringListAssignTo => 'Assign to member';

  @override
  String get bringListNoAssignment => 'Unassigned';

  @override
  String get bringListTake => 'Take';

  @override
  String get bringListUnassign => 'Unassign';

  @override
  String get rsvpNoteLabel => 'Your note';

  @override
  String get confirmRsvp => 'Confirm';

  @override
  String organizedBy(String name) {
    return 'Organised by $name';
  }

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String deleteEventMessage(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get eventTypeTrip => 'Trip';

  @override
  String get eventTypeBirthday => 'Birthday';

  @override
  String get eventTypeWedding => 'Wedding';

  @override
  String get eventTypeSocial => 'Social';

  @override
  String get eventTypePicker => 'Event type';

  @override
  String get routeTab => 'Route';

  @override
  String get leaveEventTitle => 'Leave event?';

  @override
  String leaveEventMessage(String eventTitle) {
    return 'You will be removed from $eventTitle and lose access.';
  }

  @override
  String get generateWithAi => 'AI Assistant';

  @override
  String get aiTripPlannerSubtitle =>
      'Ask anything about your event — plan activities, explore ideas, or get smart suggestions tailored to your group.';

  @override
  String get aiChatHint => 'Ask me anything...';

  @override
  String get tierFree => 'Basic';

  @override
  String get tierPro => 'Pro';

  @override
  String tierProTrial(String date) {
    return 'Pro Trial · Ends $date';
  }

  @override
  String get cancelTrial => 'Cancel Trial';

  @override
  String get cancelTrialConfirmTitle => 'Cancel your free trial?';

  @override
  String get cancelTrialConfirmMessage =>
      'You will lose access to Pro features immediately. You can upgrade to Pro later.';

  @override
  String get cancelTrialSuccess =>
      'Your trial has been cancelled. You are now on the Basic plan.';

  @override
  String get cancelTrialError => 'Failed to cancel trial. Please try again.';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String get upgradeNow => 'Upgrade Now';

  @override
  String get proAnnualPrice => '\$39.99 / year';

  @override
  String get proMonthlyPrice => '\$4.99 / month';

  @override
  String get proAnnualSavings => 'Save 33%';

  @override
  String get comparePlans => 'Compare plans';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get proFeatureAIPlanner => 'AI Event Assistant';

  @override
  String get proFeatureUnlimitedEvents => 'Unlimited events & guests';

  @override
  String get proFeatureExpenseExport => 'Expense export';

  @override
  String get proFeatureOfflineAccess => 'Offline access';

  @override
  String get proFeatureTemplates => 'Event templates';

  @override
  String get freeEventsLimit => 'Events (3 max)';

  @override
  String get freeGuestsLimit => 'Guests (10 max)';

  @override
  String get freeBasicPlanning => 'RSVP & basic planning';
}
