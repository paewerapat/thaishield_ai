import { initializeApp } from 'firebase/app';
import { getFirestore, doc, setDoc, serverTimestamp, GeoPoint } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyDWw6C1hHSmuATc_zC6FP545J1gqK36UQE',
  projectId: 'thaishield-ai-790eb',
  storageBucket: 'thaishield-ai-790eb.firebasestorage.app',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// Builds an irregular hexagon of GeoPoints around a center point, used to
// render alert zones as area shapes on the map instead of plain circles.
//
// Note the multipliers reach 1.15, so `radiusKm` is the *nominal* size of the
// shape, NOT its bounding radius — never store it as `radius_km`. Derive the
// stored fields with `derivedZoneFields` below instead.
function polygonAround(lat, lng, radiusKm) {
  const latOffset = radiusKm / 111;
  const lngOffset = radiusKm / (111 * Math.cos((lat * Math.PI) / 180));
  const angles = [90, 150, 220, 270, 330, 30];
  const mults = [1.0, 0.75, 1.1, 0.85, 1.15, 0.9];
  return angles.map((deg, i) => {
    const rad = (deg * Math.PI) / 180;
    return new GeoPoint(
      lat + latOffset * mults[i] * Math.sin(rad),
      lng + lngOffset * mults[i] * Math.cos(rad),
    );
  });
}

const toRadians = (deg) => (deg * Math.PI) / 180;

