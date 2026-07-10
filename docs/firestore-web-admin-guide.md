# ThaiShield AI — Firestore Schema & Web Admin Guide

> **Internal Technical Reference · Version 1.0 · July 2026**  
> Firebase Project: `thaishield-ai-790eb`

---

## สารบัญ

1. [ภาพรวม Cloud Firestore](#1-ภาพรวม-cloud-firestore)
2. [Collection: price_standards](#2-collection-price_standards)
3. [Collection: partner_locations](#3-collection-partner_locations)
4. [Collection: alert_zones](#4-collection-alert_zones)
5. [Firestore Security Rules](#5-firestore-security-rules)
6. [แผน Web Admin Dashboard (Phase 5)](#6-แผน-web-admin-dashboard-phase-5)
7. [Tech Stack ที่แนะนำ](#7-tech-stack-ที่แนะนำ)
8. [ข้อควรระวัง — Legal & Security](#8-ข้อควรระวัง--legal--security)

---

## 1. ภาพรวม Cloud Firestore

ThaiShield AI ใช้ **Cloud Firestore** เป็น backend หลัก เก็บข้อมูล 3 collections ที่ Flutter app อ่านแบบ real-time

| Collection | หน้าที่ |
|---|---|
| `price_standards` | ราคามาตรฐาน ใช้ใน AI Price Scanner |
| `partner_locations` | ร้านค้า Partner แสดงบน Smart Map |
| `alert_zones` | พื้นที่แจ้งเตือนนักท่องเที่ยว แสดงเป็น overlay บนแผนที่ |

**กฎทุก collection:**
- ✅ Flutter app อ่านได้โดยไม่ต้อง login (public read)
- ❌ ห้ามเขียนจาก client ทุกกรณี (`write = false`)
- การเพิ่ม/แก้ไขข้อมูลต้องทำผ่าน Firebase Console หรือ Web Admin (Phase 5) เท่านั้น

---

## 2. Collection: price_standards

เก็บราคามาตรฐานของอาหาร/ขนส่ง/สถานที่ท่องเที่ยว  
แอปใช้เปรียบเทียบกับราคาที่สแกนได้ แล้วแสดง % variance

**Document ID ตัวอย่าง:** `pad_thai`, `green_curry`, `tuk_tuk_short`

| Field | Type | คำอธิบาย |
|---|---|---|
| `id` | string | Document ID เช่น `"pad_thai"` |
| `name_en` | string | ชื่อภาษาอังกฤษ |
| `name_th` | string | ชื่อภาษาไทย |
| `name_zh` | string | ชื่อภาษาจีน |
| `name_ko` | string | ชื่อภาษาเกาหลี |
| `name_ru` | string | ชื่อภาษารัสเซีย |
| `name_ja` | string | ชื่อภาษาญี่ปุ่น |
| `min_price` | number | ราคาต่ำสุด (บาท) |
| `max_price` | number | ราคาสูงสุด (บาท) |
| `category` | string | `"food"` \| `"transport"` \| `"attraction"` |
| `image_url` | string | URL รูปสินค้า/อาหาร (แสดงในผลสแกน) |
| `updated_at` | timestamp | วันที่อัปเดตล่าสุด |

**ตัวอย่างข้อมูล:**

```json
{
  "id": "pad_thai",
  "name_en": "Pad Thai",
  "name_th": "ผัดไทย",
  "name_zh": "炒河粉",
  "name_ko": "팟타이",
  "name_ru": "Пад Тай",
  "name_ja": "パッタイ",
  "min_price": 50,
  "max_price": 120,
  "category": "food",
  "image_url": "https://images.pexels.com/...",
  "updated_at": "2026-05-01T00:00:00Z"
}
```

> **หมายเหตุ:** แอปคำนวณ `avg_price = (min_price + max_price) / 2` เองใน Flutter — ไม่ต้องเก็บ field นี้ใน Firestore  
> ถ้าราคา detected อยู่ระหว่าง min–max ถือว่า "Within Range" (แสดงสีเขียว)

---

## 3. Collection: partner_locations

ร้านค้า/บริการที่เข้าร่วมโครงการ Partner กับ ThaiShield AI  
แสดงบนแผนที่พร้อม pin สีฟ้า (verified) หรือสีส้ม (unverified)

**Document ID ตัวอย่าง:** `chatuchak_local_kitchen`, `bkk_comfort_hotel`

| Field | Type | คำอธิบาย |
|---|---|---|
| `id` | string | Document ID |
| `name` | string | ชื่อร้านค้า (แสดงใน detail popup เท่านั้น — **ห้ามแสดงในผลสแกน**) |
| `lat` | number | ละติจูด เช่น `13.7563` |
| `lng` | number | ลองจิจูด เช่น `100.5018` |
| `type` | string | `"restaurant"` \| `"hotel"` \| `"transport"` |
| `rating` | number | คะแนน 0.0–5.0 |
| `is_verified` | boolean | `true` = pin สีฟ้า, `false` = pin สีส้ม |
| `price_tier` | string | `"fair"` \| `"caution"` \| `"high"` |
| `image_url` | string | รูปร้านค้า (ปัจจุบันเป็น Pexels stock) |

> **หมายเหตุ:** `image_url` ปัจจุบันชี้ไป Pexels stock photos (ฟรีสำหรับงาน commercial)  
> เมื่อทำ Web Admin แล้ว จะอัปโหลดรูปจริงของร้านไป Firebase Storage แทน

**การ filter ใน app:** เมื่อผู้ใช้สแกนอาหาร → กด "View Nearby Partners" → แผนที่แสดงเฉพาะ partner ประเภทที่ตรงกัน:

| scanner category | partner type |
|---|---|
| `food` | `restaurant` |
| `transport` | `transport` |
| `attraction` | `hotel` |

---

## 4. Collection: alert_zones

พื้นที่แจ้งเตือนนักท่องเที่ยว แสดงเป็น polygon overlay สีบนแผนที่

| Field | Type | คำอธิบาย |
|---|---|---|
| `id` | string | Document ID |
| `name` | string | ชื่อพื้นที่ |
| `center_lat` | number | ละติจูดจุดกลาง |
| `center_lng` | number | ลองจิจูดจุดกลาง |
| `radius_km` | number | รัศมีวงกลม (ใช้เมื่อ polygon < 3 จุด) |
| `polygon` | array\<GeoPoint\> | จุดขอบเขตพื้นที่ (ถ้ามี ≥ 3 จุด จะแสดงเป็น polygon แทน circle) |
| `risk_level` | string | `"safe"` \| `"caution"` \| `"danger"` |
| `description_en` | string | คำอธิบายภาษาอังกฤษ |
| `description_th` | string | คำอธิบายภาษาไทย |

**ตัวอย่างข้อมูล:**

```json
{
  "id": "khao_san_advisory",
  "name": "Khao San Road Area",
  "center_lat": 13.7584,
  "center_lng": 100.4976,
  "radius_km": 0.5,
  "polygon": [
    { "lat": 13.760, "lng": 100.495 },
    { "lat": 13.760, "lng": 100.500 },
    { "lat": 13.756, "lng": 100.500 },
    { "lat": 13.756, "lng": 100.495 }
  ],
  "risk_level": "caution",
  "description_en": "Busy tourist area. Compare prices before purchasing.",
  "description_th": "พื้นที่นักท่องเที่ยว ควรเปรียบเทียบราคาก่อนซื้อ"
}
```

> ⚠️ **ชื่อที่แสดงในแอปต้องใช้ภาษากลาง:** "Tourist Advisory Area" ไม่ใช่ "Dangerous Zone"

---

## 5. Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Public read — Flutter app อ่านโดยไม่ต้อง authenticate
    match /price_standards/{doc} {
      allow read: if true;
      allow write: if false;
    }
    match /partner_locations/{doc} {
      allow read: if true;
      allow write: if false;
    }
    match /alert_zones/{doc} {
      allow read: if true;
      allow write: if false;
    }

    // ปิดทุกอย่างที่นอกเหนือจากนี้
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

> ⚠️ **ข้อควรระวังสำคัญ:** ห้ามเปิด "test mode" rule ที่มีวันหมดอายุ  
> (`allow read, write: if request.time < timestamp.date(...)`)  
> เพราะเมื่อหมดอายุจะ **block การอ่านทั้งหมดโดยไม่มีการแจ้งเตือน** — เคยเกิดขึ้นมาแล้วหนึ่งครั้ง  
> ถ้า Map หรือ Scanner ใช้งานไม่ได้กะทันหัน → ตรวจสอบ Rules tab ใน Firebase Console ก่อนเสมอ

---

## 6. แผน Web Admin Dashboard (Phase 5)

Web Admin คือ website แยกต่างหากสำหรับทีมงาน จัดการข้อมูล Firestore โดยไม่ต้องเข้า Firebase Console  
**Flutter app ไม่ต้องแก้โค้ดใดๆ** เพราะอ่านจาก Firestore collections เดิมอยู่แล้ว

### สิ่งที่ Web Admin จะจัดการได้

**price_standards**
- เพิ่ม/แก้ไข/ลบรายการอาหาร ขนส่ง สถานที่
- แก้ไขราคา min–max และ category
- อัปโหลดรูปภาพสินค้า

**partner_locations**
- เพิ่ม/แก้ไขข้อมูลร้านค้า Partner
- อัปโหลดรูปร้านจริงไป Firebase Storage (แทน Pexels placeholder)
- เปิด/ปิด `is_verified` และเปลี่ยน `price_tier`

**alert_zones**
- วาด polygon บนแผนที่เพื่อกำหนดขอบเขตพื้นที่
- ตั้ง `risk_level` และคำอธิบายทั้ง EN/TH
- เพิ่ม/ลบพื้นที่แจ้งเตือน

### ขั้นตอนการทำงาน

```
1. Admin Login
   └─ Firebase Authentication (Email/Password หรือ Google SSO)
      เฉพาะ account ที่ได้รับสิทธิ์ admin เท่านั้น

2. แก้ไขข้อมูลผ่าน form
   └─ UI สวยงาม ไม่ต้องรู้ JSON หรือ Firestore syntax

3. บันทึกผ่าน Firebase Admin SDK (server-side)
   └─ bypass Security Rules → ไม่ต้องเปิด write permission สาธารณะ

4. Flutter app อัปเดตอัตโนมัติ
   └─ อ่าน Firestore real-time → ข้อมูลใหม่แสดงทันทีในแอป
      ไม่ต้อง update แอปหรือ deploy อะไรใหม่
```

---

## 7. Tech Stack ที่แนะนำ

| Layer | Technology | เหตุผล |
|---|---|---|
| Frontend | **Next.js 14** (React) | Server Actions สำหรับ write ผ่าน Admin SDK ได้โดยตรง |
| Auth | **Firebase Authentication** | ใช้ project เดิม ไม่ต้องตั้งค่าเพิ่ม |
| Database | **Cloud Firestore** | collections เดิม ไม่ต้อง migrate ข้อมูล |
| Storage | **Firebase Storage** | เก็บรูปภาพ partner จริง แทน Pexels link |
| Map Editor | **Google Maps JS API** | วาด polygon สำหรับ alert_zones บนเว็บ |
| Hosting | **Firebase Hosting** | deploy ด้วย `firebase deploy` คำสั่งเดียว |

**ตัวอย่างโค้ด (Next.js Server Action):**

```typescript
// app/actions/price.ts
"use server";
import { adminDb } from "@/lib/firebase-admin";

export async function addPriceStandard(data: PriceStandard) {
  await adminDb.collection("price_standards").add({
    ...data,
    updated_at: new Date(),
  });
}
```

> ⚠️ **Firebase Admin SDK ต้องรันฝั่ง server เท่านั้น**  
> ห้ามใส่ service account credentials ใน client-side JavaScript  
> เพราะจะทำให้ใครก็ได้เขียนข้อมูล Firestore ได้

---

## 8. ข้อควรระวัง — Legal & Security

### Legal Wording (บังคับใช้กับทุก content)

| ❌ ห้ามใช้ | ✅ ใช้แทน |
|---|---|
| Scam | Travel Alert |
| Tourist Scam | Tourist Advisory |
| Fraud | Price Information |
| Overcharge | Higher Than Average |
| Rip-off Price | Above Typical Range |
| Dangerous Zone | Tourist Advisory Area |
| Scam Area | Community Alert Zone |
| Blacklist Shop | Watchlist Area |
| Avoid This Shop | Compare Before Purchasing |

**กฎเพิ่มเติม:**
- ห้ามแสดงชื่อร้านค้า โลโก้ หรือข้อมูลที่ระบุตัวร้านได้บนหน้าผลสแกนราคา
- ทุกหน้าที่แสดงผลราคาต้องมี disclaimer:
  - **EN:** "This information is generated from statistical and community-based data and is intended for informational purposes only. Actual prices may vary."
  - **TH:** "ข้อมูลนี้เป็นการประเมินจากข้อมูลสถิติและข้อมูลจากชุมชนเพื่อประกอบการตัดสินใจเท่านั้น ราคาจริงอาจแตกต่างกันได้"

### Firestore Security
- ห้ามใช้ Firebase test mode (มีวันหมดอายุ → map/scanner พัง)
- ห้ามเปิด public write จาก Flutter app
- Web Admin ต้องเขียนผ่าน Admin SDK (server-side) เท่านั้น
- API keys ส่งผ่าน `--dart-define=GEMINI_API_KEY=...` เท่านั้น ห้าม hardcode ในโค้ด

---

*เอกสารนี้อ้างอิงจาก `CLAUDE.md` ใน repo `paewerapat/thaishield_ai` (branch: main)*  
*App version ปัจจุบัน: 1.0.0+13 · ติดต่อ: dev@thaishieldapp.com*
