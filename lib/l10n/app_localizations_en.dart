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
  String get selectFriendOptional => 'Select a friend (optional)';

  @override
  String get searchFriends => 'Search friends…';

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
  String get editEventSubtitle => 'Update details, date, or location';

  @override
  String get saveEvent => 'Save event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventDescription => 'Description (optional)';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventCapacity => 'Max members (optional)';

  @override
  String get eventStartDateTime => 'Start date & time';

  @override
  String get eventEndDateTime => 'End date & time (optional)';

  @override
  String get noEventsYet => 'No events yet. Tap + to create one.';

  @override
  String get noUpcomingEvents => 'No upcoming events';

  @override
  String get noUpcomingEventsHint => 'Tap + to plan your next event.';

  @override
  String get noPastEvents => 'No past events yet';

  @override
  String get noPastEventsHint => 'Events you\'ve attended will appear here.';

  @override
  String get filterAll => 'All';

  @override
  String get calendarViewToggle => 'Calendar';

  @override
  String get listViewToggle => 'List';

  @override
  String get noEventsOnDay => 'No events on this day';

  @override
  String get myEvents => 'My events';

  @override
  String get invitedEvents => 'Invited';

  @override
  String get infoTab => 'Info';

  @override
  String get guestsTab => 'Members';

  @override
  String get noGuestsYet => 'No members yet. Tap + to add one.';

  @override
  String get addGuest => 'Add member';

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
  String get noMemoriesYet => 'No memories yet';

  @override
  String get addFirstPhoto => 'Tap + to add your first photo!';

  @override
  String get slideshow => 'Slideshow';

  @override
  String get captionHint => 'Add a caption…';

  @override
  String get photoUploadLimit => 'Upload limit reached. Try again in an hour.';

  @override
  String get photoCapReached => 'This event has reached its photo limit.';

  @override
  String get loadMore => 'Load more';

  @override
  String get storiesEditCaption => 'Edit Caption';

  @override
  String get captionSaved => 'Caption saved';

  @override
  String get saveToGallery => 'Save';

  @override
  String get savedToGallery => 'Saved to Gallery';

  @override
  String get sharePhoto => 'Share';

  @override
  String uploadingProgress(int current, int total) {
    return 'Uploading $current / $total…';
  }

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
  String get splitAmong => 'Split among members';

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
  String get cravingsTab => 'Cravings';

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
  String get foodMoodTitle => 'How hungry are you?';

  @override
  String get foodMoodStarving => 'Starving';

  @override
  String get foodMoodCouldEat => 'Could eat';

  @override
  String get foodMoodDrinksOnly => 'Just for drinks';

  @override
  String get foodMoodNibble => 'I\'ll nibble';

  @override
  String get foodMoodDDMode => 'DD mode';

  @override
  String get cravingsPrompt => 'What are you craving?';

  @override
  String get cravingsHint => 'spicy ramen, cozy vibes, under \$20...';

  @override
  String get cravingsPrivacyNote => 'Only you can see this';

  @override
  String get cravingsFindButton => 'Find me a spot';

  @override
  String get cravingsEmpty => 'No results found. Try different keywords.';

  @override
  String get cravingsPitchButton => 'Pitch to group';

  @override
  String get cravingsPitched => 'Added to group vote!';

  @override
  String get exploreTab => 'Explore';

  @override
  String exploreTitle(String destination) {
    return 'Activities in $destination';
  }

  @override
  String get exploreSubtitle => 'Powered by Viator • GetYourGuide • Klook';

  @override
  String get exploreSortCheapest => 'Cheapest first';

  @override
  String get exploreSortTopRated => 'Top rated';

  @override
  String get exploreMorePlatforms => 'MORE PLATFORMS';

  @override
  String get bookOnViator => 'Book on Viator';

  @override
  String get bookNow => 'Book now';

  @override
  String get browseGetYourGuide => 'Browse GetYourGuide';

  @override
  String get browseKlook => 'Browse Klook';

  @override
  String exploreFromPrice(String price) {
    return 'From $price';
  }

  @override
  String get exploreNoResults => 'No activities found for this destination.';

  @override
  String get exploreLoadError => 'Couldn\'t load suggestions. Tap to retry.';

  @override
  String get restaurantPollTitle => 'Pick a Spot';

  @override
  String get addRestaurantOption => 'Add restaurant';

  @override
  String get restaurantSearchHint => 'Search restaurants...';

  @override
  String get setAsVenueButton => 'Set as venue';

  @override
  String organizedBy(String name) {
    return 'Organised by $name';
  }

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String get deleteEventSubtitle => 'Permanently remove this event';

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
  String get eventTypeQuickBites => 'Quick Bites';

  @override
  String get eventTypeSignup => 'Signup';

  @override
  String signupSpotsFilled(int filled, int total) {
    return '$filled / $total spots filled';
  }

  @override
  String signupWaitlistCount(int count) {
    return '$count on the waitlist';
  }

  @override
  String get signupEventFull => 'Event full';

  @override
  String get signupSessionFull => 'Session full';

  @override
  String get signupJoinWaitlist => 'Join the waitlist';

  @override
  String get signupClaimSpot => 'Claim a Spot';

  @override
  String signupConfirmedPosition(int pos) {
    return 'You\'re #$pos on the list!';
  }

  @override
  String signupWaitlistPosition(int pos) {
    return 'You\'re #$pos on the waitlist';
  }

  @override
  String get signupWaitlistEnabled => 'Enable waitlist';

  @override
  String get signupWaitlistDescription =>
      'Guests over capacity join an ordered waitlist';

  @override
  String get signupRosterTab => 'Roster';

  @override
  String get signupInviteTab => 'Invite';

  @override
  String get signupPromoteGuest => 'Promote to confirmed';

  @override
  String get signupRemoveGuest => 'Remove from event';

  @override
  String get signupCopyLink => 'Copy invite link';

  @override
  String get signupShowQr => 'Show QR Code';

  @override
  String get signupLocked => 'Signups are locked';

  @override
  String get signupLockedMessage =>
      'Signups are locked. Contact the organiser to be removed.';

  @override
  String get signupPendingReview => 'Your request is pending approval';

  @override
  String get signupCancelSpot => 'Cancel my spot';

  @override
  String get signupMarkAttended => 'Attended';

  @override
  String get signupMarkNoShow => 'No-show';

  @override
  String get signupAttendanceHeader => 'Attendance';

  @override
  String get signupRepeat => 'Repeat';

  @override
  String get signupRepeatNone => 'None';

  @override
  String get signupRepeatWeekly => 'Weekly';

  @override
  String get signupRepeatBiweekly => 'Every 2 weeks';

  @override
  String get signupRepeatMonthly => 'Monthly';

  @override
  String get signupNextSession => 'Create next session';

  @override
  String get signupCarryOverGuests => 'Auto-enroll confirmed guests';

  @override
  String get signupCarryOverGuestsHint =>
      'Guests will receive a notification and can opt out';

  @override
  String signupPartOfSeries(String interval) {
    return 'Part of a $interval series';
  }

  @override
  String get chooseEventType => 'What are you planning?';

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

  @override
  String get budgetPerHeadLabel => 'Budget per person (optional)';

  @override
  String get cuisineTagsLabel => 'Cuisine';

  @override
  String get rsvpDeadlineLabel => 'RSVP deadline';

  @override
  String get rsvpDeadlineClosed => 'RSVP closed';

  @override
  String get vibePickerLabel => 'Vibe (optional)';

  @override
  String get honoreeNameLabel => 'Whose birthday is it?';

  @override
  String get honoreeNameHint => 'Enter their name';

  @override
  String get birthYearLabel => 'Birth year (optional)';

  @override
  String get birthYearHint => 'e.g. 1996';

  @override
  String get celebrateTab => 'Party';

  @override
  String get giftsTab => 'Gifts';

  @override
  String get memoriesTab => 'Memories';

  @override
  String birthdayHeroTitle(String name) {
    return '$name\'s Birthday';
  }

  @override
  String turningAge(int age) {
    return 'Turning $age';
  }

  @override
  String birthdayCountdownDays(int count) {
    return '$count days away';
  }

  @override
  String birthdayCountdownHours(int count) {
    return '$count hours away';
  }

  @override
  String get birthdayToday => 'Today\'s the day!';

  @override
  String activityVoteTitle(String name) {
    return 'What should we do at $name\'s party?';
  }

  @override
  String get activityVoteEmpty =>
      'No activities added yet. The organizer can add options to vote on.';

  @override
  String get addActivityOption => 'Add activity';

  @override
  String cakeVoteTitle(String name) {
    return 'What cake does $name want?';
  }

  @override
  String get cakeVoteEmpty =>
      'No cake options yet. Add flavors for everyone to vote on!';

  @override
  String get addCakeOption => 'Add flavor';

  @override
  String wishlistTitle(String name) {
    return '$name\'s Wishlist';
  }

  @override
  String wishlistEmpty(String name) {
    return 'No items yet. Add something $name would love!';
  }

  @override
  String get addWishlistItem => 'Add gift idea';

  @override
  String get wishlistItemLabel => 'Gift idea';

  @override
  String get wishlistPriceRange => 'Price range (optional)';

  @override
  String get wishlistLink => 'Link (optional)';

  @override
  String get claimItem => 'I\'ll get this!';

  @override
  String get unclaimItem => 'Unclaim';

  @override
  String get itemClaimed => 'Someone\'s on it';

  @override
  String itemClaimedBy(String name) {
    return 'Claimed by $name';
  }

  @override
  String get markReceived => 'Mark received';

  @override
  String get giftPoolTitle => 'Group Gift Pool';

  @override
  String get giftPoolEmpty => 'No group gift yet. The organizer can start one.';

  @override
  String get createGiftPool => 'Start a group gift';

  @override
  String get giftPoolName => 'Gift name';

  @override
  String get giftPoolTarget => 'Target amount';

  @override
  String giftPoolProgress(String pledged, String target) {
    return '$pledged of $target pledged';
  }

  @override
  String giftPoolContributors(int count) {
    return '$count contributors';
  }

  @override
  String get pledgeAmount => 'Pledge amount';

  @override
  String get addPledge => 'Pledge';

  @override
  String get myPledge => 'My pledge';

  @override
  String get removePledge => 'Remove pledge';

  @override
  String predictionsTitle(String name) {
    return '$name\'s Predictions';
  }

  @override
  String predictionsSealed(int count) {
    return '$count predictions sealed until the event date';
  }

  @override
  String get revealPredictions => 'Reveal Predictions';

  @override
  String get predictionsHowItWorks =>
      'Predictions are locked until the event date — then everyone finds out who called it!';

  @override
  String predictionsEmpty(String name) {
    return 'No predictions yet. What do you think $name\'s year will bring?';
  }

  @override
  String get addPrediction => 'Add prediction';

  @override
  String predictionHint(String name) {
    return 'Predict something for $name\'s next year...';
  }

  @override
  String wishesTitle(String name) {
    return 'Wishes for $name';
  }

  @override
  String wishesSealed(String name) {
    return '$name can\'t see these yet';
  }

  @override
  String get wishesHowItWorks =>
      'Wishes are kept secret until the organizer reveals them on the big day!';

  @override
  String get wishesEmpty => 'No wishes yet. Be the first to send one!';

  @override
  String get addWish => 'Make a wish';

  @override
  String wishHint(String name) {
    return 'Write your wish for $name...';
  }

  @override
  String get blowOutCandles => 'Blow out the candles!';

  @override
  String get wishesRevealed => 'Wishes revealed!';

  @override
  String memoryWallTitle(String name) {
    return '$name\'s Memory Wall';
  }

  @override
  String memoryWallEmpty(String name) {
    return 'Share your memories with $name!';
  }

  @override
  String get addMemory => 'Add a memory';

  @override
  String memoryCaptionHint(String name) {
    return 'Share your favorite memory with $name...';
  }

  @override
  String get toastsTitle => 'Toasts & Speeches';

  @override
  String toastsEmpty(String name) {
    return 'No toasts yet. Share something sweet or funny for $name!';
  }

  @override
  String get addToast => 'Write a toast';

  @override
  String get toastTypeSweet => 'Sweet';

  @override
  String get toastTypeFunny => 'Funny';

  @override
  String get toastTypePoem => 'Poem';

  @override
  String get toastTextHint => 'Write your speech here...';

  @override
  String get exportToasts => 'Export speeches';

  @override
  String get wishesTab => 'Wishes';

  @override
  String get predictionsTab => 'Predictions';

  @override
  String get wallTab => 'Wall';

  @override
  String get pleaseSelectEventType => 'Please select an event type';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsEmpty => 'You\'re all caught up!';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get sessionActivityTab => 'Activity';

  @override
  String get queueUp => 'Queue Up';

  @override
  String get createQueue => 'Create Queue';

  @override
  String get playersPerRound => 'Players per round';

  @override
  String get maxRounds => 'Max rounds';

  @override
  String get noLimit => 'No limit';

  @override
  String get checkIn => 'Check In';

  @override
  String get checkOut => 'Check Out';

  @override
  String get joinQueue => 'Join Queue';

  @override
  String get leaveQueue => 'Leave Queue';

  @override
  String get startQueue => 'Start';

  @override
  String get nextRound => 'Next Round';

  @override
  String roundN(int n) {
    return 'Round $n';
  }

  @override
  String get allRejoinQueue => 'All Rejoin Queue';

  @override
  String get releaseToFreePool => 'Release to Free Pool';

  @override
  String get freePool => 'Free Pool';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get waitingQueue => 'Waiting';

  @override
  String get queueEnded => 'Queue Ended';

  @override
  String get noQueuesYet => 'No activities yet';

  @override
  String get createFirstQueue => 'Create the first queue to get started';

  @override
  String queueRoundComplete(int n) {
    return 'Round $n complete!';
  }

  @override
  String get setupQueues => 'Set Up Queues';

  @override
  String get numberOfQueues => 'Number of queues';

  @override
  String get spotsPerQueue => 'Spots per queue';

  @override
  String get clearQueue => 'Clear';

  @override
  String get queueFull => 'Queue is full';

  @override
  String get alreadyInQueue => 'You\'re already in a queue';

  @override
  String get addToSlot => 'Grab a spot!';

  @override
  String get addMyselfToQueue => 'I\'m in!';

  @override
  String get addSomeoneElse => 'Add a teammate';

  @override
  String get selectAMember => 'Select a member';

  @override
  String get searchMembersHint => 'Search members…';

  @override
  String get leaveSlotTitle => 'Leave slot?';

  @override
  String leaveSlotMessage(int number) {
    return 'Withdraw from your spot in queue #$number?';
  }

  @override
  String get leaveSlotConfirm => 'Withdraw';

  @override
  String get kickFromSlotTitle => 'Boot \'em?';

  @override
  String kickFromSlotMessage(String name, int number) {
    return 'Remove $name from queue #$number?';
  }

  @override
  String get kickFromSlotConfirm => 'Boot out!';

  @override
  String get allowDuplicates => 'Allow joining multiple queues';

  @override
  String get allowDuplicatesSubtitle =>
      'Members can be in more than one queue at a time';

  @override
  String get customizeQueues => 'Customize queues';
}
