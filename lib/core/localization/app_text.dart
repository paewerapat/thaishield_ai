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
  'profile_feedback': {
    'th': 'ส่งความคิดเห็น',
    'en': 'Send Feedback',
    'zh': '发送反馈',
    'ko': '피드백 보내기',
    'ru': 'Отправить отзыв',
    'ja': 'フィードバックを送る',
  },
  'profile_feedback_subtitle': {
    'th': 'แจ้งปัญหาหรือข้อเสนอแนะ',
    'en': 'Report issues or share suggestions',
    'zh': '反馈问题或提出建议',
    'ko': '문제 신고 또는 제안 공유',
    'ru': 'Сообщить о проблеме или поделиться предложениями',
    'ja': '問題の報告や提案を共有',
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
    'th': 'เฟส 4 — เร็วๆ นี้', 'en': 'Phase 4 — Coming Soon', 'zh': '第四阶段 — 即将推出', 'ko': '4단계 — 출시 예정', 'ru': 'Этап 4 — скоро', 'ja': 'フェーズ4 — 近日公開',
  },
  'sos_instructions': {
    'th': 'กดค้างปุ่มแล้วพูดเป็นภาษาอังกฤษ\nAI จะแปลเป็นภาษาไทยทันที', 'en': 'Hold the button and speak in English.\nAI will translate to Thai instantly.', 'zh': '按住按钮并用英语说话\nAI 将立即翻译成泰语', 'ko': '버튼을 누른 채 영어로 말하세요\nAI가 즉시 태국어로 번역합니다', 'ru': 'Удержите кнопку и говорите по-английски\nAI мгновенно переведёт на тайский', 'ja': 'ボタンを押しながら英語で話してください\nAIがすぐにタイ語に翻訳します',
  },
  'sos_hold_to_speak': {
    'th': 'กดค้างเพื่อพูด', 'en': 'Hold to Speak', 'zh': '按住说话', 'ko': '누르고 말하기', 'ru': 'Удержите и говорите', 'ja': '押して話す',
  },
  'sos_hold_hint': {
    'th': 'พูดสั้น ๆ ว่าเกิดอะไรขึ้น แล้วปล่อยปุ่ม',
    'en': 'Say briefly what is happening, then release the button.',
    'zh': '简短说明发生了什么，然后松开按钮。',
    'ko': '무슨 일인지 짧게 말한 뒤 버튼에서 손을 떼세요.',
    'ru': 'Коротко скажите, что случилось, затем отпустите кнопку.',
    'ja': '何が起きたか短く話してから、ボタンを離してください。',
  },
  'sos_listening': {
    'th': 'กำลังฟัง...', 'en': 'Listening...', 'zh': '正在聆听...', 'ko': '듣는 중...', 'ru': 'Слушаю...', 'ja': '聞いています...',
  },
  'sos_processing': {
    'th': 'กำลังแปล...', 'en': 'Translating...', 'zh': '正在翻译...', 'ko': '번역 중...', 'ru': 'Перевожу...', 'ja': '翻訳中...',
  },
  'sos_speaking_th': {
    'th': 'กำลังพูดภาษาไทย', 'en': 'Speaking in Thai', 'zh': '正在说泰语', 'ko': '태국어로 말하는 중', 'ru': 'Говорю по-тайски', 'ja': 'タイ語で話しています',
  },
  'sos_you_said': {
    'th': 'คุณพูดว่า:', 'en': 'You said:', 'zh': '您说:', 'ko': '말한 내용:', 'ru': 'Вы сказали:', 'ja': '言ったこと:',
  },
  'sos_thai_response': {
    'th': 'คำแปลภาษาไทย:', 'en': 'Thai Response:', 'zh': '泰语翻译:', 'ko': '태국어 번역:', 'ru': 'Ответ на тайском:', 'ja': 'タイ語の返答:',
  },
  'sos_replay': {
    'th': 'เล่นซ้ำ', 'en': 'Replay', 'zh': '重播', 'ko': '다시 재생', 'ru': 'Повторить', 'ja': 'もう一度再生',
  },
  'sos_done': {
    'th': 'เสร็จสิ้น', 'en': 'Done', 'zh': '完成', 'ko': '완료', 'ru': 'Готово', 'ja': '完了',
  },
  'sos_try_again': {
    'th': 'ลองอีกครั้ง', 'en': 'Try Again', 'zh': '重试', 'ko': '다시 시도', 'ru': 'Попробовать снова', 'ja': 'もう一度試す',
  },
  'sos_error_no_speech': {
    'th': 'ไม่พบเสียงพูด กรุณาลองใหม่อีกครั้ง', 'en': 'No speech detected. Please try again.', 'zh': '未检测到语音，请重试', 'ko': '음성이 감지되지 않았습니다. 다시 시도해주세요', 'ru': 'Речь не обнаружена. Попробуйте ещё раз', 'ja': '音声が検出されませんでした。もう一度お試しください',
  },
  'sos_error_mic': {
    'th': 'ไม่สามารถใช้ไมโครโฟนได้ กรุณาตรวจสอบการอนุญาต', 'en': 'Microphone unavailable. Please check app permissions.', 'zh': '麦克风不可用，请检查应用权限', 'ko': '마이크를 사용할 수 없습니다. 앱 권한을 확인해주세요', 'ru': 'Микрофон недоступен. Проверьте разрешения приложения', 'ja': 'マイクが使用できません。アプリの権限を確認してください',
  },
  'sos_error_translation': {
    'th': 'ไม่สามารถแปลได้ในขณะนี้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต', 'en': 'Translation unavailable. Please check your internet connection.', 'zh': '翻译暂不可用，请检查网络连接', 'ko': '번역을 사용할 수 없습니다. 인터넷 연결을 확인해주세요', 'ru': 'Перевод недоступен. Проверьте подключение к интернету', 'ja': '翻訳できません。インターネット接続を確認してください',
  },
  'sos_disclaimer': {
    'th': 'การแปลด้วย AI อาจไม่สมบูรณ์แบบ ใช้เพื่อสื่อสารเบื้องต้นเท่านั้น\nสำหรับเหตุฉุกเฉิน โทร 1155 (สายด่วนนักท่องเที่ยว)', 'en': 'AI translation may not be perfect. Use for initial communication only.\nFor emergencies, call 1155 (Tourist Assistance Hotline).', 'zh': 'AI翻译可能不完美，仅供初步沟通使用\n紧急情况请拨打1155（游客援助热线）', 'ko': 'AI 번역은 완벽하지 않을 수 있습니다. 초기 소통용으로만 사용하세요\n긴급 상황 시 1155로 전화하세요 (관광객 지원 핫라인)', 'ru': 'Перевод AI может быть неточным. Используйте только для первичного общения.\nПри чрезвычайных ситуациях звоните 1155', 'ja': 'AI翻訳は完璧ではない場合があります。初期コミュニケーション用のみ使用してください\n緊急の場合は1155に電話してください（旅行者支援ホットライン）',
  },
  'travel_alerts_title': {
    'th': 'การแจ้งเตือนการเดินทางในไทย (เรียลไทม์)',
    'en': 'Real-Time Thailand Travel Alerts',
    'zh': '泰国实时旅行提醒',
    'ko': '태국 실시간 여행 알림',
    'ru': 'Актуальные оповещения о поездках по Таиланду',
    'ja': 'タイ リアルタイム旅行アラート',
  },
  'travel_alerts_view_details': {
    'th': 'ดูรายละเอียด',
    'en': 'View details',
    'zh': '查看详情',
    'ko': '자세히 보기',
    'ru': 'Подробнее',
    'ja': '詳細を見る',
  },
  'travel_alerts_empty': {
    'th': 'ยังไม่มีข้อมูลการแจ้งเตือนในขณะนี้',
    'en': 'No travel alerts at the moment',
    'zh': '目前没有旅行提醒',
    'ko': '현재 여행 알림이 없습니다',
    'ru': 'Сейчас нет оповещений о поездках',
    'ja': '現在、旅行アラートはありません',
  },
  'travel_alerts_error': {
    'th': 'ไม่สามารถโหลดข้อมูลการแจ้งเตือนได้ในขณะนี้',
    'en': 'Unable to load travel alerts right now',
    'zh': '目前无法加载旅行提醒',
    'ko': '지금은 여행 알림을 불러올 수 없습니다',
    'ru': 'Не удалось загрузить оповещения о поездках',
    'ja': '現在、旅行アラートを読み込めません',
  },
  'travel_alerts_disclaimer': {
    'th': 'ข้อมูลนี้รวบรวมจากแหล่งข่าวสาธารณะเพื่อประกอบการตัดสินใจเท่านั้น กรุณาตรวจสอบกับแหล่งข้อมูลทางการก่อนเดินทาง',
    'en': 'This information is aggregated from public news sources for informational purposes only. Please verify with official sources before traveling.',
    'zh': '此信息汇总自公开新闻来源，仅供参考。出行前请以官方信息为准。',
    'ko': '이 정보는 공개 뉴스 소스에서 수집한 것으로 참고용입니다. 여행 전 공식 정보를 확인하세요.',
    'ru': 'Эта информация собрана из открытых новостных источников и носит исключительно информационный характер. Перед поездкой уточните данные в официальных источниках.',
    'ja': 'この情報は公開ニュースソースから集約したもので、参考情報です。旅行前に公式情報をご確認ください。',
  },
  'alert_category_flood': {
    'th': 'น้ำท่วม', 'en': 'FLOOD', 'zh': '洪水', 'ko': '홍수', 'ru': 'ПАВОДОК', 'ja': '洪水',
  },
  'alert_category_fire': {
    'th': 'ไฟไหม้', 'en': 'FIRE', 'zh': '火灾', 'ko': '화재', 'ru': 'ПОЖАР', 'ja': '火災',
  },
  'alert_category_storm': {
    'th': 'พายุ', 'en': 'STORM', 'zh': '风暴', 'ko': '폭풍', 'ru': 'ШТОРМ', 'ja': '暴風',
  },
  'alert_category_earthquake': {
    'th': 'แผ่นดินไหว', 'en': 'EARTHQUAKE', 'zh': '地震', 'ko': '지진', 'ru': 'ЗЕМЛЕТРЯСЕНИЕ', 'ja': '地震',
  },
  'alert_category_accident': {
    'th': 'อุบัติเหตุ', 'en': 'ACCIDENT', 'zh': '事故', 'ko': '사고', 'ru': 'ПРОИСШЕСТВИЕ', 'ja': '事故',
  },
  'alert_category_other': {
    'th': 'แจ้งเตือน', 'en': 'ALERT', 'zh': '提醒', 'ko': '알림', 'ru': 'ОПОВЕЩЕНИЕ', 'ja': 'アラート',
  },
  'home_active_alerts_title': {
    'th': 'การแจ้งเตือนที่กำลังเกิดขึ้นในไทย',
    'en': 'Active Alerts in Thailand',
    'zh': '泰国当前提醒',
    'ko': '태국 내 활성 알림',
    'ru': 'Текущие оповещения по Таиланду',
    'ja': 'タイの現在のアラート',
  },
  'home_active_alerts_view_reports': {
    'th': 'ดูรายงาน', 'en': 'View reports', 'zh': '查看报告', 'ko': '리포트 보기', 'ru': 'Смотреть сообщения', 'ja': 'レポートを見る',
  },
  'home_alerts_unit': {
    'th': 'รายงาน', 'en': 'reports', 'zh': '条', 'ko': '건', 'ru': 'сообщений', 'ja': '件',
  },
  'home_alerts_summary_generic': {
    'th': 'มีการแจ้งเตือน {count} รายการในไทย',
    'en': '{count} active reports in Thailand',
    'zh': '泰国目前有 {count} 条提醒',
    'ko': '태국 내 활성 알림 {count}건',
    'ru': '{count} активных оповещений по Таиланду',
    'ja': 'タイで{count}件のアラートがあります',
  },
  'home_top_news': {
    'th': 'ข่าวเด่น', 'en': 'Top News', 'zh': '头条新闻', 'ko': '주요 뉴스', 'ru': 'Главные новости', 'ja': 'トップニュース',
  },
  'home_see_all': {
    'th': 'ดูทั้งหมด', 'en': 'See all', 'zh': '查看全部', 'ko': '전체 보기', 'ru': 'Смотреть все', 'ja': 'すべて見る',
  },
  'home_useful_tools': {
    'th': 'เครื่องมือที่ใช้บ่อย', 'en': 'Useful Tools', 'zh': '实用工具', 'ko': '유용한 도구', 'ru': 'Полезные инструменты', 'ja': '便利な機能',
  },
  'tool_safety_tips': {
    'th': 'คำแนะนำความปลอดภัย',
    'en': 'Safety Tips',
    'zh': '安全提示',
    'ko': '안전 수칙',
    'ru': 'Советы по безопасности',
    'ja': '安全のヒント',
  },
  'safety_tip_1': {
    'th': 'เก็บพาสปอร์ตและเอกสารสำคัญไว้ในที่ปลอดภัย พกสำเนาแยกไว้ต่างหาก',
    'en': 'Keep your passport and important documents in a safe place; carry copies separately.',
    'zh': '将护照和重要证件存放在安全的地方，并随身携带副本。',
    'ko': '여권과 중요 서류는 안전한 곳에 보관하고, 사본은 따로 챙기세요.',
    'ru': 'Храните паспорт и важные документы в надёжном месте; берите с собой отдельные копии.',
    'ja': 'パスポートや重要な書類は安全な場所に保管し、コピーは別に持ち歩きましょう。',
  },
  'safety_tip_2': {
    'th': 'ตกลงราคาหรือใช้มิเตอร์ก่อนขึ้นแท็กซี่หรือตุ๊กตุ๊ก',
    'en': 'Agree on a fare or use the meter before taking a taxi or tuk-tuk.',
    'zh': '乘坐出租车或嘟嘟车前，请先确认价格或使用计价器。',
    'ko': '택시나 뚝뚝을 타기 전에 요금을 미리 정하거나 미터기를 사용하세요.',
    'ru': 'Перед поездкой на такси или тук-туке договоритесь о цене или используйте счётчик.',
    'ja': 'タクシーやトゥクトゥクに乗る前に料金を確認するか、メーターを使用しましょう。',
  },
  'safety_tip_3': {
    'th': 'บันทึกเบอร์ฉุกเฉินไว้: ตำรวจท่องเที่ยว 1155, เหตุฉุกเฉิน 191',
    'en': 'Save emergency numbers: Tourist Police 1155, Emergency 191.',
    'zh': '保存紧急电话：旅游警察 1155，紧急求助 191。',
    'ko': '긴급 전화번호를 저장하세요: 관광경찰 1155, 응급 191.',
    'ru': 'Сохраните номера экстренных служб: туристическая полиция 1155, экстренная помощь 191.',
    'ja': '緊急連絡先を保存しましょう：観光警察 1155、緊急通報 191。',
  },
  'safety_tip_4': {
    'th': 'ตรวจสอบสภาพอากาศและประกาศเตือนน้ำท่วมก่อนเดินทางไปยังพื้นที่ที่ได้รับผลกระทบ',
    'en': 'Check weather and flood advisories before traveling to affected areas.',
    'zh': '前往受影响地区前，请查看天气和洪水预警信息。',
    'ko': '영향을 받는 지역으로 이동하기 전에 날씨와 홍수 경보를 확인하세요.',
    'ru': 'Перед поездкой в пострадавшие районы проверьте прогноз погоды и предупреждения о наводнениях.',
    'ja': '影響を受けている地域へ行く前に、天気と洪水情報を確認しましょう。',
  },
  'safety_tip_5': {
    'th': 'ดื่มน้ำให้เพียงพอและหลีกเลี่ยงแสงแดดจัดในช่วงเวลาที่ร้อนที่สุด',
    'en': 'Stay hydrated and limit sun exposure during peak hours.',
    'zh': '请保持充足水分，并在高温时段减少日晒。',
    'ko': '충분히 수분을 섭취하고 햇볕이 강한 시간대에는 노출을 줄이세요.',
    'ru': 'Пейте достаточно воды и избегайте долгого пребывания на солнце в часы пик.',
    'ja': '十分な水分を取り、日差しが強い時間帯の外出は控えましょう。',
  },
  'safety_tip_6': {
    'th': 'หลีกเลี่ยงการเดินคนเดียวในพื้นที่ที่ไม่คุ้นเคยช่วงดึก',
    'en': 'Avoid walking alone in unfamiliar areas late at night.',
    'zh': '深夜请避免在不熟悉的地区独自步行。',
    'ko': '늦은 밤에는 낯선 지역에서 혼자 걷는 것을 피하세요.',
    'ru': 'Избегайте прогулок в одиночку по незнакомым районам в позднее время.',
    'ja': '夜遅くに不慣れな場所を一人で歩くのは避けましょう。',
  },
  'safety_tip_7': {
    'th': 'เปรียบเทียบราคาก่อนซื้อสินค้าหรือบริการ',
    'en': 'Compare prices before purchasing goods or services.',
    'zh': '购买商品或服务前请先比较价格。',
    'ko': '상품이나 서비스를 구매하기 전에 가격을 비교해 보세요.',
    'ru': 'Сравнивайте цены перед покупкой товаров или услуг.',
    'ja': '商品やサービスを購入する前に価格を比較しましょう。',
  },
  'safety_tip_8': {
    'th': 'เก็บสำเนาดิจิทัลของเอกสารและข้อมูลประกันการเดินทางไว้เสมอ',
    'en': 'Keep digital copies of your documents and travel insurance information.',
    'zh': '请保留证件和旅行保险信息的电子副本。',
    'ko': '서류와 여행자 보험 정보를 디지털 사본으로 보관하세요.',
    'ru': 'Храните цифровые копии документов и информации о туристической страховке.',
    'ja': '書類と旅行保険情報のデジタルコピーを保管しておきましょう。',
  },
  'profile_tagline': {
    'th': 'ความปลอดภัยของคุณคือสิ่งสำคัญที่สุด',
    'en': 'Your Safety, Our Priority',
    'zh': '您的安全，我们的首要任务',
    'ko': '당신의 안전이 최우선입니다',
    'ru': 'Ваша безопасность — наш приоритет',
    'ja': 'あなたの安全を第一に',
  },
  'profile_current_location': {
    'th': 'ตำแหน่งปัจจุบัน', 'en': 'Current Location', 'zh': '当前位置', 'ko': '현재 위치', 'ru': 'Текущее местоположение', 'ja': '現在の位置',
  },
  'profile_update_location': {
    'th': 'อัปเดตตำแหน่งของฉัน', 'en': 'Update My Location', 'zh': '更新我的位置', 'ko': '내 위치 업데이트', 'ru': 'Обновить моё местоположение', 'ja': '位置情報を更新',
  },
  'profile_location_placeholder': {
    'th': 'แตะปุ่มด้านล่างเพื่อตรวจหาตำแหน่งของคุณ',
    'en': 'Tap the button below to detect your location',
    'zh': '点击下方按钮以检测您的位置',
    'ko': '아래 버튼을 눌러 위치를 확인하세요',
    'ru': 'Нажмите кнопку ниже, чтобы определить ваше местоположение',
    'ja': '下のボタンをタップして位置を取得しましょう',
  },
  'profile_location_denied': {
    'th': 'ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง กรุณาเปิดสิทธิ์การเข้าถึงตำแหน่งในตั้งค่า',
    'en': 'Location permission denied. Please enable location access in settings.',
    'zh': '位置权限被拒绝。请在设置中启用位置访问权限。',
    'ko': '위치 권한이 거부되었습니다. 설정에서 위치 접근을 허용해 주세요.',
    'ru': 'Доступ к местоположению запрещён. Включите его в настройках.',
    'ja': '位置情報の権限が拒否されました。設定で位置情報を許可してください。',
  },
  'profile_location_error': {
    'th': 'ไม่สามารถดึงตำแหน่งได้ในขณะนี้',
    'en': 'Unable to get your location right now',
    'zh': '目前无法获取您的位置',
    'ko': '지금은 위치를 가져올 수 없습니다',
    'ru': 'Не удалось определить местоположение',
    'ja': '現在、位置情報を取得できません',
  },
  'profile_emergency_help_center': {
    'th': 'ศูนย์ช่วยเหลือฉุกเฉิน', 'en': 'Emergency Help Center', 'zh': '紧急求助中心', 'ko': '응급 지원 센터', 'ru': 'Центр экстренной помощи', 'ja': '緊急ヘルプセンター',
  },
  'profile_call': {
    'th': 'โทร', 'en': 'Call', 'zh': '拨打', 'ko': '전화', 'ru': 'Позвонить', 'ja': '電話',
  },
  'profile_tourist_police': {
    'th': 'ตำรวจท่องเที่ยว', 'en': 'Tourist Police', 'zh': '旅游警察', 'ko': '관광경찰', 'ru': 'Туристическая полиция', 'ja': '観光警察',
  },
  'profile_police': {
    'th': 'ตำรวจ', 'en': 'Police', 'zh': '警察', 'ko': '경찰', 'ru': 'Полиция', 'ja': '警察',
  },
  'profile_ambulance': {
    'th': 'รถพยาบาล', 'en': 'Ambulance', 'zh': '救护车', 'ko': '구급차', 'ru': 'Скорая помощь', 'ja': '救急車',
  },
  'map_search_hint': {
    'th': 'ค้นหาสถานที่ เช่น กรุงเทพฯ, สุขุมวิท',
    'en': 'Search location e.g. Bangkok, Sukhumvit',
    'zh': '搜索地点，例如曼谷、素坤逸',
    'ko': '장소 검색 예: 방콕, 수쿰빗',
    'ru': 'Поиск места, напр. Бангкок, Сукхумвит',
    'ja': '場所を検索 例：バンコク、スクンビット',
  },
  'scanner_instructions_title': {
    'th': 'สแกนเมนูหรือป้ายราคา',
    'en': 'Scan a Menu or Price Tag',
    'zh': '扫描菜单或价格标签',
    'ko': '메뉴 또는 가격표 스캔',
    'ru': 'Сканируйте меню или ценник',
    'ja': 'メニューや価格表をスキャン',
  },
  'scanner_instructions_subtitle': {
    'th': 'ถ่ายรูปรายการราคา หรือถ่ายรูปอาหารเพื่อให้ AI ช่วยระบุเมนูและเทียบราคา',
    'en': 'Photograph a price list, or just the dish itself — AI will identify it and compare prices',
    'zh': '拍摄价目表，或直接拍摄菜品，AI 将识别并比较价格',
    'ko': '가격표를 찍거나 음식 사진만 찍어도 AI가 메뉴를 식별하고 가격을 비교해 드려요',
    'ru': 'Сфотографируйте прайс-лист или просто блюдо — ИИ распознает его и сравнит цены',
    'ja': '価格表を撮影するか、料理だけを撮影してもAIがメニューを識別して価格を比較します',
  },
  'scanner_capture_button': {
    'th': 'สแกนเลย', 'en': 'Scan Now', 'zh': '立即扫描', 'ko': '지금 스캔', 'ru': 'Сканировать', 'ja': '今すぐスキャン',
  },
  'scanner_processing': {
    'th': 'กำลังวิเคราะห์ภาพ...',
    'en': 'Analyzing image...',
    'zh': '正在分析图像...',
    'ko': '이미지 분석 중...',
    'ru': 'Анализ изображения...',
    'ja': '画像を解析中...',
  },
  'scanner_identifying': {
    'th': 'กำลังวิเคราะห์เมนูด้วย AI...',
    'en': 'Identifying dish with AI...',
    'zh': '正在用 AI 识别菜品...',
    'ko': 'AI로 메뉴를 분석하는 중...',
    'ru': 'Распознавание блюда с помощью ИИ...',
    'ja': 'AIでメニューを識別中...',
  },
  'scanner_ai_identified': {
    'th': 'AI ระบุเมนู', 'en': 'AI Identified', 'zh': 'AI 识别', 'ko': 'AI 식별됨', 'ru': 'Определено ИИ', 'ja': 'AI識別',
  },
  // Shown when the dish is not in price_standards at all and the range below
  // it came from Gemini. Wording follows CLAUDE.md §10: it states where the
  // number came from and that nobody has checked it, and says nothing about
  // any shop or about the price being fair or unfair.
  'scanner_ai_estimated': {
    'th': 'ประมาณการโดย AI • ยังไม่ได้ตรวจสอบ',
    'en': 'AI Estimate • Not Verified',
    'zh': 'AI 估算 • 未经核实',
    'ko': 'AI 추정 • 미확인',
    'ru': 'Оценка ИИ • не проверено',
    'ja': 'AI推定 • 未確認',
  },
  'scanner_estimated_range': {
    'th': 'ช่วงราคาโดยประมาณ (ยังไม่มีในฐานข้อมูลราคามาตรฐาน)',
    'en': 'Estimated Price Range (not yet in our price database)',
    'zh': '预估价格范围（尚未收录于价格数据库）',
    'ko': '예상 가격대 (아직 가격 데이터베이스에 없음)',
    'ru': 'Примерный диапазон цен (пока нет в базе цен)',
    'ja': '推定価格帯（価格データベース未収録）',
  },
  'scanner_reference_range': {
    'th': 'ช่วงราคาทั่วไปสำหรับเมนูนี้',
    'en': 'Typical Price Range for This Dish',
    'zh': '此菜品的一般价格范围',
    'ko': '이 메뉴의 일반적인 가격대',
    'ru': 'Типичный диапазон цен для этого блюда',
    'ja': 'このメニューの一般的な価格帯',
  },
  'scanner_view_location': {
    'th': 'ดูบนแผนที่', 'en': 'View on Map', 'zh': '在地图上查看', 'ko': '지도에서 보기', 'ru': 'Посмотреть на карте', 'ja': '地図で見る',
  },
  'scanner_no_match_found': {
    'th': 'ไม่พบรายการที่ตรงกัน ลองถ่ายรายการราคาให้ชัดเจนขึ้น หรือถ่ายภาพอาหารให้เห็นจานชัดๆ',
    'en': 'No matching items found. Try a clearer photo of the price list or the dish.',
    'zh': '未找到匹配的项目。请尝试拍摄更清晰的价目表或菜品照片。',
    'ko': '일치하는 항목을 찾지 못했습니다. 가격표나 음식 사진을 더 선명하게 찍어보세요.',
    'ru': 'Совпадений не найдено. Сделайте более чёткое фото прайс-листа или блюда.',
    'ja': '一致する項目が見つかりません。価格表または料理の写真をより鮮明に撮影してください。',
  },
  'scanner_scan_again': {
    'th': 'สแกนอีกครั้ง', 'en': 'Scan Again', 'zh': '重新扫描', 'ko': '다시 스캔', 'ru': 'Сканировать снова', 'ja': '再スキャン',
  },
  'scanner_results_title': {
    'th': 'ผลการสแกน', 'en': 'Scan Results', 'zh': '扫描结果', 'ko': '스캔 결과', 'ru': 'Результаты сканирования', 'ja': 'スキャン結果',
  },
  'scanner_detected_price': {
    'th': 'ราคาที่ตรวจพบ', 'en': 'Detected Price', 'zh': '检测到的价格', 'ko': '감지된 가격', 'ru': 'Обнаруженная цена', 'ja': '検出された価格',
  },
  'scanner_typical_range': {
    'th': 'ช่วงราคาทั่วไป', 'en': 'Typical Range', 'zh': '一般价格范围', 'ko': '일반적인 가격대', 'ru': 'Типичный диапазон', 'ja': '一般的な価格帯',
  },
  'scanner_permission_denied': {
    'th': 'ไม่ได้รับอนุญาตให้เข้าถึงกล้อง กรุณาเปิดสิทธิ์การเข้าถึงกล้องในตั้งค่า',
    'en': 'Camera permission denied. Please enable camera access in settings.',
    'zh': '相机权限被拒绝。请在设置中启用相机访问权限。',
    'ko': '카메라 권한이 거부되었습니다. 설정에서 카메라 접근을 허용해 주세요.',
    'ru': 'Доступ к камере запрещён. Включите его в настройках.',
    'ja': 'カメラの権限が拒否されました。設定でカメラを許可してください。',
  },
  'scanner_error_generic': {
    'th': 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
    'en': 'Something went wrong. Please try again.',
    'zh': '出错了，请重试。',
    'ko': '문제가 발생했습니다. 다시 시도해 주세요.',
    'ru': 'Что-то пошло не так. Попробуйте ещё раз.',
    'ja': '問題が発生しました。もう一度お試しください。',
  },
  'scanner_disclaimer': {
    'th': 'ข้อมูลนี้เป็นการประเมินจากข้อมูลสถิติและข้อมูลจากชุมชนเพื่อประกอบการตัดสินใจเท่านั้น ราคาจริงอาจแตกต่างกันได้',
    'en': 'This information is generated from statistical and community-based data and is intended for informational purposes only. Actual prices may vary.',
    'zh': '此信息基于统计和社区数据生成，仅供参考。实际价格可能有所不同。',
    'ko': '이 정보는 통계 및 커뮤니티 데이터를 기반으로 생성되었으며 참고용입니다. 실제 가격은 다를 수 있습니다.',
    'ru': 'Эта информация формируется на основе статистических и общественных данных и приведена исключительно в информационных целях. Фактические цены могут отличаться.',
    'ja': 'この情報は統計データとコミュニティデータに基づいて生成されたもので、参考情報です。実際の価格は異なる場合があります。',
  },
  'scanner_scan_location': {
    'th': 'ตำแหน่งที่ถ่ายภาพ', 'en': 'Scan Location', 'zh': '拍摄位置', 'ko': '촬영 위치', 'ru': 'Место съёмки', 'ja': '撮影位置',
  },
  'scanner_category_food': {
    'th': 'อาหาร', 'en': 'Food', 'zh': '食品', 'ko': '음식', 'ru': 'Еда', 'ja': '食べ物',
  },
  'scanner_category_transport': {
    'th': 'การเดินทาง', 'en': 'Transport', 'zh': '交通', 'ko': '교통', 'ru': 'Транспорт', 'ja': '交通',
  },
  'scanner_category_attraction': {
    'th': 'สถานที่ท่องเที่ยว', 'en': 'Attraction', 'zh': '景点', 'ko': '관광지', 'ru': 'Достопримечательности', 'ja': '観光地',
  },
  'scanner_other_matches': {
    'th': 'รายการที่พบเพิ่มเติม', 'en': 'Other Matches', 'zh': '其他匹配项', 'ko': '다른 검색 결과', 'ru': 'Другие совпадения', 'ja': 'その他の一致',
  },
  'scanner_view_nearby_partners': {
    'th': 'ดูร้านพาร์ทเนอร์ใกล้เคียง', 'en': 'View Nearby Partners', 'zh': '查看附近合作商家', 'ko': '근처 파트너 보기', 'ru': 'Смотреть партнёров рядом', 'ja': '近くのパートナーを見る',
  },
  'scanner_nearby_partners_subtitle': {
    'th': 'ค้นหาร้านพาร์ทเนอร์ที่มีราคามาตรฐานใกล้คุณ', 'en': 'Find trusted restaurants with fair prices near you.', 'zh': '在您附近寻找价格公道的合作餐厅', 'ko': '근처의 공정한 가격의 파트너 식당을 찾아보세요', 'ru': 'Найдите проверенные рестораны с честными ценами рядом с вами', 'ja': '近くの適正価格パートナーレストランを探す',
  },
  'scanner_tip_for_you': {
    'th': 'คำแนะนำสำหรับคุณ', 'en': 'Tip for You', 'zh': '给您的提示', 'ko': '여행 팁', 'ru': 'Совет для вас', 'ja': 'あなたへのヒント',
  },
  'scanner_tip_within': {
    'th': 'ราคาดี! ราคานี้อยู่ในช่วงราคาทั่วไป', 'en': 'Good price! This is within the usual price range.', 'zh': '价格合理！此价格在一般范围内', 'ko': '좋은 가격이에요! 일반적인 가격대에 있습니다', 'ru': 'Хорошая цена! Она находится в обычном диапазоне', 'ja': 'お得です！通常の価格帯内です',
  },
  'scanner_tip_below': {
    'th': 'คุ้มค่า! ราคานี้ต่ำกว่าช่วงราคาทั่วไป', 'en': 'Great value! This price is below the typical range.', 'zh': '超值！此价格低于一般范围', 'ko': '가성비 최고! 일반적인 가격대보다 낮습니다', 'ru': 'Выгодно! Цена ниже обычного диапазона', 'ja': 'お得！価格が通常より低いです',
  },
  'scanner_tip_above': {
    'th': 'ราคาดูสูงกว่าช่วงปกติ ควรเปรียบเทียบราคาก่อนตัดสินใจซื้อ', 'en': 'Price appears above typical range. Consider comparing prices before purchasing.', 'zh': '价格似乎高于一般范围，建议购买前比较价格', 'ko': '가격이 일반적인 범위보다 높아 보입니다. 구매 전 가격을 비교해보세요', 'ru': 'Цена выше обычного. Советуем сравнить перед покупкой', 'ja': '価格が通常より高いようです。購入前に比較することをお勧めします',
  },
  'scanner_tip_significant': {
    'th': 'พบความแตกต่างของราคาอย่างมีนัยสำคัญ ควรเปรียบเทียบราคาก่อนตัดสินใจ', 'en': 'Significant price variation detected. We recommend comparing prices before purchasing.', 'zh': '发现显著价格差异，建议购买前进行比较', 'ko': '상당한 가격 차이가 감지되었습니다. 구매 전 가격을 비교하는 것을 권장합니다', 'ru': 'Обнаружено значительное отклонение цены. Рекомендуем сравнить перед покупкой', 'ja': '大きな価格差が検出されました。購入前に比較することをお勧めします',
  },
  'scanner_tip_estimated': {
    'th': 'ตัวเลขนี้ AI ประเมินจากรูป ยังไม่ได้ตรวจสอบโดยทีมงาน ใช้เป็นแนวทางคร่าว ๆ เท่านั้น ราคาจริงต่างกันได้ตามสถานที่และช่วงเวลา',
    'en': 'This figure was estimated by AI from the photo and has not been reviewed by our team. Treat it as a rough guide only — actual prices vary by place and time.',
    'zh': '此数字由 AI 根据照片估算，尚未经我们的团队核实。仅供粗略参考，实际价格因地点和时间而异',
    'ko': '이 금액은 AI가 사진을 보고 추정한 값이며 담당 팀이 확인하지 않았습니다. 대략적인 참고용으로만 사용하세요. 실제 가격은 장소와 시간에 따라 다릅니다',
    'ru': 'Эта сумма рассчитана ИИ по фотографии и не проверена нашей командой. Используйте её лишь как примерный ориентир — реальные цены зависят от места и времени',
    'ja': 'この金額はAIが写真から推定したもので、担当チームによる確認は行われていません。おおよその目安としてのみご利用ください。実際の価格は場所や時間によって異なります',
  },
  'scanner_tip_reference': {
    'th': 'เปรียบเทียบราคาก่อนซื้อ ราคาอาจแตกต่างกันตามสถานที่และเวลา', 'en': 'Compare prices before you buy. Prices may vary by location and time.', 'zh': '购买前请比较价格。价格可能因地点和时间而异', 'ko': '구매 전 가격을 비교하세요. 가격은 장소와 시간에 따라 다를 수 있습니다', 'ru': 'Сравните цены перед покупкой. Цены могут различаться в зависимости от места и времени', 'ja': '購入前に価格を比較してください。価格は場所や時間によって異なる場合があります',
  },
  'variance_within': {
    'th': 'อยู่ในช่วงราคาทั่วไป', 'en': 'Within Typical Range', 'zh': '处于一般价格范围内', 'ko': '일반적인 가격대 내', 'ru': 'В пределах типичного диапазона', 'ja': '一般的な価格帯内',
  },
  'variance_above': {
    'th': 'สูงกว่าช่วงราคาทั่วไป', 'en': 'Above Typical Range', 'zh': '高于一般价格范围', 'ko': '일반적인 가격대보다 높음', 'ru': 'Выше типичного диапазона', 'ja': '一般的な価格帯より高い',
  },
  'variance_significant': {
    'th': 'มีความแตกต่างของราคาอย่างมีนัยสำคัญ', 'en': 'Significant Price Variation', 'zh': '价格差异显著', 'ko': '가격 차이가 상당함', 'ru': 'Значительное отклонение цены', 'ja': '価格差が大きい',
  },
  'variance_below': {
    'th': 'ต่ำกว่าช่วงราคาทั่วไป', 'en': 'Below Typical Range', 'zh': '低于一般价格范围', 'ko': '일반적인 가격대보다 낮음', 'ru': 'Ниже типичного диапазона', 'ja': '一般的な価格帯より低い',
  },
  'map_search_not_found': {
    'th': 'ไม่พบสถานที่นี้ ลองพิมพ์ชื่ออื่นดูนะครับ',
    'en': 'Location not found. Try a different place name.',
    'zh': '未找到该地点，请尝试其他名称。',
    'ko': '위치를 찾을 수 없습니다. 다른 이름을 입력해 보세요.',
    'ru': 'Место не найдено. Попробуйте другое название.',
    'ja': '場所が見つかりません。別の名前をお試しください。',
  },

  // --- Partner categories (the 11 values of partner_locations.type, §3) ---
  'cat_restaurant': {
    'th': 'ร้านอาหาร', 'en': 'Restaurant', 'zh': '餐厅', 'ko': '식당', 'ru': 'Ресторан', 'ja': 'レストラン',
  },
  'cat_hotel': {
    'th': 'ที่พัก', 'en': 'Hotel', 'zh': '酒店', 'ko': '숙소', 'ru': 'Отель', 'ja': 'ホテル',
  },
  'cat_transport': {
    'th': 'การเดินทาง', 'en': 'Transport', 'zh': '交通', 'ko': '교통', 'ru': 'Транспорт', 'ja': '交通',
  },
  'cat_hospital': {
    'th': 'โรงพยาบาล', 'en': 'Hospital', 'zh': '医院', 'ko': '병원', 'ru': 'Больница', 'ja': '病院',
  },
  'cat_pharmacy': {
    'th': 'ร้านขายยา', 'en': 'Pharmacy', 'zh': '药店', 'ko': '약국', 'ru': 'Аптека', 'ja': '薬局',
  },
  'cat_police': {
    'th': 'สถานีตำรวจ', 'en': 'Police Station', 'zh': '警察局', 'ko': '경찰서', 'ru': 'Полиция', 'ja': '警察署',
  },
  'cat_tourist_police': {
    'th': 'ตำรวจท่องเที่ยว', 'en': 'Tourist Police', 'zh': '旅游警察', 'ko': '관광경찰', 'ru': 'Туристическая полиция', 'ja': 'ツーリストポリス',
  },
  'cat_atm_bank': {
    'th': 'ธนาคาร & ตู้ ATM', 'en': 'Bank & ATM', 'zh': '银行与ATM', 'ko': '은행 & ATM', 'ru': 'Банк и банкомат', 'ja': '銀行・ATM',
  },
  'cat_shopping': {
    'th': 'ร้านค้า & ตลาด', 'en': 'Shops & Markets', 'zh': '商店与市场', 'ko': '상점 & 시장', 'ru': 'Магазины и рынки', 'ja': 'ショップ・市場',
  },
  'cat_attraction': {
    'th': 'สถานที่ท่องเที่ยว', 'en': 'Attraction', 'zh': '景点', 'ko': '관광지', 'ru': 'Достопримечательность', 'ja': '観光地',
  },
  'cat_tourist_info': {
    'th': 'ศูนย์บริการนักท่องเที่ยว', 'en': 'Tourist Information', 'zh': '游客服务中心', 'ko': '관광안내소', 'ru': 'Туристический центр', 'ja': '観光案内所',
  },

  // --- Safety Radar (Phase 2A task 2.1) ---
  'tool_safety_radar': {
    'th': 'เรดาร์ความปลอดภัย', 'en': 'Safety Radar', 'zh': '安全雷达', 'ko': '세이프티 레이더', 'ru': 'Радар безопасности', 'ja': 'セーフティレーダー',
  },
  'radar_title': {
    'th': 'เรดาร์ความปลอดภัย', 'en': 'Safety Radar', 'zh': '安全雷达', 'ko': '세이프티 레이더', 'ru': 'Радар безопасности', 'ja': 'セーフティレーダー',
  },
  'radar_subtitle': {
    'th': 'ดูข้อมูลรอบตัวคุณ',
    'en': "What's around me",
    'zh': '查看我周围的信息',
    'ko': '내 주변 정보 보기',
    'ru': 'Что рядом со мной',
    'ja': '周辺の情報を見る',
  },
  'radar_scan_button': {
    'th': 'ค้นหารอบตัวฉัน',
    'en': "What's Around Me",
    'zh': '搜索我的周围',
    'ko': '내 주변 검색',
    'ru': 'Что рядом со мной',
    'ja': '周辺を検索',
  },
  'radar_scan_again': {
    'th': 'ค้นหาอีกครั้ง', 'en': 'Search Again', 'zh': '重新搜索', 'ko': '다시 검색', 'ru': 'Искать снова', 'ja': '再検索',
  },
  'radar_scanning': {
    'th': 'กำลังค้นหาข้อมูลรอบตัวคุณ...', 'en': 'Searching around you...', 'zh': '正在搜索您周围的信息…', 'ko': '주변을 검색하는 중…', 'ru': 'Ищем вокруг вас…', 'ja': '周辺を検索しています…',
  },
  'radar_intro': {
    'th': 'ดูสถานที่ บริการฉุกเฉิน และข้อมูลพื้นที่รอบตำแหน่งของคุณ',
    'en': 'See places, emergency services and area information around your current location.',
    'zh': '查看您当前位置周围的地点、紧急服务和区域信息。',
    'ko': '현재 위치 주변의 장소, 응급 서비스, 지역 정보를 확인하세요.',
    'ru': 'Посмотрите места, экстренные службы и информацию о районе рядом с вами.',
    'ja': '現在地周辺の施設・緊急サービス・エリア情報を確認できます。',
  },
  'radar_radius': {
    'th': 'รัศมีการค้นหา', 'en': 'Search radius', 'zh': '搜索半径', 'ko': '검색 반경', 'ru': 'Радиус поиска', 'ja': '検索範囲',
  },
  'radar_results_found': {
    'th': 'พบ {count} รายการในรัศมีนี้',
    'en': 'Found {count} results in this radius',
    'zh': '在此范围内找到 {count} 条结果',
    'ko': '이 반경에서 {count}건을 찾았습니다',
    'ru': 'Найдено результатов в этом радиусе: {count}',
    'ja': 'この範囲で {count} 件見つかりました',
  },
  'radar_empty': {
    'th': 'ไม่พบข้อมูลในรัศมีนี้ ลองขยายรัศมีการค้นหาดูนะครับ',
    'en': 'No information found in this radius. Try a wider search radius.',
    'zh': '此范围内没有信息，请尝试扩大搜索半径。',
    'ko': '이 반경에는 정보가 없습니다. 검색 반경을 넓혀 보세요.',
    'ru': 'В этом радиусе ничего не найдено. Попробуйте увеличить радиус.',
    'ja': 'この範囲では情報が見つかりません。検索範囲を広げてみてください。',
  },
  'radar_empty_filtered': {
    'th': 'ไม่พบข้อมูลตามตัวกรองที่เลือก ลองปรับตัวกรองหรือขยายรัศมี',
    'en': 'Nothing matches the selected filters. Try adjusting them or widening the radius.',
    'zh': '没有符合所选筛选条件的结果，请调整筛选或扩大半径。',
    'ko': '선택한 필터와 일치하는 결과가 없습니다. 필터를 조정하거나 반경을 넓혀 보세요.',
    'ru': 'Нет результатов по выбранным фильтрам. Измените их или увеличьте радиус.',
    'ja': '選択したフィルターに一致する結果がありません。条件の変更か範囲の拡大をお試しください。',
  },
  'radar_location_denied': {
    'th': 'ต้องอนุญาตให้เข้าถึงตำแหน่งเพื่อค้นหาข้อมูลรอบตัวคุณ',
    'en': 'Location access is needed to search around you.',
    'zh': '需要位置权限才能搜索您周围的信息。',
    'ko': '주변을 검색하려면 위치 권한이 필요합니다.',
    'ru': 'Для поиска вокруг вас нужен доступ к геолокации.',
    'ja': '周辺を検索するには位置情報の許可が必要です。',
  },
  'radar_location_disabled': {
    'th': 'กรุณาเปิดบริการระบุตำแหน่งบนอุปกรณ์ของคุณ',
    'en': 'Please turn on location services on your device.',
    'zh': '请在您的设备上开启定位服务。',
    'ko': '기기에서 위치 서비스를 켜 주세요.',
    'ru': 'Пожалуйста, включите службы геолокации на устройстве.',
    'ja': '端末の位置情報サービスをオンにしてください。',
  },
  'radar_location_error': {
    'th': 'ไม่สามารถระบุตำแหน่งได้ กรุณาลองใหม่อีกครั้ง',
    'en': 'Could not get your location. Please try again.',
    'zh': '无法获取您的位置，请重试。',
    'ko': '위치를 확인할 수 없습니다. 다시 시도해 주세요.',
    'ru': 'Не удалось определить местоположение. Попробуйте ещё раз.',
    'ja': '位置情報を取得できませんでした。もう一度お試しください。',
  },
  'radar_load_error': {
    'th': 'โหลดข้อมูลไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
    'en': 'Could not load data. Please try again.',
    'zh': '数据加载失败，请重试。',
    'ko': '데이터를 불러오지 못했습니다. 다시 시도해 주세요.',
    'ru': 'Не удалось загрузить данные. Попробуйте ещё раз.',
    'ja': 'データを読み込めませんでした。もう一度お試しください。',
  },
  'radar_retry': {
    'th': 'ลองใหม่', 'en': 'Try Again', 'zh': '重试', 'ko': '다시 시도', 'ru': 'Повторить', 'ja': '再試行',
  },
  'radar_refresh': {
    'th': 'โหลดข้อมูลใหม่', 'en': 'Refresh', 'zh': '刷新', 'ko': '새로 고침', 'ru': 'Обновить', 'ja': '更新',
  },
  'radar_disclaimer': {
    'th': 'ข้อมูลนี้เป็นการประเมินจากข้อมูลสถิติและข้อมูลจากชุมชนเพื่อประกอบการตัดสินใจเท่านั้น ราคาจริงอาจแตกต่างกันได้',
    'en': 'This information is generated from statistical and community-based data and is intended for informational purposes only. Actual prices may vary.',
    'zh': '此信息基于统计和社区数据生成，仅供参考。实际价格可能有所不同。',
    'ko': '이 정보는 통계 및 커뮤니티 데이터를 기반으로 생성되었으며 참고용입니다. 실제 가격은 다를 수 있습니다.',
    'ru': 'Эта информация формируется на основе статистических и общественных данных и приведена исключительно в информационных целях. Фактические цены могут отличаться.',
    'ja': 'この情報は統計データとコミュニティデータに基づいて生成されたもので、参考情報です。実際の価格は異なる場合があります。',
  },
  'radar_group_zone_danger': {
    'th': 'พื้นที่ที่ชุมชนแจ้งเตือน', 'en': 'Community Alert Zone', 'zh': '社区提示区域', 'ko': '커뮤니티 알림 구역', 'ru': 'Зона общественных сообщений', 'ja': 'コミュニティ通知エリア',
  },
  'radar_group_zone_caution': {
    'th': 'พื้นที่คำแนะนำสำหรับนักท่องเที่ยว', 'en': 'Tourist Advisory Area', 'zh': '旅游提示区域', 'ko': '관광 안내 구역', 'ru': 'Зона рекомендаций для туристов', 'ja': '観光アドバイザリーエリア',
  },
  'radar_group_zone_safe': {
    'th': 'พื้นที่ข้อมูลการท่องเที่ยว', 'en': 'Travel Information Area', 'zh': '旅行信息区域', 'ko': '여행 정보 구역', 'ru': 'Зона туристической информации', 'ja': 'トラベル情報エリア',
  },
  'radar_group_emergency': {
    'th': 'บริการฉุกเฉิน', 'en': 'Emergency Services', 'zh': '紧急服务', 'ko': '응급 서비스', 'ru': 'Экстренные службы', 'ja': '緊急サービス',
  },
  'radar_group_partners': {
    'th': 'ธุรกิจพาร์ทเนอร์', 'en': 'Partner Businesses', 'zh': '合作商家', 'ko': '파트너 업체', 'ru': 'Партнёрские заведения', 'ja': 'パートナー店舗',
  },
  'radar_group_transport': {
    'th': 'การเดินทาง', 'en': 'Transport', 'zh': '交通', 'ko': '교통', 'ru': 'Транспорт', 'ja': '交通',
  },
  'radar_badge_certified': {
    'th': 'ราคามาตรฐานที่รับรอง', 'en': 'Certified Fair Price', 'zh': '认证公道价格', 'ko': '인증된 적정 가격', 'ru': 'Сертифицированная честная цена', 'ja': '認証済み適正価格',
  },
  'radar_badge_partner': {
    'th': 'ธุรกิจพาร์ทเนอร์', 'en': 'Partner Business', 'zh': '合作商家', 'ko': '파트너 업체', 'ru': 'Партнёр', 'ja': 'パートナー店舗',
  },
  'radar_badge_above_range': {
    'th': 'สูงกว่าช่วงราคาทั่วไป', 'en': 'Above Typical Range', 'zh': '高于一般价格范围', 'ko': '일반적인 가격대보다 높음', 'ru': 'Выше типичного диапазона', 'ja': '一般的な価格帯より高い',
  },
  'radar_you_are_inside': {
    'th': 'คุณอยู่ในพื้นที่นี้', 'en': 'You are in this area', 'zh': '您位于该区域内', 'ko': '현재 이 구역 안에 있습니다', 'ru': 'Вы находитесь в этой зоне', 'ja': 'このエリア内にいます',
  },
  'radar_view_on_map': {
    'th': 'ดูบนแผนที่', 'en': 'Show on Map', 'zh': '在地图上查看', 'ko': '지도에서 보기', 'ru': 'Показать на карте', 'ja': '地図で見る',
  },

  // --- Filter panel (Phase 2A task 2.3) ---
  'filter_title': {
    'th': 'ตัวกรอง', 'en': 'Filters', 'zh': '筛选', 'ko': '필터', 'ru': 'Фильтры', 'ja': 'フィルター',
  },
  'filter_subtitle': {
    'th': 'เลือกประเภทสถานที่และพื้นที่ที่ต้องการแสดง',
    'en': 'Choose which place types and areas to show',
    'zh': '选择要显示的地点类型和区域',
    'ko': '표시할 장소 유형과 구역을 선택하세요',
    'ru': 'Выберите, какие типы мест и зоны показывать',
    'ja': '表示する施設タイプとエリアを選択してください',
  },
  'filter_categories': {
    'th': 'ประเภทสถานที่', 'en': 'Place Types', 'zh': '地点类型', 'ko': '장소 유형', 'ru': 'Типы мест', 'ja': '施設タイプ',
  },
  'filter_areas': {
    'th': 'ประเภทพื้นที่', 'en': 'Area Types', 'zh': '区域类型', 'ko': '구역 유형', 'ru': 'Типы зон', 'ja': 'エリアタイプ',
  },
  'filter_select_all': {
    'th': 'เลือกทั้งหมด', 'en': 'Select All', 'zh': '全选', 'ko': '전체 선택', 'ru': 'Выбрать все', 'ja': 'すべて選択',
  },
  'filter_clear_all': {
    'th': 'ล้างทั้งหมด', 'en': 'Clear All', 'zh': '全部清除', 'ko': '전체 해제', 'ru': 'Снять все', 'ja': 'すべて解除',
  },
  'filter_apply': {
    'th': 'ใช้ตัวกรอง', 'en': 'Apply Filters', 'zh': '应用筛选', 'ko': '필터 적용', 'ru': 'Применить фильтры', 'ja': 'フィルターを適用',
  },
  'filter_active_count': {
    'th': 'ใช้ตัวกรอง {count} รายการ', 'en': '{count} filters active', 'zh': '已启用 {count} 个筛选条件', 'ko': '필터 {count}개 적용 중', 'ru': 'Активных фильтров: {count}', 'ja': 'フィルター {count} 件適用中',
  },

  // --- Alert Zone proximity card (Phase 2A task 2.2) ---
  'proximity_inside_title': {
    'th': 'คุณอยู่ในพื้นที่ที่มีข้อมูลแจ้งเตือน',
    'en': 'You are in an area with travel information',
    'zh': '您位于有旅行提示的区域',
    'ko': '여행 정보가 있는 구역에 있습니다',
    'ru': 'Вы находитесь в зоне с туристической информацией',
    'ja': '旅行情報のあるエリア内にいます',
  },
  'proximity_near_title': {
    'th': 'มีพื้นที่ที่มีข้อมูลแจ้งเตือนอยู่ใกล้คุณ',
    'en': 'There is an area with travel information near you',
    'zh': '您附近有带旅行提示的区域',
    'ko': '근처에 여행 정보가 있는 구역이 있습니다',
    'ru': 'Рядом с вами есть зона с туристической информацией',
    'ja': '近くに旅行情報のあるエリアがあります',
  },
  'proximity_distance_away': {
    'th': 'ห่างจากคุณประมาณ {distance}',
    'en': 'About {distance} from you',
    'zh': '距您约 {distance}',
    'ko': '현재 위치에서 약 {distance}',
    'ru': 'Примерно {distance} от вас',
    'ja': '現在地から約 {distance}',
  },
  'proximity_dismiss': {
    'th': 'ปิด', 'en': 'Dismiss', 'zh': '关闭', 'ko': '닫기', 'ru': 'Скрыть', 'ja': '閉じる',
  },
  'proximity_disclaimer': {
    'th': 'ข้อมูลนี้เป็นการประเมินจากข้อมูลสถิติและข้อมูลจากชุมชนเพื่อประกอบการตัดสินใจเท่านั้น',
    'en': 'This information is generated from statistical and community-based data and is intended for informational purposes only.',
    'zh': '此信息基于统计和社区数据生成，仅供参考。',
    'ko': '이 정보는 통계 및 커뮤니티 데이터를 기반으로 생성되었으며 참고용입니다.',
    'ru': 'Эта информация формируется на основе статистических и общественных данных и приведена исключительно в информационных целях.',
    'ja': 'この情報は統計データとコミュニティデータに基づいて生成されたもので、参考情報です。',
  },

  // --- Route Suggestion (Phase 2B task 2.4) ---
  //
  // Wording note (§10): this feature never claims a route is "safe" or that
  // it avoids anything — it reports distance and time as estimates from the
  // map provider and nothing more.
  //
  // The location-failure states other than "denied" reuse the generic
  // 'radar_location_disabled' / 'radar_location_error' / 'radar_retry' copy,
  // which says nothing radar-specific. Only the denied case needed its own
  // wording, because it has to explain what the permission is for here.
  'route_title': {
    'th': 'เส้นทางแนะนำ',
    'en': 'Route Suggestion',
    'zh': '路线建议',
    'ko': '경로 안내',
    'ru': 'Предлагаемый маршрут',
    'ja': 'ルート案内',
  },
  'route_subtitle': {
    'th': 'ประมาณการระยะทางและเวลาเดินทาง',
    'en': 'Estimated distance and travel time',
    'zh': '预计距离与行程时间',
    'ko': '예상 거리 및 소요 시간',
    'ru': 'Расчётное расстояние и время в пути',
    'ja': '距離と所要時間の目安',
  },
  'route_to': {
    'th': 'ไปยัง {name}',
    'en': 'To {name}',
    'zh': '前往 {name}',
    'ko': '{name}까지',
    'ru': 'До: {name}',
    'ja': '{name} へ',
  },
  'route_from_your_location': {
    'th': 'จากตำแหน่งปัจจุบันของคุณ',
    'en': 'From your current location',
    'zh': '从您的当前位置出发',
    'ko': '현재 위치에서 출발',
    'ru': 'От вашего текущего местоположения',
    'ja': '現在地から',
  },
  'route_mode_drive': {
    'th': 'รถยนต์', 'en': 'Drive', 'zh': '驾车', 'ko': '자동차', 'ru': 'На авто', 'ja': '車',
  },
  'route_mode_transit': {
    'th': 'ขนส่งสาธารณะ', 'en': 'Transit', 'zh': '公共交通', 'ko': '대중교통', 'ru': 'Транспорт', 'ja': '公共交通',
  },
  'route_mode_walk': {
    'th': 'เดิน', 'en': 'Walk', 'zh': '步行', 'ko': '도보', 'ru': 'Пешком', 'ja': '徒歩',
  },
  'route_locating': {
    'th': 'กำลังระบุตำแหน่งของคุณ…',
    'en': 'Finding your location…',
    'zh': '正在获取您的位置…',
    'ko': '현재 위치를 확인하는 중…',
    'ru': 'Определяем ваше местоположение…',
    'ja': '現在地を取得中…',
  },
  'route_calculating': {
    'th': 'กำลังคำนวณเส้นทาง…',
    'en': 'Calculating route…',
    'zh': '正在计算路线…',
    'ko': '경로를 계산하는 중…',
    'ru': 'Рассчитываем маршрут…',
    'ja': 'ルートを計算中…',
  },
  'route_estimated_time': {
    'th': 'เวลาโดยประมาณ', 'en': 'Estimated time', 'zh': '预计时间', 'ko': '예상 시간', 'ru': 'Примерное время', 'ja': '所要時間の目安',
  },
  'route_distance': {
    'th': 'ระยะทาง', 'en': 'Distance', 'zh': '距离', 'ko': '거리', 'ru': 'Расстояние', 'ja': '距離',
  },
  'route_duration_hm': {
    'th': '{h} ชม. {m} นาที',
    'en': '{h} hr {m} min',
    'zh': '{h} 小时 {m} 分钟',
    'ko': '{h}시간 {m}분',
    'ru': '{h} ч {m} мин',
    'ja': '{h} 時間 {m} 分',
  },
  'route_duration_m': {
    'th': '{m} นาที',
    'en': '{m} min',
    'zh': '{m} 分钟',
    'ko': '{m}분',
    'ru': '{m} мин',
    'ja': '{m} 分',
  },
  'route_open_in_maps': {
    'th': 'เปิดใน Google Maps',
    'en': 'Open in Google Maps',
    'zh': '在 Google 地图中打开',
    'ko': 'Google 지도에서 열기',
    'ru': 'Открыть в Google Картах',
    'ja': 'Google マップで開く',
  },
  'route_open_failed': {
    'th': 'ไม่สามารถเปิด Google Maps ได้',
    'en': 'Could not open Google Maps.',
    'zh': '无法打开 Google 地图。',
    'ko': 'Google 지도를 열 수 없습니다.',
    'ru': 'Не удалось открыть Google Карты.',
    'ja': 'Google マップを開けませんでした。',
  },
  'route_directions_button': {
    'th': 'ดูเส้นทาง', 'en': 'Directions', 'zh': '路线', 'ko': '길찾기', 'ru': 'Маршрут', 'ja': 'ルート',
  },
  'route_location_denied': {
    'th': 'ต้องอนุญาตให้เข้าถึงตำแหน่งเพื่อคำนวณเส้นทางจากจุดที่คุณอยู่',
    'en': 'Location access is needed to build a route from where you are.',
    'zh': '需要位置权限才能从您所在位置规划路线。',
    'ko': '현재 위치에서 경로를 만들려면 위치 권한이 필요합니다.',
    'ru': 'Для построения маршрута от вашего местоположения нужен доступ к геолокации.',
    'ja': '現在地からのルートを作成するには位置情報の許可が必要です。',
  },
  'route_error_not_configured': {
    'th': 'ฟีเจอร์เส้นทางยังไม่พร้อมใช้งานในแอปเวอร์ชันนี้',
    'en': 'Route suggestions are not available in this build.',
    'zh': '此版本暂不支持路线建议。',
    'ko': '이 버전에서는 경로 안내를 사용할 수 없습니다.',
    'ru': 'Маршруты недоступны в этой сборке.',
    'ja': 'このバージョンではルート案内を利用できません。',
  },
  'route_error_no_route': {
    'th': 'ไม่พบเส้นทางสำหรับการเดินทางรูปแบบนี้ ลองเลือกรูปแบบอื่น',
    'en': 'No route found for this travel mode. Try another mode.',
    'zh': '未找到此出行方式的路线，请尝试其他方式。',
    'ko': '이 이동 수단으로는 경로를 찾을 수 없습니다. 다른 수단을 선택해 보세요.',
    'ru': 'Маршрут для этого способа передвижения не найден. Попробуйте другой.',
    'ja': 'この移動手段のルートが見つかりません。別の手段をお試しください。',
  },
  'route_error_network': {
    'th': 'เชื่อมต่ออินเทอร์เน็ตไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
    'en': 'Could not connect. Please try again.',
    'zh': '连接失败，请重试。',
    'ko': '연결하지 못했습니다. 다시 시도해 주세요.',
    'ru': 'Не удалось подключиться. Попробуйте ещё раз.',
    'ja': '接続できませんでした。もう一度お試しください。',
  },
  'route_error_request': {
    'th': 'ไม่สามารถคำนวณเส้นทางได้ในขณะนี้ กรุณาลองใหม่อีกครั้ง',
    'en': 'Could not calculate a route right now. Please try again.',
    'zh': '目前无法计算路线，请重试。',
    'ko': '지금은 경로를 계산할 수 없습니다. 다시 시도해 주세요.',
    'ru': 'Сейчас не удалось рассчитать маршрут. Попробуйте ещё раз.',
    'ja': '現在ルートを計算できません。もう一度お試しください。',
  },
  'route_disclaimer': {
    'th': 'เส้นทาง ระยะทาง และเวลาที่แสดงเป็นข้อมูลประมาณการจากผู้ให้บริการแผนที่เพื่อประกอบการตัดสินใจเท่านั้น สภาพการจราจรและเส้นทางจริงอาจแตกต่างกันได้ โปรดปฏิบัติตามกฎจราจรและป้ายบอกทางเสมอ',
    'en': 'Routes, distances and times shown are estimates provided by the map service and are intended for informational purposes only. Actual traffic and road conditions may differ. Always follow local traffic rules and road signs.',
    'zh': '所显示的路线、距离和时间为地图服务提供的估算值，仅供参考。实际交通与道路状况可能有所不同。请始终遵守当地交通规则和道路标志。',
    'ko': '표시된 경로, 거리, 소요 시간은 지도 서비스가 제공하는 추정치이며 참고용입니다. 실제 교통 및 도로 상황은 다를 수 있습니다. 항상 현지 교통 법규와 도로 표지를 따르세요.',
    'ru': 'Показанные маршруты, расстояния и время — это оценки картографического сервиса, приведённые исключительно в информационных целях. Реальная дорожная обстановка может отличаться. Всегда соблюдайте местные правила дорожного движения и дорожные знаки.',
    'ja': '表示されているルート、距離、所要時間は地図サービスによる推定値で、参考情報です。実際の交通・道路状況は異なる場合があります。現地の交通ルールと道路標識に必ず従ってください。',
  },

  // --- Paywall & feature gating (Phase 2B task 2.5) ---
  //
  // Wording note (§10): paywall copy is explicitly in scope for the wording
  // rules, so every line here describes what a tool *does* — it never sells
  // safety, never implies the app protects anyone, and never characterises any
  // place or business.
  'premium_title': {
    'th': 'ThaiShield Premium',
    'en': 'ThaiShield Premium',
    'zh': 'ThaiShield Premium',
    'ko': 'ThaiShield Premium',
    'ru': 'ThaiShield Premium',
    'ja': 'ThaiShield Premium',
  },
  'premium_subtitle': {
    'th': 'ปลดล็อกเครื่องมือวางแผนการเดินทางทั้งหมด',
    'en': 'Unlock the full set of trip-planning tools',
    'zh': '解锁全部行程规划工具',
    'ko': '여행 계획 도구 전체 잠금 해제',
    'ru': 'Откройте все инструменты планирования поездки',
    'ja': '旅行プランニング機能をすべて利用できます',
  },
  'premium_feature_radar': {
    'th': 'ดูผลการค้นหารอบตัวได้ทั้งหมด',
    'en': 'See every result around you',
    'zh': '查看您周围的全部结果',
    'ko': '주변의 모든 검색 결과 보기',
    'ru': 'Все результаты поиска вокруг вас',
    'ja': '周辺の検索結果をすべて表示',
  },
  'premium_feature_filter': {
    'th': 'กรองตามหมวดหมู่และระดับข้อมูลพื้นที่',
    'en': 'Filter by category and area information level',
    'zh': '按类别与区域信息等级筛选',
    'ko': '카테고리 및 구역 정보 등급별 필터',
    'ru': 'Фильтр по категории и уровню информации о зоне',
    'ja': 'カテゴリーとエリア情報レベルで絞り込み',
  },
  'premium_feature_route': {
    'th': 'ดูเส้นทางและเวลาเดินทางโดยประมาณ',
    'en': 'See routes and estimated travel time',
    'zh': '查看路线与预计行程时间',
    'ko': '경로와 예상 소요 시간 확인',
    'ru': 'Маршруты и расчётное время в пути',
    'ja': 'ルートと所要時間の目安を表示',
  },
  'premium_benefits_title': {
    'th': 'สิ่งที่คุณจะได้รับ',
    'en': 'What you get',
    'zh': '包含内容',
    'ko': '포함 기능',
    'ru': 'Что входит',
    'ja': '含まれる機能',
  },
  'premium_plan_monthly': {
    'th': 'รายเดือน', 'en': 'Monthly', 'zh': '按月', 'ko': '월간', 'ru': 'Ежемесячно', 'ja': '月額',
  },
  'premium_plan_yearly': {
    'th': 'รายปี', 'en': 'Yearly', 'zh': '按年', 'ko': '연간', 'ru': 'Ежегодно', 'ja': '年額',
  },
  'premium_plan_lifetime': {
    'th': 'ตลอดชีพ', 'en': 'Lifetime', 'zh': '永久', 'ko': '평생', 'ru': 'Навсегда', 'ja': '買い切り',
  },
  'premium_period_monthly': {
    'th': 'ต่อเดือน', 'en': 'per month', 'zh': '每月', 'ko': '월', 'ru': 'в месяц', 'ja': '月ごと',
  },
  'premium_period_yearly': {
    'th': 'ต่อปี', 'en': 'per year', 'zh': '每年', 'ko': '년', 'ru': 'в год', 'ja': '年ごと',
  },
  'premium_period_lifetime': {
    'th': 'จ่ายครั้งเดียว', 'en': 'one-time', 'zh': '一次性付款', 'ko': '1회 결제', 'ru': 'разовый платёж', 'ja': '一度のお支払い',
  },
  'premium_badge_recommended': {
    'th': 'คุ้มที่สุด', 'en': 'Best value', 'zh': '最超值', 'ko': '최고 가성비', 'ru': 'Выгоднее всего', 'ja': 'いちばんお得',
  },
  'premium_price_note': {
    'th': 'ราคาที่คุณต้องจ่ายจริงคือราคาที่แสดงใน Google Play หรือ App Store ของประเทศคุณ ซึ่งอาจต่างจากที่แสดงที่นี่ตามสกุลเงินและภาษี',
    'en': 'The price you pay is the one shown by Google Play or the App Store in your country, which may differ from the figure here depending on currency and tax.',
    'zh': '您实际支付的价格以您所在国家/地区的 Google Play 或 App Store 显示为准，可能因币种与税费而与此处不同。',
    'ko': '실제 결제 금액은 사용자 국가의 Google Play 또는 App Store에 표시된 가격이며, 통화와 세금에 따라 여기 표시된 금액과 다를 수 있습니다.',
    'ru': 'Вы платите ту цену, которая указана в Google Play или App Store вашей страны; она может отличаться от приведённой здесь из-за валюты и налогов.',
    'ja': '実際にお支払いいただく金額は、お住まいの国の Google Play または App Store に表示される価格です。通貨や税により、ここに表示された金額と異なる場合があります。',
  },
  'premium_cta': {
    'th': 'สมัคร Premium', 'en': 'Get Premium', 'zh': '获取 Premium', 'ko': 'Premium 시작하기', 'ru': 'Получить Premium', 'ja': 'Premium を利用する',
  },
  'premium_store_unavailable': {
    'th': 'ระบบชำระเงินจะเปิดใช้งานในเวอร์ชันถัดไป',
    'en': 'Purchases open in a later version.',
    'zh': '购买功能将在后续版本开放。',
    'ko': '결제 기능은 다음 버전에서 제공됩니다.',
    'ru': 'Покупки станут доступны в следующей версии.',
    'ja': '購入機能は今後のバージョンで提供されます。',
  },
  'premium_restore': {
    'th': 'กู้คืนการซื้อ', 'en': 'Restore Purchases', 'zh': '恢复购买', 'ko': '구매 복원', 'ru': 'Восстановить покупки', 'ja': '購入を復元',
  },
  'premium_platform_note': {
    'th': 'การซื้อจะผูกกับบัญชี Google Play หรือ Apple ID ที่ใช้ซื้อ ติดตั้งใหม่หรือเปลี่ยนเครื่องแล้วกดกู้คืนการซื้อได้ แต่ไม่สามารถโอนข้ามระหว่าง Android และ iOS',
    'en': 'Your purchase is tied to the Google Play or Apple ID account you buy it with. Reinstalling or moving to a new phone restores it, but it does not transfer between Android and iOS.',
    'zh': '购买将绑定到您用于付款的 Google Play 或 Apple ID 账户。重装或更换手机后可恢复购买，但无法在 Android 与 iOS 之间转移。',
    'ko': '구매는 결제에 사용한 Google Play 또는 Apple ID 계정에 연결됩니다. 재설치하거나 새 기기로 옮겨도 복원할 수 있지만 Android와 iOS 사이에는 이전되지 않습니다.',
    'ru': 'Покупка привязана к аккаунту Google Play или Apple ID, через который она совершена. После переустановки или смены телефона её можно восстановить, но она не переносится между Android и iOS.',
    'ja': '購入は決済に使用した Google Play または Apple ID のアカウントに紐づきます。再インストールや機種変更後は復元できますが、Android と iOS の間では引き継げません。',
  },
  'premium_legal_note': {
    'th': 'แพ็กเกจรายเดือนและรายปีจะต่ออายุอัตโนมัติ ยกเลิกได้ทุกเมื่อจากการตั้งค่าบัญชี Google Play หรือ Apple ID',
    'en': 'Monthly and yearly plans renew automatically. You can cancel any time in your Google Play or Apple ID account settings.',
    'zh': '按月与按年套餐将自动续订。您可随时在 Google Play 或 Apple ID 账户设置中取消。',
    'ko': '월간 및 연간 플랜은 자동으로 갱신됩니다. Google Play 또는 Apple ID 계정 설정에서 언제든지 해지할 수 있습니다.',
    'ru': 'Ежемесячный и ежегодный планы продлеваются автоматически. Отменить можно в любой момент в настройках аккаунта Google Play или Apple ID.',
    'ja': '月額プランと年額プランは自動更新されます。Google Play または Apple ID のアカウント設定からいつでも解約できます。',
  },
  'premium_status_free_title': {
    'th': 'อัปเกรดเป็น Premium',
    'en': 'Upgrade to Premium',
    'zh': '升级到 Premium',
    'ko': 'Premium으로 업그레이드',
    'ru': 'Перейти на Premium',
    'ja': 'Premium にアップグレード',
  },
  'premium_status_free_subtitle': {
    'th': 'เรดาร์แบบเต็ม ตัวกรอง และเส้นทางแนะนำ',
    'en': 'Full radar results, filters and route suggestions',
    'zh': '完整雷达结果、筛选与路线建议',
    'ko': '전체 레이더 결과, 필터, 경로 안내',
    'ru': 'Все результаты радара, фильтры и маршруты',
    'ja': 'レーダーの全結果・フィルター・ルート案内',
  },
  'premium_status_active_title': {
    'th': 'Premium กำลังใช้งาน',
    'en': 'Premium active',
    'zh': 'Premium 已启用',
    'ko': 'Premium 사용 중',
    'ru': 'Premium активен',
    'ja': 'Premium 有効',
  },
  'premium_status_expires': {
    'th': 'ใช้ได้ถึง {date}',
    'en': 'Valid until {date}',
    'zh': '有效期至 {date}',
    'ko': '{date}까지 이용 가능',
    'ru': 'Действует до {date}',
    'ja': '{date} まで有効',
  },
  'premium_status_qa': {
    'th': 'ปลดล็อกสำหรับการทดสอบ (QA)',
    'en': 'Unlocked for testing (QA)',
    'zh': '测试解锁 (QA)',
    'ko': '테스트용 잠금 해제 (QA)',
    'ru': 'Разблокировано для тестирования (QA)',
    'ja': 'テスト用に解除中 (QA)',
  },
  'premium_upgrade_action': {
    'th': 'ดูแพ็กเกจ', 'en': 'View plans', 'zh': '查看套餐', 'ko': '플랜 보기', 'ru': 'Тарифы', 'ja': 'プランを見る',
  },
  'premium_locked_results': {
    'th': 'มีผลการค้นหาอีก {count} รายการในรัศมีนี้',
    'en': '{count} more results within this radius',
    'zh': '此范围内还有 {count} 条结果',
    'ko': '이 반경 안에 {count}개의 결과가 더 있습니다',
    'ru': 'Ещё {count} результатов в этом радиусе',
    'ja': 'この範囲にあと {count} 件の結果があります',
  },
  'premium_locked_action': {
    'th': 'ปลดล็อกด้วย Premium',
    'en': 'Unlock with Premium',
    'zh': '通过 Premium 解锁',
    'ko': 'Premium으로 잠금 해제',
    'ru': 'Открыть с Premium',
    'ja': 'Premium で解除',
  },
};

/// Every string in every language, keyed the same way [appText] reads them.
///
/// Exposed so tests can assert on the copy itself without a widget tree —
/// specifically that a key exists in all six languages, and that it obeys the
/// §10 wording rules. Widgets should call [appText] instead.
Map<String, Map<String, String>> get appStrings => _appText;

/// Returns the localized string for [key] based on the app's current
/// locale, falling back to English if no translation exists.
String appText(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  final entry = _appText[key];
  if (entry == null) return key;
  return entry[code] ?? entry['en'] ?? key;
}
