/// مسارات التطبيق.
abstract final class Routes {
  /// التبويبات الأربعة داخل الهيكل، بترتيب كبسولة التنقل.
  static const home = '/';
  static const favorites = '/favorites';
  static const messages = '/messages';
  static const account = '/account';

  /// تفاصيل إعلان منشور (C01)؛ شاشة كاملة خارج الهيكل، متاحة للزائر.
  static const listingPattern = '/listing/:id';
  static String listing(String id) => '/listing/$id';

  /// تقييمات معلن (F05)؛ شاشة كاملة خارج الهيكل، متاحة للزائر.
  static const sellerRatingsPattern = '/seller/:id/ratings';
  static String sellerRatings(String id) => '/seller/$id/ratings';

  /// تقييماتي كمعلن (F08)؛ شاشة كاملة خارج الهيكل وتشترط الدخول.
  static const receivedRatings = '/account/ratings';

  /// الملف العام للمعلن (C06)؛ شاشة كاملة خارج الهيكل، متاحة للزائر.
  static const sellerPattern = '/seller/:id';
  static String seller(String id) => '/seller/$id';

  /// محادثة (F02)؛ شاشة كاملة خارج الهيكل وتشترط الدخول.
  static const chatPattern = '/chat/:id';
  static String chat(String id) => '/chat/$id';

  /// بدء إنشاء إعلان؛ شاشة كاملة خارج الهيكل.
  static const postAd = '/post';

  /// الدخول برقم الهاتف (A02) ثم رمز التحقق (A03/A05)؛ شاشتان كاملتان خارج الهيكل.
  static const login = '/login';
  static const loginOtp = '/login/otp';

  /// إكمال الحساب (A04) وتعديل الملف (G02)؛ شاشتان كاملتان خارج الهيكل.
  static const accountComplete = '/account/complete';
  static const accountEdit = '/account/edit';

  /// مركز الإشعارات (G04) وإعداداته (G05)؛ شاشتان كاملتان خارج الهيكل.
  static const notifications = '/notifications';
  static const notificationSettings = '/notifications/settings';

  /// الإعدادات (G06) والشروط والخصوصية والمساعدة (G09)؛ شاشتان كاملتان متاحتان للزائر.
  static const settings = '/settings';
  static const legal = '/settings/legal';

  /// المتابعات (G03)؛ شاشة كاملة خارج الهيكل وتشترط الدخول.
  static const follows = '/account/follows';

  /// المحظورون (G08)؛ شاشة كاملة خارج الهيكل وتشترط الدخول.
  static const blockedUsers = '/account/blocks';

  /// إعلاناتي؛ شاشة كاملة خارج الهيكل (MOBILE-APP-110).
  static const myListings = '/account/listings';

  /// المسارات التي تشترط جلسة. الزائر يُوجَّه إلى الدخول ثم يعود إليها.
  static const requiresSignIn = {
    postAd,
    accountComplete,
    accountEdit,
    myListings,
    blockedUsers,
    follows,
    notificationSettings,
    receivedRatings,
  };

  /// مسار يشترط جلسة حسب نمطه (شاشات بمعرف).
  static bool needsSignIn(String path) =>
      requiresSignIn.contains(path) || path.startsWith('/chat/');

  /// شاشة إعداد البيئة الناقص؛ تظهر في التطوير فقط.
  static const setup = '/setup';

  /// وجهة العودة بعد الدخول: مسار داخلي فقط، فلا يوجّه رابط خارجي أحدًا.
  static String safeFrom(String? from) {
    if (from == null || !from.startsWith('/') || from.startsWith('//')) {
      return home;
    }
    final path = Uri.tryParse(from)?.path;
    if (path == null || path == login || path == loginOtp) return home;
    return from;
  }
}
