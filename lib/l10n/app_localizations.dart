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
