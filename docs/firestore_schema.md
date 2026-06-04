# ThaiShield AI — Firestore Database Schema
**Project:** thaishield-ai-790eb
**Last Updated:** June 2026
**Version:** 1.0 (MVP)

---

## ภาพรวม (Overview)

ฐานข้อมูล Cloud Firestore ประกอบด้วย 3 Collections หลัก สำหรับระบบ ThaiShield AI MVP:

| Collection | วัตถุประสงค์ | ใช้ใน Phase |
|---|---|---|
| `price_standards` | ตารางราคามาตรฐานอาหาร/บริการ | Phase 3 (AI Scanner) |
| `partner_locations` | พิกัดพาร์ทเนอร์บนแผนที่ | Phase 2 (Smart Map) |
| `alert_zones` | โซนเตือนภัยบนแผนที่ | Phase 2 (Smart Map) |

---

## Collection 1: `price_standards`
ตารางราคากลางสำหรับเปรียบเทียบใน AI Price Scanner

### Schema

| Field | Type | Description | ตัวอย่าง |
|---|---|---|---|
| `id` | string (Document ID) | รหัสรายการ (ใช้ underscore) | `pad_thai` |
| `name_en` | string | ชื่อภาษาอังกฤษ | `Pad Thai` |
| `name_th` | string | ชื่อภาษาไทย | `ผัดไทย` |
| `name_zh` | string | ชื่อภาษาจีน | `炒河粉` |
| `name_ko` | string | ชื่อภาษาเกาหลี | `팟타이` |
| `name_ru` | string | ชื่อภาษารัสเซีย | `Пад Тай` |
| `name_ja` | string | ชื่อภาษาญี่ปุ่น | `パッタイ` |
| `min_price` | number | ราคาต่ำสุด (บาท) | `80` |
| `max_price` | number | ราคาสูงสุด (บาท) | `120` |
| `category` | string | หมวดหมู่ | `food` / `transport` / `attraction` |
| `updated_at` | timestamp | วันที่อัปเดตล่าสุด | `2026-06-04` |

### ตัวอย่างข้อมูล (Seed Data)

```
Document ID: pad_thai
  name_en:    "Pad Thai"
  name_th:    "ผัดไทย"
  name_zh:    "炒河粉"
  name_ko:    "팟타이"
  name_ru:    "Пад Тай"
  name_ja:    "パッタイ"
  min_price:  80
  max_price:  120
  category:   "food"
  updated_at: June 4, 2026

Document ID: tom_yum_goong
  name_en:    "Tom Yum Goong"
  name_th:    "ต้มยำกุ้ง"
  name_zh:    "冬阴功虾"
  name_ko:    "똠얌꿍"
  name_ru:    "Том Ям Кунг"
  name_ja:    "トムヤムクン"
  min_price:  150
  max_price:  250
  category:   "food"
  updated_at: June 4, 2026

Document ID: tuk_tuk_short
  name_en:    "Tuk Tuk (Short Trip)"
  name_th:    "ตุ๊กตุ๊ก (ระยะสั้น)"
  name_zh:    "嘟嘟车 (短途)"
  name_ko:    "뚝뚝 (단거리)"
  name_ru:    "Тук-Тук (короткий)"
  name_ja:    "トゥクトゥク（近距離）"
  min_price:  60
  max_price:  100
  category:   "transport"
  updated_at: June 4, 2026
```

---

## Collection 2: `partner_locations`
พิกัดและข้อมูลพาร์ทเนอร์ที่ได้รับการยืนยันบน Smart Map

### Schema

| Field | Type | Description | ตัวอย่าง |
|---|---|---|---|
| `id` | string (Document ID) | รหัสสถานที่ | `landmark_bangkok` |
| `name` | string | ชื่อสถานที่ | `The Landmark Bangkok` |
| `lat` | number | ละติจูด | `13.7401` |
| `lng` | number | ลองจิจูด | `100.5601` |
| `type` | string | ประเภท | `restaurant` / `hotel` / `transport` |
| `rating` | number | คะแนน (0.0–5.0) | `4.8` |
| `is_verified` | boolean | ผ่านการยืนยัน | `true` |
| `price_tier` | string | ระดับราคา | `fair` / `caution` / `high` |
| `image_url` | string | URL รูปภาพ | `https://...` |

