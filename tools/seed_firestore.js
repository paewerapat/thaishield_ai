import { initializeApp } from 'firebase/app';
import { getFirestore, doc, setDoc, GeoPoint } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyDWw6C1hHSmuATc_zC6FP545J1gqK36UQE',
  projectId: 'thaishield-ai-790eb',
  storageBucket: 'thaishield-ai-790eb.firebasestorage.app',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// Builds an irregular hexagon of GeoPoints around a center point, used to
// render alert zones as area shapes on the map instead of plain circles.
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

const partnerLocations = {
  landmark_bangkok: {
    name: 'The Landmark Bangkok',
    lat: 13.7401, lng: 100.5601,
    type: 'hotel', rating: 4.8,
    is_verified: true, price_tier: 'fair',
    image_url: 'https://example.com/landmark.jpg',
  },
  chatuchak_restaurant_01: {
    name: 'Chatuchak Local Kitchen',
    lat: 13.7999, lng: 100.5500,
    type: 'restaurant', rating: 4.2,
    is_verified: true, price_tier: 'fair',
    image_url: 'https://example.com/chatuchak.jpg',
  },
  siam_tuk_tuk_stand: {
    name: 'Siam Tuk Tuk Stand',
    lat: 13.7466, lng: 100.5347,
    type: 'transport', rating: 3.6,
    is_verified: false, price_tier: 'caution',
    image_url: 'https://example.com/tuktuk.jpg',
  },
  silom_restaurant_02: {
    name: 'Silom Night Market Grill',
    lat: 13.7244, lng: 100.5290,
    type: 'restaurant', rating: 4.5,
    is_verified: true, price_tier: 'fair',
    image_url: 'https://example.com/silom.jpg',
  },
  sukhumvit_hotel_01: {
    name: 'Sukhumvit Boutique Inn',
    lat: 13.7300, lng: 100.5700,
    type: 'hotel', rating: 4.1,
    is_verified: true, price_tier: 'fair',
    image_url: 'https://example.com/sukhumvit.jpg',
  },
};

const alertZones = {
  zone_silom_safe: {
    name: 'Silom Business District',
    center_lat: 13.7244, center_lng: 100.5278, radius_km: 1.0,
    polygon: polygonAround(13.7244, 100.5278, 1.0),
    risk_level: 'safe',
    description_en: 'Business and tourist-friendly area with verified partners.',
    description_th: 'ย่านธุรกิจและท่องเที่ยว มีพาร์ทเนอร์ที่ผ่านการรับรอง',
  },
  zone_khaosan_caution: {
    name: 'Khaosan Road Area',
    center_lat: 13.7590, center_lng: 100.4972, radius_km: 0.5,
    polygon: polygonAround(13.7590, 100.4972, 0.5),
    risk_level: 'caution',
    description_en: 'Popular tourist area. Tuk-tuk and tour pricing here may vary significantly from typical rates — compare before booking.',
    description_th: 'พื้นที่ท่องเที่ยวที่ได้รับความนิยม ราคาตุ๊กตุ๊กและทัวร์ในบริเวณนี้อาจแตกต่างจากราคาทั่วไป ควรเปรียบเทียบราคาก่อนตัดสินใจ',
  },
  zone_patpong_caution: {
    name: 'Patpong Night Bazaar',
    center_lat: 13.7274, center_lng: 100.5300, radius_km: 0.4,
    polygon: polygonAround(13.7274, 100.5300, 0.4),
    risk_level: 'caution',
    description_en: 'Busy night market area. Prices and conditions here may vary — please stay alert to your surroundings and confirm prices before purchasing.',
    description_th: 'ตลาดนัดกลางคืนที่มีผู้คนพลุกพล่าน โปรดดูแลทรัพย์สินส่วนตัวและตรวจสอบราคาก่อนตัดสินใจซื้อ',
  },
  zone_danger_01: {
    name: 'Community Alert Zone',
    center_lat: 13.7500, center_lng: 100.5200, radius_km: 0.3,
    polygon: polygonAround(13.7500, 100.5200, 0.3),
    risk_level: 'danger',
    description_en: 'Increased community reports in this area. Extra caution is recommended, especially at night.',
    description_th: 'มีรายงานจากชุมชนในพื้นที่นี้เพิ่มขึ้น แนะนำให้เพิ่มความระมัดระวังเป็นพิเศษ โดยเฉพาะช่วงเวลากลางคืน',
  },
  zone_sukhumvit_safe: {
    name: 'Sukhumvit Tourist Zone',
    center_lat: 13.7300, center_lng: 100.5680, radius_km: 1.2,
    polygon: polygonAround(13.7300, 100.5680, 1.2),
    risk_level: 'safe',
    description_en: 'Well-lit tourist corridor with hotels and verified restaurants.',
    description_th: 'แหล่งท่องเที่ยวมีแสงสว่าง มีโรงแรมและร้านอาหารที่ผ่านการรับรอง',
  },
};

const priceStandards = {
  pad_thai: {
    name_en: 'Pad Thai', name_th: 'ผัดไทย', name_zh: '炒河粉',
    name_ko: '팟타이', name_ru: 'Пад Тай', name_ja: 'パッタイ',
    min_price: 80, max_price: 120, category: 'food',
  },
  tom_yum_goong: {
    name_en: 'Tom Yum Goong', name_th: 'ต้มยำกุ้ง', name_zh: '冬阴功虾',
    name_ko: '똠얌꿍', name_ru: 'Том Ям Кунг', name_ja: 'トムヤムクン',
    min_price: 150, max_price: 250, category: 'food',
  },
  green_curry: {
    name_en: 'Green Curry', name_th: 'แกงเขียวหวาน', name_zh: '绿咖喱',
    name_ko: '그린 커리', name_ru: 'Зелёный карри', name_ja: 'グリーンカレー',
    min_price: 100, max_price: 180, category: 'food',
  },
  tuk_tuk_short: {
    name_en: 'Tuk Tuk (Short Trip)', name_th: 'ตุ๊กตุ๊ก (ระยะสั้น)', name_zh: '嘟嘟车 (短途)',
    name_ko: '뚝뚝 (단거리)', name_ru: 'Тук-Тук (короткий)', name_ja: 'トゥクトゥク（近距離）',
    min_price: 60, max_price: 100, category: 'transport',
  },
  taxi_meter: {
    name_en: 'Taxi (Meter)', name_th: 'แท็กซี่ (มิเตอร์)', name_zh: '出租车 (计价器)',
    name_ko: '택시 (미터)', name_ru: 'Такси (счётчик)', name_ja: 'タクシー（メーター）',
    min_price: 35, max_price: 200, category: 'transport',
  },
  grand_palace: {
    name_en: 'Grand Palace Entrance', name_th: 'พระบรมมหาราชวัง', name_zh: '大皇宫门票',
    name_ko: '왕궁 입장료', name_ru: 'Большой дворец', name_ja: '王宮入場料',
    min_price: 500, max_price: 500, category: 'attraction',
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
      await setDoc(doc(db, name, id), fields);
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
