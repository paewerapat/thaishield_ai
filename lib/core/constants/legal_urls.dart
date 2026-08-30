/// The two public legal pages, in one place.
///
/// Both stores require a subscription purchase screen to link to Terms of Use
/// and a Privacy Policy that a reviewer can open **without an account** — see
/// `_LegalLinks` in `paywall_screen.dart`. Profile links to the privacy page
/// too, which is how these strings came to be copied into two files, where they
/// could drift apart without anything noticing.
///
/// 🚨 These are served by the **web admin** repo, from routes deliberately kept
/// outside `/admin` (auth lives in `app/admin/layout.tsx`, not middleware).
/// Changing the hosting domain, or putting the CMS behind global auth without
/// exempting `/terms` and `/privacy`, turns both of these into redirects and
/// fails store review. Whoever changes them must change `app/terms/page.tsx`
/// and `app/privacy/page.tsx` in the same breath.
class LegalUrls {
  const LegalUrls._();

  static const String _base =
      'https://thaishield-admin--thaishield-ai-790eb.asia-southeast1.hosted.app';

  static const String terms = '$_base/terms';
  static const String privacy = '$_base/privacy';
}
