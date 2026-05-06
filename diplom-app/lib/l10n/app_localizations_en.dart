// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Clinova';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get emergency => 'Emergency';

  @override
  String get appointments => 'Appointments';

  @override
  String get patients => 'Patients';

  @override
  String get reminders => 'Reminders';

  @override
  String get follow_up => 'Follow-up';

  @override
  String get total_today => 'Total today';

  @override
  String get completed => 'Completed';

  @override
  String get pending => 'Pending';

  @override
  String get accept => 'Accept';

  @override
  String get call => 'Call';

  @override
  String get no_data => 'No data';

  @override
  String get loading => 'Loading…';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get alerts => 'Alerts';

  @override
  String get retry => 'Retry';

  @override
  String get messages => 'Messages';

  @override
  String get logOut => 'Log out';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMongolian => 'Mongolian';

  @override
  String get doctorBranchFallback => 'Your branch';

  @override
  String get doctorRoleFallback => 'Doctor';

  @override
  String get patientFallback => 'Patient';

  @override
  String get consultationFallback => 'Consultation';

  @override
  String get dashUnknown => '—';

  @override
  String get timeTbd => 'Time TBD';

  @override
  String get emergencyIntakeTitle => 'Emergency intake';

  @override
  String get emergencyIntakeSubtitle =>
      'Tagged with [EMERGENCY] on the booking reason.';

  @override
  String get emergencyBadge => 'EMERGENCY';

  @override
  String get remindersSectionSubtitle => 'What needs attention next.';

  @override
  String get remindersEmpty => 'No reminder items right now.';

  @override
  String get quickStatsTitle => 'Quick stats';

  @override
  String get quickStatsSubtitle => 'Your day at a glance.';

  @override
  String get todayScheduleTitle => 'Today\'s schedule';

  @override
  String get todayScheduleSubtitle => 'Swipe a card to mark a visit complete.';

  @override
  String get noVisitsTodayTitle => 'No visits scheduled today';

  @override
  String get noVisitsTodayBody =>
      'Enjoy the focus time — new bookings will land here automatically.';

  @override
  String get routineClearTitle => 'Routine schedule clear';

  @override
  String get routineClearBody =>
      'Today\'s remaining visits are handled under Emergency intake above.';

  @override
  String get followUpPatientsTitle => 'Follow-up patients';

  @override
  String get followUpPatientsSubtitle =>
      'Recent documentation tied to your care.';

  @override
  String get followUpEmptyTitle => 'No follow-up tasks yet';

  @override
  String get followUpEmptyBody =>
      'Completed visits with notes will appear here.';

  @override
  String get followUpNotePreview => 'Review last visit documentation';

  @override
  String get openRecord => 'Open record';

  @override
  String followUpUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String get noNoteRecorded => 'No note recorded.';

  @override
  String get loadErrorTitle => 'Something went wrong';

  @override
  String get emergencyAccepted => 'Emergency visit accepted.';

  @override
  String get noPatientPhone => 'No phone number on file for this patient.';

  @override
  String get cannotPlaceCall => 'Cannot start phone call on this device.';

  @override
  String get visitMarkedCompleted => 'Marked as completed.';

  @override
  String get statCaptionTotal => 'Total';

  @override
  String get statLabelToday => 'Today';

  @override
  String get statLabelDone => 'Done';

  @override
  String get statLabelOpen => 'Open';

  @override
  String get reminderUpcomingSoon => 'Upcoming soon';

  @override
  String get reminderNextBooking => 'Next booking';

  @override
  String get reminderUnconfirmed => 'Unconfirmed';

  @override
  String get reminderFollowUpDue => 'Follow-up due';

  @override
  String get reminderReviewCarePlan => 'Review care plan';

  @override
  String unconfirmedBookingsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookings need confirmation',
      one: '1 booking needs confirmation',
    );
    return '$_temp0';
  }

  @override
  String get patientsEmptyTitle => 'No patients in your schedule yet';

  @override
  String get patientsEmptyBody =>
      'Patients from today and upcoming visits will be listed here.';

  @override
  String get phoneOnFile => 'Phone on file';

  @override
  String get alertsLoadError => 'Could not load alerts.';

  @override
  String get alertsAllCaughtUp => 'You are all caught up';

  @override
  String get alertsEmptyBody =>
      'Appointment and system alerts will show up here.';

  @override
  String get notificationFallback => 'Notification';

  @override
  String get symptomFallback => 'Emergency visit — see clinical details.';

  @override
  String get priorityEmergency => 'Emergency';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get slidableDone => 'Done';

  @override
  String get statusPending => 'PENDING';

  @override
  String get statusConfirmed => 'CONFIRMED';

  @override
  String get statusCompleted => 'COMPLETED';

  @override
  String get statusCancelled => 'CANCELLED';

  @override
  String get statusNoShow => 'NO_SHOW';

  @override
  String get statusUnknown => 'UNKNOWN';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsProfileTitle => 'Profile & sign-in';

  @override
  String get settingsProfileSubtitle =>
      'Manage your account, security, and log out';

  @override
  String get settingsSectionLanguage => 'Language & region';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileGuestTitle => 'Your profile';

  @override
  String get profileGuestSubtitle =>
      'Sign in to view your account, appointments, and saved preferences.';

  @override
  String get profileSignIn => 'Log in';

  @override
  String get profileCreateAccount => 'Create account';

  @override
  String get profileSettingsSubtitle => 'Language and preferences';

  @override
  String get profileHomeTooltip => 'Home';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileEditSubtitle =>
      'Choose a display name (nickname) and profile photo visible in the app.';

  @override
  String get profileEditNicknameLabel => 'Nickname';

  @override
  String get profileEditPickPhoto => 'Pick photo';

  @override
  String get profileEditRemovePhoto => 'Remove photo';

  @override
  String get profileEditSave => 'Save';

  @override
  String get profileEditSavedSnack => 'Saved.';

  @override
  String get profileEditErrorSnack => 'Could not save. Try again.';

  @override
  String get profileChangePasswordTitle => 'Change password';

  @override
  String get profileChangePasswordSubtitle =>
      'Use your current password, then choose a new one (min. 8 characters).';

  @override
  String get profileChangePasswordCurrentLabel => 'Current password';

  @override
  String get profileChangePasswordNewLabel => 'New password';

  @override
  String get profileChangePasswordConfirmLabel => 'Confirm new password';

  @override
  String get profileChangePasswordSubmit => 'Update password';

  @override
  String get profileChangePasswordSuccessSnack =>
      'Password updated. Use your new password next time you sign in.';

  @override
  String get profileChangePasswordMismatch =>
      'New passwords do not match.';

  @override
  String get profileChangePasswordTooShort =>
      'New password must be at least 8 characters.';

  @override
  String get profileChangePasswordGenericError =>
      'Could not update password. Try again.';

  @override
  String get settingsProfileEditTitle => 'Name & photo';

  @override
  String get settingsProfileEditSubtitle => 'Nickname and profile picture';

  @override
  String get splashLoadingSubtitle => 'Loading your clinic experience…';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authWelcomeBackSubtitle =>
      'Sign in to continue to your Clinova account.';

  @override
  String get authCreateAccountTitle => 'Create your account';

  @override
  String get authCreateAccountSubtitle =>
      'After verification you can book visits, message doctors, and use every Clinova service in one place.';

  @override
  String get authFormLogInTitle => 'Log in';

  @override
  String get authEmailLabel => 'Email or login ID';

  @override
  String get authEmailHint => 'you@example.com or doctor.enkhbayar';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authPasswordShow => 'Show';

  @override
  String get authPasswordHide => 'Hide';

  @override
  String get authForgotPasswordLink => 'Forgot password?';

  @override
  String get authUseEmailCode => 'Use email code instead';

  @override
  String get authNewTo => 'New to Clinova?';

  @override
  String get authFooterSecure => 'Secure access for patients and staff.';

  @override
  String get authClinovaLocalUsePasswordOnly =>
      'This is a demo @clinova.local account. Sign in with your password only — email codes are not delivered to this address.';

  @override
  String get welcomeTitleLine1 => 'Your Health.';

  @override
  String get welcomeTitleLine2 => 'Our Priority.';

  @override
  String get welcomeSubtitle =>
      'Book appointments, check symptoms, and connect with trusted doctors in one smart healthcare app.';

  @override
  String get welcomeCreateAccount => 'Create account';

  @override
  String get welcomeLogIn => 'Log in';

  @override
  String get welcomeFeatureAi => 'Services & AI assistance';

  @override
  String get welcomeFeatureAppointments => 'Smart scheduling';

  @override
  String get welcomeFeatureChat => 'Specialists & doctors';

  @override
  String get welcomeFeatureEmergency => 'Emergency Help';

  @override
  String get welcomeFeatureSecureProfile => 'Secure patient profile';

  @override
  String get welcomeNavHome => 'Home';

  @override
  String get welcomeNavServices => 'Services';

  @override
  String get welcomeNavDoctors => 'Doctors';

  @override
  String get welcomeNavAbout => 'Trust';

  @override
  String get welcomeBrandSubtitle => 'AI healthcare platform';

  @override
  String get welcomeHeroHeadline =>
      'Fast, reliable, intelligent care for your health.';

  @override
  String get welcomeHeroSub =>
      'Book visits, reach your doctors, get guidance, and tap AI support — all in one place.';

  @override
  String get welcomeCtaExploreServices => 'Browse services';

  @override
  String get welcomeSectionFeaturesTitle => 'What you can do';

  @override
  String get welcomeTrustAiAssist => 'AI-assisted guidance';

  @override
  String get welcomeTrustRealtimeBooking => 'Real-time scheduling';

  @override
  String get welcomeTrustSecureRegistration => 'Verified sign-up';

  @override
  String get welcomeTrustDoctorChat => 'Chat with clinicians';

  @override
  String get welcomeTrustDialogTitle => 'Why trust Clinova';

  @override
  String get welcomeTrustDialogBody =>
      'We protect your information and connect you with verified clinicians. Sign-in, chat, and booking follow modern security practices.';

  @override
  String get authMarketingLoginTitle => 'Your digital health companion';

  @override
  String get authMarketingLoginLine1 =>
      'AI guidance that supports symptom review and next steps.';

  @override
  String get authMarketingLoginLine2 =>
      'See live availability and confirmed bookings with your care team.';

  @override
  String get authMarketingLoginLine3 =>
      'Data is encrypted and visible only to you and authorized staff.';

  @override
  String get authMarketingRegisterTitle => 'One account for full access';

  @override
  String get authMarketingRegisterLine1 =>
      'Manage your patient profile, history, and reminders in one hub.';

  @override
  String get authMarketingRegisterLine2 =>
      'Message doctors, share files, and rebook without friction.';

  @override
  String get authMarketingRegisterLine3 =>
      'Email verification keeps every account authentic.';

  @override
  String get authMarketingRecoveryTitle => 'Recover access securely';

  @override
  String get authMarketingRecoveryLine1 =>
      'A verification code is sent only to your email inbox.';

  @override
  String get authMarketingRecoveryLine2 =>
      'Choose a new password, then sign in to continue.';

  @override
  String get authMarketingRecoveryLine3 =>
      'Modern safeguards help keep your account protected.';

  @override
  String get authMarketingVerifyTitle => 'Verify your email';

  @override
  String get authMarketingVerifyLine1 =>
      'The code is delivered only to the address you provided.';

  @override
  String get authMarketingVerifyLine2 =>
      'Finish this step to unlock booking, chat, and the rest of Clinova.';

  @override
  String get authMarketingVerifyLine3 =>
      'One-time codes add an extra layer of account protection.';

  @override
  String get authSecurityPill =>
      'Enhanced security • Email verification enabled';

  @override
  String get authGoogleContinue => 'Continue with Google';

  @override
  String get authGoogleSkipsOtp =>
      'Google sign-in skips email code verification.';

  @override
  String get authSecurityCardTitle => 'We’re improving your security';

  @override
  String get authSecurityCardBody =>
      'For extra protection, email & password sign-in will send a 6-digit verification code to your email before you can access your account.';

  @override
  String get authTrustSecureTitle => 'Secure sign in';

  @override
  String get authTrustSecureBody => 'Your account is always protected.';

  @override
  String get authTrustEncryptedTitle => 'Encrypted data';

  @override
  String get authTrustEncryptedBody => 'We use advanced encryption.';

  @override
  String get authTrustDoctorsTitle => 'Trusted doctors';

  @override
  String get authTrustDoctorsBody => 'Care you can count on.';

  @override
  String get authRememberMe => 'Remember me';

  @override
  String get authOrDivider => 'or';

  @override
  String get authVerifyBackToLogin => 'Back to log in';

  @override
  String get authVerifyBackToRegister => 'Back to sign up';

  @override
  String get authOtpSixDigitInstruction =>
      'Enter your 6-digit verification code';

  @override
  String get authOtpExtraSecurityBadge => 'Extra security step';

  @override
  String get authOtpGoogleHint =>
      'If you sign in with Google, this verification step is skipped.';

  @override
  String get authOtpProtectionNote =>
      'For your protection, we verify email sign-ins before access is granted.';

  @override
  String authResendIn(String time) => 'Resend code in $time';

  @override
  String get authChangeEmail => 'Change email';

  @override
  String get aptLandingTitle => 'Book care in minutes';

  @override
  String get aptLandingSubtitle =>
      'Choose a department, find the right doctor, and reserve a verified appointment slot.';

  @override
  String get aptLandingStart => 'Start booking';

  @override
  String get aptLandingViewDoctors => 'View doctors';

  @override
  String get aptLandingTrustNote =>
      'Your appointment is confirmed only after slot verification.';

  @override
  String get aptLandingLoginToBook => 'Log in to book';

  @override
  String get chatLandingTitle => 'Chat with trusted doctors';

  @override
  String get chatLandingSubtitle =>
      'Ask non-emergency health questions and get guidance from verified Clinova doctors.';

  @override
  String get chatLandingStart => 'Start doctor chat';

  @override
  String get chatLandingViewOnline => 'View online doctors';

  @override
  String get chatLandingSafety =>
      'For emergencies, call emergency services or use Emergency Help. Doctor chat is not for urgent life-threatening situations.';

  @override
  String get chatLandingLoginToChat => 'Log in to chat';

  @override
  String get resetPasswordTitle => 'Choose a new password';

  @override
  String get resetPasswordNewLabel => 'New password';

  @override
  String get resetPasswordConfirmLabel => 'Confirm new password';

  @override
  String get resetPasswordSubmit => 'Update password';

  @override
  String get resetPasswordSuccess =>
      'Password updated. You can sign in with your new password.';

  @override
  String get valEmailRequired => 'Please enter your email.';

  @override
  String get valEmailInvalid => 'Enter a valid email address.';

  @override
  String get valPasswordShort => 'Password must be at least 8 characters.';

  @override
  String get authFirstName => 'First name';

  @override
  String get authLastName => 'Last name';

  @override
  String get authFormRegisterTitle => 'Register';

  @override
  String get authRegisterCheckEmailSnack =>
      'A verification code has been sent to your email.';

  @override
  String get valFullName => 'Please enter your full name.';

  @override
  String get valEmailInvalidShort => 'Enter a valid email.';

  @override
  String get valPasswordsNoMatch => 'Passwords do not match.';

  @override
  String get authAlreadyHaveAccount => 'Already have an account?';

  @override
  String get authResetAccessTitle => 'Reset access';

  @override
  String get authResetAccessSubtitle =>
      'We will email you a 6-digit code. Use it on the next screen to set a new password.';

  @override
  String get authFormForgotTitle => 'Forgot password';

  @override
  String get authSendVerificationCode => 'Send verification code';

  @override
  String get authBackToLogin => 'Back to log in';

  @override
  String get authForgotSnackGeneric =>
      'If this email is registered, we sent a 6-digit code.';

  @override
  String get authForgotRateLimitMessage =>
      'Please wait a moment before requesting another code.';

  @override
  String authForgotRetryAfterSeconds(int seconds) =>
      'Try again in ${seconds}s';

  @override
  String get authCodeSignInTitle => 'Sign in with email code';

  @override
  String get authCodeSignInSubtitle =>
      'We will send a one-time code. New emails create a patient account automatically.';

  @override
  String get authRequestCodeTitle => 'Request code';

  @override
  String get authSendCodeButton => 'Send code';

  @override
  String get authUsePassword => 'Use password instead';

  @override
  String get authCodeSentInbox => 'Code sent. Check your inbox.';

  @override
  String get authVerifyEmailTitle => 'Check your email';

  @override
  String get authVerifyEmailMissing =>
      'Request a new code from log in or registration.';

  @override
  String authVerifyEmailBody(String email) =>
      'Enter the 6-digit code we sent to $email.';

  @override
  String get authVerifyFormTitle => 'Verify code';

  @override
  String get authOtpFieldLabel => 'Verification code';

  @override
  String authDevCode(String code) => 'Dev code: $code';

  @override
  String get authVerifyContinue => 'Verify and continue';

  @override
  String get authResendCode => 'Resend code';

  @override
  String get authNewCodeSent => 'A new code was sent.';

  @override
  String get guestAuthTitle => 'Please log in to continue';

  @override
  String get guestAuthBody =>
      'Log in or create an account to use this feature.';

  @override
  String get guestAuthNotNow => 'Not now';

  @override
  String get homeGuestName => 'Guest';

  @override
  String get homeDockHome => 'Home';

  @override
  String get homeDockBook => 'Book';

  @override
  String get homeDockAi => 'AI';

  @override
  String get homeDockProfile => 'Profile';

  @override
  String get homeDockSettings => 'Settings';

  @override
  String get homeBrandLabel => 'Clinova';

  @override
  String get homeTagline => 'Care that feels fast, calm, and premium.';

  @override
  String get homeTooltipProfile => 'Profile';

  @override
  String get homeTooltipSignIn => 'Sign in';

  @override
  String get homeFilterEnt => 'ENT';

  @override
  String get homeFilterPediatrics => 'Pediatrics';

  @override
  String get homeFilterDermatology => 'Dermatology';

  @override
  String get homeFilterWomensCare => "Women's Care";

  @override
  String get homeMoveFasterTitle => 'Move faster';

  @override
  String get homeMoveFasterSubtitle => 'Everything important is one tap away.';

  @override
  String get homeCardBookVisitTitle => 'Book a visit';

  @override
  String get homeCardBookVisitSubtitle => 'Find the next open slot instantly.';

  @override
  String get homeCardAskAiTitle => 'Ask the AI';

  @override
  String get homeCardAskAiSubtitle => 'Get a department and doctor match.';

  @override
  String get homeCardLiveChatTitle => 'Live doctor chat';

  @override
  String get homeCardLiveChatSubtitle => 'Stay connected in real time.';

  @override
  String get homeCardPreferencesTitle => 'Preferences';

  @override
  String get homeCardPreferencesSubtitle => 'Language and care settings.';

  @override
  String get homeCardBranchesTitle => 'Clinic branches';

  @override
  String get homeCardBranchesSubtitle =>
      'Addresses, contacts, book at a location.';

  @override
  String get homeYourCareTitle => 'Your care snapshot';

  @override
  String get homeYourCareSubtitle =>
      'Notes from your profile, recent records, and visits.';

  @override
  String get homeMedicalNoteTitle => 'Medical history note';

  @override
  String get homeRecentRecordsTitle => 'Recent medical records';

  @override
  String get homePastVisitsTitle => 'Past visits';

  @override
  String get homeNoHealthDataYet =>
      'No health data to show yet. Complete your profile or book a visit.';

  @override
  String get homeStaffTitle => 'Our clinical team';

  @override
  String get homeStaffSubtitle =>
      'Doctors and specialists across Clinova branches.';

  @override
  String get homeStaffEmpty => 'Staff directory will appear here soon.';

  @override
  String get homeBranchesSectionTitle => 'Clinic branches';

  @override
  String get homeBranchesSectionSubtitle =>
      'Where we care for you — tap to see all locations.';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get branchesTitle => 'Clinic branches';

  @override
  String get branchesBookHere => 'Book at this branch';

  @override
  String get branchesEmpty => 'No branches are available yet.';

  @override
  String get branchesRetry => 'Try again';

  @override
  String get homeTodayTitle => 'Today at Clinova';

  @override
  String get homeTodaySubtitle =>
      'Available doctors across branches right now.';

  @override
  String get homeNoSlotsToday =>
      'No free slots found for today. Try the booking screen for another date.';

  @override
  String get homeBadgePremiumCare => 'Premium digital care';

  @override
  String homeHeroGreeting(String name) =>
      'Hi $name, your care dashboard is ready.';

  @override
  String get homeHeroSubtitle =>
      'Book, triage, and chat from one cleaner control center.';

  @override
  String get homeMetricUpcoming => 'Upcoming visits';

  @override
  String get homeMetricProfile => 'Profile ready';

  @override
  String get homeBookNow => 'Book visit';

  @override
  String get homeHeroSecondaryCta => 'AI consultation';

  @override
  String get homePremiumHeadlineAuthed =>
      'Welcome — your health dashboard is ready.';

  @override
  String get homePremiumHeadlineGuest =>
      'Premium healthcare, organised in one place.';

  @override
  String get homePremiumSubtitle =>
      'Book visits, get advice, and manage your care from a single calm hub.';

  @override
  String get homeNavHome => 'Home';

  @override
  String get homeNavServices => 'Services';

  @override
  String get homeNavDoctors => 'Doctors';

  @override
  String get homeNavAi => 'AI advisor';

  @override
  String get homeNavBook => 'Book visit';

  @override
  String get homeNavLogin => 'Sign in';

  @override
  String get homeNavProfile => 'Profile';

  @override
  String get homeAskAi => 'Ask AI';

  @override
  String homeTodayAt(String time) => 'Today at $time';

  @override
  String get homeSlotBook => 'Book';

  @override
  String get homeFallbackDoctor => 'Doctor';

  @override
  String get homeFallbackDepartment => 'General';

  @override
  String get homeFallbackBranch => 'Clinova';

  @override
  String get aptTitle => 'Appointments';

  @override
  String get aptSubtitle => 'Real-time slots from the clinic.';

  @override
  String get aptHeroTitle => 'Book a real slot';

  @override
  String get aptHeroSubtitle =>
      'We only show free slots that match the doctor schedule, breaks, and current appointments.';

  @override
  String get aptChooseBranch => 'Choose branch';

  @override
  String get aptChooseDepartment => 'Choose department';

  @override
  String get aptChooseService => 'Choose service';

  @override
  String get aptChooseDoctor => 'Choose doctor';

  @override
  String get aptTapToChoose => 'Tap to choose';

  @override
  String get aptBookingChoicesTitle => 'Booking details';

  @override
  String get aptVisitReason => 'Why are you visiting?';

  @override
  String get aptReasonHint => 'Optional short reason';

  @override
  String get aptAvailableSlots => 'Available slots';

  @override
  String get aptNoSlots =>
      'No free slots found for this doctor and date. Try another combination.';

  @override
  String get aptBranchNoServices =>
      'This branch has no bookable services yet. Choose another branch.';

  @override
  String get aptNoServicesForDept =>
      'No services for this department at the selected branch. Pick another department.';

  @override
  String get aptPendingListTitle => 'My pending appointments';

  @override
  String get aptNoPending => 'No pending appointments yet.';

  @override
  String get aptBook => 'Book';

  @override
  String get aptBooking => 'Booking...';

  @override
  String get aptBookedSuccess => 'Appointment booked successfully.';

  @override
  String get aptSelect => 'Select';

  @override
  String get aptSlotLockExpired =>
      'Slot lock expired. Please select the time again.';

  @override
  String aptPaymentIntentCreated(String mode) {
    return 'Payment intent created ($mode).';
  }

  @override
  String get aptRecommendedTimesTitle => 'AI recommended times';

  @override
  String get aptSuggestedDoctorsTitle => 'Suggested lower-queue doctors';

  @override
  String aptQueueLabel(int count) {
    return 'queue $count';
  }

  @override
  String get aptAddedToWaitlist => 'Added to waitlist for this service.';

  @override
  String get aptJoinWaitingList => 'Join waiting list';

  @override
  String get aptStepDetails => 'Details';

  @override
  String get aptStepTime => 'Time';

  @override
  String get aptStepConfirm => 'Confirm';

  @override
  String get aptConfirmBookingTitle => 'Confirm booking';

  @override
  String get aptChangeSlot => 'Change slot';

  @override
  String get aptConfirm => 'Confirm';

  @override
  String get aptDynamicIntakeTitle => 'Dynamic intake form';

  @override
  String aptDoctorLabel(String firstName, String lastName) {
    final t = '$firstName $lastName'.trim();
    if (t.isEmpty) return 'Dr.';
    return 'Dr. $t';
  }

  @override
  String get aiTitle => 'Clinova AI';

  @override
  String get aiTagline => 'Triage with a little more taste.';

  @override
  String get aiHeroLine1 =>
      'Describe symptoms once. Get the next best step quickly.';

  @override
  String get aiHeroLine2 =>
      'The experience is now structured like a guided assistant instead of a raw form.';

  @override
  String get aiSymptomPrompt => 'What are you feeling?';

  @override
  String get aiSymptomHint => 'Example: I have fever and ear pain for 2 days';

  @override
  String get aiAnalyzeNow => 'Analyze now';

  @override
  String get aiAnalyzing => 'Analyzing...';

  @override
  String get aiUseSample => 'Use sample';

  @override
  String get aiSampleSymptomText => 'I have fever and ear pain for 2 days';

  @override
  String get aiNextStepTitle => 'Recommended next step';

  @override
  String get aiNextStepEmpty =>
      'Run the symptom analysis to get a department and doctor suggestion.';

  @override
  String get aiDept => 'Department';

  @override
  String get aiDoctor => 'Doctor';

  @override
  String get aiBranch => 'Branch';

  @override
  String get aiSlot => 'Slot';

  @override
  String get aiRealtimeTitle => 'Realtime chat';

  @override
  String get aiRealtimeConnected => 'Connected';

  @override
  String get aiChatEmpty =>
      'No live messages yet. Start with a short question for your doctor.';

  @override
  String get aiChatHint => 'Send a realtime message';

  @override
  String get chatDemoDoctorName => 'Dr. Namuun';

  @override
  String get chatOnlineStatus => 'Online';

  @override
  String get chatWriteMessageHint => 'Write message…';

  @override
  String get chatSelectDoctor => 'Choose a doctor';

  @override
  String get chatNoDoctors =>
      'No doctors are listed yet. Please try again later.';

  @override
  String get chatSignInToSaveMessages =>
      'Sign in to save your chat history and message your doctor.';

  @override
  String get homeMenuTitle => 'Menu';

  @override
  String get homeDrawerAgent => 'Agent';

  @override
  String get homeDrawerAiAgentSubtitle =>
      'AI triage and care assistant in one place.';

  @override
  String get docDashboardTitle => 'Doctor dashboard';

  @override
  String docDashboardWelcome(String name) => 'Welcome back, $name';

  @override
  String get docTodayAppointmentsTitle => 'Today appointments';

  @override
  String get docUpcomingTitle => 'Upcoming';

  @override
  String get docQuickActionsTitle => 'Quick actions';

  @override
  String get docOpenChat => 'Open chat';

  @override
  String get docNoPatientsToday => 'No patients booked for today yet.';

  @override
  String get docNoUpcoming => 'No upcoming appointments found.';

  @override
  String get docHeroUpcoming => 'Upcoming';

  @override
  String get docHeroPatients => 'Patients';

  @override
  String get adminControlTitle => 'Admin control';

  @override
  String get adminDefaultName => 'Admin';

  @override
  String adminWelcome(String name) => 'Welcome back, $name';

  @override
  String get adminAddBranch => 'Add branch';

  @override
  String get adminAddService => 'Add service';

  @override
  String get adminAddDoctor => 'Add doctor';

  @override
  String get adminUsers => 'Users';

  @override
  String get adminJobApplications => 'Job applications';

  @override
  String get adminBranches => 'Branches';

  @override
  String get adminServices => 'Services';

  @override
  String get adminDoctors => 'Doctors';

  @override
  String get adminDeactivate => 'Deactivate';

  @override
  String get adminActivate => 'Activate';

  @override
  String get adminJobReviewing => 'Reviewing';

  @override
  String get adminJobInterview => 'Interview';

  @override
  String get adminJobAccepted => 'Accepted';

  @override
  String get adminJobRejected => 'Rejected';

  @override
  String get adminCreateBranchTitle => 'Create branch';

  @override
  String get adminCreateServiceTitle => 'Create service';

  @override
  String get adminCreateDoctorTitle => 'Create doctor';

  @override
  String get adminCancel => 'Cancel';

  @override
  String get adminCreate => 'Create';

  @override
  String get adminLabelName => 'Name';

  @override
  String get adminLabelCode => 'Code';

  @override
  String get adminLabelAddress => 'Address';

  @override
  String get adminLabelCity => 'City';

  @override
  String get adminLabelPhone => 'Phone';

  @override
  String get adminLabelOpeningHours => 'Opening hours';

  @override
  String get adminLabelDescription => 'Description';

  @override
  String get adminLabelPrice => 'Price';

  @override
  String get adminLabelDuration => 'Duration (minutes)';

  @override
  String get adminLabelBranch => 'Branch';

  @override
  String get adminLabelDepartment => 'Department';

  @override
  String get adminLabelPrimaryService => 'Primary service';

  @override
  String get adminLabelBio => 'Bio';

  @override
  String get adminLabelConsultationFee => 'Consultation fee';

  @override
  String get adminHeroUsers => 'Users';

  @override
  String get adminHeroDoctors => 'Doctors';

  @override
  String get adminHeroPatients => 'Patients';

  @override
  String get adminHeroToday => 'Today';

  @override
  String get adminHeroJobs => 'Jobs';

  @override
  String get adminHeroBranches => 'Branches';
}
