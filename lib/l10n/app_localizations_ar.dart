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
    return 'حذف \"$tripTitle\"؟ لا يمكن التراجع عن هذا الإجراء.';
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
  String get invitePending => 'معلق';

  @override
  String get inviteAccepted => 'مقبول';

  @override
  String get inviteDeclined => 'مرفوض';

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
}
