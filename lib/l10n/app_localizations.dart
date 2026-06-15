import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String failed(String error);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} — Coming soon'**
  String comingSoon(String feature);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @languageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSectionTitle;

  /// No description provided for @selectLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguageTitle;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @themeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get themeSectionTitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @accountSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSectionTitle;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePassword;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get passwordUpdated;

  /// No description provided for @currentPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get currentPasswordIncorrect;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordMinLength;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all data. This cannot be undone.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountInstructions.
  ///
  /// In en, this message translates to:
  /// **'To delete your account, please contact support. We\'ll process your request within 48 hours.'**
  String get deleteAccountInstructions;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'support@tripplanner.app'**
  String get supportEmail;

  /// No description provided for @emailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email copied to clipboard'**
  String get emailCopied;

  /// No description provided for @copyEmail.
  ///
  /// In en, this message translates to:
  /// **'Copy Email'**
  String get copyEmail;

  /// No description provided for @aboutSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSectionTitle;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @failedToLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get failedToLoadProfile;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @editProfileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTooltip;

  /// No description provided for @personalInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Personal Info'**
  String get personalInfoSection;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get fullNameHint;

  /// No description provided for @jobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Title'**
  String get jobTitle;

  /// No description provided for @jobTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Travel Enthusiast'**
  String get jobTitleHint;

  /// No description provided for @contactInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Contact Info'**
  String get contactInfoSection;

  /// No description provided for @managedByAccount.
  ///
  /// In en, this message translates to:
  /// **'Managed by your account'**
  String get managedByAccount;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get memberSince;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @chooseFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from Library'**
  String get chooseFromLibrary;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get removePhoto;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(String error);

  /// No description provided for @uploadRequiresConnection.
  ///
  /// In en, this message translates to:
  /// **'Upload requires a connection'**
  String get uploadRequiresConnection;

  /// No description provided for @photoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get photoUpdated;

  /// No description provided for @removeRequiresConnection.
  ///
  /// In en, this message translates to:
  /// **'Requires a connection to remove photo'**
  String get removeRequiresConnection;

  /// No description provided for @removeFailed.
  ///
  /// In en, this message translates to:
  /// **'Remove failed: {error}'**
  String removeFailed(String error);

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @profileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String profileSaveFailed(String error);

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You will be returned to the login screen.'**
  String get signOutConfirmMessage;

  /// No description provided for @nameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Name is too long'**
  String get nameTooLong;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip Planner'**
  String get appTitle;

  /// No description provided for @signInToAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInToAccount;

  /// No description provided for @planNextAdventure.
  ///
  /// In en, this message translates to:
  /// **'Plan your next adventure'**
  String get planNextAdventure;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password too short'**
  String get passwordTooShort;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @passwordMinimum6.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get passwordMinimum6;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @orSignInWith.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orSignInWith;

  /// No description provided for @myTrips.
  ///
  /// In en, this message translates to:
  /// **'My Trips'**
  String get myTrips;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No description provided for @deleteTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete trip?'**
  String get deleteTripTitle;

  /// No description provided for @deleteTripMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {tripTitle}? This cannot be undone.'**
  String deleteTripMessage(String tripTitle);

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @leaveTripTooltip.
  ///
  /// In en, this message translates to:
  /// **'Leave trip'**
  String get leaveTripTooltip;

  /// No description provided for @thisTripFallback.
  ///
  /// In en, this message translates to:
  /// **'this trip'**
  String get thisTripFallback;

  /// No description provided for @leaveTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave trip?'**
  String get leaveTripTitle;

  /// No description provided for @leaveTripMessage.
  ///
  /// In en, this message translates to:
  /// **'You will be removed from {tripTitle} and lose access.'**
  String leaveTripMessage(String tripTitle);

  /// No description provided for @couldNotLoadTrips.
  ///
  /// In en, this message translates to:
  /// **'Could not load trips'**
  String get couldNotLoadTrips;

  /// No description provided for @noTripsYet.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get noTripsYet;

  /// No description provided for @noTripsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to get started.'**
  String get noTripsHint;

  /// No description provided for @noUpcomingTrips.
  ///
  /// In en, this message translates to:
  /// **'No upcoming trips'**
  String get noUpcomingTrips;

  /// No description provided for @noUpcomingTripsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to plan your next adventure.'**
  String get noUpcomingTripsHint;

  /// No description provided for @noPastTrips.
  ///
  /// In en, this message translates to:
  /// **'No past trips'**
  String get noPastTrips;

  /// No description provided for @noPastTripsHint.
  ///
  /// In en, this message translates to:
  /// **'Your completed trips will appear here.'**
  String get noPastTripsHint;

  /// No description provided for @editTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get editTrip;

  /// No description provided for @newTrip.
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get newTrip;

  /// No description provided for @tripTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip title'**
  String get tripTitle;

  /// No description provided for @startingFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Starting from (optional)'**
  String get startingFromLabel;

  /// No description provided for @destinationLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destinationLabel;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @startLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startLabel;

  /// No description provided for @endLabel.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endLabel;

  /// No description provided for @setStartDateTime.
  ///
  /// In en, this message translates to:
  /// **'Set start date & time'**
  String get setStartDateTime;

  /// No description provided for @setEndDateTime.
  ///
  /// In en, this message translates to:
  /// **'Set end date & time'**
  String get setEndDateTime;

  /// No description provided for @endDateAfterStart.
  ///
  /// In en, this message translates to:
  /// **'End date must be after start date.'**
  String get endDateAfterStart;

  /// No description provided for @stopsSection.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get stopsSection;

  /// No description provided for @addStop.
  ///
  /// In en, this message translates to:
  /// **'Add stop'**
  String get addStop;

  /// No description provided for @noStopsYet.
  ///
  /// In en, this message translates to:
  /// **'No stops added yet.'**
  String get noStopsYet;

  /// No description provided for @mapSection.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapSection;

  /// No description provided for @membersSection.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersSection;

  /// No description provided for @addMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get addMember;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fullNameLabel;

  /// No description provided for @emailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailOptional;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get phoneOptional;

  /// No description provided for @saveTrip.
  ///
  /// In en, this message translates to:
  /// **'Save trip'**
  String get saveTrip;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @organizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get organizer;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @tripNotFound.
  ///
  /// In en, this message translates to:
  /// **'Trip not found'**
  String get tripNotFound;

  /// No description provided for @editTripTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get editTripTooltip;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @itinerary.
  ///
  /// In en, this message translates to:
  /// **'Itinerary'**
  String get itinerary;

  /// No description provided for @mapTab.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapTab;

  /// No description provided for @startingFrom.
  ///
  /// In en, this message translates to:
  /// **'Starting from'**
  String get startingFrom;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @noStopsInItinerary.
  ///
  /// In en, this message translates to:
  /// **'No stops yet'**
  String get noStopsInItinerary;

  /// No description provided for @addFirstStop.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first stop.'**
  String get addFirstStop;

  /// No description provided for @removeStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove stop?'**
  String get removeStopTitle;

  /// No description provided for @removeStopMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{stopTitle}\" from the itinerary?'**
  String removeStopMessage(String stopTitle);

  /// No description provided for @arrive.
  ///
  /// In en, this message translates to:
  /// **'Arrive'**
  String get arrive;

  /// No description provided for @depart.
  ///
  /// In en, this message translates to:
  /// **'Depart'**
  String get depart;

  /// No description provided for @stopTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get stopTitleLabel;

  /// No description provided for @addressOptional.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get addressOptional;

  /// No description provided for @arriveLabel.
  ///
  /// In en, this message translates to:
  /// **'Arrive'**
  String get arriveLabel;

  /// No description provided for @departLabel.
  ///
  /// In en, this message translates to:
  /// **'Depart'**
  String get departLabel;

  /// No description provided for @addStopButton.
  ///
  /// In en, this message translates to:
  /// **'Add stop'**
  String get addStopButton;

  /// No description provided for @editStop.
  ///
  /// In en, this message translates to:
  /// **'Edit stop'**
  String get editStop;

  /// No description provided for @navTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get navTrips;

  /// No description provided for @navJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get navJournal;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @journalComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Journal coming soon'**
  String get journalComingSoon;

  /// No description provided for @memberSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get memberSearching;

  /// No description provided for @memberAccountFound.
  ///
  /// In en, this message translates to:
  /// **'Account found'**
  String get memberAccountFound;

  /// No description provided for @memberNoAccountFound.
  ///
  /// In en, this message translates to:
  /// **'No account found'**
  String get memberNoAccountFound;

  /// No description provided for @memberLinkedAccount.
  ///
  /// In en, this message translates to:
  /// **'Linked account'**
  String get memberLinkedAccount;

  /// No description provided for @selectFriendOptional.
  ///
  /// In en, this message translates to:
  /// **'Select a friend (optional)'**
  String get selectFriendOptional;

  /// No description provided for @searchFriends.
  ///
  /// In en, this message translates to:
  /// **'Search friends…'**
  String get searchFriends;

  /// No description provided for @invitePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get invitePending;

  /// No description provided for @inviteAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get inviteAccepted;

  /// No description provided for @inviteDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get inviteDeclined;

  /// No description provided for @memberLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get memberLeft;

  /// No description provided for @invitedBy.
  ///
  /// In en, this message translates to:
  /// **'Invited by {name}'**
  String invitedBy(String name);

  /// No description provided for @tripInvitationsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 trip invitation} other{{count} trip invitations}}'**
  String tripInvitationsTitle(int count);

  /// No description provided for @acceptInvite.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptInvite;

  /// No description provided for @declineInvite.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineInvite;

  /// No description provided for @inviteNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip invitation'**
  String get inviteNotifTitle;

  /// No description provided for @inviteNotifBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been invited to {tripTitle}'**
  String inviteNotifBody(String tripTitle);

  /// No description provided for @blockReinviteLabel.
  ///
  /// In en, this message translates to:
  /// **'Don\'t allow future invitations to this trip'**
  String get blockReinviteLabel;

  /// No description provided for @reinviteBlockedError.
  ///
  /// In en, this message translates to:
  /// **'This user has opted out of future invitations to this trip'**
  String get reinviteBlockedError;

  /// No description provided for @resendInvite.
  ///
  /// In en, this message translates to:
  /// **'Resend invite'**
  String get resendInvite;

  /// No description provided for @inviteResentTo.
  ///
  /// In en, this message translates to:
  /// **'Invite resent to {name}'**
  String inviteResentTo(String name);

  /// No description provided for @declineInviteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline invitation?'**
  String get declineInviteConfirmTitle;

  /// No description provided for @declineInviteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Decline the invitation to {tripTitle}? You will lose access.'**
  String declineInviteConfirmMessage(String tripTitle);

  /// No description provided for @securitySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securitySectionTitle;

  /// No description provided for @biometricToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Face ID / Touch ID'**
  String get biometricToggleTitle;

  /// No description provided for @biometricToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics to unlock the app'**
  String get biometricToggleSubtitle;

  /// No description provided for @biometricLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify It\'s You'**
  String get biometricLockTitle;

  /// No description provided for @biometricLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to access your account'**
  String get biometricLockSubtitle;

  /// No description provided for @biometricSignInWithFace.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Face ID'**
  String get biometricSignInWithFace;

  /// No description provided for @biometricSignInWithFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Fingerprint'**
  String get biometricSignInWithFingerprint;

  /// No description provided for @biometricSignInWithBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Biometrics'**
  String get biometricSignInWithBiometrics;

  /// No description provided for @biometricReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to access your account'**
  String get biometricReason;

  /// No description provided for @biometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get biometricFailed;

  /// No description provided for @usePasswordInstead.
  ///
  /// In en, this message translates to:
  /// **'Use password instead'**
  String get usePasswordInstead;

  /// No description provided for @navFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get navFriends;

  /// No description provided for @friendsTabFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTabFriends;

  /// No description provided for @friendsTabRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get friendsTabRequests;

  /// No description provided for @friendsAddFriend.
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get friendsAddFriend;

  /// No description provided for @friendsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, email or phone'**
  String get friendsSearchHint;

  /// No description provided for @friendsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get friendsNoResults;

  /// No description provided for @friendsRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Friend request sent'**
  String get friendsRequestSent;

  /// No description provided for @friendsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get friendsAccept;

  /// No description provided for @friendsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get friendsDecline;

  /// No description provided for @friendsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove Friend'**
  String get friendsRemove;

  /// No description provided for @friendsRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from your friends?'**
  String friendsRemoveConfirm(String name);

  /// No description provided for @friendsNoFriends.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get friendsNoFriends;

  /// No description provided for @friendsNoFriendsHint.
  ///
  /// In en, this message translates to:
  /// **'Search for someone to add as a friend.'**
  String get friendsNoFriendsHint;

  /// No description provided for @friendsNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get friendsNoRequests;

  /// No description provided for @friendsIncomingSection.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get friendsIncomingSection;

  /// No description provided for @friendsOutgoingSection.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get friendsOutgoingSection;

  /// No description provided for @friendsCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get friendsCancelRequest;

  /// No description provided for @chatTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTabLabel;

  /// No description provided for @chatSendHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get chatSendHint;

  /// No description provided for @chatNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get chatNoMessages;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @notificationsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsSectionTitle;

  /// No description provided for @mentionNotifToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Mention alerts'**
  String get mentionNotifToggleTitle;

  /// No description provided for @mentionNotifToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified when you\'re @mentioned in a trip chat'**
  String get mentionNotifToggleSubtitle;

  /// No description provided for @privacySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacySectionTitle;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsersTitle;

  /// No description provided for @blockedUsersEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone'**
  String get blockedUsersEmpty;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blockUser;

  /// No description provided for @unblockUser.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblockUser;

  /// No description provided for @blockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockConfirmTitle(String name);

  /// No description provided for @blockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to add you to trips or send you friend requests.'**
  String get blockConfirmBody;

  /// No description provided for @blockSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} has been blocked'**
  String blockSuccess(String name);

  /// No description provided for @unblockSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} has been unblocked'**
  String unblockSuccess(String name);

  /// No description provided for @contactsButton.
  ///
  /// In en, this message translates to:
  /// **'From Contacts'**
  String get contactsButton;

  /// No description provided for @contactsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Find from Contacts'**
  String get contactsScreenTitle;

  /// No description provided for @contactsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Contacts access is required to find your friends on TripManagement.'**
  String get contactsPermissionDenied;

  /// No description provided for @contactsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get contactsOpenSettings;

  /// No description provided for @contactsOnApp.
  ///
  /// In en, this message translates to:
  /// **'On TripManagement'**
  String get contactsOnApp;

  /// No description provided for @contactsInviteSection.
  ///
  /// In en, this message translates to:
  /// **'Invite to TripManagement'**
  String get contactsInviteSection;

  /// No description provided for @contactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No contacts with a phone or email were found.'**
  String get contactsEmpty;

  /// No description provided for @contactsAddFriend.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get contactsAddFriend;

  /// No description provided for @contactsPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get contactsPending;

  /// No description provided for @contactsInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get contactsInvite;

  /// No description provided for @contactsInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Hey {name}! I\'\'m using TripManagement to plan trips together. Join me here: [APP_STORE_LINK]'**
  String contactsInviteMessage(String name);

  /// No description provided for @navEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get navEvents;

  /// No description provided for @newEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get newEvent;

  /// No description provided for @editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get editEvent;

  /// No description provided for @editEventSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update details, date, or location'**
  String get editEventSubtitle;

  /// No description provided for @saveEvent.
  ///
  /// In en, this message translates to:
  /// **'Save event'**
  String get saveEvent;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Event title'**
  String get eventTitle;

  /// No description provided for @eventDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get eventDescription;

  /// No description provided for @eventLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get eventLocation;

  /// No description provided for @eventCapacity.
  ///
  /// In en, this message translates to:
  /// **'Max members (optional)'**
  String get eventCapacity;

  /// No description provided for @eventStartDateTime.
  ///
  /// In en, this message translates to:
  /// **'Start date & time'**
  String get eventStartDateTime;

  /// No description provided for @eventEndDateTime.
  ///
  /// In en, this message translates to:
  /// **'End date & time (optional)'**
  String get eventEndDateTime;

  /// No description provided for @noEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet. Tap + to create one.'**
  String get noEventsYet;

  /// No description provided for @noUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events'**
  String get noUpcomingEvents;

  /// No description provided for @noUpcomingEventsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to plan your next event.'**
  String get noUpcomingEventsHint;

  /// No description provided for @noPastEvents.
  ///
  /// In en, this message translates to:
  /// **'No past events yet'**
  String get noPastEvents;

  /// No description provided for @noPastEventsHint.
  ///
  /// In en, this message translates to:
  /// **'Events you\'ve attended will appear here.'**
  String get noPastEventsHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @calendarViewToggle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarViewToggle;

  /// No description provided for @listViewToggle.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get listViewToggle;

  /// No description provided for @noEventsOnDay.
  ///
  /// In en, this message translates to:
  /// **'No events on this day'**
  String get noEventsOnDay;

  /// No description provided for @myEvents.
  ///
  /// In en, this message translates to:
  /// **'My events'**
  String get myEvents;

  /// No description provided for @invitedEvents.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get invitedEvents;

  /// No description provided for @infoTab.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get infoTab;

  /// No description provided for @guestsTab.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get guestsTab;

  /// No description provided for @noGuestsYet.
  ///
  /// In en, this message translates to:
  /// **'No members yet. Tap + to add one.'**
  String get noGuestsYet;

  /// No description provided for @addGuest.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get addGuest;

  /// No description provided for @photosTab.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photosTab;

  /// No description provided for @expensesTab.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTab;

  /// No description provided for @rsvpGoing.
  ///
  /// In en, this message translates to:
  /// **'Going'**
  String get rsvpGoing;

  /// No description provided for @rsvpMaybe.
  ///
  /// In en, this message translates to:
  /// **'Maybe'**
  String get rsvpMaybe;

  /// No description provided for @rsvpDeclined.
  ///
  /// In en, this message translates to:
  /// **'Can\'t go'**
  String get rsvpDeclined;

  /// No description provided for @changeRsvp.
  ///
  /// In en, this message translates to:
  /// **'Change RSVP'**
  String get changeRsvp;

  /// No description provided for @goingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} going'**
  String goingCount(int count);

  /// No description provided for @maybeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} maybe'**
  String maybeCount(int count);

  /// No description provided for @declinedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} can\'t go'**
  String declinedCount(int count);

  /// No description provided for @shareEvent.
  ///
  /// In en, this message translates to:
  /// **'Share event'**
  String get shareEvent;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @noPhotosYet.
  ///
  /// In en, this message translates to:
  /// **'No photos yet.'**
  String get noPhotosYet;

  /// No description provided for @deletePhoto.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get deletePhoto;

  /// No description provided for @deletePhotoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get deletePhotoConfirm;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// No description provided for @editExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editExpense;

  /// No description provided for @deleteExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete expense'**
  String get deleteExpenseTitle;

  /// No description provided for @deleteExpenseMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{description}\"? This cannot be undone.'**
  String deleteExpenseMessage(String description);

  /// No description provided for @noExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get noExpensesYet;

  /// No description provided for @expenseDescription.
  ///
  /// In en, this message translates to:
  /// **'What was paid for?'**
  String get expenseDescription;

  /// No description provided for @expenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseAmount;

  /// No description provided for @splitAmong.
  ///
  /// In en, this message translates to:
  /// **'Split among members'**
  String get splitAmong;

  /// No description provided for @paidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get paidBy;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// No description provided for @totalOwed.
  ///
  /// In en, this message translates to:
  /// **'You owe: {amount}'**
  String totalOwed(String amount);

  /// No description provided for @youAreOwed.
  ///
  /// In en, this message translates to:
  /// **'You are owed: {amount}'**
  String youAreOwed(String amount);

  /// No description provided for @settleUp.
  ///
  /// In en, this message translates to:
  /// **'Settle Up'**
  String get settleUp;

  /// No description provided for @totalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get totalSpent;

  /// No description provided for @theScore.
  ///
  /// In en, this message translates to:
  /// **'The Score'**
  String get theScore;

  /// No description provided for @settlementPlan.
  ///
  /// In en, this message translates to:
  /// **'Settlement plan'**
  String get settlementPlan;

  /// No description provided for @allSquare.
  ///
  /// In en, this message translates to:
  /// **'All square! Everyone\'s even 🎉'**
  String get allSquare;

  /// No description provided for @eventFull.
  ///
  /// In en, this message translates to:
  /// **'This event is at capacity.'**
  String get eventFull;

  /// No description provided for @publicRsvpTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re invited!'**
  String get publicRsvpTitle;

  /// No description provided for @publicRsvpName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get publicRsvpName;

  /// No description provided for @publicRsvpEmail.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get publicRsvpEmail;

  /// No description provided for @publicRsvpPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get publicRsvpPhone;

  /// No description provided for @rsvpSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your RSVP was saved!'**
  String get rsvpSuccess;

  /// No description provided for @rsvpNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get rsvpNoteHint;

  /// No description provided for @organizeTab.
  ///
  /// In en, this message translates to:
  /// **'Organize'**
  String get organizeTab;

  /// No description provided for @detailsTab.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsTab;

  /// No description provided for @todoTab.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get todoTab;

  /// No description provided for @cravingsTab.
  ///
  /// In en, this message translates to:
  /// **'Cravings'**
  String get cravingsTab;

  /// No description provided for @pollsTab.
  ///
  /// In en, this message translates to:
  /// **'Polls'**
  String get pollsTab;

  /// No description provided for @pollsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No polls yet.'**
  String get pollsEmpty;

  /// No description provided for @pollsAddPoll.
  ///
  /// In en, this message translates to:
  /// **'Add poll'**
  String get pollsAddPoll;

  /// No description provided for @pollsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get pollsQuestion;

  /// No description provided for @pollsOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Option {n}'**
  String pollsOptionHint(int n);

  /// No description provided for @pollsAddOption.
  ///
  /// In en, this message translates to:
  /// **'+ Add option'**
  String get pollsAddOption;

  /// No description provided for @pollsVoteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 vote} other{{count} votes}}'**
  String pollsVoteCount(int count);

  /// No description provided for @pollsDeletePoll.
  ///
  /// In en, this message translates to:
  /// **'Delete poll'**
  String get pollsDeletePoll;

  /// No description provided for @bringListTitle.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get bringListTitle;

  /// No description provided for @bringListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet. Tap + to add one.'**
  String get bringListEmpty;

  /// No description provided for @bringListAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get bringListAddItem;

  /// No description provided for @bringListEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get bringListEditItem;

  /// No description provided for @bringListItemLabel.
  ///
  /// In en, this message translates to:
  /// **'What to do'**
  String get bringListItemLabel;

  /// No description provided for @bringListNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get bringListNote;

  /// No description provided for @bringListAssignTo.
  ///
  /// In en, this message translates to:
  /// **'Assign to member'**
  String get bringListAssignTo;

  /// No description provided for @bringListNoAssignment.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get bringListNoAssignment;

  /// No description provided for @bringListTake.
  ///
  /// In en, this message translates to:
  /// **'Take'**
  String get bringListTake;

  /// No description provided for @bringListUnassign.
  ///
  /// In en, this message translates to:
  /// **'Unassign'**
  String get bringListUnassign;

  /// No description provided for @rsvpNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get rsvpNoteLabel;

  /// No description provided for @confirmRsvp.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmRsvp;

  /// No description provided for @foodMoodTitle.
  ///
  /// In en, this message translates to:
  /// **'How hungry are you?'**
  String get foodMoodTitle;

  /// No description provided for @foodMoodStarving.
  ///
  /// In en, this message translates to:
  /// **'Starving'**
  String get foodMoodStarving;

  /// No description provided for @foodMoodCouldEat.
  ///
  /// In en, this message translates to:
  /// **'Could eat'**
  String get foodMoodCouldEat;

  /// No description provided for @foodMoodDrinksOnly.
  ///
  /// In en, this message translates to:
  /// **'Just for drinks'**
  String get foodMoodDrinksOnly;

  /// No description provided for @foodMoodNibble.
  ///
  /// In en, this message translates to:
  /// **'I\'ll nibble'**
  String get foodMoodNibble;

  /// No description provided for @foodMoodDDMode.
  ///
  /// In en, this message translates to:
  /// **'DD mode'**
  String get foodMoodDDMode;

  /// No description provided for @cravingsPrompt.
  ///
  /// In en, this message translates to:
  /// **'What are you craving?'**
  String get cravingsPrompt;

  /// No description provided for @cravingsHint.
  ///
  /// In en, this message translates to:
  /// **'spicy ramen, cozy vibes, under \$20...'**
  String get cravingsHint;

  /// No description provided for @cravingsPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this'**
  String get cravingsPrivacyNote;

  /// No description provided for @cravingsFindButton.
  ///
  /// In en, this message translates to:
  /// **'Find me a spot'**
  String get cravingsFindButton;

  /// No description provided for @cravingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No results found. Try different keywords.'**
  String get cravingsEmpty;

  /// No description provided for @cravingsPitchButton.
  ///
  /// In en, this message translates to:
  /// **'Pitch to group'**
  String get cravingsPitchButton;

  /// No description provided for @cravingsPitched.
  ///
  /// In en, this message translates to:
  /// **'Added to group vote!'**
  String get cravingsPitched;

  /// No description provided for @restaurantPollTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a Spot'**
  String get restaurantPollTitle;

  /// No description provided for @addRestaurantOption.
  ///
  /// In en, this message translates to:
  /// **'Add restaurant'**
  String get addRestaurantOption;

  /// No description provided for @restaurantSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants...'**
  String get restaurantSearchHint;

  /// No description provided for @setAsVenueButton.
  ///
  /// In en, this message translates to:
  /// **'Set as venue'**
  String get setAsVenueButton;

  /// No description provided for @organizedBy.
  ///
  /// In en, this message translates to:
  /// **'Organised by {name}'**
  String organizedBy(String name);

  /// No description provided for @deleteEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get deleteEventTitle;

  /// No description provided for @deleteEventSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove this event'**
  String get deleteEventSubtitle;

  /// No description provided for @deleteEventMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This cannot be undone.'**
  String deleteEventMessage(String title);

  /// No description provided for @eventTypeTrip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get eventTypeTrip;

  /// No description provided for @eventTypeBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get eventTypeBirthday;

  /// No description provided for @eventTypeWedding.
  ///
  /// In en, this message translates to:
  /// **'Wedding'**
  String get eventTypeWedding;

  /// No description provided for @eventTypeSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get eventTypeSocial;

  /// No description provided for @eventTypeQuickBites.
  ///
  /// In en, this message translates to:
  /// **'Quick Bites'**
  String get eventTypeQuickBites;

  /// No description provided for @eventTypeSignup.
  ///
  /// In en, this message translates to:
  /// **'Signup'**
  String get eventTypeSignup;

  /// No description provided for @signupSpotsFilled.
  ///
  /// In en, this message translates to:
  /// **'{filled} / {total} spots filled'**
  String signupSpotsFilled(int filled, int total);

  /// No description provided for @signupWaitlistCount.
  ///
  /// In en, this message translates to:
  /// **'{count} on the waitlist'**
  String signupWaitlistCount(int count);

  /// No description provided for @signupEventFull.
  ///
  /// In en, this message translates to:
  /// **'Event full'**
  String get signupEventFull;

  /// No description provided for @signupJoinWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join the waitlist'**
  String get signupJoinWaitlist;

  /// No description provided for @signupClaimSpot.
  ///
  /// In en, this message translates to:
  /// **'Claim a Spot'**
  String get signupClaimSpot;

  /// No description provided for @signupConfirmedPosition.
  ///
  /// In en, this message translates to:
  /// **'You\'re #{pos} on the list!'**
  String signupConfirmedPosition(int pos);

  /// No description provided for @signupWaitlistPosition.
  ///
  /// In en, this message translates to:
  /// **'You\'re #{pos} on the waitlist'**
  String signupWaitlistPosition(int pos);

  /// No description provided for @signupWaitlistEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable waitlist'**
  String get signupWaitlistEnabled;

  /// No description provided for @signupWaitlistDescription.
  ///
  /// In en, this message translates to:
  /// **'Guests over capacity join an ordered waitlist'**
  String get signupWaitlistDescription;

  /// No description provided for @signupRosterTab.
  ///
  /// In en, this message translates to:
  /// **'Roster'**
  String get signupRosterTab;

  /// No description provided for @signupInviteTab.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get signupInviteTab;

  /// No description provided for @signupPromoteGuest.
  ///
  /// In en, this message translates to:
  /// **'Promote to confirmed'**
  String get signupPromoteGuest;

  /// No description provided for @signupRemoveGuest.
  ///
  /// In en, this message translates to:
  /// **'Remove from event'**
  String get signupRemoveGuest;

  /// No description provided for @signupCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy invite link'**
  String get signupCopyLink;

  /// No description provided for @signupShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show QR Code'**
  String get signupShowQr;

  /// No description provided for @signupLocked.
  ///
  /// In en, this message translates to:
  /// **'Signups are locked'**
  String get signupLocked;

  /// No description provided for @signupLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Signups are locked. Contact the organiser to be removed.'**
  String get signupLockedMessage;

  /// No description provided for @signupPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Your request is pending approval'**
  String get signupPendingReview;

  /// No description provided for @signupCancelSpot.
  ///
  /// In en, this message translates to:
  /// **'Cancel my spot'**
  String get signupCancelSpot;

  /// No description provided for @signupMarkAttended.
  ///
  /// In en, this message translates to:
  /// **'Attended'**
  String get signupMarkAttended;

  /// No description provided for @signupMarkNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get signupMarkNoShow;

  /// No description provided for @signupAttendanceHeader.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get signupAttendanceHeader;

  /// No description provided for @signupRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get signupRepeat;

  /// No description provided for @signupRepeatNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get signupRepeatNone;

  /// No description provided for @signupRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get signupRepeatWeekly;

  /// No description provided for @signupRepeatBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get signupRepeatBiweekly;

  /// No description provided for @signupRepeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get signupRepeatMonthly;

  /// No description provided for @signupNextSession.
  ///
  /// In en, this message translates to:
  /// **'Create next session'**
  String get signupNextSession;

  /// No description provided for @signupCarryOverGuests.
  ///
  /// In en, this message translates to:
  /// **'Auto-enroll confirmed guests'**
  String get signupCarryOverGuests;

  /// No description provided for @signupCarryOverGuestsHint.
  ///
  /// In en, this message translates to:
  /// **'Guests will receive a notification and can opt out'**
  String get signupCarryOverGuestsHint;

  /// No description provided for @signupPartOfSeries.
  ///
  /// In en, this message translates to:
  /// **'Part of a {interval} series'**
  String signupPartOfSeries(String interval);

  /// No description provided for @chooseEventType.
  ///
  /// In en, this message translates to:
  /// **'What are you planning?'**
  String get chooseEventType;

  /// No description provided for @eventTypePicker.
  ///
  /// In en, this message translates to:
  /// **'Event type'**
  String get eventTypePicker;

  /// No description provided for @routeTab.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get routeTab;

  /// No description provided for @leaveEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave event?'**
  String get leaveEventTitle;

  /// No description provided for @leaveEventMessage.
  ///
  /// In en, this message translates to:
  /// **'You will be removed from {eventTitle} and lose access.'**
  String leaveEventMessage(String eventTitle);

  /// No description provided for @generateWithAi.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get generateWithAi;

  /// No description provided for @aiTripPlannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about your event — plan activities, explore ideas, or get smart suggestions tailored to your group.'**
  String get aiTripPlannerSubtitle;

  /// No description provided for @aiChatHint.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything...'**
  String get aiChatHint;

  /// No description provided for @tierFree.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get tierFree;

  /// No description provided for @tierPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get tierPro;

  /// No description provided for @tierProTrial.
  ///
  /// In en, this message translates to:
  /// **'Pro Trial · Ends {date}'**
  String tierProTrial(String date);

  /// No description provided for @cancelTrial.
  ///
  /// In en, this message translates to:
  /// **'Cancel Trial'**
  String get cancelTrial;

  /// No description provided for @cancelTrialConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel your free trial?'**
  String get cancelTrialConfirmTitle;

  /// No description provided for @cancelTrialConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You will lose access to Pro features immediately. You can upgrade to Pro later.'**
  String get cancelTrialConfirmMessage;

  /// No description provided for @cancelTrialSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your trial has been cancelled. You are now on the Basic plan.'**
  String get cancelTrialSuccess;

  /// No description provided for @cancelTrialError.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel trial. Please try again.'**
  String get cancelTrialError;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @upgradeNow.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Now'**
  String get upgradeNow;

  /// No description provided for @proAnnualPrice.
  ///
  /// In en, this message translates to:
  /// **'\$39.99 / year'**
  String get proAnnualPrice;

  /// No description provided for @proMonthlyPrice.
  ///
  /// In en, this message translates to:
  /// **'\$4.99 / month'**
  String get proMonthlyPrice;

  /// No description provided for @proAnnualSavings.
  ///
  /// In en, this message translates to:
  /// **'Save 33%'**
  String get proAnnualSavings;

  /// No description provided for @comparePlans.
  ///
  /// In en, this message translates to:
  /// **'Compare plans'**
  String get comparePlans;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @proFeatureAIPlanner.
  ///
  /// In en, this message translates to:
  /// **'AI Event Assistant'**
  String get proFeatureAIPlanner;

  /// No description provided for @proFeatureUnlimitedEvents.
  ///
  /// In en, this message translates to:
  /// **'Unlimited events & guests'**
  String get proFeatureUnlimitedEvents;

  /// No description provided for @proFeatureExpenseExport.
  ///
  /// In en, this message translates to:
  /// **'Expense export'**
  String get proFeatureExpenseExport;

  /// No description provided for @proFeatureOfflineAccess.
  ///
  /// In en, this message translates to:
  /// **'Offline access'**
  String get proFeatureOfflineAccess;

  /// No description provided for @proFeatureTemplates.
  ///
  /// In en, this message translates to:
  /// **'Event templates'**
  String get proFeatureTemplates;

  /// No description provided for @freeEventsLimit.
  ///
  /// In en, this message translates to:
  /// **'Events (3 max)'**
  String get freeEventsLimit;

  /// No description provided for @freeGuestsLimit.
  ///
  /// In en, this message translates to:
  /// **'Guests (10 max)'**
  String get freeGuestsLimit;

  /// No description provided for @freeBasicPlanning.
  ///
  /// In en, this message translates to:
  /// **'RSVP & basic planning'**
  String get freeBasicPlanning;

  /// No description provided for @budgetPerHeadLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget per person (optional)'**
  String get budgetPerHeadLabel;

  /// No description provided for @cuisineTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cuisine'**
  String get cuisineTagsLabel;

  /// No description provided for @rsvpDeadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'RSVP deadline'**
  String get rsvpDeadlineLabel;

  /// No description provided for @rsvpDeadlineClosed.
  ///
  /// In en, this message translates to:
  /// **'RSVP closed'**
  String get rsvpDeadlineClosed;

  /// No description provided for @vibePickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Vibe (optional)'**
  String get vibePickerLabel;

  /// No description provided for @honoreeNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Whose birthday is it?'**
  String get honoreeNameLabel;

  /// No description provided for @honoreeNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter their name'**
  String get honoreeNameHint;

  /// No description provided for @birthYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Birth year (optional)'**
  String get birthYearLabel;

  /// No description provided for @birthYearHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1996'**
  String get birthYearHint;

  /// No description provided for @celebrateTab.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get celebrateTab;

  /// No description provided for @giftsTab.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get giftsTab;

  /// No description provided for @memoriesTab.
  ///
  /// In en, this message translates to:
  /// **'Memories'**
  String get memoriesTab;

  /// No description provided for @birthdayHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Birthday'**
  String birthdayHeroTitle(String name);

  /// No description provided for @turningAge.
  ///
  /// In en, this message translates to:
  /// **'Turning {age}'**
  String turningAge(int age);

  /// No description provided for @birthdayCountdownDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days away'**
  String birthdayCountdownDays(int count);

  /// No description provided for @birthdayCountdownHours.
  ///
  /// In en, this message translates to:
  /// **'{count} hours away'**
  String birthdayCountdownHours(int count);

  /// No description provided for @birthdayToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s the day!'**
  String get birthdayToday;

  /// No description provided for @activityVoteTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we do at {name}\'s party?'**
  String activityVoteTitle(String name);

  /// No description provided for @activityVoteEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activities added yet. The organizer can add options to vote on.'**
  String get activityVoteEmpty;

  /// No description provided for @addActivityOption.
  ///
  /// In en, this message translates to:
  /// **'Add activity'**
  String get addActivityOption;

  /// No description provided for @cakeVoteTitle.
  ///
  /// In en, this message translates to:
  /// **'What cake does {name} want?'**
  String cakeVoteTitle(String name);

  /// No description provided for @cakeVoteEmpty.
  ///
  /// In en, this message translates to:
  /// **'No cake options yet. Add flavors for everyone to vote on!'**
  String get cakeVoteEmpty;

  /// No description provided for @addCakeOption.
  ///
  /// In en, this message translates to:
  /// **'Add flavor'**
  String get addCakeOption;

  /// No description provided for @wishlistTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Wishlist'**
  String wishlistTitle(String name);

  /// No description provided for @wishlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'No items yet. Add something {name} would love!'**
  String wishlistEmpty(String name);

  /// No description provided for @addWishlistItem.
  ///
  /// In en, this message translates to:
  /// **'Add gift idea'**
  String get addWishlistItem;

  /// No description provided for @wishlistItemLabel.
  ///
  /// In en, this message translates to:
  /// **'Gift idea'**
  String get wishlistItemLabel;

  /// No description provided for @wishlistPriceRange.
  ///
  /// In en, this message translates to:
  /// **'Price range (optional)'**
  String get wishlistPriceRange;

  /// No description provided for @wishlistLink.
  ///
  /// In en, this message translates to:
  /// **'Link (optional)'**
  String get wishlistLink;

  /// No description provided for @claimItem.
  ///
  /// In en, this message translates to:
  /// **'I\'ll get this!'**
  String get claimItem;

  /// No description provided for @unclaimItem.
  ///
  /// In en, this message translates to:
  /// **'Unclaim'**
  String get unclaimItem;

  /// No description provided for @itemClaimed.
  ///
  /// In en, this message translates to:
  /// **'Someone\'s on it'**
  String get itemClaimed;

  /// No description provided for @itemClaimedBy.
  ///
  /// In en, this message translates to:
  /// **'Claimed by {name}'**
  String itemClaimedBy(String name);

  /// No description provided for @markReceived.
  ///
  /// In en, this message translates to:
  /// **'Mark received'**
  String get markReceived;

  /// No description provided for @giftPoolTitle.
  ///
  /// In en, this message translates to:
  /// **'Group Gift Pool'**
  String get giftPoolTitle;

  /// No description provided for @giftPoolEmpty.
  ///
  /// In en, this message translates to:
  /// **'No group gift yet. The organizer can start one.'**
  String get giftPoolEmpty;

  /// No description provided for @createGiftPool.
  ///
  /// In en, this message translates to:
  /// **'Start a group gift'**
  String get createGiftPool;

  /// No description provided for @giftPoolName.
  ///
  /// In en, this message translates to:
  /// **'Gift name'**
  String get giftPoolName;

  /// No description provided for @giftPoolTarget.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get giftPoolTarget;

  /// No description provided for @giftPoolProgress.
  ///
  /// In en, this message translates to:
  /// **'{pledged} of {target} pledged'**
  String giftPoolProgress(String pledged, String target);

  /// No description provided for @giftPoolContributors.
  ///
  /// In en, this message translates to:
  /// **'{count} contributors'**
  String giftPoolContributors(int count);

  /// No description provided for @pledgeAmount.
  ///
  /// In en, this message translates to:
  /// **'Pledge amount'**
  String get pledgeAmount;

  /// No description provided for @addPledge.
  ///
  /// In en, this message translates to:
  /// **'Pledge'**
  String get addPledge;

  /// No description provided for @myPledge.
  ///
  /// In en, this message translates to:
  /// **'My pledge'**
  String get myPledge;

  /// No description provided for @removePledge.
  ///
  /// In en, this message translates to:
  /// **'Remove pledge'**
  String get removePledge;

  /// No description provided for @predictionsTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Predictions'**
  String predictionsTitle(String name);

  /// No description provided for @predictionsSealed.
  ///
  /// In en, this message translates to:
  /// **'{count} predictions sealed until the event date'**
  String predictionsSealed(int count);

  /// No description provided for @revealPredictions.
  ///
  /// In en, this message translates to:
  /// **'Reveal Predictions'**
  String get revealPredictions;

  /// No description provided for @predictionsHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'Predictions are locked until the event date — then everyone finds out who called it!'**
  String get predictionsHowItWorks;

  /// No description provided for @predictionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No predictions yet. What do you think {name}\'s year will bring?'**
  String predictionsEmpty(String name);

  /// No description provided for @addPrediction.
  ///
  /// In en, this message translates to:
  /// **'Add prediction'**
  String get addPrediction;

  /// No description provided for @predictionHint.
  ///
  /// In en, this message translates to:
  /// **'Predict something for {name}\'s next year...'**
  String predictionHint(String name);

  /// No description provided for @wishesTitle.
  ///
  /// In en, this message translates to:
  /// **'Wishes for {name}'**
  String wishesTitle(String name);

  /// No description provided for @wishesSealed.
  ///
  /// In en, this message translates to:
  /// **'{name} can\'t see these yet'**
  String wishesSealed(String name);

  /// No description provided for @wishesHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'Wishes are kept secret until the organizer reveals them on the big day!'**
  String get wishesHowItWorks;

  /// No description provided for @wishesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No wishes yet. Be the first to send one!'**
  String get wishesEmpty;

  /// No description provided for @addWish.
  ///
  /// In en, this message translates to:
  /// **'Make a wish'**
  String get addWish;

  /// No description provided for @wishHint.
  ///
  /// In en, this message translates to:
  /// **'Write your wish for {name}...'**
  String wishHint(String name);

  /// No description provided for @blowOutCandles.
  ///
  /// In en, this message translates to:
  /// **'Blow out the candles!'**
  String get blowOutCandles;

  /// No description provided for @wishesRevealed.
  ///
  /// In en, this message translates to:
  /// **'Wishes revealed!'**
  String get wishesRevealed;

  /// No description provided for @memoryWallTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Memory Wall'**
  String memoryWallTitle(String name);

  /// No description provided for @memoryWallEmpty.
  ///
  /// In en, this message translates to:
  /// **'Share your memories with {name}!'**
  String memoryWallEmpty(String name);

  /// No description provided for @addMemory.
  ///
  /// In en, this message translates to:
  /// **'Add a memory'**
  String get addMemory;

  /// No description provided for @memoryCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Share your favorite memory with {name}...'**
  String memoryCaptionHint(String name);

  /// No description provided for @toastsTitle.
  ///
  /// In en, this message translates to:
  /// **'Toasts & Speeches'**
  String get toastsTitle;

  /// No description provided for @toastsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No toasts yet. Share something sweet or funny for {name}!'**
  String toastsEmpty(String name);

  /// No description provided for @addToast.
  ///
  /// In en, this message translates to:
  /// **'Write a toast'**
  String get addToast;

  /// No description provided for @toastTypeSweet.
  ///
  /// In en, this message translates to:
  /// **'Sweet'**
  String get toastTypeSweet;

  /// No description provided for @toastTypeFunny.
  ///
  /// In en, this message translates to:
  /// **'Funny'**
  String get toastTypeFunny;

  /// No description provided for @toastTypePoem.
  ///
  /// In en, this message translates to:
  /// **'Poem'**
  String get toastTypePoem;

  /// No description provided for @toastTextHint.
  ///
  /// In en, this message translates to:
  /// **'Write your speech here...'**
  String get toastTextHint;

  /// No description provided for @exportToasts.
  ///
  /// In en, this message translates to:
  /// **'Export speeches'**
  String get exportToasts;

  /// No description provided for @wishesTab.
  ///
  /// In en, this message translates to:
  /// **'Wishes'**
  String get wishesTab;

  /// No description provided for @predictionsTab.
  ///
  /// In en, this message translates to:
  /// **'Predictions'**
  String get predictionsTab;

  /// No description provided for @wallTab.
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get wallTab;

  /// No description provided for @pleaseSelectEventType.
  ///
  /// In en, this message translates to:
  /// **'Please select an event type'**
  String get pleaseSelectEventType;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up!'**
  String get notificationsEmpty;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'ja',
    'ko',
    'pt',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
