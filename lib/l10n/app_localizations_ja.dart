// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get close => '閉じる';

  @override
  String get retry => '再試行';

  @override
  String get save => '保存';

  @override
  String get required => '必須';

  @override
  String get notes => 'メモ';

  @override
  String get email => 'メール';

  @override
  String get phone => '電話';

  @override
  String get remove => '削除';

  @override
  String get notSet => '未設定';

  @override
  String failed(String error) {
    return '失敗：$error';
  }

  @override
  String comingSoon(String feature) {
    return '$feature — 近日公開';
  }

  @override
  String get settingsTitle => '設定';

  @override
  String get languageSectionTitle => '言語';

  @override
  String get selectLanguageTitle => '言語を選択';

  @override
  String get systemDefault => 'システムデフォルト';

  @override
  String get themeSectionTitle => '外観';

  @override
  String get themeSystem => 'システムデフォルト';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get accountSectionTitle => 'アカウント';

  @override
  String get changePasswordTitle => 'パスワードを変更';

  @override
  String get currentPassword => '現在のパスワード';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get confirmNewPassword => '新しいパスワードを確認';

  @override
  String get updatePassword => 'パスワードを更新';

  @override
  String get passwordUpdated => 'パスワードを更新しました';

  @override
  String get currentPasswordIncorrect => '現在のパスワードが正しくありません';

  @override
  String get passwordMinLength => '8文字以上';

  @override
  String get passwordsDoNotMatch => 'パスワードが一致しません';

  @override
  String get deleteAccountTitle => 'アカウントを削除';

  @override
  String get deleteAccountWarning => 'アカウントとすべてのデータが完全に削除されます。この操作は元に戻せません。';

  @override
  String get deleteAccountInstructions =>
      'アカウントを削除するには、サポートにご連絡ください。48時間以内に対応いたします。';

  @override
  String get supportEmail => 'support@tripplanner.app';

  @override
  String get emailCopied => 'メールをクリップボードにコピーしました';

  @override
  String get copyEmail => 'メールをコピー';

  @override
  String get aboutSectionTitle => 'このアプリについて';

  @override
  String get appVersion => 'アプリバージョン';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get termsOfService => '利用規約';

  @override
  String get myProfile => 'マイプロフィール';

  @override
  String get failedToLoadProfile => 'プロフィールの読み込みに失敗しました';

  @override
  String get settingsTooltip => '設定';

  @override
  String get editProfileTooltip => 'プロフィールを編集';

  @override
  String get personalInfoSection => '個人情報';

  @override
  String get fullName => '氏名';

  @override
  String get fullNameHint => '氏名を入力してください';

  @override
  String get jobTitle => '役職';

  @override
  String get jobTitleHint => '例：旅行好き';

  @override
  String get contactInfoSection => '連絡先情報';

  @override
  String get managedByAccount => 'アカウントで管理';

  @override
  String get memberSince => '登録日';

  @override
  String get saveChanges => '変更を保存';

  @override
  String get signOut => 'サインアウト';

  @override
  String get chooseFromLibrary => 'ライブラリから選択';

  @override
  String get takePhoto => '写真を撮る';

  @override
  String get removePhoto => '写真を削除';

  @override
  String uploadFailed(String error) {
    return 'アップロード失敗：$error';
  }

  @override
  String get uploadRequiresConnection => 'アップロードには接続が必要です';

  @override
  String get photoUpdated => '写真を更新しました';

  @override
  String get removeRequiresConnection => '写真の削除には接続が必要です';

  @override
  String removeFailed(String error) {
    return '削除失敗：$error';
  }

  @override
  String get profileSaved => 'プロフィールを保存しました';

  @override
  String profileSaveFailed(String error) {
    return '保存失敗：$error';
  }

  @override
  String get signOutConfirmTitle => 'サインアウトしますか？';

  @override
  String get signOutConfirmMessage => 'ログイン画面に戻ります。';

  @override
  String get nameTooLong => '名前が長すぎます';

  @override
  String get appTitle => '旅行プランナー';

  @override
  String get signInToAccount => 'アカウントにサインイン';

  @override
  String get planNextAdventure => '次の冒険を計画しよう';

  @override
  String get signIn => 'サインイン';

  @override
  String get signUp => '登録';

  @override
  String get createAccount => 'アカウントを作成';

  @override
  String get dontHaveAccount => 'アカウントをお持ちでないですか？';

  @override
  String get alreadyHaveAccount => 'すでにアカウントをお持ちですか？';

  @override
  String get password => 'パスワード';

  @override
  String get enterValidEmail => '有効なメールを入力してください';

  @override
  String get passwordTooShort => 'パスワードが短すぎます';

  @override
  String get enterYourName => '名前を入力してください';

  @override
  String get passwordMinimum6 => '最低6文字';

  @override
  String get confirmPassword => 'パスワードを確認';

  @override
  String get rememberMe => 'ログイン状態を保持';

  @override
  String get myTrips => 'マイトリップ';

  @override
  String get all => 'すべて';

  @override
  String get upcoming => '予定';

  @override
  String get past => '過去';

  @override
  String get deleteTripTitle => '旅行を削除しますか？';

  @override
  String deleteTripMessage(String tripTitle) {
    return '\"$tripTitle\"を削除しますか？この操作は元に戻せません。';
  }

  @override
  String get couldNotLoadTrips => '旅行を読み込めませんでした';

  @override
  String get noTripsYet => 'まだ旅行はありません';

  @override
  String get noTripsHint => '+ をタップして始めましょう。';

  @override
  String get noUpcomingTrips => '予定の旅行はありません';

  @override
  String get noUpcomingTripsHint => '+ をタップして次の冒険を計画しましょう。';

  @override
  String get noPastTrips => '過去の旅行はありません';

  @override
  String get noPastTripsHint => '完了した旅行がここに表示されます。';

  @override
  String get editTrip => '旅行を編集';

  @override
  String get newTrip => '新しい旅行';

  @override
  String get tripTitle => '旅行タイトル';

  @override
  String get startingFromLabel => '出発地（任意）';

  @override
  String get destinationLabel => '目的地';

  @override
  String get notesOptional => 'メモ（任意）';

  @override
  String get startLabel => '開始';

  @override
  String get endLabel => '終了';

  @override
  String get setStartDateTime => '開始日時を設定';

  @override
  String get setEndDateTime => '終了日時を設定';

  @override
  String get endDateAfterStart => '終了日は開始日より後にしてください。';

  @override
  String get stopsSection => '途中停車地';

  @override
  String get addStop => '停車地を追加';

  @override
  String get noStopsYet => '停車地はまだありません。';

  @override
  String get mapSection => '地図';

  @override
  String get membersSection => 'メンバー';

  @override
  String get addMember => 'メンバーを追加';

  @override
  String get fullNameLabel => '名前';

  @override
  String get emailOptional => 'メール（任意）';

  @override
  String get phoneOptional => '電話（任意）';

  @override
  String get saveTrip => '旅行を保存';

  @override
  String get you => 'あなた';

  @override
  String get organizer => '主催者';

  @override
  String get member => 'メンバー';

  @override
  String get tripNotFound => '旅行が見つかりません';

  @override
  String get editTripTooltip => '旅行を編集';

  @override
  String get overview => '概要';

  @override
  String get itinerary => '旅程';

  @override
  String get mapTab => '地図';

  @override
  String get startingFrom => '出発地';

  @override
  String get destination => '目的地';

  @override
  String get noStopsInItinerary => '停車地はまだありません';

  @override
  String get addFirstStop => '+ をタップして最初の停車地を追加しましょう。';

  @override
  String get removeStopTitle => '停車地を削除しますか？';

  @override
  String removeStopMessage(String stopTitle) {
    return '旅程から\"$stopTitle\"を削除しますか？';
  }

  @override
  String get arrive => '到着';

  @override
  String get depart => '出発';

  @override
  String get stopTitleLabel => 'タイトル';

  @override
  String get addressOptional => '住所（任意）';

  @override
  String get arriveLabel => '到着';

  @override
  String get departLabel => '出発';

  @override
  String get addStopButton => '停車地を追加';

  @override
  String get editStop => '停車地を編集';

  @override
  String get navTrips => '旅行';

  @override
  String get navJournal => '日記';

  @override
  String get navProfile => 'プロフィール';

  @override
  String get journalComingSoon => '日記機能は近日公開';

  @override
  String get memberSearching => '検索中…';

  @override
  String get memberAccountFound => 'アカウントが見つかりました';

  @override
  String get memberNoAccountFound => 'アカウントが見つかりません';

  @override
  String get memberLinkedAccount => 'リンク済みアカウント';
}
