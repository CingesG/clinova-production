// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Mongolian (`mn`).
class AppLocalizationsMn extends AppLocalizations {
  AppLocalizationsMn([String locale = 'mn']) : super(locale);

  @override
  String get appTitle => 'Clinova';

  @override
  String get dashboard => 'Хяналтын самбар';

  @override
  String get emergency => 'Яаралтай';

  @override
  String get appointments => 'Цаг захиалга';

  @override
  String get patients => 'Өвчтөнүүд';

  @override
  String get reminders => 'Сануулга';

  @override
  String get follow_up => 'Давтан үзлэг';

  @override
  String get total_today => 'Өнөөдрийн нийт';

  @override
  String get completed => 'Дууссан';

  @override
  String get pending => 'Хүлээгдэж буй';

  @override
  String get accept => 'Зөвшөөрөх';

  @override
  String get call => 'Залгах';

  @override
  String get no_data => 'Мэдээлэл байхгүй';

  @override
  String get loading => 'Уншиж байна…';

  @override
  String get settings => 'Тохиргоо';

  @override
  String get language => 'Хэл';

  @override
  String get alerts => 'Мэдэгдэл';

  @override
  String get retry => 'Дахин оролдох';

  @override
  String get messages => 'Мессеж';

  @override
  String get logOut => 'Гарах';

  @override
  String get languageEnglish => 'Англи';

  @override
  String get languageMongolian => 'Монгол';

  @override
  String get doctorBranchFallback => 'Таны салбар';

  @override
  String get doctorRoleFallback => 'Эмч';

  @override
  String get patientFallback => 'Өвчтөн';

  @override
  String get consultationFallback => 'Зөвлөгөө';

  @override
  String get dashUnknown => '—';

  @override
  String get timeTbd => 'Цаг тодорхойгүй';

  @override
  String get emergencyIntakeTitle => 'Яаралтай хүлээн авах';

  @override
  String get emergencyIntakeSubtitle =>
      'Захиалгын шалтгаанд [EMERGENCY] гэж тэмдэглэгдсэн тохиолдол.';

  @override
  String get emergencyBadge => 'ЯАРАЛТАЙ';

  @override
  String get remindersSectionSubtitle => 'Дараагийн анхаарах зүйлс.';

  @override
  String get remindersEmpty => 'Одоогоор сануулга алга.';

  @override
  String get quickStatsTitle => 'Товч статистик';

  @override
  String get quickStatsSubtitle => 'Өдрийн тойм.';

  @override
  String get todayScheduleTitle => 'Өнөөдрийн хуваарь';

  @override
  String get todayScheduleSubtitle =>
      'Картыг шудрахаар үзлэг дууссан гэж тэмдэглэнэ.';

  @override
  String get noVisitsTodayTitle => 'Өнөөдөр цаг алга';

  @override
  String get noVisitsTodayBody => 'Шинэ захиалгууд энд автоматаар харагдана.';

  @override
  String get routineClearTitle => 'Энгийн хуваарь цэвэр';

  @override
  String get routineClearBody =>
      'Өнөөдрийн үлдсэн үзлэгүүд дээрх Яаралтай хэсэгт байна.';

  @override
  String get followUpPatientsTitle => 'Давтан үзлэгтэй өвчтөн';

  @override
  String get followUpPatientsSubtitle => 'Сүүлийн бичлэг, тэмдэглэл.';

  @override
  String get followUpEmptyTitle => 'Давтан даалгавар алга';

  @override
  String get followUpEmptyBody => 'Тэмдэглэлтэй дууссан үзлэгүүд энд гарна.';

  @override
  String get followUpNotePreview => 'Сүүлийн үзлэгийн бичлэгийг шалгана уу';

  @override
  String get openRecord => 'Бичлэг нээх';

  @override
  String followUpUpdated(String date) {
    return 'Шинэчилсэн $date';
  }

  @override
  String get noNoteRecorded => 'Тэмдэглэл байхгүй.';

  @override
  String get loadErrorTitle => 'Алдаа гарлаа';

  @override
  String get emergencyAccepted => 'Яаралтай хүлээн авлаа.';

  @override
  String get noPatientPhone => 'Энэ өвчтөнд утасны дугаар бүртгэгдээгүй байна.';

  @override
  String get cannotPlaceCall => 'Энэ төхөөрөмж дээр залгах боломжгүй.';

  @override
  String get visitMarkedCompleted => 'Дууссан гэж тэмдэглэгдлээ.';

  @override
  String get statCaptionTotal => 'Нийт';

  @override
  String get statLabelToday => 'Өнөөдөр';

  @override
  String get statLabelDone => 'Дууссан';

  @override
  String get statLabelOpen => 'Нээлттэй';

  @override
  String get reminderUpcomingSoon => 'Удахгүй';

  @override
  String get reminderNextBooking => 'Дараагийн цаг';

  @override
  String get reminderUnconfirmed => 'Баталгаажаагүй';

  @override
  String get reminderFollowUpDue => 'Давтан хяналт';

  @override
  String get reminderReviewCarePlan => 'Төлөвлөгөөг шалгах';

