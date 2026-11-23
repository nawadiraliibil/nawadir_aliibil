import '../data/auth_backend.dart';

String authFailureMessage(AuthFailureKind kind) => switch (kind) {
  AuthFailureKind.invalidCode =>
    'الرمز غير صحيح أو انتهت صلاحيته. اطلب رمزًا جديدًا إن لزم.',
  AuthFailureKind.rateLimited =>
    'تجاوزت عدد المحاولات المسموح. انتظر قليلًا ثم حاول مجددًا.',
  AuthFailureKind.invalidPhone =>
    'تعذّر قبول رقم الجوال. تحقق منه وحاول مجددًا.',
  AuthFailureKind.network => 'تعذّر الاتصال. تحقق من الإنترنت وحاول مجددًا.',
  AuthFailureKind.unavailable =>
    'تعذّر إرسال الرمز حاليًا. حاول مرة أخرى بعد قليل.',
};
