import 'package:flutter/material.dart';

/// Small shared UI-string table for chrome text (nav labels, headers,
/// placeholders) that isn't covered by the ARB-based localization.
/// Falls back to English if the current locale has no entry for a key.
const Map<String, Map<String, String>> _appText = {
  'nav_home': {
    'th': 'หน้าแรก',
    'en': 'Home',
    'zh': '首页',
    'ko': '홈',
    'ru': 'Главная',
    'ja': 'ホーム',
  },
  'nav_scan': {
    'th': 'สแกน',
    'en': 'Scan',
    'zh': '扫描',
    'ko': '스캔',
    'ru': 'Скан',
    'ja': 'スキャン',
  },
  'nav_map': {
    'th': 'แผนที่',
    'en': 'Map',
    'zh': '地图',
    'ko': '지도',
    'ru': 'Карта',
    'ja': 'マップ',
  },
  'nav_sos': {
    'th': 'SOS',
    'en': 'SOS',
    'zh': 'SOS',
    'ko': 'SOS',
    'ru': 'SOS',
    'ja': 'SOS',
  },
  'nav_profile': {
    'th': 'โปรไฟล์',
    'en': 'Profile',
    'zh': '我的',
    'ko': '프로필',
    'ru': 'Профиль',
    'ja': 'プロフィール',
  },
  'home_tagline': {
    'th': 'เที่ยวปลอดภัย ฉลาดขึ้น',
    'en': 'Travel Safe · Stay Smart',
    'zh': '安全旅行 · 智慧出行',
    'ko': '안전한 여행 · 스마트한 선택',
    'ru': 'Безопасные путешествия · Будьте умнее',
    'ja': '安全な旅 · スマートに',
  },
  'feature_scanner_subtitle': {
    'th': 'สแกนเมนู ตรวจสอบราคา',
    'en': 'Scan menus, check prices',
    'zh': '扫描菜单，检查价格',
    'ko': '메뉴 스캔, 가격 확인',
    'ru': 'Сканируйте меню, проверяйте цены',
    'ja': 'メニューをスキャンして価格を確認',
  },
  'feature_map_subtitle': {
    'th': 'แผนที่พาร์ทเนอร์ & โซนเตือนภัย',
    'en': 'Partner map & alert zones',
    'zh': '合作伙伴地图和警示区域',
    'ko': '파트너 지도 및 알림 구역',
    'ru': 'Карта партнёров и зоны оповещения',
    'ja': 'パートナーマップとアラートゾーン',
  },
  'feature_sos_subtitle': {
    'th': 'พูดภาษาอังกฤษ สื่อสารทันที',
    'en': 'Speak English, communicate instantly',
    'zh': '说英语，即时沟通',
    'ko': '영어로 말하면 즉시 소통',
    'ru': 'Говорите по-английски — мгновенное общение',
    'ja': '英語で話して即時に伝える',
  },
  'profile_title': {
    'th': 'โปรไฟล์',
    'en': 'Profile',
    'zh': '个人资料',
    'ko': '프로필',
    'ru': 'Профиль',
    'ja': 'プロフィール',
  },
  'profile_language': {
    'th': 'ภาษา',
    'en': 'Language',
    'zh': '语言',
    'ko': '언어',
    'ru': 'Язык',
    'ja': '言語',
  },
  'profile_about_title': {
    'th': 'เกี่ยวกับ ThaiShield AI',
    'en': 'About ThaiShield AI',
    'zh': '关于 ThaiShield AI',
    'ko': 'ThaiShield AI 정보',
    'ru': 'О ThaiShield AI',
    'ja': 'ThaiShield AI について',
  },
  'scanner_coming_soon': {
    'th': 'เฟส 3 — เร็วๆ นี้',
    'en': 'Phase 3 — Coming Soon',
    'zh': '第三阶段 — 即将推出',
    'ko': '3단계 — 출시 예정',
    'ru': 'Этап 3 — скоро',
    'ja': 'フェーズ3 — 近日公開',
  },
  'sos_coming_soon': {
    'th': 'เฟส 4 — เร็วๆ นี้',
    'en': 'Phase 4 — Coming Soon',
    'zh': '第四阶段 — 即将推出',
    'ko': '4단계 — 출시 예정',
    'ru': 'Этап 4 — скоро',
    'ja': 'フェーズ4 — 近日公開',
  },
};

/// Returns the localized string for [key] based on the app's current
/// locale, falling back to English if no translation exists.
String appText(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  final entry = _appText[key];
  if (entry == null) return key;
  return entry[code] ?? entry['en'] ?? key;
}
