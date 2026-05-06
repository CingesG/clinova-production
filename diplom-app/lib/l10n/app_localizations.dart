import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_mn.dart';

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
    Locale('en'),
    Locale('mn'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinova'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @patients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get patients;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @follow_up.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get follow_up;

  /// No description provided for @total_today.
  ///
  /// In en, this message translates to:
  /// **'Total today'**
  String get total_today;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @no_data.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get no_data;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageMongolian.
  ///
  /// In en, this message translates to:
  /// **'Mongolian'**
  String get languageMongolian;

  /// No description provided for @doctorBranchFallback.
  ///
  /// In en, this message translates to:
  /// **'Your branch'**
  String get doctorBranchFallback;

  /// No description provided for @doctorRoleFallback.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get doctorRoleFallback;

  /// No description provided for @patientFallback.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patientFallback;

  /// No description provided for @consultationFallback.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get consultationFallback;

  /// No description provided for @dashUnknown.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get dashUnknown;

  /// No description provided for @timeTbd.
  ///
  /// In en, this message translates to:
  /// **'Time TBD'**
  String get timeTbd;

  /// No description provided for @emergencyIntakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency intake'**
  String get emergencyIntakeTitle;

  /// No description provided for @emergencyIntakeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tagged with [EMERGENCY] on the booking reason.'**
  String get emergencyIntakeSubtitle;

  /// No description provided for @emergencyBadge.
  ///
  /// In en, this message translates to:
  /// **'EMERGENCY'**
  String get emergencyBadge;

  /// No description provided for @remindersSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What needs attention next.'**
  String get remindersSectionSubtitle;

  /// No description provided for @remindersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reminder items right now.'**
  String get remindersEmpty;

  /// No description provided for @quickStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick stats'**
  String get quickStatsTitle;

  /// No description provided for @quickStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your day at a glance.'**
  String get quickStatsSubtitle;

  /// No description provided for @todayScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s schedule'**
  String get todayScheduleTitle;

  /// No description provided for @todayScheduleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Swipe a card to mark a visit complete.'**
  String get todayScheduleSubtitle;

  /// No description provided for @noVisitsTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'No visits scheduled today'**
  String get noVisitsTodayTitle;

  /// No description provided for @noVisitsTodayBody.
  ///
  /// In en, this message translates to:
  /// **'Enjoy the focus time — new bookings will land here automatically.'**
  String get noVisitsTodayBody;

  /// No description provided for @routineClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Routine schedule clear'**
  String get routineClearTitle;

  /// No description provided for @routineClearBody.
  ///
  /// In en, this message translates to:
  /// **'Today\'s remaining visits are handled under Emergency intake above.'**
  String get routineClearBody;

  /// No description provided for @followUpPatientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow-up patients'**
  String get followUpPatientsTitle;

  /// No description provided for @followUpPatientsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recent documentation tied to your care.'**
  String get followUpPatientsSubtitle;

  /// No description provided for @followUpEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No follow-up tasks yet'**
  String get followUpEmptyTitle;

  /// No description provided for @followUpEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Completed visits with notes will appear here.'**
  String get followUpEmptyBody;

  /// No description provided for @followUpNotePreview.
  ///
  /// In en, this message translates to:
  /// **'Review last visit documentation'**
  String get followUpNotePreview;

  /// No description provided for @openRecord.
  ///
  /// In en, this message translates to:
  /// **'Open record'**
  String get openRecord;

  /// No description provided for @followUpUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String followUpUpdated(String date);

  /// No description provided for @noNoteRecorded.
  ///
  /// In en, this message translates to:
  /// **'No note recorded.'**
  String get noNoteRecorded;

  /// No description provided for @loadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get loadErrorTitle;

  /// No description provided for @emergencyAccepted.
  ///
  /// In en, this message translates to:
  /// **'Emergency visit accepted.'**
  String get emergencyAccepted;

  /// No description provided for @noPatientPhone.
  ///
  /// In en, this message translates to:
  /// **'No phone number on file for this patient.'**
  String get noPatientPhone;

  /// No description provided for @cannotPlaceCall.
  ///
  /// In en, this message translates to:
  /// **'Cannot start phone call on this device.'**
  String get cannotPlaceCall;

  /// No description provided for @visitMarkedCompleted.
  ///
  /// In en, this message translates to:
  /// **'Marked as completed.'**
  String get visitMarkedCompleted;

  /// No description provided for @statCaptionTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get statCaptionTotal;

  /// No description provided for @statLabelToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statLabelToday;

  /// No description provided for @statLabelDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statLabelDone;

  /// No description provided for @statLabelOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get statLabelOpen;

  /// No description provided for @reminderUpcomingSoon.
  ///
  /// In en, this message translates to:
  /// **'Upcoming soon'**
  String get reminderUpcomingSoon;

  /// No description provided for @reminderNextBooking.
  ///
  /// In en, this message translates to:
  /// **'Next booking'**
  String get reminderNextBooking;

  /// No description provided for @reminderUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Unconfirmed'**
  String get reminderUnconfirmed;

  /// No description provided for @reminderFollowUpDue.
  ///
  /// In en, this message translates to:
  /// **'Follow-up due'**
  String get reminderFollowUpDue;

  /// No description provided for @reminderReviewCarePlan.
  ///
  /// In en, this message translates to:
  /// **'Review care plan'**
  String get reminderReviewCarePlan;

  /// No description provided for @unconfirmedBookingsBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 booking needs confirmation} other{{count} bookings need confirmation}}'**
  String unconfirmedBookingsBody(int count);

  /// No description provided for @patientsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No patients in your schedule yet'**
  String get patientsEmptyTitle;

  /// No description provided for @patientsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Patients from today and upcoming visits will be listed here.'**
  String get patientsEmptyBody;

  /// No description provided for @phoneOnFile.
  ///
  /// In en, this message translates to:
  /// **'Phone on file'**
  String get phoneOnFile;

  /// No description provided for @alertsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load alerts.'**
  String get alertsLoadError;

  /// No description provided for @alertsAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You are all caught up'**
  String get alertsAllCaughtUp;

  /// No description provided for @alertsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Appointment and system alerts will show up here.'**
  String get alertsEmptyBody;

  /// No description provided for @notificationFallback.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationFallback;

  /// No description provided for @symptomFallback.
  ///
  /// In en, this message translates to:
  /// **'Emergency visit — see clinical details.'**
  String get symptomFallback;

  /// No description provided for @priorityEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get priorityEmergency;

  /// No description provided for @priorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get priorityUrgent;

  /// No description provided for @priorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get priorityNormal;

  /// No description provided for @slidableDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get slidableDone;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'CONFIRMED'**
  String get statusConfirmed;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get statusCancelled;

  /// No description provided for @statusNoShow.
  ///
  /// In en, this message translates to:
  /// **'NO_SHOW'**
  String get statusNoShow;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'UNKNOWN'**
  String get statusUnknown;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile & sign-in'**
  String get settingsProfileTitle;

  /// No description provided for @settingsProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account, security, and log out'**
  String get settingsProfileSubtitle;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language & region'**
  String get settingsSectionLanguage;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get profileGuestTitle;

  /// No description provided for @profileGuestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your account, appointments, and saved preferences.'**
  String get profileGuestSubtitle;

  /// No description provided for @profileSignIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get profileSignIn;

  /// No description provided for @profileCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get profileCreateAccount;

  /// No description provided for @profileSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language and preferences'**
  String get profileSettingsSubtitle;

  /// No description provided for @profileHomeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get profileHomeTooltip;

  String get profileEditTitle;
  String get profileEditSubtitle;
  String get profileEditNicknameLabel;
  String get profileEditPickPhoto;
  String get profileEditRemovePhoto;
  String get profileEditSave;
  String get profileEditSavedSnack;
  String get profileEditErrorSnack;
  String get profileChangePasswordTitle;
  String get profileChangePasswordSubtitle;
  String get profileChangePasswordCurrentLabel;
  String get profileChangePasswordNewLabel;
  String get profileChangePasswordConfirmLabel;
  String get profileChangePasswordSubmit;
  String get profileChangePasswordSuccessSnack;
  String get profileChangePasswordMismatch;
  String get profileChangePasswordTooShort;
  String get profileChangePasswordGenericError;
  String get settingsProfileEditTitle;
  String get settingsProfileEditSubtitle;

  // Splash, home, auth (patient), booking, AI
  String get splashLoadingSubtitle;

  String get authWelcomeBack;
  String get authWelcomeBackSubtitle;
  String get authCreateAccountTitle;
  String get authCreateAccountSubtitle;
  String get authFormLogInTitle;
  String get authEmailLabel;
  String get authEmailHint;
  String get authPasswordLabel;
  String get authConfirmPasswordLabel;
  String get authPasswordShow;
  String get authPasswordHide;
  String get authForgotPasswordLink;
  String get authUseEmailCode;
  String get authNewTo;
  String get authFooterSecure;
  String get authClinovaLocalUsePasswordOnly;

  String get welcomeTitleLine1;
  String get welcomeTitleLine2;
  String get welcomeSubtitle;
  String get welcomeCreateAccount;
  String get welcomeLogIn;
  String get welcomeFeatureAi;
  String get welcomeFeatureAppointments;
  String get welcomeFeatureChat;
  String get welcomeFeatureEmergency;
  String get welcomeFeatureSecureProfile;

  String get welcomeNavHome;
  String get welcomeNavServices;
  String get welcomeNavDoctors;
  String get welcomeNavAbout;
  String get welcomeBrandSubtitle;
  String get welcomeHeroHeadline;
  String get welcomeHeroSub;
  String get welcomeCtaExploreServices;
  String get welcomeSectionFeaturesTitle;
  String get welcomeTrustAiAssist;
  String get welcomeTrustRealtimeBooking;
  String get welcomeTrustSecureRegistration;
  String get welcomeTrustDoctorChat;
  String get welcomeTrustDialogTitle;
  String get welcomeTrustDialogBody;

  String get authMarketingLoginTitle;
  String get authMarketingLoginLine1;
  String get authMarketingLoginLine2;
  String get authMarketingLoginLine3;
  String get authMarketingRegisterTitle;
  String get authMarketingRegisterLine1;
  String get authMarketingRegisterLine2;
  String get authMarketingRegisterLine3;

  String get authMarketingRecoveryTitle;
  String get authMarketingRecoveryLine1;
  String get authMarketingRecoveryLine2;
  String get authMarketingRecoveryLine3;
  String get authMarketingVerifyTitle;
  String get authMarketingVerifyLine1;
  String get authMarketingVerifyLine2;
  String get authMarketingVerifyLine3;

  String get authSecurityPill;
  String get authGoogleContinue;
  String get authGoogleSkipsOtp;
  String get authSecurityCardTitle;
  String get authSecurityCardBody;
  String get authTrustSecureTitle;
  String get authTrustSecureBody;
  String get authTrustEncryptedTitle;
  String get authTrustEncryptedBody;
  String get authTrustDoctorsTitle;
  String get authTrustDoctorsBody;
  String get authRememberMe;
  String get authOrDivider;
  String get authVerifyBackToLogin;
  String get authVerifyBackToRegister;
  /// Shown above the OTP input (email verification).
  String get authOtpSixDigitInstruction;
  String get authOtpExtraSecurityBadge;
  String get authOtpGoogleHint;
  String get authOtpProtectionNote;
  String authResendIn(String time);
  String get authChangeEmail;
  String get aptLandingTitle;
  String get aptLandingSubtitle;
  String get aptLandingStart;
  String get aptLandingViewDoctors;
  String get aptLandingTrustNote;
  String get aptLandingLoginToBook;
  String get chatLandingTitle;
  String get chatLandingSubtitle;
  String get chatLandingStart;
  String get chatLandingViewOnline;
  String get chatLandingSafety;
  String get chatLandingLoginToChat;
  String get resetPasswordTitle;
  String get resetPasswordNewLabel;
  String get resetPasswordConfirmLabel;
  String get resetPasswordSubmit;
  String get resetPasswordSuccess;

  String get valEmailRequired;
  String get valEmailInvalid;
  String get valEmailInvalidShort;
  String get valPasswordShort;

  String get authFirstName;
  String get authLastName;
  String get authFormRegisterTitle;
  String get authRegisterCheckEmailSnack;
  String get valFullName;
  String get valPasswordsNoMatch;
  String get authAlreadyHaveAccount;

  String get authResetAccessTitle;
  String get authResetAccessSubtitle;
  String get authFormForgotTitle;
  String get authSendVerificationCode;
  String get authBackToLogin;

  String get authForgotSnackGeneric;

  /// Rate limit / 429 on forgot-password (and related resend paths using the same API).
  String get authForgotRateLimitMessage;

  /// Countdown label while forgot-password submit is briefly disabled after a request.
  String authForgotRetryAfterSeconds(int seconds);

  String get authCodeSignInTitle;
  String get authCodeSignInSubtitle;
  String get authRequestCodeTitle;
  String get authSendCodeButton;
  String get authUsePassword;
  String get authCodeSentInbox;

  String get authVerifyEmailTitle;
  String get authVerifyEmailMissing;
  String authVerifyEmailBody(String email);
  String get authVerifyFormTitle;
  String get authOtpFieldLabel;
  String authDevCode(String code);
  String get authVerifyContinue;
  String get authResendCode;
  String get authNewCodeSent;

  String get guestAuthTitle;
  String get guestAuthBody;
  String get guestAuthNotNow;

  String get homeGuestName;
  String get homeDockHome;
  String get homeDockBook;
  String get homeDockAi;
  String get homeDockProfile;
  String get homeDockSettings;
  String get homeBrandLabel;
  String get homeTagline;
  String get homeTooltipProfile;
  String get homeTooltipSignIn;
  String get homeFilterEnt;
  String get homeFilterPediatrics;
  String get homeFilterDermatology;
  String get homeFilterWomensCare;
  String get homeMoveFasterTitle;
  String get homeMoveFasterSubtitle;
  String get homeCardBookVisitTitle;
  String get homeCardBookVisitSubtitle;
  String get homeCardAskAiTitle;
  String get homeCardAskAiSubtitle;
  String get homeCardLiveChatTitle;
  String get homeCardLiveChatSubtitle;
  String get homeCardPreferencesTitle;
  String get homeCardPreferencesSubtitle;
  String get homeCardBranchesTitle;
  String get homeCardBranchesSubtitle;
  String get homeYourCareTitle;
  String get homeYourCareSubtitle;
  String get homeMedicalNoteTitle;
  String get homeRecentRecordsTitle;
  String get homePastVisitsTitle;
  String get homeNoHealthDataYet;
  String get homeStaffTitle;
  String get homeStaffSubtitle;
  String get homeStaffEmpty;
  String get homeBranchesSectionTitle;
  String get homeBranchesSectionSubtitle;
  String get homeSeeAll;
  String get branchesTitle;
  String get branchesBookHere;
  String get branchesEmpty;
  String get branchesRetry;
  String get homeTodayTitle;
  String get homeTodaySubtitle;
  String get homeNoSlotsToday;
  String get homeBadgePremiumCare;
  String homeHeroGreeting(String name);
  String get homeHeroSubtitle;
  String get homeMetricUpcoming;
  String get homeMetricProfile;
  String get homeBookNow;
  String get homeHeroSecondaryCta;
  String get homePremiumHeadlineAuthed;
  String get homePremiumHeadlineGuest;
  String get homePremiumSubtitle;
  String get homeNavHome;
  String get homeNavServices;
  String get homeNavDoctors;
  String get homeNavAi;
  String get homeNavBook;
  String get homeNavLogin;
  String get homeNavProfile;
  String get homeAskAi;
  String homeTodayAt(String time);
  String get homeSlotBook;
  String get homeFallbackDoctor;
  String get homeFallbackDepartment;
  String get homeFallbackBranch;

  String get aptTitle;
  String get aptSubtitle;
  String get aptHeroTitle;
  String get aptHeroSubtitle;
  String get aptChooseBranch;
  String get aptChooseDepartment;
  String get aptChooseService;
  String get aptChooseDoctor;
  String get aptTapToChoose;
  String get aptBookingChoicesTitle;
  String get aptVisitReason;
  String get aptReasonHint;
  String get aptAvailableSlots;
  String get aptNoSlots;
  String get aptBranchNoServices;
  String get aptNoServicesForDept;
  String get aptPendingListTitle;
  String get aptNoPending;
  String get aptBook;
  String get aptBooking;
  String get aptBookedSuccess;
  String get aptSelect;
  String get aptSlotLockExpired;
  String aptPaymentIntentCreated(String mode);
  String get aptRecommendedTimesTitle;
  String get aptSuggestedDoctorsTitle;
  String aptQueueLabel(int count);
  String get aptAddedToWaitlist;
  String get aptJoinWaitingList;
  String get aptStepDetails;
  String get aptStepTime;
  String get aptStepConfirm;
  String get aptConfirmBookingTitle;
  String get aptChangeSlot;
  String get aptConfirm;
  String get aptDynamicIntakeTitle;

  String aptDoctorLabel(String firstName, String lastName);

  String get aiTitle;
  String get aiTagline;
  String get aiHeroLine1;
  String get aiHeroLine2;
  String get aiSymptomPrompt;
  String get aiSymptomHint;
  String get aiAnalyzeNow;
  String get aiAnalyzing;
  String get aiUseSample;
  String get aiSampleSymptomText;
  String get aiNextStepTitle;
  String get aiNextStepEmpty;
  String get aiDept;
  String get aiDoctor;
  String get aiBranch;
  String get aiSlot;
  String get aiRealtimeTitle;
  String get aiRealtimeConnected;
  String get aiChatEmpty;
  String get aiChatHint;

  String get chatDemoDoctorName;
  String get chatOnlineStatus;
  String get chatWriteMessageHint;
  String get chatSelectDoctor;
  String get chatNoDoctors;
  String get chatSignInToSaveMessages;
  String get homeMenuTitle;
  String get homeDrawerAgent;
  String get homeDrawerAiAgentSubtitle;

  String get docDashboardTitle;
  String docDashboardWelcome(String name);
  String get docTodayAppointmentsTitle;
  String get docUpcomingTitle;
  String get docQuickActionsTitle;
  String get docOpenChat;
  String get docNoPatientsToday;
  String get docNoUpcoming;
  String get docHeroUpcoming;
  String get docHeroPatients;

  String get adminControlTitle;
  String get adminDefaultName;
  String adminWelcome(String name);
  String get adminAddBranch;
  String get adminAddService;
  String get adminAddDoctor;
  String get adminUsers;
  String get adminJobApplications;
  String get adminBranches;
  String get adminServices;
  String get adminDoctors;
  String get adminDeactivate;
  String get adminActivate;
  String get adminJobReviewing;
  String get adminJobInterview;
  String get adminJobAccepted;
  String get adminJobRejected;
  String get adminCreateBranchTitle;
  String get adminCreateServiceTitle;
  String get adminCreateDoctorTitle;
  String get adminCancel;
  String get adminCreate;
  String get adminLabelName;
  String get adminLabelCode;
  String get adminLabelAddress;
  String get adminLabelCity;
  String get adminLabelPhone;
  String get adminLabelOpeningHours;
  String get adminLabelDescription;
  String get adminLabelPrice;
  String get adminLabelDuration;
  String get adminLabelBranch;
  String get adminLabelDepartment;
  String get adminLabelPrimaryService;
  String get adminLabelBio;
  String get adminLabelConsultationFee;
  String get adminHeroUsers;
  String get adminHeroDoctors;
  String get adminHeroPatients;
  String get adminHeroToday;
  String get adminHeroJobs;
  String get adminHeroBranches;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'mn'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'mn':
      return AppLocalizationsMn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
