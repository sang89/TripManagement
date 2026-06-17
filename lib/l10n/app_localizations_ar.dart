// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get close => 'إغلاق';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get save => 'حفظ';

  @override
  String get required => 'مطلوب';

  @override
  String get notes => 'ملاحظات';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get phone => 'الهاتف';

  @override
  String get remove => 'إزالة';

  @override
  String get notSet => 'غير محدد';

  @override
  String failed(String error) {
    return 'فشل: $error';
  }

  @override
  String comingSoon(String feature) {
    return '$feature — قريباً';
  }

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get languageSectionTitle => 'اللغة';

  @override
  String get selectLanguageTitle => 'اختر اللغة';

  @override
  String get systemDefault => 'الإعداد الافتراضي للنظام';

  @override
  String get themeSectionTitle => 'المظهر';

  @override
  String get themeSystem => 'الإعداد الافتراضي للنظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get accountSectionTitle => 'الحساب';

  @override
  String get changePasswordTitle => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get updatePassword => 'تحديث كلمة المرور';

  @override
  String get passwordUpdated => 'تم تحديث كلمة المرور';

  @override
  String get currentPasswordIncorrect => 'كلمة المرور الحالية غير صحيحة';

  @override
  String get passwordMinLength => '8 أحرف على الأقل';

  @override
  String get passwordsDoNotMatch => 'كلمات المرور غير متطابقة';

  @override
  String get deleteAccountTitle => 'حذف الحساب';

  @override
  String get deleteAccountWarning =>
      'سيؤدي هذا إلى حذف حسابك وجميع بياناتك بشكل دائم. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get deleteAccountInstructions =>
      'لحذف حسابك، يرجى التواصل مع الدعم. سنعالج طلبك خلال 48 ساعة.';

  @override
  String get supportEmail => 'support@tripplanner.app';

  @override
  String get emailCopied => 'تم نسخ البريد الإلكتروني إلى الحافظة';

  @override
  String get copyEmail => 'نسخ البريد الإلكتروني';

  @override
  String get aboutSectionTitle => 'حول';

  @override
  String get appVersion => 'إصدار التطبيق';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get myProfile => 'ملفي الشخصي';

  @override
  String get failedToLoadProfile => 'فشل تحميل الملف الشخصي';

  @override
  String get settingsTooltip => 'الإعدادات';

  @override
  String get editProfileTooltip => 'تعديل الملف الشخصي';

  @override
  String get personalInfoSection => 'المعلومات الشخصية';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get fullNameHint => 'اسمك الكامل';

  @override
  String get jobTitle => 'المسمى الوظيفي';

  @override
  String get jobTitleHint => 'مثال: مسافر متحمس';

  @override
  String get contactInfoSection => 'معلومات الاتصال';

  @override
  String get managedByAccount => 'مدار من خلال حسابك';

  @override
  String get memberSince => 'عضو منذ';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get chooseFromLibrary => 'اختيار من المكتبة';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get removePhoto => 'إزالة الصورة';

  @override
  String uploadFailed(String error) {
    return 'فشل الرفع: $error';
  }

  @override
  String get uploadRequiresConnection => 'الرفع يتطلب اتصالاً بالإنترنت';

  @override
  String get photoUpdated => 'تم تحديث الصورة';

  @override
  String get removeRequiresConnection => 'إزالة الصورة تتطلب اتصالاً بالإنترنت';

  @override
  String removeFailed(String error) {
    return 'فشل الإزالة: $error';
  }

  @override
  String get profileSaved => 'تم حفظ الملف الشخصي';

  @override
  String profileSaveFailed(String error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String get signOutConfirmTitle => 'تسجيل الخروج؟';

  @override
  String get signOutConfirmMessage => 'ستتم إعادتك إلى شاشة تسجيل الدخول.';

  @override
  String get nameTooLong => 'الاسم طويل جداً';

  @override
  String get appTitle => 'مخطط الرحلات';

  @override
  String get signInToAccount => 'تسجيل الدخول إلى حسابك';

  @override
  String get planNextAdventure => 'خطط لمغامرتك القادمة';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get password => 'كلمة المرور';

  @override
  String get enterValidEmail => 'أدخل بريداً إلكترونياً صحيحاً';

  @override
  String get passwordTooShort => 'كلمة المرور قصيرة جداً';

  @override
  String get enterYourName => 'أدخل اسمك';

  @override
  String get passwordMinimum6 => '6 أحرف على الأقل';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get rememberMe => 'تذكرني';

  @override
  String get continueWithGoogle => 'المتابعة مع Google';

  @override
  String get continueWithApple => 'المتابعة مع Apple';

  @override
  String get orSignInWith => 'أو';

  @override
  String get myTrips => 'رحلاتي';

  @override
  String get all => 'الكل';

  @override
  String get upcoming => 'القادمة';

  @override
  String get past => 'الماضية';

  @override
  String get deleteTripTitle => 'حذف الرحلة؟';

  @override
  String deleteTripMessage(String tripTitle) {
    return 'حذف $tripTitle؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get leave => 'مغادرة';

  @override
  String get leaveTripTooltip => 'مغادرة الرحلة';

  @override
  String get thisTripFallback => 'هذه الرحلة';

  @override
  String get leaveTripTitle => 'مغادرة الرحلة؟';

  @override
  String leaveTripMessage(String tripTitle) {
    return 'ستتم إزالتك من $tripTitle وستفقد الوصول.';
  }

  @override
  String get couldNotLoadTrips => 'تعذر تحميل الرحلات';

  @override
  String get noTripsYet => 'لا توجد رحلات بعد';

  @override
  String get noTripsHint => 'اضغط + للبدء.';

  @override
  String get noUpcomingTrips => 'لا توجد رحلات قادمة';

  @override
  String get noUpcomingTripsHint => 'اضغط + لتخطيط مغامرتك القادمة.';

  @override
  String get noPastTrips => 'لا توجد رحلات سابقة';

  @override
  String get noPastTripsHint => 'ستظهر الرحلات المكتملة هنا.';

  @override
  String get editTrip => 'تعديل الرحلة';

  @override
  String get newTrip => 'رحلة جديدة';

  @override
  String get tripTitle => 'عنوان الرحلة';

  @override
  String get startingFromLabel => 'المغادرة من (اختياري)';

  @override
  String get destinationLabel => 'الوجهة';

  @override
  String get notesOptional => 'ملاحظات (اختياري)';

  @override
  String get startLabel => 'البداية';

  @override
  String get endLabel => 'النهاية';

  @override
  String get setStartDateTime => 'تحديد تاريخ ووقت البداية';

  @override
  String get setEndDateTime => 'تحديد تاريخ ووقت النهاية';

  @override
  String get endDateAfterStart =>
      'يجب أن يكون تاريخ الانتهاء بعد تاريخ البداية.';

  @override
  String get stopsSection => 'المحطات';

  @override
  String get addStop => 'إضافة محطة';

  @override
  String get noStopsYet => 'لا توجد محطات بعد.';

  @override
  String get mapSection => 'الخريطة';

  @override
  String get membersSection => 'الأعضاء';

  @override
  String get addMember => 'إضافة عضو';

  @override
  String get fullNameLabel => 'الاسم';

  @override
  String get emailOptional => 'البريد الإلكتروني (اختياري)';

  @override
  String get phoneOptional => 'الهاتف (اختياري)';

  @override
  String get saveTrip => 'حفظ الرحلة';

  @override
  String get you => 'أنت';

  @override
  String get organizer => 'المنظم';

  @override
  String get member => 'عضو';

  @override
  String get tripNotFound => 'الرحلة غير موجودة';

  @override
  String get editTripTooltip => 'تعديل الرحلة';

  @override
  String get overview => 'نظرة عامة';

  @override
  String get itinerary => 'خط سير الرحلة';

  @override
  String get mapTab => 'الخريطة';

  @override
  String get startingFrom => 'المغادرة من';

  @override
  String get destination => 'الوجهة';

  @override
  String get noStopsInItinerary => 'لا توجد محطات بعد';

  @override
  String get addFirstStop => 'اضغط + لإضافة أول محطة.';

  @override
  String get removeStopTitle => 'إزالة المحطة؟';

  @override
  String removeStopMessage(String stopTitle) {
    return 'إزالة \"$stopTitle\" من خط السير؟';
  }

  @override
  String get arrive => 'وصول';

  @override
  String get depart => 'مغادرة';

  @override
  String get stopTitleLabel => 'العنوان';

  @override
  String get addressOptional => 'العنوان (اختياري)';

  @override
  String get arriveLabel => 'وصول';

  @override
  String get departLabel => 'مغادرة';

  @override
  String get addStopButton => 'إضافة محطة';

  @override
  String get editStop => 'تعديل المحطة';

  @override
  String get navTrips => 'الرحلات';

  @override
  String get navJournal => 'المذكرات';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get journalComingSoon => 'المذكرات قريباً';

  @override
  String get memberSearching => 'جارٍ البحث…';

  @override
  String get memberAccountFound => 'تم العثور على الحساب';

  @override
  String get memberNoAccountFound => 'لم يتم العثور على حساب';

  @override
  String get memberLinkedAccount => 'حساب مرتبط';

  @override
  String get selectFriendOptional => 'اختر صديقاً (اختياري)';

  @override
  String get searchFriends => 'البحث عن الأصدقاء…';

  @override
  String get invitePending => 'معلق';

  @override
  String get inviteAccepted => 'مقبول';

  @override
  String get inviteDeclined => 'مرفوض';

  @override
  String get memberLeft => 'غادر';

  @override
  String invitedBy(String name) {
    return 'تمت الدعوة بواسطة $name';
  }

  @override
  String tripInvitationsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دعوات رحلات',
      one: 'دعوة رحلة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get acceptInvite => 'قبول';

  @override
  String get declineInvite => 'رفض';

  @override
  String get inviteNotifTitle => 'دعوة رحلة';

  @override
  String inviteNotifBody(String tripTitle) {
    return 'لقد تمت دعوتك إلى $tripTitle';
  }

  @override
  String get blockReinviteLabel => 'عدم السماح بالدعوات المستقبلية لهذه الرحلة';

  @override
  String get reinviteBlockedError =>
      'اختار هذا المستخدم إلغاء الاشتراك في الدعوات المستقبلية لهذه الرحلة';

  @override
  String get resendInvite => 'إعادة إرسال الدعوة';

  @override
  String inviteResentTo(String name) {
    return 'تمت إعادة إرسال الدعوة إلى $name';
  }

  @override
  String get declineInviteConfirmTitle => 'رفض الدعوة؟';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return 'رفض الدعوة إلى \'$tripTitle\'؟ ستفقد الوصول.';
  }

  @override
  String get securitySectionTitle => 'الأمان';

  @override
  String get biometricToggleTitle => 'Face ID / Touch ID';

  @override
  String get biometricToggleSubtitle => 'استخدام المقاييس الحيوية لفتح التطبيق';

  @override
  String get biometricLockTitle => 'تحقق من هويتك';

  @override
  String get biometricLockSubtitle => 'المصادقة للوصول إلى حسابك';

  @override
  String get biometricSignInWithFace => 'تسجيل الدخول بـ Face ID';

  @override
  String get biometricSignInWithFingerprint => 'تسجيل الدخول ببصمة الإصبع';

  @override
  String get biometricSignInWithBiometrics => 'تسجيل الدخول بالمقاييس الحيوية';

  @override
  String get biometricReason => 'المصادقة للوصول إلى حسابك';

  @override
  String get biometricFailed => 'فشلت المصادقة. يرجى المحاولة مرة أخرى.';

  @override
  String get usePasswordInstead => 'استخدام كلمة المرور';

  @override
  String get navFriends => 'الأصدقاء';

  @override
  String get friendsTabFriends => 'الأصدقاء';

  @override
  String get friendsTabRequests => 'الطلبات';

  @override
  String get friendsAddFriend => 'إضافة صديق';

  @override
  String get friendsSearchHint => 'البحث بالاسم أو البريد أو الهاتف';

  @override
  String get friendsNoResults => 'لم يُعثر على مستخدمين';

  @override
  String get friendsRequestSent => 'تم إرسال طلب الصداقة';

  @override
  String get friendsAccept => 'قبول';

  @override
  String get friendsDecline => 'رفض';

  @override
  String get friendsRemove => 'إزالة صديق';

  @override
  String friendsRemoveConfirm(String name) {
    return 'إزالة $name من قائمة أصدقائك؟';
  }

  @override
  String get friendsNoFriends => 'لا أصدقاء بعد';

  @override
  String get friendsNoFriendsHint => 'ابحث عن شخص لإضافته كصديق.';

  @override
  String get friendsNoRequests => 'لا طلبات معلقة';

  @override
  String get friendsIncomingSection => 'واردة';

  @override
  String get friendsOutgoingSection => 'مرسلة';

  @override
  String get friendsCancelRequest => 'إلغاء الطلب';

  @override
  String get chatTabLabel => 'محادثة';

  @override
  String get chatSendHint => 'رسالة…';

  @override
  String get chatNoMessages => 'لا رسائل بعد. قل مرحباً!';

  @override
  String get chatSend => 'إرسال';

  @override
  String get notificationsSectionTitle => 'الإشعارات';

  @override
  String get mentionNotifToggleTitle => 'تنبيهات الإشارة';

  @override
  String get mentionNotifToggleSubtitle =>
      'احصل على إشعار عند الإشارة إليك بـ @ في دردشة الرحلة';

  @override
  String get privacySectionTitle => 'الخصوصية';

  @override
  String get blockedUsersTitle => 'المستخدمون المحظورون';

  @override
  String get blockedUsersEmpty => 'لم تحظر أي شخص';

  @override
  String get blockUser => 'حظر';

  @override
  String get unblockUser => 'إلغاء الحظر';

  @override
  String blockConfirmTitle(String name) {
    return 'حظر $name؟';
  }

  @override
  String get blockConfirmBody =>
      'لن يتمكنوا من إضافتك إلى الرحلات أو إرسال طلبات الصداقة إليك.';

  @override
  String blockSuccess(String name) {
    return 'تم حظر $name';
  }

  @override
  String unblockSuccess(String name) {
    return 'تم إلغاء حظر $name';
  }

  @override
  String get contactsButton => 'من جهات الاتصال';

  @override
  String get contactsScreenTitle => 'البحث من جهات الاتصال';

  @override
  String get contactsPermissionDenied =>
      'يلزم الوصول إلى جهات الاتصال للعثور على أصدقائك في TripManagement.';

  @override
  String get contactsOpenSettings => 'فتح الإعدادات';

  @override
  String get contactsOnApp => 'على TripManagement';

  @override
  String get contactsInviteSection => 'دعوة إلى TripManagement';

  @override
  String get contactsEmpty =>
      'لم يتم العثور على جهات اتصال برقم هاتف أو بريد إلكتروني.';

  @override
  String get contactsAddFriend => 'إضافة';

  @override
  String get contactsPending => 'قيد الانتظار';

  @override
  String get contactsInvite => 'دعوة';

  @override
  String contactsInviteMessage(String name) {
    return 'مرحباً $name! أستخدم TripManagement لتخطيط الرحلات معًا. انضم إليّ هنا: [APP_STORE_LINK]';
  }

  @override
  String get navEvents => 'Events';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get editEventSubtitle => 'تحديث التفاصيل أو التاريخ أو الموقع';

  @override
  String get saveEvent => 'Save event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventDescription => 'Description (optional)';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventCapacity => 'الحد الأقصى للأعضاء (اختياري)';

  @override
  String get eventStartDateTime => 'Start date & time';

  @override
  String get eventEndDateTime => 'End date & time (optional)';

  @override
  String get noEventsYet => 'No events yet. Tap + to create one.';

  @override
  String get noUpcomingEvents => 'لا توجد أحداث قادمة';

  @override
  String get noUpcomingEventsHint => 'اضغط + لتخطيط حدثك القادم.';

  @override
  String get noPastEvents => 'لا توجد أحداث سابقة بعد';

  @override
  String get noPastEventsHint => 'ستظهر الأحداث التي حضرتها هنا.';

  @override
  String get filterAll => 'الكل';

  @override
  String get calendarViewToggle => 'تقويم';

  @override
  String get listViewToggle => 'قائمة';

  @override
  String get noEventsOnDay => 'لا توجد أحداث في هذا اليوم';

  @override
  String get myEvents => 'My events';

  @override
  String get invitedEvents => 'Invited';

  @override
  String get infoTab => 'معلومات';

  @override
  String get guestsTab => 'الأعضاء';

  @override
  String get noGuestsYet => 'لا أعضاء حتى الآن. انقر + لإضافة أحد.';

  @override
  String get addGuest => 'إضافة عضو';

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
  String get noExpensesYet => 'لا توجد نفقات حتى الآن';

  @override
  String get expenseDescription => 'What was paid for?';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get splitAmong => 'توزيع بين الأعضاء';

  @override
  String get paidBy => 'مدفوع من قبل';

  @override
  String get selectAll => 'تحديد الكل';

  @override
  String get deselectAll => 'إلغاء تحديد الكل';

  @override
  String totalOwed(String amount) {
    return 'You owe: $amount';
  }

  @override
  String youAreOwed(String amount) {
    return 'أنت مدين لك: $amount';
  }

  @override
  String get settleUp => 'تسوية الحسابات';

  @override
  String get totalSpent => 'المجموع المنفق';

  @override
  String get theScore => 'النتيجة';

  @override
  String get settlementPlan => 'خطة التسوية';

  @override
  String get allSquare => 'الجميع متساوٍ! لا ديون 🎉';

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
  String get rsvpNoteHint => 'أضف ملاحظة (اختياري)';

  @override
  String get organizeTab => 'تنظيم';

  @override
  String get detailsTab => 'التفاصيل';

  @override
  String get todoTab => 'المهام';

  @override
  String get cravingsTab => 'شهيات';

  @override
  String get pollsTab => 'الاستطلاعات';

  @override
  String get pollsEmpty => 'لا توجد استطلاعات بعد.';

  @override
  String get pollsAddPoll => 'إضافة استطلاع';

  @override
  String get pollsQuestion => 'السؤال';

  @override
  String pollsOptionHint(int n) {
    return 'الخيار $n';
  }

  @override
  String get pollsAddOption => '+ إضافة خيار';

  @override
  String pollsVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أصوات',
      one: 'صوت واحد',
    );
    return '$_temp0';
  }

  @override
  String get pollsDeletePoll => 'حذف الاستطلاع';

  @override
  String get bringListTitle => 'المهام';

  @override
  String get bringListEmpty => 'لا توجد مهام بعد. اضغط + لإضافة واحدة.';

  @override
  String get bringListAddItem => 'إضافة مهمة';

  @override
  String get bringListEditItem => 'تعديل المهمة';

  @override
  String get bringListItemLabel => 'ماذا تفعل';

  @override
  String get bringListNote => 'ملاحظة (اختياري)';

  @override
  String get bringListAssignTo => 'تعيين لعضو';

  @override
  String get bringListNoAssignment => 'غير مخصص';

  @override
  String get bringListTake => 'خذ';

  @override
  String get bringListUnassign => 'إلغاء التعيين';

  @override
  String get rsvpNoteLabel => 'ملاحظتك';

  @override
  String get confirmRsvp => 'تأكيد';

  @override
  String get foodMoodTitle => 'كم أنت جائع؟';

  @override
  String get foodMoodStarving => 'جائع جداً';

  @override
  String get foodMoodCouldEat => 'يمكنني الأكل';

  @override
  String get foodMoodDrinksOnly => 'للمشروبات فقط';

  @override
  String get foodMoodNibble => 'سأتناول شيئاً خفيفاً';

  @override
  String get foodMoodDDMode => 'سائق مخصص';

  @override
  String get cravingsPrompt => 'ماذا تشتهي؟';

  @override
  String get cravingsHint => 'رامن حار، أجواء مريحة، أقل من 20\$...';

  @override
  String get cravingsPrivacyNote => 'فقط أنت يمكنك رؤية هذا';

  @override
  String get cravingsFindButton => 'ابحث لي عن مكان';

  @override
  String get cravingsEmpty => 'لا توجد نتائج. جرب كلمات مختلفة.';

  @override
  String get cravingsPitchButton => 'اقتراح للمجموعة';

  @override
  String get cravingsPitched => 'تمت الإضافة إلى تصويت المجموعة!';

  @override
  String get exploreTab => 'استكشف';

  @override
  String exploreTitle(String destination) {
    return 'أنشطة في $destination';
  }

  @override
  String get exploreSubtitle => 'Powered by Viator • GetYourGuide • Klook';

  @override
  String get exploreSortCheapest => 'الأرخص أولاً';

  @override
  String get exploreSortTopRated => 'الأعلى تقييماً';

  @override
  String get exploreMorePlatforms => 'منصات أخرى';

  @override
  String get bookOnViator => 'احجز على Viator';

  @override
  String get bookNow => 'احجز الآن';

  @override
  String get browseGetYourGuide => 'تصفح GetYourGuide';

  @override
  String get browseKlook => 'تصفح Klook';

  @override
  String exploreFromPrice(String price) {
    return 'من $price';
  }

  @override
  String get exploreNoResults => 'لم يتم العثور على أنشطة لهذه الوجهة.';

  @override
  String get exploreLoadError =>
      'تعذّر تحميل الاقتراحات. انقر للمحاولة مرة أخرى.';

  @override
  String get restaurantPollTitle => 'اختيار مكان';

  @override
  String get addRestaurantOption => 'إضافة مطعم';

  @override
  String get restaurantSearchHint => 'ابحث عن المطاعم...';

  @override
  String get setAsVenueButton => 'تعيين كموقع';

  @override
  String organizedBy(String name) {
    return 'Organised by $name';
  }

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String get deleteEventSubtitle => 'إزالة هذا الحدث نهائياً';

  @override
  String deleteEventMessage(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get eventTypeTrip => 'رحلة';

  @override
  String get eventTypeBirthday => 'عيد ميلاد';

  @override
  String get eventTypeWedding => 'زفاف';

  @override
  String get eventTypeSocial => 'اجتماعي';

  @override
  String get eventTypeQuickBites => 'لقمات سريعة';

  @override
  String get eventTypeSignup => 'تسجيل';

  @override
  String signupSpotsFilled(int filled, int total) {
    return '$filled / $total أماكن مشغولة';
  }

  @override
  String signupWaitlistCount(int count) {
    return '$count في قائمة الانتظار';
  }

  @override
  String get signupEventFull => 'الفعالية ممتلئة';

  @override
  String get signupJoinWaitlist => 'انضم لقائمة الانتظار';

  @override
  String get signupClaimSpot => 'احجز مكانًا';

  @override
  String signupConfirmedPosition(int pos) {
    return 'أنت رقم #$pos في القائمة!';
  }

  @override
  String signupWaitlistPosition(int pos) {
    return 'أنت رقم #$pos في قائمة الانتظار';
  }

  @override
  String get signupWaitlistEnabled => 'تفعيل قائمة الانتظار';

  @override
  String get signupWaitlistDescription =>
      'الضيوف الزائدون عن الطاقة يدخلون قائمة انتظار مرتبة';

  @override
  String get signupRosterTab => 'القائمة';

  @override
  String get signupInviteTab => 'دعوة';

  @override
  String get signupPromoteGuest => 'ترقية للمؤكدين';

  @override
  String get signupRemoveGuest => 'إزالة من الفعالية';

  @override
  String get signupCopyLink => 'نسخ رابط الدعوة';

  @override
  String get signupShowQr => 'عرض رمز QR';

  @override
  String get signupLocked => 'التسجيل مغلق';

  @override
  String get signupLockedMessage => 'التسجيل مغلق. تواصل مع المنظم.';

  @override
  String get signupPendingReview => 'طلبك قيد المراجعة';

  @override
  String get signupCancelSpot => 'إلغاء مكاني';

  @override
  String get signupMarkAttended => 'حضر';

  @override
  String get signupMarkNoShow => 'لم يحضر';

  @override
  String get signupAttendanceHeader => 'الحضور';

  @override
  String get signupRepeat => 'تكرار';

  @override
  String get signupRepeatNone => 'لا يوجد';

  @override
  String get signupRepeatWeekly => 'أسبوعي';

  @override
  String get signupRepeatBiweekly => 'كل أسبوعين';

  @override
  String get signupRepeatMonthly => 'شهري';

  @override
  String get signupNextSession => 'إنشاء الجلسة التالية';

  @override
  String get signupCarryOverGuests => 'تسجيل الضيوف المؤكدين تلقائيًا';

  @override
  String get signupCarryOverGuestsHint =>
      'سيتلقى الضيوف إشعارًا ويمكنهم إلغاء التسجيل';

  @override
  String signupPartOfSeries(String interval) {
    return 'جزء من سلسلة $interval';
  }

  @override
  String get chooseEventType => 'ماذا تخطط؟';

  @override
  String get eventTypePicker => 'نوع الحدث';

  @override
  String get routeTab => 'المسار';

  @override
  String get leaveEventTitle => 'مغادرة الحدث؟';

  @override
  String leaveEventMessage(String eventTitle) {
    return 'ستتم إزالتك من $eventTitle وستفقد الوصول.';
  }

  @override
  String get generateWithAi => 'AI Assistant';

  @override
  String get aiTripPlannerSubtitle =>
      'اطرح أسئلة حول وجهتك، أو صف أسلوبك لإضافة محطات إلى خط سيرك.';

  @override
  String get aiChatHint => 'اسأل أي شيء عن رحلتك...';

  @override
  String get tierFree => 'Basic';

  @override
  String get tierPro => 'برو';

  @override
  String tierProTrial(String date) {
    return 'تجربة برو · تنتهي $date';
  }

  @override
  String get cancelTrial => 'إلغاء التجربة';

  @override
  String get cancelTrialConfirmTitle => 'إلغاء تجربتك المجانية؟';

  @override
  String get cancelTrialConfirmMessage =>
      'ستفقد الوصول إلى ميزات Pro فوراً. يمكنك الترقية لاحقاً.';

  @override
  String get cancelTrialSuccess => 'تم إلغاء تجربتك. أنت الآن على خطة Basic.';

  @override
  String get cancelTrialError => 'فشل إلغاء التجربة. حاول مرة أخرى.';

  @override
  String get upgradeToPro => 'ترقية إلى برو';

  @override
  String get upgradeNow => 'الترقية الآن';

  @override
  String get proAnnualPrice => '39.99 دولار / سنة';

  @override
  String get proMonthlyPrice => '4.99 دولار / شهر';

  @override
  String get proAnnualSavings => 'وفر 33%';

  @override
  String get comparePlans => 'قارن الخطط';

  @override
  String get restorePurchases => 'استعادة المشتريات';

  @override
  String get proFeatureAIPlanner => 'AI Event Assistant';

  @override
  String get proFeatureUnlimitedEvents => 'فعاليات وضيوف غير محدودين';

  @override
  String get proFeatureExpenseExport => 'Expense export';

  @override
  String get proFeatureOfflineAccess => 'الوصول دون اتصال';

  @override
  String get proFeatureTemplates => 'قوالب الفعاليات';

  @override
  String get freeEventsLimit => 'الفعاليات (3 كحد أقصى)';

  @override
  String get freeGuestsLimit => 'الضيوف (10 كحد أقصى)';

  @override
  String get freeBasicPlanning => 'التسجيل والتخطيط الأساسي';

  @override
  String get budgetPerHeadLabel => 'الميزانية لكل شخص (اختياري)';

  @override
  String get cuisineTagsLabel => 'المطبخ';

  @override
  String get rsvpDeadlineLabel => 'الموعد النهائي للتأكيد';

  @override
  String get rsvpDeadlineClosed => 'التأكيد مغلق';

  @override
  String get vibePickerLabel => 'الأجواء (اختياري)';

  @override
  String get honoreeNameLabel => 'لمن هذا عيد الميلاد؟';

  @override
  String get honoreeNameHint => 'أدخل اسمه/اسمها';

  @override
  String get birthYearLabel => 'سنة الميلاد (اختياري)';

  @override
  String get birthYearHint => 'مثال: 1996';

  @override
  String get celebrateTab => 'حفلة';

  @override
  String get giftsTab => 'هدايا';

  @override
  String get memoriesTab => 'ذكريات';

  @override
  String birthdayHeroTitle(String name) {
    return 'عيد ميلاد $name';
  }

  @override
  String turningAge(int age) {
    return 'يبلغ $age';
  }

  @override
  String birthdayCountdownDays(int count) {
    return 'بعد $count أيام';
  }

  @override
  String birthdayCountdownHours(int count) {
    return 'بعد $count ساعات';
  }

  @override
  String get birthdayToday => 'اليوم هو اليوم!';

  @override
  String activityVoteTitle(String name) {
    return 'ماذا نفعل في حفلة $name؟';
  }

  @override
  String get activityVoteEmpty => 'لا أنشطة بعد.';

  @override
  String get addActivityOption => 'إضافة نشاط';

  @override
  String cakeVoteTitle(String name) {
    return 'ما الكعكة التي يريدها $name؟';
  }

  @override
  String get cakeVoteEmpty => 'لا خيارات للكعكة بعد.';

  @override
  String get addCakeOption => 'إضافة نكهة';

  @override
  String wishlistTitle(String name) {
    return 'قائمة أمنيات $name';
  }

  @override
  String wishlistEmpty(String name) {
    return 'لا عناصر بعد. أضف شيئاً يحبه $name!';
  }

  @override
  String get addWishlistItem => 'إضافة فكرة هدية';

  @override
  String get wishlistItemLabel => 'فكرة هدية';

  @override
  String get wishlistPriceRange => 'نطاق السعر (اختياري)';

  @override
  String get wishlistLink => 'رابط (اختياري)';

  @override
  String get claimItem => 'سأتكفل بهذا!';

  @override
  String get unclaimItem => 'إلغاء';

  @override
  String get itemClaimed => 'شخص ما يتكفل بذلك';

  @override
  String itemClaimedBy(String name) {
    return 'محجوز بواسطة $name';
  }

  @override
  String get markReceived => 'تحديد كمستلم';

  @override
  String get giftPoolTitle => 'هدية جماعية';

  @override
  String get giftPoolEmpty => 'لا هدية جماعية بعد.';

  @override
  String get createGiftPool => 'بدء هدية جماعية';

  @override
  String get giftPoolName => 'اسم الهدية';

  @override
  String get giftPoolTarget => 'المبلغ المستهدف';

  @override
  String giftPoolProgress(String pledged, String target) {
    return '$pledged من $target متعهد';
  }

  @override
  String giftPoolContributors(int count) {
    return '$count مساهمين';
  }

  @override
  String get pledgeAmount => 'مبلغ التعهد';

  @override
  String get addPledge => 'تعهد';

  @override
  String get myPledge => 'تعهدي';

  @override
  String get removePledge => 'إزالة التعهد';

  @override
  String predictionsTitle(String name) {
    return 'تنبؤات لـ $name';
  }

  @override
  String predictionsSealed(int count) {
    return '$count تنبؤات مختومة';
  }

  @override
  String get revealPredictions => 'الكشف عن التنبؤات';

  @override
  String get predictionsHowItWorks =>
      'التنبؤات مقفلة حتى تاريخ الحدث — ثم يكتشف الجميع من كان محقاً!';

  @override
  String predictionsEmpty(String name) {
    return 'لا تنبؤات بعد لـ $name.';
  }

  @override
  String get addPrediction => 'إضافة تنبؤ';

  @override
  String predictionHint(String name) {
    return 'توقع شيئاً للسنة القادمة لـ $name...';
  }

  @override
  String wishesTitle(String name) {
    return 'أمنيات لـ $name';
  }

  @override
  String wishesSealed(String name) {
    return '$name لا يمكنه رؤية هذه بعد';
  }

  @override
  String get wishesHowItWorks =>
      'تبقى الأمنيات سرية حتى يكشف المنظم عنها في اليوم الكبير!';

  @override
  String get wishesEmpty => 'لا أمنيات بعد. كن الأول!';

  @override
  String get addWish => 'تمنَّ أمنية';

  @override
  String wishHint(String name) {
    return 'اكتب أمنيتك لـ $name...';
  }

  @override
  String get blowOutCandles => 'أطفئ الشمعات!';

  @override
  String get wishesRevealed => 'تم الكشف عن الأمنيات!';

  @override
  String memoryWallTitle(String name) {
    return 'جدار ذكريات $name';
  }

  @override
  String memoryWallEmpty(String name) {
    return 'شارك ذكرياتك مع $name!';
  }

  @override
  String get addMemory => 'إضافة ذكرى';

  @override
  String memoryCaptionHint(String name) {
    return 'شارك ذكرتك المفضلة مع $name...';
  }

  @override
  String get toastsTitle => 'الكلمات والخطابات';

  @override
  String toastsEmpty(String name) {
    return 'لا كلمات بعد لـ $name.';
  }

  @override
  String get addToast => 'كتابة كلمة';

  @override
  String get toastTypeSweet => 'عاطفي';

  @override
  String get toastTypeFunny => 'مضحك';

  @override
  String get toastTypePoem => 'قصيدة';

  @override
  String get toastTextHint => 'اكتب خطابك هنا...';

  @override
  String get exportToasts => 'تصدير الخطابات';

  @override
  String get wishesTab => 'أمنيات';

  @override
  String get predictionsTab => 'تنبؤات';

  @override
  String get wallTab => 'الجدار';

  @override
  String get pleaseSelectEventType => 'الرجاء اختيار نوع الحدث';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get notificationsEmpty => 'لقد اطلعت على كل شيء!';

  @override
  String get notificationsMarkAllRead => 'تحديد الكل كمقروء';

  @override
  String get sessionActivityTab => 'النشاط';

  @override
  String get queueUp => 'طابور';

  @override
  String get createQueue => 'إنشاء طابور';

  @override
  String get playersPerRound => 'لاعبون لكل جولة';

  @override
  String get maxRounds => 'الحد الأقصى للجولات';

  @override
  String get noLimit => 'بلا حد';

  @override
  String get checkIn => 'تسجيل الحضور';

  @override
  String get checkOut => 'المغادرة';

  @override
  String get joinQueue => 'الانضمام للطابور';

  @override
  String get leaveQueue => 'مغادرة الطابور';

  @override
  String get startQueue => 'بدء';

  @override
  String get nextRound => 'الجولة التالية';

  @override
  String roundN(int n) {
    return 'الجولة $n';
  }

  @override
  String get allRejoinQueue => 'الجميع يعود للطابور';

  @override
  String get releaseToFreePool => 'الإفراج إلى المجموعة';

  @override
  String get freePool => 'المجموعة الحرة';

  @override
  String get nowPlaying => 'يلعب الآن';

  @override
  String get waitingQueue => 'في الانتظار';

  @override
  String get queueEnded => 'انتهى الطابور';

  @override
  String get noQueuesYet => 'لا أنشطة بعد';

  @override
  String get createFirstQueue => 'أنشئ الطابور الأول للبدء';

  @override
  String queueRoundComplete(int n) {
    return 'اكتملت الجولة $n!';
  }

  @override
  String get setupQueues => 'إعداد الطوابير';

  @override
  String get numberOfQueues => 'عدد الطوابير';

  @override
  String get spotsPerQueue => 'أماكن لكل طابور';

  @override
  String get clearQueue => 'مسح';

  @override
  String get queueFull => 'الطابور ممتلئ';

  @override
  String get alreadyInQueue => 'أنت بالفعل في طابور';

  @override
  String get addToSlot => 'احجز مكانك!';

  @override
  String get addMyselfToQueue => 'أنا مشارك!';

  @override
  String get addSomeoneElse => 'أضف زميلاً';

  @override
  String get selectAMember => 'اختر عضوًا';

  @override
  String get searchMembersHint => 'ابحث عن أعضاء…';

  @override
  String get leaveSlotTitle => 'مغادرة المكان؟';

  @override
  String leaveSlotMessage(int number) {
    return 'الانسحاب من مكانك في الطابور #$number؟';
  }

  @override
  String get leaveSlotConfirm => 'انسحاب';

  @override
  String get kickFromSlotTitle => 'طرده؟';

  @override
  String kickFromSlotMessage(String name, int number) {
    return 'إزالة $name من الطابور #$number؟';
  }

  @override
  String get kickFromSlotConfirm => 'طرد!';

  @override
  String get allowDuplicates => 'السماح بالانضمام لعدة طوابير';

  @override
  String get allowDuplicatesSubtitle =>
      'يمكن للأعضاء التواجد في أكثر من طابور في نفس الوقت';

  @override
  String get customizeQueues => 'تخصيص الطوابير';
}