### ตัวอย่างข้อมูล (Seed Data)

```
Document ID: landmark_bangkok
  name:         "The Landmark Bangkok"
  lat:          13.7401
  lng:          100.5601
  type:         "hotel"
  rating:       4.8
  is_verified:  true
  price_tier:   "fair"
  image_url:    "https://example.com/landmark.jpg"

Document ID: chatuchak_restaurant_01
  name:         "Chatuchak Local Kitchen"
  lat:          13.7999
  lng:          100.5500
  type:         "restaurant"
  rating:       4.2
  is_verified:  true
  price_tier:   "fair"
  image_url:    "https://example.com/chatuchak.jpg"
```

---

## Collection 3: `alert_zones`
โซนพื้นที่เตือนภัยสำหรับแสดงบน Smart Map

### Schema

| Field | Type | Description | ตัวอย่าง |
|---|---|---|---|
| `id` | string (Document ID) | รหัสโซน | `zone_khaosan` |
| `name` | string | ชื่อโซน | `Khaosan Road Area` |
| `center_lat` | number | ละติจูดจุดศูนย์กลาง | `13.7590` |
| `center_lng` | number | ลองจิจูดจุดศูนย์กลาง | `100.4972` |
| `radius_km` | number | รัศมี (กิโลเมตร) | `0.5` |
| `risk_level` | string | ระดับความเสี่ยง | `safe` / `caution` / `danger` |
| `description_en` | string | คำอธิบายภาษาอังกฤษ | `Popular tourist area...` |
| `description_th` | string | คำอธิบายภาษาไทย | `พื้นที่ท่องเที่ยวยอดนิยม...` |

### ระดับความเสี่ยง (Risk Levels)

| risk_level | สีบนแผนที่ | ความหมาย |
|---|---|---|
| `safe` | 🟢 เขียว | พื้นที่ปลอดภัย มีพาร์ทเนอร์รับรอง |
| `caution` | 🟡 เหลือง | ควรระวัง มีรายงานการโก่งราคา |
| `danger` | 🔴 แดง | พื้นที่ความเสี่ยงสูง ควรหลีกเลี่ยง |

### ตัวอย่างข้อมูล (Seed Data)

```
Document ID: zone_silom_safe
  name:            "Silom Business District"
  center_lat:      13.7244
  center_lng:      100.5278
  radius_km:       1.0
  risk_level:      "safe"
  description_en:  "Business and tourist-friendly area with verified partners."
  description_th:  "ย่านธุรกิจและท่องเที่ยว มีพาร์ทเนอร์ที่ผ่านการรับรอง"

Document ID: zone_khaosan_caution
  name:            "Khaosan Road Area"
  center_lat:      13.7590
  center_lng:      100.4972
  radius_km:       0.5
  risk_level:      "caution"
  description_en:  "Popular tourist area. Watch out for overpriced tuk-tuks and tours."
  description_th:  "พื้นที่ท่องเที่ยว ระวังตุ๊กตุ๊กและทัวร์ราคาแพง"

Document ID: zone_danger_01
  name:            "High Risk Zone"
  center_lat:      13.7500
  center_lng:      100.5200
  radius_km:       0.3
  risk_level:      "danger"
  description_en:  "High crime rate reported. Avoid this area at night."
  description_th:  "มีรายงานอาชญากรรมสูง ควรหลีกเลี่ยงในเวลากลางคืน"
```

---

## วิธีเพิ่มข้อมูลใน Firebase Console

1. เข้า [console.firebase.google.com](https://console.firebase.google.com)
2. เลือกโปรเจกต์ **thaishield-ai-790eb**
3. เมนูซ้าย → **Firestore Database**
4. กด **+ Start collection** → ใส่ชื่อ collection
5. กด **+ Add document** → ใส่ Document ID และ fields ตามตาราง

---

## หมายเหตุสำคัญ

- ข้อมูลทั้งหมดจัดการผ่าน **Firebase Console โดยตรง** (ไม่มี Admin Panel ในระบบ)
- **Phase 3 AI Scanner:** เปรียบเทียบราคาจาก `price_standards` เท่านั้น ห้ามแสดงชื่อร้านหรือที่อยู่จริง
- รองรับการขยายจำนวน documents ได้ไม่จำกัดในอนาคต
