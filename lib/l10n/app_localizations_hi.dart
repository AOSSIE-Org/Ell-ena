// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Ell-ena';

  @override
  String get login => 'साइन इन';

  @override
  String get signUp => 'साइन अप';

  @override
  String get logout => 'लॉग आउट';

  @override
  String get logoutTitle => 'लॉग आउट करें?';

  @override
  String get logoutMessage =>
      'अपने खाते तक पहुँचने के लिए आपको दोबारा लॉग इन करना होगा।';

  @override
  String get dashboard => 'डैशबोर्ड';

  @override
  String get calendar => 'कैलेंडर';

  @override
  String get workspace => 'वर्कस्पेस';

  @override
  String get chat => 'चैट';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get tasks => 'कार्य';

  @override
  String get tickets => 'टिकट';

  @override
  String get meetings => 'मीटिंग';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get save => 'सहेजें';

  @override
  String get loading => 'लोड हो रहा है...';

  @override
  String get search => 'खोजें';

  @override
  String get language => 'भाषा';

  @override
  String languageName(String localeCode) {
    String _temp0 = intl.Intl.selectLogic(
      localeCode,
      {
        'en': 'अंग्रेज़ी',
        'hi': 'हिन्दी',
        'other': '$localeCode',
      },
    );
    return '$_temp0';
  }

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get refresh => 'रीफ़्रेश करें';

  @override
  String get switchTeam => 'टीम बदलें';

  @override
  String teamCode(String code) {
    return 'टीम कोड: $code';
  }

  @override
  String get teamFallbackName => 'टीम';

  @override
  String get myTeam => 'मेरी टीम';

  @override
  String errorSwitchingTeam(String error) {
    return 'टीम बदलने में त्रुटि: $error';
  }

  @override
  String get dashboardWelcomeBack => 'वापसी पर स्वागत है,';

  @override
  String get dashboardTodaysOverview => 'आज का अवलोकन';

  @override
  String get dashboardTotalTasks => 'कुल कार्य';

  @override
  String get dashboardInProgress => 'प्रगति में';

  @override
  String get dashboardCompleted => 'पूर्ण';

  @override
  String get dashboardOpenTickets => 'खुले टिकट';

  @override
  String get dashboardTicketsInProgress => 'प्रगति में टिकट';

  @override
  String get dashboardResolved => 'हल किए गए';

  @override
  String get dashboardTaskCompletionByDay => 'दिन के अनुसार कार्य पूर्णता';

  @override
  String get dashboardWeek => 'सप्ताह';

  @override
  String get dashboardMonth => 'महीना';

  @override
  String get dashboardNoCompletions => 'अभी तक कोई कार्य पूरा नहीं हुआ';

  @override
  String get dashboardUpcoming => 'आगामी';

  @override
  String get dashboardNothingUpcoming =>
      'आज कुछ भी देय नहीं है और जल्द कुछ भी निर्धारित नहीं है';

  @override
  String get dashboardRecentActivity => 'हाल की गतिविधि';

  @override
  String get dashboardNoRecentActivity => 'कोई हाल की गतिविधि नहीं';

  @override
  String get dashboardTask => 'कार्य';

  @override
  String get dashboardTicket => 'टिकट';

  @override
  String get dashboardMeeting => 'मीटिंग';

  @override
  String dashboardStatus(String status) {
    return 'स्थिति: $status';
  }

  @override
  String get newTask => 'नया कार्य';

  @override
  String get newTicket => 'नया टिकट';

  @override
  String get newMeeting => 'नई मीटिंग';

  @override
  String get authWelcomeBack => 'वापसी पर स्वागत है';

  @override
  String get authSignInSubtitle =>
      'Ell-ena के साथ जारी रखने के लिए साइन इन करें';

  @override
  String get authEmailLabel => 'ईमेल';

  @override
  String get authPasswordLabel => 'पासवर्ड';

  @override
  String get authEnterEmail => 'कृपया अपना ईमेल दर्ज करें';

  @override
  String get authEnterValidEmail => 'कृपया मान्य ईमेल दर्ज करें';

  @override
  String get authEnterPassword => 'कृपया अपना पासवर्ड दर्ज करें';

  @override
  String get authPasswordTooShort => 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए';

  @override
  String get authForgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get authOr => 'या';

  @override
  String get authSignInWithGoogle => 'Google से साइन इन करें';

  @override
  String get authNoAccount => 'खाता नहीं है? ';

  @override
  String get authLoginFailed => 'लॉगिन विफल रहा। कृपया फिर से प्रयास करें।';

  @override
  String get authInvalidCredentials => 'ईमेल या पासवर्ड गलत है';

  @override
  String get authConnectionError =>
      'कनेक्शन में त्रुटि। कृपया फिर से प्रयास करें।';

  @override
  String get authGoogleSignInFailed => 'Google साइन-इन विफल रहा';

  @override
  String authErrorWithDetails(String error) {
    return 'त्रुटि: $error';
  }

  @override
  String get authVerificationEmailSent =>
      'सत्यापन ईमेल भेज दिया गया है। कृपया अपना इनबॉक्स देखें।';

  @override
  String get authTeamIdNotFound =>
      'टीम ID नहीं मिली। कृपया जाँचें और फिर से प्रयास करें।';

  @override
  String get authTeamIdLabel => 'टीम ID';

  @override
  String get authEnterTeamId => 'कृपया टीम ID दर्ज करें';

  @override
  String get authTeamIdLength => 'टीम ID 6 अक्षरों की होनी चाहिए';

  @override
  String get authFullNameLabel => 'पूरा नाम';

  @override
  String get authEnterName => 'कृपया अपना नाम दर्ज करें';

  @override
  String get authConfirmPasswordLabel => 'पासवर्ड की पुष्टि करें';

  @override
  String get authConfirmPasswordPrompt => 'कृपया अपने पासवर्ड की पुष्टि करें';

  @override
  String get authPasswordsDoNotMatch => 'पासवर्ड मेल नहीं खाते';

  @override
  String get authTeamNameLabel => 'टीम का नाम';

  @override
  String get authEnterTeamName => 'कृपया टीम का नाम दर्ज करें';

  @override
  String get authAdminNameLabel => 'एडमिन का नाम';

  @override
  String get authEnterAdminName => 'कृपया एडमिन का नाम दर्ज करें';

  @override
  String get authAdminEmailLabel => 'एडमिन ईमेल';

  @override
  String get authEnterAdminEmail => 'कृपया एडमिन ईमेल दर्ज करें';

  @override
  String get authCreateAccount => 'खाता बनाएँ';

  @override
  String get authSignUpSubtitle => 'शुरू करने के लिए Ell-ena से जुड़ें';

  @override
  String get authJoinTheTeamTab => 'टीम से जुड़ें';

  @override
  String get authCreateTheTeamTab => 'टीम बनाएँ';

  @override
  String get authJoinTeam => 'टीम से जुड़ें';

  @override
  String get authCreateTeam => 'टीम बनाएँ';

  @override
  String get authSignUpWithGoogle => 'Google से साइन अप करें';

  @override
  String get authAlreadyHaveAccount => 'पहले से खाता है? साइन इन करें';

  @override
  String get authResetCodeSent => 'रीसेट कोड आपके ईमेल पर भेज दिया गया है';

  @override
  String get authGenericError => 'एक त्रुटि हुई। कृपया फिर से प्रयास करें।';

  @override
  String get authInvalidEmailAddress => 'अमान्य ईमेल पता';

  @override
  String get authEmailNotFound => 'ईमेल पता नहीं मिला';

  @override
  String get authTooManyAttempts =>
      'बहुत अधिक प्रयास। कृपया बाद में फिर से प्रयास करें।';

  @override
  String get authResetPasswordTitle => 'पासवर्ड रीसेट करें';

  @override
  String get authResetPasswordSubtitle =>
      'रीसेट कोड पाने के लिए अपना ईमेल दर्ज करें';

  @override
  String get authSendResetCode => 'रीसेट कोड भेजें';

  @override
  String get authBackToLogin => 'लॉगिन पर वापस जाएँ';

  @override
  String get authPasswordUpdated => 'पासवर्ड सफलतापूर्वक अपडेट हो गया';

  @override
  String get authPasswordUpdateFailed => 'पासवर्ड अपडेट नहीं हो सका';

  @override
  String get authSetNewPasswordTitle => 'नया पासवर्ड सेट करें';

  @override
  String get authSetNewPasswordSubtitle => 'अपने खाते के लिए नया पासवर्ड बनाएँ';

  @override
  String get authNewPasswordLabel => 'नया पासवर्ड';

  @override
  String get authEnterNewPassword => 'कृपया पासवर्ड दर्ज करें';

  @override
  String get authUpdatePassword => 'पासवर्ड अपडेट करें';

  @override
  String get authVerificationFailed => 'सत्यापन विफल रहा';

  @override
  String get authCodeExpiredOrInvalid =>
      'सत्यापन कोड की समय-सीमा समाप्त हो गई है या वह अमान्य है। कृपया नया कोड मँगाएँ।';

  @override
  String get authInvalidCode => 'अमान्य सत्यापन कोड। कृपया फिर से प्रयास करें।';

  @override
  String get authCodeExpired =>
      'सत्यापन कोड की समय-सीमा समाप्त हो गई है। कृपया नया कोड मँगाएँ।';

  @override
  String get authCodeResent =>
      'सत्यापन कोड फिर से भेज दिया गया है। कृपया अपना इनबॉक्स और स्पैम फ़ोल्डर देखें।';

  @override
  String get authResendFailed => 'कोड दोबारा नहीं भेजा जा सका';

  @override
  String get authEmailNotFoundOrInvalid => 'ईमेल पता नहीं मिला या अमान्य है।';

  @override
  String get authUnableToResend =>
      'कोड दोबारा नहीं भेजा जा सका। कृपया वापस जाएँ और फिर से प्रयास करें।';

  @override
  String get authTeamCreatedTitle => 'टीम सफलतापूर्वक बन गई!';

  @override
  String get authYourTeamIdIs => 'आपकी टीम ID है:';

  @override
  String get authCopyTeamId => 'टीम ID कॉपी करें';

  @override
  String get authTeamIdCopied => 'टीम ID क्लिपबोर्ड पर कॉपी हो गई';

  @override
  String get authShareTeamId =>
      'यह ID अपनी टीम के सदस्यों के साथ साझा करें ताकि वे आपकी टीम से जुड़ सकें।';

  @override
  String get authContinue => 'जारी रखें';

  @override
  String get authVerifyEmailTitle => 'ईमेल सत्यापित करें';

  @override
  String authVerifyEmailSubtitle(String email) {
    return '$email पर भेजा गया 6 अंकों का कोड दर्ज करें';
  }

  @override
  String authResendCodeIn(String countdown) {
    return '$countdown में कोड फिर से भेजें';
  }

  @override
  String get authCheckSpamFolder =>
      'अगर ईमेल नहीं दिख रहा है, तो अपना\n स्पैम/जंक फ़ोल्डर देखें।';

  @override
  String get authVerifyCode => 'कोड सत्यापित करें';

  @override
  String get authDidNotReceiveCode => 'कोड नहीं मिला? ';

  @override
  String get authResend => 'फिर से भेजें';

  @override
  String get authFailedToJoinTeam => 'टीम से जुड़ नहीं सके';

  @override
  String get authFailedToCreateTeam => 'टीम नहीं बन सकी';

  @override
  String get authCompleteSetup => 'अपना सेटअप पूरा करें';

  @override
  String get authChooseHowToProceed => 'चुनें कि आप कैसे आगे बढ़ना चाहते हैं:';

  @override
  String get authYourNameLabel => 'आपका नाम';

  @override
  String get authTeamCodeLabel => 'टीम कोड';

  @override
  String get authEnterTeamCode => 'कृपया टीम कोड दर्ज करें';

  @override
  String get onboardingTaskManagementTitle => 'ऑल-इन-वन टास्क मैनेजमेंट';

  @override
  String get onboardingTaskManagementDescription =>
      'टिकट और टू-डू बनाएँ, और मीटिंग ट्रांसक्राइब करें—सब एक ही जगह।';

  @override
  String get onboardingAssistantTitle => 'AI-संचालित असिस्टेंट';

  @override
  String get onboardingAssistantDescription =>
      'बस Ell-ena से चैट करें और भारी काम AI पर छोड़ दें।';

  @override
  String get onboardingContextTitle => 'स्मार्ट कॉन्टेक्स्ट';

  @override
  String get onboardingContextDescription =>
      'AI-संचालित संदर्भ जागरूकता के साथ और भी स्मार्ट बनें।';

  @override
  String get onboardingGetStarted => 'शुरू करें';

  @override
  String get onboardingNext => 'आगे';

  @override
  String get onboardingSkip => 'छोड़ें';

  @override
  String meetingErrorDeleting(String error) {
    return 'मीटिंग हटाने में त्रुटि: $error';
  }

  @override
  String get meetingCouldNotLaunchUrl => 'मीटिंग URL नहीं खोला जा सका';

  @override
  String meetingErrorLaunchingUrl(String error) {
    return 'URL खोलने में त्रुटि: $error';
  }

  @override
  String get meetingUpcoming => 'आगामी';

  @override
  String get meetingPast => 'पिछली';

  @override
  String get meetingNoUpcoming => 'कोई आगामी मीटिंग नहीं';

  @override
  String get meetingNoPast => 'कोई पिछली मीटिंग नहीं';

  @override
  String get meetingEmptyUpcomingHint => 'शुरू करने के लिए नई मीटिंग बनाएं';

  @override
  String get meetingEmptyPastHint => 'पिछली मीटिंग यहां दिखाई देंगी';

  @override
  String get meetingToday => 'आज';

  @override
  String get meetingTomorrow => 'कल';

  @override
  String get meetingYesterday => 'कल';

  @override
  String meetingDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन पहले',
      one: '1 दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String get meetingUntitled => 'बिना शीर्षक की मीटिंग';

  @override
  String get meetingUnknownUser => 'अज्ञात';

  @override
  String get meetingCancelMeetingTooltip => 'मीटिंग रद्द करें';

  @override
  String meetingDurationMin(String minutes) {
    return '$minutes मिनट';
  }

  @override
  String meetingCreatedBy(String name) {
    return '$name द्वारा बनाई गई';
  }

  @override
  String get meetingJoin => 'जुड़ें';

  @override
  String get meetingTranscription => 'ट्रांसक्रिप्शन';

  @override
  String get meetingAiSummary => 'AI सारांश';

  @override
  String get meetingSelectDateTimeFirst => 'कृपया पहले तारीख और समय चुनें';

  @override
  String get meetingTimeMustBeFuture => 'मीटिंग का समय भविष्य में होना चाहिए';

  @override
  String get meetingMeetLinkCreated => 'Google Meet लिंक सफलतापूर्वक बनाया गया';

  @override
  String get meetingMeetLinkFailed =>
      'Google Meet लिंक बनाने में विफल। कृपया Google से साइन इन करें।';

  @override
  String get meetingRetry => 'फिर से कोशिश करें';

  @override
  String get meetingSelectDatePrompt => 'कृपया तारीख चुनें';

  @override
  String get meetingSelectTimePrompt => 'कृपया समय चुनें';

  @override
  String get meetingOnlyGoogleMeetSupported =>
      'ट्रांसक्रिप्शन के लिए केवल Google Meet URL समर्थित हैं';

  @override
  String meetingFailedToCreate(String error) {
    return 'मीटिंग बनाने में विफल: $error';
  }

  @override
  String meetingErrorCreating(String error) {
    return 'मीटिंग बनाने में त्रुटि: $error';
  }

  @override
  String get meetingCreateTitle => 'मीटिंग बनाएं';

  @override
  String get meetingTitleRequiredLabel => 'शीर्षक *';

  @override
  String get meetingEnterTitle => 'कृपया शीर्षक दर्ज करें';

  @override
  String get meetingDescription => 'विवरण';

  @override
  String get meetingSelectDateRequired => 'तारीख चुनें *';

  @override
  String get meetingSelectTimeRequired => 'समय चुनें *';

  @override
  String get meetingDurationMinutesLabel => 'अवधि (मिनट)';

  @override
  String get meetingDurationPositive => 'अवधि 0 से अधिक होनी चाहिए';

  @override
  String get meetingEnterValidNumber => 'कृपया एक मान्य संख्या दर्ज करें';

  @override
  String get meetingGoogleMeetUrl => 'Google Meet URL';

  @override
  String get meetingCreatingMeetLink => 'Meet लिंक बनाया जा रहा है...';

  @override
  String get meetingCreateMeetLink => 'Google Meet लिंक बनाएं';

  @override
  String get meetingTranscriptionGoogleMeetOnly =>
      'Ellena AI ट्रांसक्रिप्शन केवल Google Meet URL के साथ काम करता है';

  @override
  String get meetingNotFound => 'मीटिंग नहीं मिली';

  @override
  String meetingErrorLoadingDetails(String error) {
    return 'मीटिंग विवरण लोड करने में त्रुटि: $error';
  }

  @override
  String get meetingTitleEmpty => 'शीर्षक खाली नहीं हो सकता';

  @override
  String get meetingSelectDateTime => 'कृपया तारीख और समय चुनें';

  @override
  String meetingErrorUpdating(String error) {
    return 'मीटिंग अपडेट करने में त्रुटि: $error';
  }

  @override
  String get meetingTicketCreated => 'टिकट बनाया गया';

  @override
  String meetingFailedToCreateTicket(String error) {
    return 'टिकट बनाने में विफल: $error';
  }

  @override
  String meetingErrorGeneric(String error) {
    return 'त्रुटि: $error';
  }

  @override
  String get meetingTaskCreated => 'टास्क बनाया गया';

  @override
  String meetingFailedToCreateTask(String error) {
    return 'टास्क बनाने में विफल: $error';
  }

  @override
  String get meetingUrlCopied => 'मीटिंग URL क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get meetingEditTitle => 'मीटिंग संपादित करें';

  @override
  String get meetingDetailsTitle => 'मीटिंग विवरण';

  @override
  String get meetingSaveChanges => 'बदलाव सेव करें';

  @override
  String get meetingDeleteTitle => 'मीटिंग हटाएं';

  @override
  String get meetingStatusNotStarted => 'शुरू नहीं हुआ';

  @override
  String get meetingStatusCompleted => 'पूरा हुआ';

  @override
  String get meetingStatusAttempted => 'प्रयास किया गया';

  @override
  String get meetingStatusInProgress => 'जारी है';

  @override
  String get meetingStatusPending => 'लंबित';

  @override
  String get meetingStatusNotAvailable => 'उपलब्ध नहीं';

  @override
  String get meetingBadgeUpcoming => 'आगामी';

  @override
  String get meetingBadgePast => 'पिछली';

  @override
  String get meetingDate => 'तारीख';

  @override
  String get meetingTime => 'समय';

  @override
  String get meetingDuration => 'अवधि';

  @override
  String meetingDurationMinutes(String minutes) {
    return '$minutes मिनट';
  }

  @override
  String get meetingUrl => 'मीटिंग URL';

  @override
  String get meetingCopyUrl => 'URL कॉपी करें';

  @override
  String get meetingOpenUrl => 'URL खोलें';

  @override
  String meetingTranscriptionStatus(String status) {
    return 'ट्रांसक्रिप्शन: $status';
  }

  @override
  String get meetingJoinMeeting => 'मीटिंग में जुड़ें';

  @override
  String get meetingTitleLabel => 'शीर्षक';

  @override
  String get meetingSelectDate => 'तारीख चुनें';

  @override
  String get meetingSelectTime => 'समय चुनें';

  @override
  String get meetingAiSummaryNotAvailable => 'AI सारांश अभी उपलब्ध नहीं है।';

  @override
  String get meetingActionItemFallback => 'एक्शन आइटम';

  @override
  String meetingOwnerDeadline(String owner, String deadline) {
    return 'ज़िम्मेदार: $owner   •   समय-सीमा: $deadline';
  }

  @override
  String get meetingNotApplicable => 'लागू नहीं';

  @override
  String get meetingManageDiscussion => 'महत्वपूर्ण चर्चा प्रबंधित करें';

  @override
  String get meetingNoActionItems => 'कोई एक्शन आइटम नहीं मिला';

  @override
  String get meetingManageTasks => 'टास्क प्रबंधित करें';

  @override
  String get meetingNoFollowUps => 'कोई फॉलो-अप टास्क नहीं मिला';

  @override
  String get meetingFollowUpTaskFallback => 'फॉलो-अप टास्क';

  @override
  String meetingDeadline(String deadline) {
    return 'समय-सीमा: $deadline';
  }

  @override
  String get meetingDeleteConfirm =>
      'क्या आप वाकई इस मीटिंग को हटाना चाहते हैं? यह कार्रवाई पूर्ववत नहीं की जा सकती।';

  @override
  String get meetingDelete => 'हटाएं';

  @override
  String meetingFailedToLoad(String error) {
    return 'मीटिंग लोड करने में विफल: $error';
  }

  @override
  String get meetingInsightsTitle => 'मीटिंग इनसाइट्स';

  @override
  String get meetingDownloadPdf => 'PDF डाउनलोड करें';

  @override
  String meetingSavedTo(String path) {
    return '$path में सेव किया गया';
  }

  @override
  String meetingPdfError(String error) {
    return 'PDF त्रुटि: $error';
  }

  @override
  String get meetingNoTranscription => 'कोई ट्रांसक्रिप्शन उपलब्ध नहीं';

  @override
  String get meetingSpeaker => 'वक्ता';

  @override
  String get meetingNoAiSummary => 'अभी तक कोई AI सारांश नहीं बना';

  @override
  String get meetingKeyDiscussionPoints => 'मुख्य चर्चा बिंदु';

  @override
  String get meetingImportantDecisions => 'महत्वपूर्ण निर्णय';

  @override
  String get meetingActionItems => 'एक्शन आइटम';

  @override
  String get meetingHighlights => 'मीटिंग की मुख्य बातें';

  @override
  String get meetingFollowUpTasks => 'फॉलो-अप टास्क';

  @override
  String get meetingOverallSummary => 'समग्र सारांश';

  @override
  String get chatListening => 'सुन रहे हैं...';

  @override
  String get chatTapToCancel => 'रद्द करने के लिए कहीं भी टैप करें';

  @override
  String get chatCouldNotOpenItemDetails =>
      'यह आइटम नहीं खुल सका। विवरण उपलब्ध नहीं है।';

  @override
  String get chatCouldNotOpenItem => 'यह आइटम नहीं खुल सका।';

  @override
  String get chatCouldNotNavigate =>
      'आइटम पर नहीं जा सके। विवरण उपलब्ध नहीं है।';

  @override
  String chatNavigationError(String error) {
    return 'नेविगेशन त्रुटि: $error';
  }

  @override
  String get chatSpeechNotAvailable => 'इस डिवाइस पर वॉइस पहचान उपलब्ध नहीं है';

  @override
  String get chatTitle => 'Ell-ena से चैट करें';

  @override
  String get chatSubtitle => 'आपका AI असिस्टेंट';

  @override
  String get chatContext => 'संदर्भ';

  @override
  String get chatEmptyState => 'Ell-ena के साथ बातचीत शुरू करें';

  @override
  String get chatInputHint => 'अपना संदेश लिखें...';

  @override
  String get chatVoiceInputTooltip => 'वॉइस इनपुट';

  @override
  String get chatStopListeningTooltip => 'सुनना बंद करें';

  @override
  String get chatSendTooltip => 'संदेश भेजें';

  @override
  String get chatItemCreated => 'आइटम बनाया गया';

  @override
  String get chatCreatedJustNow => 'अभी बनाया गया';

  @override
  String get chatViewTask => 'टास्क देखें';

  @override
  String get chatViewTicket => 'टिकट देखें';

  @override
  String get chatViewMeeting => 'मीटिंग देखें';

  @override
  String get chatViewItem => 'आइटम देखें';

  @override
  String get chatContextLoadError => 'संदर्भ लोड नहीं हो सका';

  @override
  String get chatContextTryAgain => 'अपना संदेश फिर से भेजकर देखें।';

  @override
  String get chatContextEmptyTitle => 'अभी कोई संदर्भ नहीं';

  @override
  String get chatContextEmptyMessage =>
      'संबंधित टास्क, टिकट और मीटिंग खोजने के लिए एक संदेश भेजें।';

  @override
  String get chatContextNoMatchesTitle => 'कोई मिलान नहीं मिला';

  @override
  String get chatContextNoMatchesMessage =>
      'आपके वर्कस्पेस में कुछ भी इस संदेश से पर्याप्त रूप से मेल नहीं खाता।';

  @override
  String chatResultDue(String date) {
    return 'नियत तिथि $date';
  }

  @override
  String get calendarUntitledTask => 'बिना शीर्षक का टास्क';

  @override
  String get calendarUntitledTicket => 'बिना शीर्षक का टिकट';

  @override
  String get calendarUntitledMeeting => 'बिना शीर्षक की मीटिंग';

  @override
  String calendarCreateAt(String time) {
    return '$time पर बनाएं';
  }

  @override
  String get calendarScheduleMeeting => 'मीटिंग शेड्यूल करें';

  @override
  String get calendarCreateTask => 'टास्क बनाएं';

  @override
  String get calendarCreateTicket => 'टिकट बनाएं';

  @override
  String get calendarCreateWithAi => 'Ell-ena AI के साथ बनाएं';

  @override
  String profileFailedToLoad(String error) {
    return 'प्रोफ़ाइल लोड करने में विफल: $error';
  }

  @override
  String get profileUserFallback => 'उपयोगकर्ता';

  @override
  String get profileTeamAdmin => 'टीम एडमिन';

  @override
  String get profileTeamMember => 'टीम सदस्य';

  @override
  String get profileYourTeam => 'आपकी टीम';

  @override
  String get profileAdminBadge => 'एडमिन';

  @override
  String get profileMemberBadge => 'सदस्य';

  @override
  String get profileTeamSwitched => 'टीम सफलतापूर्वक बदली गई';

  @override
  String get profileTeamInformation => 'टीम की जानकारी';

  @override
  String get profileTeamName => 'टीम का नाम';

  @override
  String get profileTeamId => 'टीम ID';

  @override
  String get profileYourActivity => 'आपकी गतिविधि';

  @override
  String get profileStatTasksCompleted => 'पूरे किए\nटास्क';

  @override
  String get profileStatHoursLogged => 'दर्ज किए\nघंटे';

  @override
  String get profileStatTeamProjects => 'टीम\nप्रोजेक्ट';

  @override
  String get profileEditProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get profileEditProfileSubtitle => 'अपनी व्यक्तिगत जानकारी अपडेट करें';

  @override
  String get profileNotifications => 'सूचनाएं';

  @override
  String get profileNotificationsSubtitle =>
      'अपनी सूचना प्राथमिकताएं प्रबंधित करें';

  @override
  String get profileSecurity => 'सुरक्षा';

  @override
  String get profileSecuritySubtitle => 'सुरक्षा सेटिंग्स कॉन्फ़िगर करें';

  @override
  String get profileSwitchTeamSubtitle => 'दूसरी टीम पर जाएं';

  @override
  String get profileTeamMembers => 'टीम सदस्य';

  @override
  String get profileTeamMembersSubtitle =>
      'अपनी टीम के सदस्यों को प्रबंधित करें';

  @override
  String get profileThemeLight => 'लाइट';

  @override
  String get profileThemeDark => 'डार्क';

  @override
  String get profileThemeSystem => 'सिस्टम';

  @override
  String get profilePreferences => 'प्राथमिकताएं';

  @override
  String get profilePushNotifications => 'पुश सूचनाएं';

  @override
  String get profileTheme => 'थीम';

  @override
  String get profileUpdated => 'प्रोफ़ाइल सफलतापूर्वक अपडेट हुई';

  @override
  String get profileUpdateFailed => 'प्रोफ़ाइल अपडेट करने में विफल';

  @override
  String profileUpdateError(String error) {
    return 'प्रोफ़ाइल अपडेट करने में त्रुटि: $error';
  }

  @override
  String get profilePersonalInformation => 'व्यक्तिगत जानकारी';

  @override
  String get profileFirstName => 'पहला नाम';

  @override
  String get profileFirstNameRequired => 'कृपया अपना पहला नाम दर्ज करें';

  @override
  String get profileLastName => 'उपनाम';

  @override
  String get profileEmail => 'ईमेल';

  @override
  String get profileEmailCannotChange => 'ईमेल बदला नहीं जा सकता';

  @override
  String get profileRole => 'भूमिका';

  @override
  String get profileAdminPrivileges => 'आपके पास एडमिन अधिकार हैं';

  @override
  String get profileStandardAccess => 'सामान्य टीम सदस्य एक्सेस';

  @override
  String profileErrorLoadingMembers(String error) {
    return 'टीम सदस्यों को लोड करने में त्रुटि: $error';
  }

  @override
  String profileTeamMembersTitle(String teamName) {
    return '$teamName के सदस्य';
  }

  @override
  String get profileNoMembersFound => 'कोई टीम सदस्य नहीं मिला';

  @override
  String get profileNoMembersYet => 'आपकी टीम में अभी कोई सदस्य नहीं है';

  @override
  String get profileUnknownMember => 'अज्ञात';

  @override
  String get profileRoleAdmin => 'एडमिन';

  @override
  String get profileRoleMember => 'सदस्य';

  @override
  String get workspaceTaskCreated => 'टास्क सफलतापूर्वक बनाया गया';

  @override
  String get workspaceTicketCreated => 'टिकट सफलतापूर्वक बनाया गया';

  @override
  String get workspaceMeetingCreated => 'मीटिंग सफलतापूर्वक बनाई गई';

  @override
  String commonErrorLoggingOut(String error) {
    return 'लॉग आउट करने में त्रुटि: $error';
  }

  @override
  String taskErrorUpdatingStatus(String error) {
    return 'कार्य की स्थिति अपडेट करने में त्रुटि: $error';
  }

  @override
  String taskErrorUpdatingApproval(String error) {
    return 'कार्य की स्वीकृति अपडेट करने में त्रुटि: $error';
  }

  @override
  String get taskCreatedSuccess => 'कार्य सफलतापूर्वक बनाया गया';

  @override
  String get taskNoTasksFound => 'कोई कार्य नहीं मिला';

  @override
  String get taskEmptyTodo => 'शुरू करने के लिए नए कार्य जोड़ें';

  @override
  String get taskEmptyInProgress =>
      'जब आप कार्यों पर काम शुरू करें, तो उन्हें यहाँ ले आएं';

  @override
  String get taskEmptyCompleted => 'पूरे हुए कार्य यहाँ दिखाई देंगे';

  @override
  String get taskStatusTodo => 'करने हैं';

  @override
  String get taskStatusInProgress => 'प्रगति में';

  @override
  String get taskStatusCompleted => 'पूर्ण';

  @override
  String taskViewStatusTasks(String status) {
    return '$status कार्य देखें';
  }

  @override
  String get taskDeleteTitle => 'कार्य हटाएं';

  @override
  String get taskDeleteConfirmMessage =>
      'क्या आप वाकई इस कार्य को हटाना चाहते हैं? यह कार्रवाई पूर्ववत नहीं की जा सकती।';

  @override
  String get taskDelete => 'हटाएं';

  @override
  String get taskDeletedSuccess => 'कार्य सफलतापूर्वक हटाया गया';

  @override
  String get taskDeleteFailed => 'कार्य हटाने में विफल';

  @override
  String taskErrorGeneric(String error) {
    return 'त्रुटि: $error';
  }

  @override
  String get taskUntitled => 'बिना शीर्षक का कार्य';

  @override
  String get taskNoDescription => 'कोई विवरण नहीं';

  @override
  String get taskYou => 'आप';

  @override
  String get taskUnknown => 'अज्ञात';

  @override
  String get taskUnassigned => 'असाइन नहीं किया गया';

  @override
  String get taskNoDueDate => 'कोई नियत तिथि नहीं';

  @override
  String get taskApprove => 'स्वीकृत करें';

  @override
  String get taskReject => 'अस्वीकार करें';

  @override
  String taskCreatedBy(String name) {
    return '$name द्वारा बनाया गया';
  }

  @override
  String taskAssignedTo(String name) {
    return '$name को असाइन किया गया';
  }

  @override
  String get taskDragToChangeStatus => 'स्थिति बदलने के लिए खींचें';

  @override
  String get taskTableTask => 'कार्य';

  @override
  String get taskTableApproval => 'स्वीकृति';

  @override
  String get taskTableCreatedBy => 'बनाने वाले';

  @override
  String get taskTableAssignedTo => 'असाइन किया गया';

  @override
  String get taskTableDueDate => 'नियत तिथि';

  @override
  String get taskLinkedTicketUpdateFailed =>
      'लिंक किया गया टिकट अपडेट करने में विफल';

  @override
  String taskStatusUpdatedTo(String status) {
    return 'कार्य की स्थिति $status में अपडेट की गई';
  }

  @override
  String get taskStatusUpdateFailed => 'कार्य की स्थिति अपडेट करने में विफल';

  @override
  String get taskApprovedMessage => 'कार्य स्वीकृत किया गया';

  @override
  String get taskRejectedMessage => 'कार्य अस्वीकार किया गया';

  @override
  String taskErrorDeleting(String error) {
    return 'कार्य हटाने में त्रुटि: $error';
  }

  @override
  String taskErrorAddingComment(String error) {
    return 'टिप्पणी जोड़ने में त्रुटि: $error';
  }

  @override
  String get taskDetailsTitle => 'कार्य विवरण';

  @override
  String get taskNotFound => 'कार्य नहीं मिला';

  @override
  String get taskMayHaveBeenDeleted => 'हो सकता है कि कार्य हटा दिया गया हो';

  @override
  String taskDueLabel(String date) {
    return 'नियत तिथि: $date';
  }

  @override
  String get taskLinkedTicket => 'लिंक किया गया टिकट';

  @override
  String get taskNoLinkedTicket => 'कोई लिंक किया गया टिकट नहीं';

  @override
  String get taskActions => 'कार्रवाइयाँ';

  @override
  String get taskStart => 'शुरू करें';

  @override
  String get taskComplete => 'पूरा करें';

  @override
  String taskCommentsCount(int count) {
    return 'टिप्पणियाँ ($count)';
  }

  @override
  String get taskLatestFirst => 'नवीनतम पहले';

  @override
  String get taskNoCommentsYet => 'अभी तक कोई टिप्पणी नहीं';

  @override
  String get taskBeFirstToComment => 'सबसे पहले टिप्पणी करें';

  @override
  String taskDaysAgo(int count) {
    return '$count दिन पहले';
  }

  @override
  String taskHoursAgo(int count) {
    return '$count घंटे पहले';
  }

  @override
  String taskMinutesAgo(int count) {
    return '$count मिनट पहले';
  }

  @override
  String get taskJustNow => 'अभी-अभी';

  @override
  String get taskAddCommentHint => 'टिप्पणी जोड़ें...';

  @override
  String get taskSendComment => 'टिप्पणी भेजें';

  @override
  String taskErrorCreating(String error) {
    return 'कार्य बनाने में त्रुटि: $error';
  }

  @override
  String get taskCreateNewTitle => 'नया कार्य बनाएं';

  @override
  String get taskTitleLabel => 'कार्य का शीर्षक';

  @override
  String get taskTitleHint => 'कार्य का शीर्षक दर्ज करें';

  @override
  String get taskTitleRequired => 'कृपया कार्य का शीर्षक दर्ज करें';

  @override
  String get taskDescriptionLabel => 'विवरण';

  @override
  String get taskDescriptionHint => 'कार्य का विवरण दर्ज करें';

  @override
  String get taskDueDateLabel => 'नियत तिथि';

  @override
  String get taskSelectDueDate => 'नियत तिथि चुनें';

  @override
  String get taskAssignToLabel => 'असाइन करें';

  @override
  String get taskSelectTeamMember => 'टीम सदस्य चुनें';

  @override
  String get taskAdminBadge => 'एडमिन';

  @override
  String get taskCreateButton => 'कार्य बनाएं';

  @override
  String ticketErrorUpdatingStatus(String error) {
    return 'टिकट की स्थिति अपडेट करने में त्रुटि: $error';
  }

  @override
  String ticketErrorUpdatingApproval(String error) {
    return 'टिकट की स्वीकृति अपडेट करने में त्रुटि: $error';
  }

  @override
  String get ticketCreatedSuccess => 'टिकट सफलतापूर्वक बनाया गया';

  @override
  String get ticketStatusOpen => 'खुला';

  @override
  String get ticketStatusInProgress => 'प्रगति में';

  @override
  String get ticketStatusResolved => 'हल किया गया';

  @override
  String get ticketNoTicketsFound => 'कोई टिकट नहीं मिला';

  @override
  String get ticketEmptyOpen => 'शुरू करने के लिए नए टिकट बनाएं';

  @override
  String get ticketEmptyInProgress =>
      'जब आप टिकट पर काम शुरू करें तो उन्हें यहां ले आएं';

  @override
  String get ticketEmptyResolved => 'हल किए गए टिकट यहां दिखाई देंगे';

  @override
  String ticketViewStatusTickets(String status) {
    return '$status टिकट देखें';
  }

  @override
  String get ticketDeleteTitle => 'टिकट हटाएं';

  @override
  String get ticketDeleteConfirm =>
      'क्या आप वाकई इस टिकट को हटाना चाहते हैं? इस कार्रवाई को पूर्ववत नहीं किया जा सकता।';

  @override
  String get ticketDelete => 'हटाएं';

  @override
  String get ticketDeletedSuccess => 'टिकट सफलतापूर्वक हटाया गया';

  @override
  String get ticketDeleteFailed => 'टिकट हटाने में विफल';

  @override
  String ticketErrorGeneric(String error) {
    return 'त्रुटि: $error';
  }

  @override
  String get ticketUntitled => 'बिना शीर्षक का टिकट';

  @override
  String get ticketNoDescription => 'कोई विवरण नहीं';

  @override
  String get ticketYou => 'आप';

  @override
  String get ticketUnknown => 'अज्ञात';

  @override
  String get ticketApprove => 'स्वीकृत करें';

  @override
  String get ticketReject => 'अस्वीकार करें';

  @override
  String ticketCreatedByName(String name) {
    return '$name द्वारा बनाया गया';
  }

  @override
  String get ticketDragToChangeStatus => 'स्थिति बदलने के लिए खींचें';

  @override
  String get ticketPriority => 'प्राथमिकता';

  @override
  String get ticketTicket => 'टिकट';

  @override
  String get ticketTitle => 'शीर्षक';

  @override
  String get ticketCategory => 'श्रेणी';

  @override
  String get ticketApproval => 'स्वीकृति';

  @override
  String get ticketCreatedByLabel => 'द्वारा बनाया गया';

  @override
  String get ticketCreated => 'बनाया गया';

  @override
  String get ticketLoadDetailsFailed => 'टिकट का विवरण लोड करने में विफल';

  @override
  String ticketErrorLoadingDetails(String error) {
    return 'टिकट का विवरण लोड करने में त्रुटि: $error';
  }

  @override
  String ticketErrorDeleting(String error) {
    return 'टिकट हटाने में त्रुटि: $error';
  }

  @override
  String ticketAddCommentFailed(String error) {
    return 'टिप्पणी जोड़ने में विफल: $error';
  }

  @override
  String ticketErrorAddingComment(String error) {
    return 'टिप्पणी जोड़ने में त्रुटि: $error';
  }

  @override
  String get ticketStatusUpdated => 'टिकट की स्थिति सफलतापूर्वक अपडेट की गई';

  @override
  String ticketUpdateStatusFailed(String error) {
    return 'टिकट की स्थिति अपडेट करने में विफल: $error';
  }

  @override
  String get ticketPriorityUpdated =>
      'टिकट की प्राथमिकता सफलतापूर्वक अपडेट की गई';

  @override
  String ticketUpdatePriorityFailed(String error) {
    return 'टिकट की प्राथमिकता अपडेट करने में विफल: $error';
  }

  @override
  String ticketErrorUpdatingPriority(String error) {
    return 'टिकट की प्राथमिकता अपडेट करने में त्रुटि: $error';
  }

  @override
  String get ticketCouldNotOpenGithubIssue => 'GitHub इश्यू नहीं खोला जा सका';

  @override
  String get ticketGithubSyncUpdated => 'GitHub सिंक अपडेट हो गया';

  @override
  String get ticketGithubSyncFailed => 'GitHub सिंक विफल रहा';

  @override
  String ticketErrorSyncingGithub(String error) {
    return 'GitHub पर सिंक करने में त्रुटि: $error';
  }

  @override
  String ticketViewOnGithubWithId(String id) {
    return 'GitHub पर देखें (#$id)';
  }

  @override
  String get ticketViewOnGithub => 'GitHub पर देखें';

  @override
  String get ticketRetryGithubSync => 'GitHub सिंक फिर से करें';

  @override
  String get ticketAssignedSuccess => 'टिकट सफलतापूर्वक असाइन किया गया';

  @override
  String ticketAssignFailed(String error) {
    return 'टिकट असाइन करने में विफल: $error';
  }

  @override
  String ticketErrorAssigning(String error) {
    return 'टिकट असाइन करने में त्रुटि: $error';
  }

  @override
  String get ticketAssignTitle => 'टिकट असाइन करें';

  @override
  String get ticketErrorLoadingTeamMembers =>
      'टीम सदस्यों को लोड करने में त्रुटि';

  @override
  String get ticketNoTeamMembers => 'कोई टीम सदस्य नहीं मिला';

  @override
  String get ticketRoleAdmin => 'एडमिन';

  @override
  String get ticketRoleTeamMember => 'टीम सदस्य';

  @override
  String get ticketDetailsTitle => 'टिकट विवरण';

  @override
  String get ticketNotFound => 'टिकट नहीं मिला';

  @override
  String get ticketNotFoundMessage =>
      'हो सकता है टिकट हटा दिया गया हो या आपके पास इसकी पहुंच न हो।';

  @override
  String get ticketChangeStatus => 'स्थिति बदलें';

  @override
  String get ticketChangePriority => 'प्राथमिकता बदलें';

  @override
  String get ticketPriorityHigh => 'उच्च';

  @override
  String get ticketPriorityMedium => 'मध्यम';

  @override
  String get ticketPriorityLow => 'निम्न';

  @override
  String get ticketCategoryBug => 'बग';

  @override
  String get ticketCategoryFeatureRequest => 'फ़ीचर अनुरोध';

  @override
  String get ticketCategoryUiUx => 'UI/UX';

  @override
  String get ticketCategoryPerformance => 'परफ़ॉर्मेंस';

  @override
  String get ticketCategoryDocumentation => 'डॉक्यूमेंटेशन';

  @override
  String get ticketCategorySecurity => 'सुरक्षा';

  @override
  String get ticketCategoryOther => 'अन्य';

  @override
  String get ticketNoDescriptionProvided => 'कोई विवरण नहीं दिया गया।';

  @override
  String get ticketAssignedTo => 'असाइन किया गया';

  @override
  String get ticketAssign => 'असाइन करें';

  @override
  String ticketCommentsCount(int count) {
    return 'टिप्पणियां ($count)';
  }

  @override
  String get ticketNoComments => 'अभी तक कोई टिप्पणी नहीं';

  @override
  String get ticketBeFirstComment => 'सबसे पहले टिप्पणी जोड़ें';

  @override
  String get ticketAddCommentHint => 'टिप्पणी जोड़ें...';

  @override
  String get ticketSendComment => 'टिप्पणी भेजें';

  @override
  String ticketCreateFailed(String error) {
    return 'टिकट बनाने में विफल: $error';
  }

  @override
  String ticketErrorCreating(String error) {
    return 'टिकट बनाने में त्रुटि: $error';
  }

  @override
  String get ticketCreateTitle => 'टिकट बनाएं';

  @override
  String get ticketTitleHint => 'टिकट का शीर्षक दर्ज करें';

  @override
  String get ticketTitleRequired => 'कृपया शीर्षक दर्ज करें';

  @override
  String get ticketDescription => 'विवरण';

  @override
  String get ticketDescriptionHint =>
      'टिकट का विवरण दर्ज करें (अधिकतम 75 शब्द सुझाए गए हैं)';

  @override
  String get ticketDescriptionRequired => 'कृपया विवरण दर्ज करें';

  @override
  String get ticketAssignToOptional => 'असाइन करें (वैकल्पिक)';

  @override
  String get ticketSelectTeamMember => 'टीम सदस्य चुनें';

  @override
  String get ticketUnassigned => 'असाइन नहीं किया गया';

  @override
  String get ticketCreateGithubIssue => 'GitHub इश्यू बनाएं';

  @override
  String get ticketCreateGithubIssueSubtitle =>
      'इस टिकट को कॉन्फ़िगर की गई GitHub रिपॉज़िटरी में सिंक करें';
}