  @override
  String unconfirmedBookingsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count цаг баталгаажих хэрэгтэй',
      one: '1 цаг баталгаажих хэрэгтэй',
    );
    return '$_temp0';
  }

  @override
  String get patientsEmptyTitle => 'Хуваарьд өвчтөн алга';

  @override
  String get patientsEmptyBody =>
      'Өнөөдөр болон удахгүй болох үзлэгүүдийн өвчтөнүүд энд харагдана.';

  @override
  String get phoneOnFile => 'Утас бүртгэгдсэн';

  @override
  String get alertsLoadError => 'Мэдэгдэл ачаалахад алдаа гарлаа.';

  @override
  String get alertsAllCaughtUp => 'Бүх зүйл шинэ';

  @override
  String get alertsEmptyBody => 'Цаг болон системийн мэдэгдэл энд харагдана.';

  @override
  String get notificationFallback => 'Мэдэгдэл';

  @override
  String get symptomFallback =>
      'Яаралтай үзлэг — нарийвчилсан мэдээллийг бүртгэлээс үзнэ үү.';

  @override
  String get priorityEmergency => 'Яаралтай';

  @override
  String get priorityUrgent => 'Түргэн';

  @override
  String get priorityNormal => 'Энгийн';

  @override
  String get slidableDone => 'Дуусгах';

  @override
  String get statusPending => 'ХҮЛЭЭГДЭЖ БУЙ';

  @override
  String get statusConfirmed => 'БАТАЛГААЖСАН';

  @override
  String get statusCompleted => 'ДУУССАН';

  @override
  String get statusCancelled => 'ЦУЦЛАГДСАН';

  @override
  String get statusNoShow => 'ИРЭЭГҮЙ';

  @override
  String get statusUnknown => 'ТОДОРХОЙГҮЙ';

  @override
  String get settingsSectionAccount => 'Бүртгэл';

  @override
  String get settingsProfileTitle => 'Профайл ба нэвтрэлт';

  @override
  String get settingsProfileSubtitle => 'Бүртгэл, аюулгүй байдал, гарах';

  @override
  String get settingsSectionLanguage => 'Хэл ба бүс';

  @override
  String get profileTitle => 'Профайл';

  @override
  String get profileGuestTitle => 'Таны профайл';

  @override
  String get profileGuestSubtitle =>
      'Бүртгэл, цаг захиалга, хадгалсан тохиргоог харахын тулд нэвтрэнэ үү.';

  @override
  String get profileSignIn => 'Нэвтрэх';

  @override
  String get profileCreateAccount => 'Бүртгүүлэх';

  @override
  String get profileSettingsSubtitle => 'Хэл болон тохиргоо';

  @override
  String get profileHomeTooltip => 'Нүүр';

  @override
  String get profileEditTitle => 'Профайл засах';

  @override
  String get profileEditSubtitle =>
      'Никнейм болон профайлын зурагаа энд өөрчилнө үү.';

  @override
  String get profileEditNicknameLabel => 'Харуулах нэр (никнейм)';

  @override
  String get profileEditPickPhoto => 'Зураг сонгох';

  @override
  String get profileEditRemovePhoto => 'Зураг арилгах';

  @override
  String get profileEditSave => 'Хадгалах';

  @override
  String get profileEditSavedSnack => 'Хадгалагдлаа.';

  @override
  String get profileEditErrorSnack =>
      'Хадгалахад алдаа гарлаа. Дахин оролдоно уу.';

  @override
  String get profileChangePasswordTitle => 'Нууц үг солих';

  @override
  String get profileChangePasswordSubtitle =>
      'Одоогийн нууц үгээ оруулаад, шинэ нууц (хамгийн багадаа 8 тэмдэгт) сонгоно уу.';

  @override
  String get profileChangePasswordCurrentLabel => 'Одоогийн нууц үг';

  @override
  String get profileChangePasswordNewLabel => 'Шинэ нууц үг';

  @override
  String get profileChangePasswordConfirmLabel => 'Шинэ нууц давтах';

  @override
  String get profileChangePasswordSubmit => 'Шинэчлэх';

  @override
  String get profileChangePasswordSuccessSnack =>
      'Нууц үг шинэчлэгдлээ. Дараагийн удаа шинэ нууцаар нэвтэрнэ үү.';

  @override
  String get profileChangePasswordMismatch =>
      'Шинэ нууц хоёр удаа ижил биш байна.';

  @override
  String get profileChangePasswordTooShort =>
      'Шинэ нууц хамгийн багадаа 8 тэмдэгт байна.';

  @override
  String get profileChangePasswordGenericError =>
      'Нууц шинэчлэхэд алдаа гарлаа. Дахин оролдоно уу.';

  @override
  String get settingsProfileEditTitle => 'Никнейм ба профайлын зураг';

  @override
  String get settingsProfileEditSubtitle => 'Харуулах нэр, зургийг засах';

  @override
  String get splashLoadingSubtitle => 'Эмнэлгийн туршлага ачаалж байна…';

  @override
  String get authWelcomeBack => 'Сайн байна уу';

  @override
  String get authWelcomeBackSubtitle =>
      'Clinova бүртгэлдээ нэвтрэхийн тулд үргэлжлүүлнэ үү.';

  @override
  String get authCreateAccountTitle => 'Бүртгэл үүсгэх';

  @override
  String get authCreateAccountSubtitle =>
      'Баталгаажуулсны дараа цаг захиалах, эмчтэй холбогдох, үйлчилгээг ашиглах боломжтой.';

  @override
  String get authFormLogInTitle => 'Нэвтрэх';

  @override
  String get authEmailLabel => 'Имэйл эсвэл нэвтрэх нэр';

  @override
  String get authEmailHint => 'имэйл@жишээ.mn эсвэл doctor.enkhbayar';

  @override
  String get authPasswordLabel => 'Нууц үг';

  @override
  String get authConfirmPasswordLabel => 'Нууц үг давтах';

  @override
  String get authPasswordShow => 'Харуулах';

  @override
  String get authPasswordHide => 'Нуух';

  @override
  String get authForgotPasswordLink => 'Нууц үгээ мартсан уу?';

  @override
  String get authUseEmailCode => 'Имэйл кодоор нэвтрэх';

  @override
  String get authNewTo => 'Clinova-д шинэ үү?';

  @override
  String get authFooterSecure =>
      'Өвчтөн болон ажилтнуудад зориулсан аюулгүй нэвтрэлт.';

  @override
  String get authClinovaLocalUsePasswordOnly =>
      'Demo account байна. Нууц үгээр нэвтэрнэ үү. Энэ хаяг руу имэйл илгээгдэхгүй.';

  @override
  String get welcomeTitleLine1 => 'Таны эрүүл мэнд.';

  @override
  String get welcomeTitleLine2 => 'Бидний тэргүүлэх зорилт.';

  @override
  String get welcomeSubtitle =>
      'Цаг захиалах, шинж тэмдэг шалгах, найдвартай эмч нартай холбогдох бүгдийг нэг апп-д.';

  @override
  String get welcomeCreateAccount => 'Бүртгэл үүсгэх';

  @override
  String get welcomeLogIn => 'Нэвтрэх';

  @override
  String get welcomeFeatureAi => 'Үйлчилгээ ба AI тусламж';

  @override
  String get welcomeFeatureAppointments => 'Ухаалаг цаг захиалга';

  @override
  String get welcomeFeatureChat => 'Мэргэжилтэн, эмч нар';

  @override
  String get welcomeFeatureEmergency => 'Яаралтай тусламж';

  @override
  String get welcomeFeatureSecureProfile => 'Найдвартай профайл';

  @override
  String get welcomeNavHome => 'Нүүр';

  @override
  String get welcomeNavServices => 'Үйлчилгээ';

  @override
  String get welcomeNavDoctors => 'Эмч, мэргэжилтэн';

  @override
  String get welcomeNavAbout => 'Найдвар, аюулгүй байдал';

  @override
  String get welcomeBrandSubtitle => 'AI эрүүл мэндийн платформ';

  @override
  String get welcomeHeroHeadline =>
      'Хурдан, найдвартай, ухаалаг эрүүл мэндийн үйлчилгээ.';

  @override
  String get welcomeHeroSub =>
      'Цаг захиалах, эмчтэй холбогдох, зөвлөгөө авах, AI тусламж — бүгдийг нэг дор.';

  @override
  String get welcomeCtaExploreServices => 'Үйлчилгээ үзэх';

  @override
  String get welcomeSectionFeaturesTitle => 'Юу хийж чадах вэ';

  @override
  String get welcomeTrustAiAssist => 'AI туслахтай';

  @override
  String get welcomeTrustRealtimeBooking => 'Цаг захиалга real-time';

  @override
  String get welcomeTrustSecureRegistration => 'Найдвартай бүртгэл';

  @override
  String get welcomeTrustDoctorChat => 'Эмчтэй чатлах боломж';

  @override
  String get welcomeTrustDialogTitle => 'Clinova-д итгэх үндэс';

  @override
  String get welcomeTrustDialogBody =>
      'Бид таны мэдээллийг хамгаалж, баталгаажсан эмч нартай холбодог. Нэвтрэлт, чат болон цаг захиалга нь орчин үеийн аюулгүй стандартад нийцдэг.';

  @override
  String get authMarketingLoginTitle => 'Таны эрүүл мэндийн дижитал түнш';

  @override
  String get authMarketingLoginLine1 =>
      'AI тусламж, шинж тэмдгийн урьдчилан оношлолтод дэмжлэг үзүүлнэ.';

  @override
  String get authMarketingLoginLine2 =>
      'Эмч нарын сул цаг, баталгаажсан захиалгыг шууд харна.';

  @override
  String get authMarketingLoginLine3 =>
      'Өгөгдлийг шифрлэж, зөвхөн таны багт харагдана.';

  @override
  String get authMarketingRegisterTitle => 'Нэг бүртгэл — бүх үйлчилгээ';

  @override
  String get authMarketingRegisterLine1 =>
      'Өвчтөний профайл, түүх болон сануулгыг нэг дор удирдана.';

  @override
  String get authMarketingRegisterLine2 =>
      'Эмч нартай чат, зураг илгээх, дахин захиалах амархан.';

  @override
  String get authMarketingRegisterLine3 =>
      'Имэйлээр баталгаажуулалт — найдвартай эхлэл.';

  @override
  String get authMarketingRecoveryTitle =>
      'Нэвтрэлтээ аюулгүйгаар сэргээнэ үү';

  @override
  String get authMarketingRecoveryLine1 =>
      'Баталгаажуулах код зөвхөн таны имэйл хаягт илгээгдэнэ.';

  @override
  String get authMarketingRecoveryLine2 =>
      'Шинэ нууц үг тохируулснаар дахин нэвтэрч үйлчилгээ ашиглана.';

  @override
  String get authMarketingRecoveryLine3 =>
      'Орчин үеийн аюулгүй стандарт таны бүртгэлийг хамгаална.';

  @override
  String get authMarketingVerifyTitle => 'Имэйлээ баталгаажуулна';

  @override
  String get authMarketingVerifyLine1 =>
      'Кодыг зөвхөн таны оруулсан имэйл хаяг руу илгээнэ.';

  @override
  String get authMarketingVerifyLine2 =>
      'Алхамыг дуусгаснаар цаг захиалга, чат гэх мэт үйлчилгээ нээгдэнэ.';

  @override
  String get authMarketingVerifyLine3 =>
      'Нэг удаагийн код нэмэлт хамгаалалт болно.';

  @override
  String get authSecurityPill =>
      'Илүү аюулгүй • Имэйл баталгаажуулалт идэвхтэй';

  @override
  String get authGoogleContinue => 'Google-ээр үргэлжлүүлэх';

  @override
  String get authGoogleSkipsOtp =>
      'Google-ээр нэвтрэхэд имэйл код шаардлагагүй.';

  @override
  String get authSecurityCardTitle => 'Бид таны аюулгүйг сайжруулж байна';

  @override
  String get authSecurityCardBody =>
      'Нэмэлт хамгаалалтын тулд имэйл ба нууц үгээр нэвтрэхэд бүртгэлдээ хандахаас өмнө имэйл рүү 6 оронтой баталгаажуулах код илгээнэ.';

  @override
  String get authTrustSecureTitle => 'Аюулгүй нэвтрэлт';

  @override
  String get authTrustSecureBody => 'Таны бүртгэл үргэлж хамгаалагдсан.';

  @override
  String get authTrustEncryptedTitle => 'Шифрлэгдсэн өгөгдөл';

  @override
  String get authTrustEncryptedBody => 'Дэвшилтэт шифрлэлт ашигладаг.';

  @override
  String get authTrustDoctorsTitle => 'Найдвартай эмч нар';

  @override
  String get authTrustDoctorsBody => 'Танд найдвартай эмчилгээ.';

  @override
  String get authRememberMe => 'Намайг сана';

  @override
  String get authOrDivider => 'эсвэл';

  @override
  String get authVerifyBackToLogin => 'Нэвтрэх рүү буцах';

  @override
  String get authVerifyBackToRegister => 'Бүртгэл рүү буцах';

  @override
  String get authOtpSixDigitInstruction =>
      '6 оронтой баталгаажуулах кодоо оруулна уу';

  @override
  String get authOtpExtraSecurityBadge => 'Нэмэлт аюулгүй алхам';

  @override
  String get authOtpGoogleHint =>
      'Google-ээр нэвтэрвэл энэ баталгаажуулах алхам алгасагдана.';

  @override
  String get authOtpProtectionNote =>
      'Таны хамгаалалтын тулд имэйлээр нэвтрэхийг хандахаас өмнө баталгаажуулдаг.';

  @override
  String authResendIn(String time) => 'Код дахин илгээх: $time';

  @override
  String get authChangeEmail => 'Имэйл солих';

  @override
  String get aptLandingTitle => 'Хэдхэн минутад цаг захиал';

  @override
  String get aptLandingSubtitle =>
      'Тасаг сонгоод, тохирох эмчээ олж, баталгаажсан цагийн слот захиал.';

  @override
  String get aptLandingStart => 'Захиалга эхлүүлэх';

  @override
  String get aptLandingViewDoctors => 'Эмч нарыг харах';

  @override
  String get aptLandingTrustNote =>
      'Слот баталгаажсаны дараа л таны цаг баталгаатай.';

  @override
  String get aptLandingLoginToBook => 'Захиалахын тулд нэвтэрнэ үү';

  @override
  String get chatLandingTitle => 'Найдвартай эмч нартай чатлах';

  @override
  String get chatLandingSubtitle =>
      'Яаралтай бус эрүүл мэндийн асуултаа асууж, Clinova-ийн баталгаажсан эмч нарын зөвлөгөө аваарай.';

  @override
  String get chatLandingStart => 'Эмчтэй чат эхлүүлэх';

  @override
  String get chatLandingViewOnline => 'Онлайн эмч нарыг харах';

  @override
  String get chatLandingSafety =>
      'Яаралтай үед эмнэлгийн тусламж эсвэл Яаралтай тусламжийг ашиглана уу. Эмчтэй чат амь насанд аюултай нөхцөлд зориулагдаагүй.';

  @override
  String get chatLandingLoginToChat => 'Чатлахын тулд нэвтэрнэ үү';

  @override
  String get resetPasswordTitle => 'Шинэ нууц үг сонгоно уу';

  @override
  String get resetPasswordNewLabel => 'Шинэ нууц үг';

  @override
  String get resetPasswordConfirmLabel => 'Шинэ нууц үг давтах';

  @override
  String get resetPasswordSubmit => 'Нууц үг шинэчлэх';

  @override
  String get resetPasswordSuccess =>
      'Нууц үг шинэчлэгдлээ. Шинэ нууц үгээрээ нэвтэрнэ үү.';

  @override
  String get valEmailRequired => 'Имэйлээ оруулна уу.';

  @override
  String get valEmailInvalid => 'Зөв имэйл хаяг оруулна уу.';

  @override
  String get valEmailInvalidShort => 'Зөв имэйл оруулна уу.';

  @override
  String get valPasswordShort => 'Нууц үг хамгийн багадаа 8 тэмдэгт байна.';

  @override
  String get authFirstName => 'Нэр';

  @override
  String get authLastName => 'Овог';

  @override
  String get authFormRegisterTitle => 'Бүртгүүлэх';

  @override
  String get authRegisterCheckEmailSnack =>
      'Баталгаажуулах код таны имэйл рүү илгээгдлээ.';

  @override
  String get valFullName => 'Бүтэн нэрээ оруулна уу.';

  @override
  String get valPasswordsNoMatch => 'Нууц үг таарахгүй байна.';

  @override
  String get authAlreadyHaveAccount => 'Бүртгэлтэй юу?';

  @override
  String get authResetAccessTitle => 'Нэвтрэх эрх сэргээх';

  @override
  String get authResetAccessSubtitle =>
      'Бид 6 оронтой код имэйлээр илгээнэ. Дараагийн дэлгэцээр шинэ нууц үг тохируулна уу.';

  @override
  String get authFormForgotTitle => 'Нууц үг сэргээх';

  @override
  String get authSendVerificationCode => 'Баталгаажуулах код илгээх';

  @override
  String get authBackToLogin => 'Нэвтрэх хуудас руу буцах';

  @override
  String get authForgotSnackGeneric =>
      'Энэ имэйл бүртгэлтэй бол 6 оронтой код илгээгдсэн.';

  @override
  String get authForgotRateLimitMessage =>
      'Код дахин авахын өмнө түр хүлээнэ үү.';

  @override
  String authForgotRetryAfterSeconds(int seconds) =>
      'Дахин оролдох: ${seconds}с';

  @override
  String get authCodeSignInTitle => 'Имэйл кодоор нэвтрэх';

  @override
  String get authCodeSignInSubtitle =>
      'Нэг удаагийн код илгээнэ. Шинэ имэйлээр өвчтөний бүртгэл автоматаар үүснэ.';

  @override
  String get authRequestCodeTitle => 'Код авах';

  @override
  String get authSendCodeButton => 'Код илгээх';

  @override
  String get authUsePassword => 'Нууц үгээр нэвтрэх';

  @override
  String get authCodeSentInbox => 'Код илгээгдлээ. Имэйлээ шалгана уу.';

  @override
  String get authVerifyEmailTitle => 'Имэйлээ шалгана уу';

  @override
  String get authVerifyEmailMissing =>
      'Нэвтрэх эсвэл бүртгэлийн хуудаснаас шинэ код аваарай.';

  @override
  String authVerifyEmailBody(String email) =>
      '$email хаяг руу илгээсэн 6 оронтой кодыг оруулна уу.';

  @override
  String get authVerifyFormTitle => 'Код баталгаажуулах';

  @override
  String get authOtpFieldLabel => 'Баталгаажуулах код';

  @override
  String authDevCode(String code) => 'Хөгжүүлэлтийн код: $code';

  @override
  String get authVerifyContinue => 'Баталгаажуулах, үргэлжлүүлэх';

  @override
  String get authResendCode => 'Код дахин илгээх';

  @override
  String get authNewCodeSent => 'Шинэ код илгээгдлээ.';

  @override
  String get guestAuthTitle => 'Үргэлжлүүлэхийн тулд нэвтрэнэ үү';

  @override
  String get guestAuthBody =>
      'Энэ боломжийг ашиглахын тулд нэвтэрнэ үү эсвэл бүртгүүлнэ үү.';

  @override
  String get guestAuthNotNow => 'Дараа нь';

  @override
  String get homeGuestName => 'Зочин';

  @override
  String get homeDockHome => 'Нүүр';

  @override
  String get homeDockBook => 'Цаг';

  @override
  String get homeDockAi => 'AI';

  @override
  String get homeDockProfile => 'Профайл';

  @override
  String get homeDockSettings => 'Тохиргоо';

  @override
  String get homeBrandLabel => 'Clinova';

  @override
  String get homeTagline => 'Хурдан, тайван, чанартай эмнэлгийн үйлчилгээ.';

  @override
  String get homeTooltipProfile => 'Профайл';

  @override
  String get homeTooltipSignIn => 'Нэвтрэх';

  @override
  String get homeFilterEnt => 'ЧХА';

  @override
  String get homeFilterPediatrics => 'Хүүхдийн эмгэг';

  @override
  String get homeFilterDermatology => 'Арьсны эмгэг';

  @override
  String get homeFilterWomensCare => 'Эмэгтэйчүүдийн эрүүл мэнд';

  @override
  String get homeMoveFasterTitle => 'Илүү хурдан';

  @override
  String get homeMoveFasterSubtitle => 'Чухал бүхэн нэг товшилтоор.';

  @override
  String get homeCardBookVisitTitle => 'Цаг захиалах';

  @override
  String get homeCardBookVisitSubtitle => 'Дараагийн чөлөөт цагийг шууд олно.';

  @override
  String get homeCardAskAiTitle => 'AI-аас асуух';

  @override
  String get homeCardAskAiSubtitle => 'Тасаг болон эмчийн тохирлыг авах.';

  @override
  String get homeCardLiveChatTitle => 'Эмчтэй чат';

  @override
  String get homeCardLiveChatSubtitle => 'Бодит цагт холбогдоно.';

  @override
  String get homeCardPreferencesTitle => 'Тохиргоо';

  @override
  String get homeCardPreferencesSubtitle => 'Хэл болон эмнэлгийн тохиргоо.';

  @override
  String get homeCardBranchesTitle => 'Эмнэлгийн салбарууд';

  @override
  String get homeCardBranchesSubtitle =>
      'Хаяг, холбоо барих, сонгосон салбарт цаг авах.';

  @override
  String get homeYourCareTitle => 'Таны эрүүл мэндийн товч';

  @override
  String get homeYourCareSubtitle =>
      'Профайлын тэмдэглэл, сүүлийн бичлэг, үзлэгүүд.';

  @override
  String get homeMedicalNoteTitle => 'Өвчний түүх / тэмдэглэл';

  @override
  String get homeRecentRecordsTitle => 'Сүүлийн эмнэлгийн бичлэг';

  @override
  String get homePastVisitsTitle => 'Өмнөх үзлэгүүд';

  @override
  String get homeNoHealthDataYet =>
      'Одоогоор мэдээлэл алга. Профайлаа бөглөөд эсвэл цаг аваарай.';

  @override
  String get homeStaffTitle => 'Манай эмч, мэргэжилтнүүд';

  @override
  String get homeStaffSubtitle => 'Clinova-ийн салбаруудад ажилладаг баг.';

  @override
  String get homeStaffEmpty => 'Удахгүй энд жагсаалт гарна.';

  @override
  String get homeBranchesSectionTitle => 'Эмнэлгийн салбарууд';

  @override
  String get homeBranchesSectionSubtitle =>
      'Хаана үйлчилдэг вэ — бүгдийг харахын тулд дарна уу.';

  @override
  String get homeSeeAll => 'Бүгдийг харах';

  @override
  String get branchesTitle => 'Эмнэлгийн салбарууд';

  @override
  String get branchesBookHere => 'Энэ салбарт цаг авах';

  @override
  String get branchesEmpty => 'Одоогоор салбарын мэдээлэл алга.';

  @override
  String get branchesRetry => 'Дахин оролдох';

  @override
  String get homeTodayTitle => 'Өнөөдөр Clinova-д';

  @override
  String get homeTodaySubtitle => 'Салбаруудад одоо боломжтой эмч нар.';

  @override
  String get homeNoSlotsToday =>
      'Өнөөдөр чөлөөт цаг олдсонгүй. Өөр огноогоор цаг захиалах хуудсаас сонгоно уу.';

  @override
  String get homeBadgePremiumCare => 'Премиум дижитал эмнэлэг';

  @override
  String homeHeroGreeting(String name) =>
      'Сайн байна уу, $name, таны самбар бэлэн байна.';

  @override
  String get homeHeroSubtitle =>
      'Цаг захиалах, зөвлөгөө, чат — бүгдийг нэг газраас.';

  @override
  String get homeMetricUpcoming => 'Удахгүйхэн үзлэг';

  @override
  String get homeMetricProfile => 'Профайл бэлэн';

  @override
  String get homeBookNow => 'Цаг авах';

  @override
  String get homeHeroSecondaryCta => 'AI зөвлөгөө авах';

  @override
  String get homePremiumHeadlineAuthed =>
      'Сайн байна уу, таны эрүүл мэндийн самбар бэлэн боллоо.';

  @override
  String get homePremiumHeadlineGuest =>
      'Clinova — эрүүл мэндээ нэг дороос удирдаарай.';

  @override
  String get homePremiumSubtitle =>
      'Цаг захиалах, зөвлөгөө авах, үзлэгийн мэдээллээ нэг дороос удирдаарай.';

  @override
  String get homeNavHome => 'Нүүр';

  @override
  String get homeNavServices => 'Үйлчилгээ';

  @override
  String get homeNavDoctors => 'Эмч нар';

  @override
  String get homeNavAi => 'AI зөвлөгөө';

  @override
  String get homeNavBook => 'Цаг авах';

  @override
  String get homeNavLogin => 'Нэвтрэх';

  @override
  String get homeNavProfile => 'Профайл';

  @override
  String get homeAskAi => 'AI асуух';

  @override
  String homeTodayAt(String time) => 'Өнөөдөр $time';

  @override
  String get homeSlotBook => 'Захиалах';

  @override
  String get homeFallbackDoctor => 'Эмч';

  @override
  String get homeFallbackDepartment => 'Ерөнхий';

  @override
  String get homeFallbackBranch => 'Clinova';

  @override
  String get aptTitle => 'Цаг захиалга';

  @override
  String get aptSubtitle => 'Эмнэлгийн бодит чөлөөт цаг.';

  @override
  String get aptHeroTitle => 'Бодит цаг захиалах';

  @override
  String get aptHeroSubtitle =>
      'Зөвхөн эмчийн хуваарь, амралт, одоогийн цагтай нийцсэн чөлөөт цагийг харуулна.';

  @override
  String get aptChooseBranch => 'Салбар сонгох';

  @override
  String get aptChooseDepartment => 'Тасаг сонгох';

  @override
  String get aptChooseService => 'Үйлчилгээ сонгох';

  @override
  String get aptChooseDoctor => 'Эмч сонгох';

  @override
  String get aptTapToChoose => 'Товшоод сонгоно уу';

  @override
  String get aptBookingChoicesTitle => 'Сонголт';

  @override
  String get aptVisitReason => 'Яагаад ирж байна вэ?';

  @override
  String get aptReasonHint => 'Товч шалтгаан (сонголттой)';

  @override
  String get aptAvailableSlots => 'Чөлөөт цагууд';

  @override
  String get aptNoSlots =>
      'Энэ эмч, огноонд чөлөөт цаг алга. Өөр сонголт туршина уу.';

  @override
  String get aptBranchNoServices =>
      'Энэ салбарт захиалах үйлчилгээ бүртгэгдээгүй байна. Өөр салбар сонгоно уу.';

  @override
  String get aptNoServicesForDept =>
      'Сонгосон салбар, тасгийн хослолд үйлчилгээ алга. Өөр тасаг сонгоно уу.';

  @override
  String get aptPendingListTitle => 'Хүлээгдэж буй захиалгууд';

  @override
  String get aptNoPending => 'Хүлээгдэж буй захиалга алга.';

  @override
  String get aptBook => 'Захиалах';

  @override
  String get aptBooking => 'Захиалж байна…';

  @override
  String get aptBookedSuccess => 'Цаг амжилттай захиалагдлаа.';

  @override
  String get aptSelect => 'Сонгох';

  @override
  String get aptSlotLockExpired =>
      'Слотын түгжээ дууссан байна. Цагаа дахин сонгоно уу.';

  @override
  String aptPaymentIntentCreated(String mode) {
    return 'Төлбөрийн хүсэлт үүслээ ($mode).';
  }

  @override
  String get aptRecommendedTimesTitle => 'AI санал болгосон цагууд';

  @override
  String get aptSuggestedDoctorsTitle => 'Дараалал бага эмчийн санал';

  @override
  String aptQueueLabel(int count) {
    return 'дараалал $count';
  }

  @override
  String get aptAddedToWaitlist =>
      'Энэ үйлчилгээний хүлээлгийн жагсаалтад нэмэгдлээ.';

  @override
  String get aptJoinWaitingList => 'Хүлээлгийн жагсаалтад орох';

  @override
  String get aptStepDetails => 'Дэлгэрэнгүй';

  @override
  String get aptStepTime => 'Цаг';

  @override
  String get aptStepConfirm => 'Батлах';

  @override
  String get aptConfirmBookingTitle => 'Захиалга батлах';

  @override
  String get aptChangeSlot => 'Цаг солих';

  @override
  String get aptConfirm => 'Батлах';

  @override
  String get aptDynamicIntakeTitle => 'Нэмэлт асуулгын маягт';

  @override
  String aptDoctorLabel(String firstName, String lastName) {
    final t = '$firstName $lastName'.trim();
    if (t.isEmpty) return 'Эмч';
    return 'Эмч $t';
  }

  @override
  String get aiTitle => 'Clinova AI';

  @override
  String get aiTagline => 'Урьдчилан сэргийлэх зөвлөгөө, илүү ойлгомжтой.';

  @override
  String get aiHeroLine1 =>
      'Шинж тэмдгээ нэг удаа бичнэ. Дараагийн алхмыг хурдан олно.';

  @override
  String get aiHeroLine2 =>
      'Туршлага нь энгийн маягт биш, удирдан чиглүүлэх туслах шиг байна.';

  @override
  String get aiSymptomPrompt => 'Юу мэдэрч байна вэ?';

  @override
  String get aiSymptomHint =>
      'Жишээ: 2 хоногийн дараа халуураад, чих өвдөж байна';

  @override
  String get aiAnalyzeNow => 'Шинжилэх';

  @override
  String get aiAnalyzing => 'Шинжилж байна…';

  @override
  String get aiUseSample => 'Жишээ ашиглах';

  @override
  String get aiSampleSymptomText =>
      '2 хоногийн дараа халуураад, чих өвдөж байна';

  @override
  String get aiNextStepTitle => 'Зөвлөмжийн дараагийн алхам';

  @override
  String get aiNextStepEmpty =>
      'Тасаг болон эмчийн саналыг авахын тулд шинжилгээ ажиллуулна уу.';

  @override
  String get aiDept => 'Тасаг';

  @override
  String get aiDoctor => 'Эмч';

  @override
  String get aiBranch => 'Салбар';

  @override
  String get aiSlot => 'Цаг';

  @override
  String get aiRealtimeTitle => 'Бодит цагийн чат';

  @override
  String get aiRealtimeConnected => 'Холбогдсон';

  @override
  String get aiChatEmpty =>
      'Одоогоор мессеж алга. Эмчид товч асуулт илгээнэ үү.';

  @override
  String get aiChatHint => 'Мессеж бичих';

  @override
  String get chatDemoDoctorName => 'Эмч Намуун';

  @override
  String get chatOnlineStatus => 'Онлайн';

  @override
  String get chatWriteMessageHint => 'Мессеж бичих…';

  @override
  String get chatSelectDoctor => 'Эмч сонгох';

  @override
  String get chatNoDoctors =>
      'Одоогоор эмчийн жагсаалт хоосон байна. Дараа дахин оролдоно уу.';

  @override
  String get chatSignInToSaveMessages =>
      'Чатаа хадгалж, эмчтэй бичихийн тулд нэвтэрнэ үү.';

  @override
  String get homeMenuTitle => 'Цэс';

  @override
  String get homeDrawerAgent => 'Агент';

  @override
  String get homeDrawerAiAgentSubtitle => 'AI зөвлөгөө, туслах нэг дор.';

  @override
  String get docDashboardTitle => 'Эмчийн самбар';

  @override
  String docDashboardWelcome(String name) => 'Сайн байна уу, $name';

  @override
  String get docTodayAppointmentsTitle => 'Өнөөдрийн цагууд';

  @override
  String get docUpcomingTitle => 'Удахгүйхэн';

  @override
  String get docQuickActionsTitle => 'Түргэн үйлдлүүд';

  @override
  String get docOpenChat => 'Чат нээх';

  @override
  String get docNoPatientsToday => 'Өнөөдөр захиалгатай өвчтөн алга.';

  @override
  String get docNoUpcoming => 'Удахгүйхэн цаг олдсонгүй.';

  @override
  String get docHeroUpcoming => 'Удахгүй';

  @override
  String get docHeroPatients => 'Өвчтөн';

  @override
  String get adminControlTitle => 'Админ удирдлага';

  @override
  String get adminDefaultName => 'Админ';

  @override
  String adminWelcome(String name) => 'Сайн байна уу, $name';

  @override
  String get adminAddBranch => 'Салбар нэмэх';

  @override
  String get adminAddService => 'Үйлчилгээ нэмэх';

  @override
  String get adminAddDoctor => 'Эмч нэмэх';

  @override
  String get adminUsers => 'Хэрэглэгчид';

  @override
  String get adminJobApplications => 'Ажлын өргөдөл';

  @override
  String get adminBranches => 'Салбарууд';

  @override
  String get adminServices => 'Үйлчилгээнүүд';

  @override
  String get adminDoctors => 'Эмч нар';

  @override
  String get adminDeactivate => 'Идэвхгүй болгох';

  @override
  String get adminActivate => 'Идэвхжүүлэх';

  @override
  String get adminJobReviewing => 'Шалгаж байна';

  @override
  String get adminJobInterview => 'Ярилцлага';

  @override
  String get adminJobAccepted => 'Зөвшөөрсөн';

  @override
  String get adminJobRejected => 'Татгалзсан';

  @override
  String get adminCreateBranchTitle => 'Салбар үүсгэх';

  @override
  String get adminCreateServiceTitle => 'Үйлчилгээ үүсгэх';

  @override
  String get adminCreateDoctorTitle => 'Эмч үүсгэх';

  @override
  String get adminCancel => 'Цуцлах';

  @override
  String get adminCreate => 'Үүсгэх';

  @override
  String get adminLabelName => 'Нэр';

  @override
  String get adminLabelCode => 'Код';

  @override
  String get adminLabelAddress => 'Хаяг';

  @override
  String get adminLabelCity => 'Хот';

  @override
  String get adminLabelPhone => 'Утас';

  @override
  String get adminLabelOpeningHours => 'Ажиллах цаг';

  @override
  String get adminLabelDescription => 'Тайлбар';

  @override
  String get adminLabelPrice => 'Үнэ';

  @override
  String get adminLabelDuration => 'Үргэлжлэх хугацаа (минут)';

  @override
  String get adminLabelBranch => 'Салбар';

  @override
  String get adminLabelDepartment => 'Тасаг';

  @override
  String get adminLabelPrimaryService => 'Үндсэн үйлчилгээ';

  @override
  String get adminLabelBio => 'Танилцуулга';

  @override
  String get adminLabelConsultationFee => 'Зөвлөгөөний хөлс';

  @override
  String get adminHeroUsers => 'Хэрэглэгч';

  @override
  String get adminHeroDoctors => 'Эмч';

  @override
  String get adminHeroPatients => 'Өвчтөн';

  @override
  String get adminHeroToday => 'Өнөөдөр';

  @override
  String get adminHeroJobs => 'Өргөдөл';

  @override
  String get adminHeroBranches => 'Салбар';
}