/** Great-circle distance in km — same formula as the CMS's lib/geo/polygon.ts. */
function haversineKm(a, b) {
  const EARTH_RADIUS_KM = 6371;
  const dLat = toRadians(b.lat - a.lat);
  const dLng = toRadians(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(a.lat)) * Math.cos(toRadians(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(h));
}

/** Area-weighted centroid (shoelace), planar — mirrors computePolygonCentroid. */
function centroidOf(points) {
  let area = 0;
  let cx = 0;
  let cy = 0;
  for (let i = 0; i < points.length; i++) {
    const p0 = points[i];
    const p1 = points[(i + 1) % points.length];
    const cross = p0.lng * p1.lat - p1.lng * p0.lat;
    area += cross;
    cx += (p0.lng + p1.lng) * cross;
    cy += (p0.lat + p1.lat) * cross;
  }
  area /= 2;
  if (Math.abs(area) < 1e-12) {
    const sum = points.reduce((a, p) => ({ lat: a.lat + p.lat, lng: a.lng + p.lng }), { lat: 0, lng: 0 });
    return { lat: sum.lat / points.length, lng: sum.lng / points.length };
  }
  return { lat: cy / (6 * area), lng: cx / (6 * area) };
}

/**
 * Derives `center_lat` / `center_lng` / `radius_km` FROM the polygon, exactly
 * as the CMS does on every save (lib/geo/polygon.ts).
 *
 * These fields used to be hard-coded next to the polygon, which put all five
 * seeded zones ~13% short: `radius_km` was the nominal size passed to
 * `polygonAround`, but that helper pushes vertices out to 1.15× it. Since
 * `geo_utils.isInsideZone` uses center + radius_km as a bounding-circle
 * rejection BEFORE the precise polygon test, a tourist standing near a corner
 * of a zone was thrown out at the first gate — no Radar hit, no proximity
 * card. See INTEGRATION_TEST.md §F2.
 */
function derivedZoneFields(polygon) {
  const points = polygon.map((p) => ({ lat: p.latitude, lng: p.longitude }));
  const center = centroidOf(points);
  return {
    center_lat: center.lat,
    center_lng: center.lng,
    radius_km: points.reduce((max, p) => Math.max(max, haversineKm(center, p)), 0),
  };
}

// Free-to-use stock photos (Pexels License — free for commercial use, no
// attribution required) used as placeholder imagery until real photos exist.
const placeholderImages = {
  hotel: 'https://images.pexels.com/photos/14580368/pexels-photo-14580368.jpeg?auto=compress&cs=tinysrgb&w=800',
  restaurant: 'https://images.pexels.com/photos/776538/pexels-photo-776538.jpeg?auto=compress&cs=tinysrgb&w=800',
  transport: 'https://images.pexels.com/photos/29817094/pexels-photo-29817094.jpeg?auto=compress&cs=tinysrgb&w=800',
};

// Dish reference photos grouped by food family (Pexels License).
const dishImages = {
  noodle:      'https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?auto=compress&cs=tinysrgb&w=800',
  basil_stir:  'https://images.pexels.com/photos/3850838/pexels-photo-3850838.jpeg?auto=compress&cs=tinysrgb&w=800',
  curry:       'https://images.pexels.com/photos/2347311/pexels-photo-2347311.jpeg?auto=compress&cs=tinysrgb&w=800',
  tom_yum:     'https://images.pexels.com/photos/4518843/pexels-photo-4518843.jpeg?auto=compress&cs=tinysrgb&w=800',
  fried_rice:  'https://images.pexels.com/photos/723198/pexels-photo-723198.jpeg?auto=compress&cs=tinysrgb&w=800',
  stir_fry:    'https://images.pexels.com/photos/6260921/pexels-photo-6260921.jpeg?auto=compress&cs=tinysrgb&w=800',
  egg:         'https://images.pexels.com/photos/824635/pexels-photo-824635.jpeg?auto=compress&cs=tinysrgb&w=800',
  salad:       'https://images.pexels.com/photos/1279330/pexels-photo-1279330.jpeg?auto=compress&cs=tinysrgb&w=800',
  tuk_tuk:     'https://images.pexels.com/photos/29817094/pexels-photo-29817094.jpeg?auto=compress&cs=tinysrgb&w=800',
  temple:      'https://images.pexels.com/photos/2736135/pexels-photo-2736135.jpeg?auto=compress&cs=tinysrgb&w=800',
};

const partnerLocations = {
  landmark_bangkok: {
    name: 'The Landmark Bangkok',
    lat: 13.7401, lng: 100.5601,
    type: 'hotel', rating: 4.8,
    is_verified: true, price_tier: 'fair',
    image_url: placeholderImages.hotel,
  },
  chatuchak_restaurant_01: {
    name: 'Chatuchak Local Kitchen',
    lat: 13.7999, lng: 100.5500,
    type: 'restaurant', rating: 4.2,
    is_verified: true, price_tier: 'fair',
    image_url: placeholderImages.restaurant,
  },
  siam_tuk_tuk_stand: {
    name: 'Siam Tuk Tuk Stand',
    lat: 13.7466, lng: 100.5347,
    type: 'transport', rating: 3.6,
    is_verified: false, price_tier: 'caution',
    image_url: placeholderImages.transport,
  },
  silom_restaurant_02: {
    name: 'Silom Night Market Grill',
    lat: 13.7244, lng: 100.5290,
    type: 'restaurant', rating: 4.5,
    is_verified: true, price_tier: 'fair',
    image_url: placeholderImages.restaurant,
  },
  sukhumvit_hotel_01: {
    name: 'Sukhumvit Boutique Inn',
    lat: 13.7300, lng: 100.5700,
    type: 'hotel', rating: 4.1,
    is_verified: true, price_tier: 'fair',
    image_url: placeholderImages.hotel,
  },

  // --- Categories added by the 3 -> 11 `type` expansion (Phase 2A task 2.3).
  // Sample entries so every Safety Radar group has content to render; they
  // carry no photo, which the app already handles (`image_url` may be "").
  silom_community_hospital: {
    name: 'Silom Community Hospital',
    lat: 13.7261, lng: 100.5340,
    type: 'hospital', rating: 4.4,
    is_verified: true, price_tier: 'fair',
    image_url: '',
  },
  sukhumvit_pharmacy_01: {
    name: 'Sukhumvit Pharmacy',
    lat: 13.7321, lng: 100.5665,
    type: 'pharmacy', rating: 4.0,
    is_verified: true, price_tier: 'fair',
    image_url: '',
  },
  bangrak_police_station: {
    name: 'Bang Rak Police Station',
    lat: 13.7286, lng: 100.5241,
    type: 'police', rating: 4.0,
    is_verified: true, price_tier: 'fair',
    image_url: '',
  },
  khaosan_tourist_police: {
    name: 'Khaosan Tourist Police Point',
    lat: 13.7585, lng: 100.4980,
    type: 'tourist_police', rating: 4.3,
    is_verified: true, price_tier: 'fair',
    image_url: '',
  },
  siam_atm_point: {
    name: 'Siam Square Bank & ATM Point',
    lat: 13.7455, lng: 100.5340,
    type: 'atm_bank', rating: 4.1,
    is_verified: true, price_tier: 'fair',
    image_url: '',
  },
  chatuchak_market_shops: {
    name: 'Chatuchak Weekend Market Shops',
    lat: 13.7996, lng: 100.5502,
    type: 'shopping', rating: 4.3,
    is_verified: false, price_tier: 'caution',
    image_url: '',
  },
  wat_pho_attraction: {
    name: 'Wat Pho Temple Area',
    lat: 13.7465, lng: 100.4933,
    type: 'attraction', rating: 4.7,
    is_verified: true, price_tier: 'fair',
    image_url: dishImages.temple,
  },
  silom_tourist_info: {
    name: 'Silom Tourist Information Centre',
    lat: 13.7250, lng: 100.5300,
    type: 'tourist_info', rating: 4.2,
    is_verified: true, price_tier: 'fair',
    image_url: '',
  },
};

/**
 * Draws the polygon around (lat, lng) at the given nominal size, then derives
 * center_lat/center_lng/radius_km from the result — never the other way round.
 * `sizeKm` shapes the polygon only; it is deliberately not stored anywhere.
 */
function zone({ name, lat, lng, sizeKm, risk_level, description_en, description_th }) {
  const polygon = polygonAround(lat, lng, sizeKm);
  return { name, polygon, ...derivedZoneFields(polygon), risk_level, description_en, description_th };
}

const alertZones = {
  zone_silom_safe: zone({
    name: 'Silom Business District',
    lat: 13.7244, lng: 100.5278, sizeKm: 1.0,
    risk_level: 'safe',
    description_en: 'Business and tourist-friendly area with verified partners.',
    description_th: 'ย่านธุรกิจและท่องเที่ยว มีพาร์ทเนอร์ที่ผ่านการรับรอง',
  }),
  zone_khaosan_caution: zone({
    name: 'Khaosan Road Area',
    lat: 13.7590, lng: 100.4972, sizeKm: 0.5,
    risk_level: 'caution',
    description_en: 'Popular tourist area. Tuk-tuk and tour pricing here may vary significantly from typical rates — compare before booking.',
    description_th: 'พื้นที่ท่องเที่ยวที่ได้รับความนิยม ราคาตุ๊กตุ๊กและทัวร์ในบริเวณนี้อาจแตกต่างจากราคาทั่วไป ควรเปรียบเทียบราคาก่อนตัดสินใจ',
  }),
  zone_patpong_caution: zone({
    name: 'Patpong Night Bazaar',
    lat: 13.7274, lng: 100.5300, sizeKm: 0.4,
    risk_level: 'caution',
    description_en: 'Busy night market area. Prices and conditions here may vary — please stay alert to your surroundings and confirm prices before purchasing.',
    description_th: 'ตลาดนัดกลางคืนที่มีผู้คนพลุกพล่าน โปรดดูแลทรัพย์สินส่วนตัวและตรวจสอบราคาก่อนตัดสินใจซื้อ',
  }),
  zone_danger_01: zone({
    name: 'Community Alert Zone',
    lat: 13.7500, lng: 100.5200, sizeKm: 0.3,
    risk_level: 'danger',
    description_en: 'Increased community reports in this area. Extra caution is recommended, especially at night.',
    description_th: 'มีรายงานจากชุมชนในพื้นที่นี้เพิ่มขึ้น แนะนำให้เพิ่มความระมัดระวังเป็นพิเศษ โดยเฉพาะช่วงเวลากลางคืน',
  }),
  zone_sukhumvit_safe: zone({
    name: 'Sukhumvit Tourist Zone',
    lat: 13.7300, lng: 100.5680, sizeKm: 1.2,
    risk_level: 'safe',
    description_en: 'Well-lit tourist corridor with hotels and verified restaurants.',
    description_th: 'แหล่งท่องเที่ยวมีแสงสว่าง มีโรงแรมและร้านอาหารที่ผ่านการรับรอง',
  }),
};

const priceStandards = {
  pad_thai: {
    name_en: 'Pad Thai', name_th: 'ผัดไทย', name_zh: '炒河粉',
    name_ko: '팟타이', name_ru: 'Пад Тай', name_ja: 'パッタイ',
    min_price: 80, max_price: 120, category: 'food', image_url: dishImages.noodle,
  },
  tom_yum_goong: {
    name_en: 'Tom Yum Goong', name_th: 'ต้มยำกุ้ง', name_zh: '冬阴功虾',
    name_ko: '똠얌꿍', name_ru: 'Том Ям Кунг', name_ja: 'トムヤムクン',
    min_price: 150, max_price: 250, category: 'food', image_url: dishImages.tom_yum,
  },
  green_curry: {
    name_en: 'Green Curry', name_th: 'แกงเขียวหวาน', name_zh: '绿咖喱',
    name_ko: '그린 커리', name_ru: 'Зелёный карри', name_ja: 'グリーンカレー',
    min_price: 100, max_price: 180, category: 'food', image_url: dishImages.curry,
  },
  tuk_tuk_short: {
    name_en: 'Tuk Tuk (Short Trip)', name_th: 'ตุ๊กตุ๊ก (ระยะสั้น)', name_zh: '嘟嘟车 (短途)',
    name_ko: '뚝뚝 (단거리)', name_ru: 'Тук-Тук (короткий)', name_ja: 'トゥクトゥク（近距離）',
    min_price: 60, max_price: 100, category: 'transport', image_url: dishImages.tuk_tuk,
  },
  taxi_meter: {
    name_en: 'Taxi (Meter)', name_th: 'แท็กซี่ (มิเตอร์)', name_zh: '出租车 (计价器)',
    name_ko: '택시 (미터)', name_ru: 'Такси (счётчик)', name_ja: 'タクシー（メーター）',
    min_price: 35, max_price: 200, category: 'transport', image_url: dishImages.tuk_tuk,
  },
  grand_palace: {
    name_en: 'Grand Palace Entrance', name_th: 'พระบรมมหาราชวัง', name_zh: '大皇宫门票',
    name_ko: '왕궁 입장료', name_ru: 'Большой дворец', name_ja: '王宮入場料',
    min_price: 500, max_price: 500, category: 'attraction', image_url: dishImages.temple,
  },

  // --- Krapao (Holy Basil stir-fry) ---
  krapao_moo_sap: {
    name_en: 'Stir-Fried Minced Pork with Basil', name_th: 'กะเพราหมูสับ', name_zh: '罗勒炒猪肉末',
    name_ko: '바질 다진 돼지고기 볶음', name_ru: 'Жареная свинина с базиликом', name_ja: 'ガパオ豚ひき肉炒め',
    min_price: 60, max_price: 90, category: 'food', image_url: dishImages.basil_stir,
  },
  krapao_gai: {
    name_en: 'Stir-Fried Chicken with Basil', name_th: 'กะเพราไก่', name_zh: '罗勒炒鸡肉',
    name_ko: '바질 치킨 볶음', name_ru: 'Жареная курица с базиликом', name_ja: 'ガパオチキン炒め',
    min_price: 60, max_price: 90, category: 'food', image_url: dishImages.basil_stir,
  },
  krapao_neua: {
    name_en: 'Stir-Fried Beef with Basil', name_th: 'กะเพราเนื้อ', name_zh: '罗勒炒牛肉',
    name_ko: '바질 소고기 볶음', name_ru: 'Жареная говядина с базиликом', name_ja: 'ガパオ牛肉炒め',
    min_price: 70, max_price: 110, category: 'food', image_url: dishImages.basil_stir,
  },
  krapao_moo_grob: {
    name_en: 'Stir-Fried Crispy Pork with Basil', name_th: 'กะเพราหมูกรอบ', name_zh: '罗勒炒脆皮猪肉',
    name_ko: '바질 바삭한 돼지고기 볶음', name_ru: 'Жареная хрустящая свинина с базиликом', name_ja: 'ガパオカリカリ豚肉炒め',
    min_price: 70, max_price: 110, category: 'food', image_url: dishImages.basil_stir,
  },
  krapao_talay: {
    name_en: 'Stir-Fried Seafood with Basil', name_th: 'กะเพราทะเล', name_zh: '罗勒炒海鲜',
    name_ko: '바질 해산물 볶음', name_ru: 'Жареные морепродукты с базиликом', name_ja: 'ガパオシーフード炒め',
    min_price: 90, max_price: 150, category: 'food', image_url: dishImages.basil_stir,
  },

  // --- Garlic pepper stir-fry ---
  moo_kratiem: {
    name_en: 'Garlic Pepper Pork', name_th: 'หมูกระเทียม', name_zh: '蒜蓉胡椒猪肉',
    name_ko: '마늘 후추 돼지고기', name_ru: 'Свинина с чесноком и перцем', name_ja: '豚肉のニンニク胡椒炒め',
    min_price: 60, max_price: 90, category: 'food', image_url: dishImages.stir_fry,
  },
  gai_kratiem: {
    name_en: 'Garlic Pepper Chicken', name_th: 'ไก่กระเทียม', name_zh: '蒜蓉胡椒鸡肉',
    name_ko: '마늘 후추 치킨', name_ru: 'Курица с чесноком и перцем', name_ja: '鶏肉のニンニク胡椒炒め',
    min_price: 60, max_price: 90, category: 'food', image_url: dishImages.stir_fry,
  },
  neua_kratiem: {
    name_en: 'Garlic Pepper Beef', name_th: 'เนื้อกระเทียม', name_zh: '蒜蓉胡椒牛肉',
    name_ko: '마늘 후추 소고기', name_ru: 'Говядина с чесноком и перцем', name_ja: '牛肉のニンニク胡椒炒め',
    min_price: 80, max_price: 130, category: 'food', image_url: dishImages.stir_fry,
  },

  // --- Curry paste stir-fry ---
  pad_prik_gaeng_moo: {
    name_en: 'Stir-Fried Pork with Curry Paste', name_th: 'ผัดพริกแกงหมู', name_zh: '咖喱酱炒猪肉',
    name_ko: '커리 페이스트 돼지고기 볶음', name_ru: 'Свинина, жареная с карри-пастой', name_ja: '豚肉のカレーペースト炒め',
    min_price: 60, max_price: 100, category: 'food', image_url: dishImages.curry,
  },
  pad_prik_gaeng_gai: {
    name_en: 'Stir-Fried Chicken with Curry Paste', name_th: 'ผัดพริกแกงไก่', name_zh: '咖喱酱炒鸡肉',
    name_ko: '커리 페이스트 치킨 볶음', name_ru: 'Курица, жареная с карри-пастой', name_ja: '鶏肉のカレーペースト炒め',
    min_price: 60, max_price: 100, category: 'food', image_url: dishImages.curry,
  },
  pad_prik_gaeng_pla_duk: {
    name_en: 'Stir-Fried Catfish with Curry Paste', name_th: 'ผัดพริกแกงปลาดุก', name_zh: '咖喱酱炒鲶鱼',
    name_ko: '커리 페이스트 메기 볶음', name_ru: 'Сом, жареный с карри-пастой', name_ja: 'ナマズのカレーペースト炒め',
    min_price: 80, max_price: 130, category: 'food', image_url: dishImages.curry,
  },
  pad_prik_gaeng_tua_fak_yao: {
    name_en: 'Stir-Fried Long Beans with Curry Paste', name_th: 'ผัดพริกแกงถั่วฝักยาว', name_zh: '咖喱酱炒长豆',
    name_ko: '커리 페이스트 긴콩 볶음', name_ru: 'Длинная фасоль, жареная с карри-пастой', name_ja: 'ササゲのカレーペースト炒め',
    min_price: 50, max_price: 80, category: 'food', image_url: dishImages.curry,
  },

  // --- Oyster sauce stir-fry ---
  moo_pad_namman_hoy: {
    name_en: 'Pork in Oyster Sauce', name_th: 'หมูผัดน้ำมันหอย', name_zh: '蚝油猪肉',
    name_ko: '굴소스 돼지고기', name_ru: 'Свинина в устричном соусе', name_ja: '豚肉のオイスターソース炒め',
    min_price: 60, max_price: 90, category: 'food', image_url: dishImages.stir_fry,
  },
  neua_pad_namman_hoy: {
    name_en: 'Beef in Oyster Sauce', name_th: 'เนื้อผัดน้ำมันหอย', name_zh: '蚝油牛肉',
    name_ko: '굴소스 소고기', name_ru: 'Говядина в устричном соусе', name_ja: '牛肉のオイスターソース炒め',
    min_price: 80, max_price: 130, category: 'food', image_url: dishImages.stir_fry,
  },
  het_fang_pad_namman_hoy: {
    name_en: 'Straw Mushroom in Oyster Sauce', name_th: 'เห็ดฟางผัดน้ำมันหอย', name_zh: '蚝油草菇',
    name_ko: '굴소스 짚버섯', name_ru: 'Соломенные грибы в устричном соусе', name_ja: 'フクロタケのオイスターソース炒め',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.stir_fry,
  },

  // --- Stir-fried vegetables ---
  pad_kana_moo_grob: {
    name_en: 'Stir-Fried Kale with Crispy Pork', name_th: 'ผัดคะน้าหมูกรอบ', name_zh: '脆皮猪肉炒芥兰',
    name_ko: '바삭한 돼지고기 케일 볶음', name_ru: 'Кейл с хрустящей свининой', name_ja: 'カリカリ豚肉とケールの炒め物',
    min_price: 60, max_price: 100, category: 'food', image_url: dishImages.stir_fry,
  },
  pad_pak_boong_fai_daeng: {
    name_en: 'Stir-Fried Morning Glory', name_th: 'ผัดผักบุ้งไฟแดง', name_zh: '炒空心菜',
    name_ko: '모닝글로리 볶음', name_ru: 'Жареный водяной шпинат', name_ja: '空芯菜炒め',
    min_price: 40, max_price: 70, category: 'food', image_url: dishImages.stir_fry,
  },
  pad_kalam_plee_nam_pla: {
    name_en: 'Stir-Fried Cabbage with Fish Sauce', name_th: 'ผัดกะหล่ำปลีน้ำปลา', name_zh: '鱼露炒卷心菜',
    name_ko: '피쉬소스 양배추 볶음', name_ru: 'Капуста, жареная с рыбным соусом', name_ja: 'キャベツのナンプラー炒め',
    min_price: 40, max_price: 70, category: 'food', image_url: dishImages.stir_fry,
  },
  pad_pak_ruam_mit: {
    name_en: 'Stir-Fried Mixed Vegetables', name_th: 'ผัดผักรวมมิตร', name_zh: '炒杂菜',
    name_ko: '모듬 야채 볶음', name_ru: 'Жареные смешанные овощи', name_ja: '野菜炒め',
    min_price: 50, max_price: 80, category: 'food', image_url: dishImages.stir_fry,
  },

  // --- Other popular stir-fries ---
  gai_pad_med_mamuang: {
    name_en: 'Cashew Nut Chicken', name_th: 'ไก่ผัดเม็ดมะม่วง', name_zh: '腰果鸡丁',
    name_ko: '캐슈넛 치킨', name_ru: 'Курица с кешью', name_ja: 'カシューナッツチキン',
    min_price: 80, max_price: 130, category: 'food', image_url: dishImages.stir_fry,
  },
  pad_priao_wan: {
    name_en: 'Sweet and Sour Stir-Fry', name_th: 'ผัดเปรี้ยวหวาน', name_zh: '糖醋炒',
    name_ko: '탕수 볶음', name_ru: 'Кисло-сладкое жаркое', name_ja: '酢豚（甘酢炒め）',
    min_price: 70, max_price: 120, category: 'food', image_url: dishImages.stir_fry,
  },
  pad_cha_talay: {
    name_en: 'Spicy Stir-Fried Seafood', name_th: 'ผัดฉ่าทะเล', name_zh: '香辣炒海鲜',
    name_ko: '매운 해산물 볶음', name_ru: 'Острые жареные морепродукты', name_ja: 'シーフードのスパイシー炒め',
    min_price: 100, max_price: 160, category: 'food', image_url: dishImages.stir_fry,
  },
  muek_pad_kai_kem: {
    name_en: 'Squid with Salted Egg', name_th: 'หมึกผัดไข่เค็ม', name_zh: '咸蛋炒鱿鱼',
    name_ko: '소금계란 오징어 볶음', name_ru: 'Кальмар с солёным яйцом', name_ja: 'イカの塩卵炒め',
    min_price: 100, max_price: 160, category: 'food', image_url: dishImages.stir_fry,
  },

  // --- Egg dishes ---
  kai_jiao_moo_sap: {
    name_en: 'Pork Omelette', name_th: 'ไข่เจียวหมูสับ', name_zh: '猪肉煎蛋',
    name_ko: '돼지고기 오믈렛', name_ru: 'Омлет со свининой', name_ja: '豚ひき肉入りオムレツ',
    min_price: 40, max_price: 70, category: 'food', image_url: dishImages.egg,
  },
  kai_jiao_cha_om: {
    name_en: 'Cha-om Omelette', name_th: 'ไข่เจียวชะอม', name_zh: '假含羞草煎蛋',
    name_ko: '차옴 오믈렛', name_ru: 'Омлет с чаом', name_ja: 'チャオムオムレツ',
    min_price: 40, max_price: 70, category: 'food', image_url: dishImages.egg,
  },
  kai_dao: {
    name_en: 'Fried Egg', name_th: 'ไข่ดาว', name_zh: '煎蛋',
    name_ko: '계란후라이', name_ru: 'Яичница', name_ja: '目玉焼き',
    min_price: 15, max_price: 30, category: 'food', image_url: dishImages.egg,
  },
  kai_tun_moo_sap: {
    name_en: 'Steamed Egg with Minced Pork', name_th: 'ไข่ตุ๋นหมูสับ', name_zh: '蒸肉末蛋',
    name_ko: '다진 돼지고기 계란찜', name_ru: 'Яйцо на пару с фаршем', name_ja: '豚ひき肉入り茶碗蒸し',
    min_price: 40, max_price: 70, category: 'food', image_url: dishImages.egg,
  },
  kai_luk_khoey: {
    name_en: 'Son-in-Law Eggs', name_th: 'ไข่ลูกเขย', name_zh: '女婿蛋',
    name_ko: '사위 계란', name_ru: 'Яйца "Зять"', name_ja: 'カイルークコーイ（揚げ卵の甘辛ソース）',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.egg,
  },
  kai_palo: {
    name_en: 'Stewed Egg in Five-Spice', name_th: 'ไข่พะโล้', name_zh: '卤蛋',
    name_ko: '오향계란조림', name_ru: 'Тушёное яйцо в пяти специях', name_ja: 'パロー卵（五香煮卵）',
    min_price: 30, max_price: 60, category: 'food', image_url: dishImages.egg,
  },

  // --- Fried rice ---
  khao_pad_moo: {
    name_en: 'Pork Fried Rice', name_th: 'ข้าวผัดหมู', name_zh: '猪肉炒饭',
    name_ko: '돼지고기 볶음밥', name_ru: 'Жареный рис со свининой', name_ja: '豚肉チャーハン',
    min_price: 50, max_price: 80, category: 'food', image_url: dishImages.fried_rice,
  },
  khao_pad_goong: {
    name_en: 'Shrimp Fried Rice', name_th: 'ข้าวผัดกุ้ง', name_zh: '虾仁炒饭',
    name_ko: '새우 볶음밥', name_ru: 'Жареный рис с креветками', name_ja: 'エビチャーハン',
    min_price: 60, max_price: 100, category: 'food', image_url: dishImages.fried_rice,
  },
  khao_pad_naem: {
    name_en: 'Fried Rice with Fermented Pork Sausage', name_th: 'ข้าวผัดแหนม', name_zh: '泰式酸肉炒饭',
    name_ko: '발효 소시지 볶음밥', name_ru: 'Жареный рис с ферментированной свиной колбасой', name_ja: 'ナームチャーハン（発酵ソーセージ炒飯）',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.fried_rice,
  },
  khao_pad_pla_tu: {
    name_en: 'Mackerel Fried Rice', name_th: 'ข้าวผัดปลาทู', name_zh: '鲭鱼炒饭',
    name_ko: '고등어 볶음밥', name_ru: 'Жареный рис со скумбрией', name_ja: '鯖チャーハン',
    min_price: 50, max_price: 80, category: 'food', image_url: dishImages.fried_rice,
  },
  khao_pad_tom_yum: {
    name_en: 'Tom Yum Fried Rice', name_th: 'ข้าวผัดต้มยำ', name_zh: '冬阴功炒饭',
    name_ko: '똠얌 볶음밥', name_ru: 'Жареный рис том ям', name_ja: 'トムヤムチャーハン',
    min_price: 60, max_price: 100, category: 'food', image_url: dishImages.fried_rice,
  },
  khao_kluk_kapi: {
    name_en: 'Shrimp Paste Fried Rice', name_th: 'ข้าวคลุกกะปิ', name_zh: '虾酱拌饭',
    name_ko: '새우페이스트 비빔밥', name_ru: 'Рис с пастой из креветок', name_ja: 'カピ炒めご飯（エビペースト炒飯）',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.fried_rice,
  },

  // --- Quick breakfast-style rice dishes ---
  khao_kai_khon: {
    name_en: 'Rice with Creamy Egg Sauce', name_th: 'ข้าวไข่ข้น', name_zh: '滑蛋饭',
    name_ko: '크리미 에그 라이스', name_ru: 'Рис с кремовым яичным соусом', name_ja: 'とろとろ卵かけご飯',
    min_price: 40, max_price: 70, category: 'food', image_url: dishImages.egg,
  },
  khao_kai_jiao_rad_tom_yum: {
    name_en: 'Rice with Omelette and Tom Yum Sauce', name_th: 'ข้าวไข่เจียวราดต้มยำ', name_zh: '冬阴功酱炒蛋盖饭',
    name_ko: '똠얌 소스 오믈렛 라이스', name_ru: 'Рис с омлетом под соусом том ям', name_ja: 'トムヤムソースオムレツ丼',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.egg,
  },

  // --- Soups & curries ---
  tom_yum_gai_baan: {
    name_en: 'Tom Yum Free-Range Chicken Soup', name_th: 'ต้มยำไก่บ้าน', name_zh: '冬阴功土鸡汤',
    name_ko: '똠얌 토종닭 수프', name_ru: 'Том ям с домашней курицей', name_ja: '鶏肉のトムヤムスープ',
    min_price: 100, max_price: 180, category: 'food', image_url: dishImages.tom_yum,
  },
  tom_jued_tao_hu_moo_sap: {
    name_en: 'Clear Soup with Tofu and Minced Pork', name_th: 'ต้มจืดเต้าหู้หมูสับ', name_zh: '豆腐肉末清汤',
    name_ko: '두부 다진 돼지고기 맑은국', name_ru: 'Прозрачный суп с тофу и фаршем', name_ja: '豆腐と豚ひき肉のすまし汁',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.tom_yum,
  },
  gaeng_som_cha_om_goong: {
    name_en: 'Sour Curry with Cha-om and Shrimp', name_th: 'แกงส้มชะอมกุ้ง', name_zh: '酸咖喱虾炒含羞草',
    name_ko: '차옴 새우 사워커리', name_ru: 'Кислый карри с чаомом и креветками', name_ja: 'チャオムと海老のゲーンソム',
    min_price: 100, max_price: 180, category: 'food', image_url: dishImages.curry,
  },
  tom_saep_kraduk_on: {
    name_en: 'Spicy Cartilage Bone Soup', name_th: 'ต้มแซ่บกระดูกอ่อน', name_zh: '香辣软骨汤',
    name_ko: '매운 연골탕', name_ru: 'Острый суп с хрящами', name_ja: '軟骨のスパイシースープ',
    min_price: 80, max_price: 150, category: 'food', image_url: dishImages.tom_yum,
  },

  // --- Salads (yum/larb) ---
  yam_wun_sen: {
    name_en: 'Glass Noodle Salad', name_th: 'ยำวุ้นเส้น', name_zh: '凉拌粉丝',
    name_ko: '글래스 누들 샐러드', name_ru: 'Салат из стеклянной лапши', name_ja: 'ヤムウンセン（春雨サラダ）',
    min_price: 60, max_price: 110, category: 'food', image_url: dishImages.salad,
  },
  yam_moo_yo: {
    name_en: 'Vietnamese Pork Sausage Salad', name_th: 'ยำหมูยอ', name_zh: '越式猪肉肠沙拉',
    name_ko: '무요 소시지 샐러드', name_ru: 'Салат с вьетнамской свиной колбасой', name_ja: 'ムーヨー（豚肉ソーセージ）サラダ',
    min_price: 60, max_price: 100, category: 'food', image_url: dishImages.salad,
  },
  yam_mama: {
    name_en: 'Instant Noodle Salad', name_th: 'ยำมาม่า', name_zh: '凉拌泡面',
    name_ko: '마마 라면 샐러드', name_ru: 'Салат с лапшой быстрого приготовления', name_ja: 'ヤムママー（インスタント麺サラダ）',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.salad,
  },
  yam_kai_dao: {
    name_en: 'Fried Egg Salad', name_th: 'ยำไข่ดาว', name_zh: '凉拌煎蛋',
    name_ko: '계란후라이 샐러드', name_ru: 'Салат с яичницей', name_ja: '目玉焼きのヤム',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.salad,
  },
  plah_goong: {
    name_en: 'Spicy Shrimp Salad', name_th: 'พล่ากุ้ง', name_zh: '酸辣虾沙拉',
    name_ko: '매운 새우 샐러드', name_ru: 'Острый салат с креветками', name_ja: '海老の辛味サラダ（プラーグン）',
    min_price: 120, max_price: 200, category: 'food', image_url: dishImages.salad,
  },
  larb_moo: {
    name_en: 'Spicy Minced Pork Salad', name_th: 'ลาบหมู', name_zh: '拉帕猪肉碎沙拉',
    name_ko: '라프 돼지고기 샐러드', name_ru: 'Острый салат лаб со свининой', name_ja: 'ラープムー（豚ひき肉サラダ）',
    min_price: 60, max_price: 110, category: 'food', image_url: dishImages.salad,
  },
  nam_tok_neua: {
    name_en: 'Waterfall Beef Salad', name_th: 'น้ำตกเนื้อ', name_zh: '瀑布牛肉沙拉',
    name_ko: '남똑 소고기 샐러드', name_ru: 'Салат "Водопад" с говядиной', name_ja: 'ナムトック（牛肉サラダ）',
    min_price: 80, max_price: 150, category: 'food', image_url: dishImages.salad,
  },

  // --- Noodles & sukiyaki ---
  pad_see_ew: {
    name_en: 'Pad See Ew (Stir-Fried Noodles in Soy Sauce)', name_th: 'ผัดซีอิ๊ว', name_zh: '干炒河粉',
    name_ko: '팟씨유 (간장 볶음국수)', name_ru: 'Пад Си Ю (лапша в соевом соусе)', name_ja: 'パッシーユー（醤油焼きそば）',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.noodle,
  },
  rad_na_moo_num: {
    name_en: 'Rad Na with Tender Pork', name_th: 'ราดหน้าหมูนุ่ม', name_zh: '嫩猪肉打卤河粉',
    name_ko: '부드러운 돼지고기 랏나', name_ru: 'Рад на с нежной свининой', name_ja: '柔らか豚肉のラートナー',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.noodle,
  },
  guay_tiew_kua_gai: {
    name_en: 'Kua Gai (Stir-Fried Rice Noodles with Chicken)', name_th: 'ก๋วยเตี๋ยวคั่วไก่', name_zh: '鸡肉炒河粉',
    name_ko: '꾸어이띠여우 꾸어 치킨', name_ru: 'Лапша с курицей «Куа Гай»', name_ja: 'クアガイ（鶏肉焼きそば）',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.noodle,
  },
  mama_pad_kee_mao: {
    name_en: 'Drunken Stir-Fried Instant Noodles', name_th: 'มาม่าผัดขี้เมา', name_zh: '醉面炒泡面',
    name_ko: '마마 키마오 볶음', name_ru: 'Пьяная лапша из быстрого супа', name_ja: 'マーマー・キーマオ（インスタント麺の激辛炒め）',
    min_price: 50, max_price: 90, category: 'food', image_url: dishImages.noodle,
  },
  suki_nam_moo: {
    name_en: 'Pork Sukiyaki Soup', name_th: 'สุกี้น้ำหมู', name_zh: '猪肉打边炉汤',
    name_ko: '돼지고기 수끼 수프', name_ru: 'Суп сукияки со свининой', name_ja: '豚肉スキー（タイ風スキヤキスープ）',
    min_price: 60, max_price: 100, category: 'food', image_url: dishImages.tom_yum,
  },
  suki_haeng_talay: {
    name_en: 'Dry Seafood Sukiyaki', name_th: 'สุกี้แห้งทะเล', name_zh: '干海鲜打边炉',
    name_ko: '건식 해산물 수끼', name_ru: 'Сухое сукияки с морепродуктами', name_ja: 'シーフードの汁なしスキー',
    min_price: 90, max_price: 160, category: 'food', image_url: dishImages.stir_fry,
  },
  suki_haeng_gai: {
    name_en: 'Dry Chicken Sukiyaki', name_th: 'สุกี้แห้งไก่', name_zh: '干鸡肉打边炉',
    name_ko: '건식 치킨 수끼', name_ru: 'Сухое сукияки с курицей', name_ja: '鶏肉の汁なしスキー',
    min_price: 70, max_price: 120, category: 'food', image_url: dishImages.stir_fry,
  },
};

async function seed() {
  const collections = [
    { name: 'partner_locations', data: partnerLocations },
    { name: 'alert_zones', data: alertZones },
    { name: 'price_standards', data: priceStandards },
  ];

  for (const { name, data } of collections) {
    const entries = Object.entries(data);
    for (const [id, fields] of entries) {
      // `id` must be written as a FIELD too, not just used as the document ID.
      // Omitting it is what produced INTEGRATION_TEST.md §F1/§F3: the CMS list
      // query dropped every seeded document, and the edit form fed an
      // undefined id back into Zod so those rows could not be saved.
      // `updated_at` is part of the price_standards contract only —
      // partner_locations and alert_zones deliberately have no such field
      // (CLAUDE.md §3).
      await setDoc(doc(db, name, id), {
        id,
        ...fields,
        ...(name === 'price_standards' ? { updated_at: serverTimestamp() } : {}),
      });
      console.log(`  ✓ ${name}/${id}`);
    }
    console.log(`✅ ${name} — ${entries.length} documents\n`);
  }

  console.log('🎉 Seed completed!');
  process.exit(0);
}

seed().catch((err) => {
  console.error('❌ Seed failed:', err.message);
  process.exit(1);
});
