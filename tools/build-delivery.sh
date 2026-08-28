#!/usr/bin/env bash
#
# Builds the two APKs that go to the client, and stages them in the workspace
# delivery/ folder under the names DELIVERY_2B.md refers to.
#
#   bash tools/build-delivery.sh
#
# Why this exists: the build needs three --dart-define keys that live in a file
# outside git, and typing them by hand risks pasting a secret into a shell
# history, a log, or a chat transcript. This reads them from the file and never
# prints a value.
#
# Two builds, on purpose (CLAUDE.md §7.6):
#   ตรวจรับ  — debug, so kDebugMode exposes the QA switch and the tester can
#              flip between free and Premium. A fresh install grants the 3-day
#              trial, so without that switch the paywall is unreachable for
#              three days — which is the very thing being accepted.
#   เวอร์ชันจริง — release, what a real user gets.
#
# --split-per-abi is not optional: the fat debug APK is ~206 MB against ~107 MB
# for the arm64 slice, and arm64-v8a covers every current Android handset.

set -euo pipefail

FLUTTER_BIN="/c/Users/werapat/flutter/bin"
REPO="/c/Fastwork/thaishield-ai/thaishield_ai"
SECRETS="/c/Fastwork/thaishield-ai/thaishield_ai-secret.txt"
DELIVERY="/c/Fastwork/thaishield-ai/delivery"

export PATH="$FLUTTER_BIN:$PATH"
cd "$REPO"

[ -f "$SECRETS" ] || { echo "ไม่พบไฟล์ secret: $SECRETS"; exit 1; }

# Pulled out of the ready-made `flutter run` line the secrets file already
# carries, so there is one place to update when a key rotates.
GEMINI=$(grep -oE -- '--dart-define=GEMINI_API_KEY=[^ `]+' "$SECRETS" | head -1 | cut -d= -f3-)
STT=$(grep -oE -- '--dart-define=GCS_STT_KEY=[^ `]+' "$SECRETS" | head -1 | cut -d= -f3-)

# Routes has no run-line yet — it is read from its own labelled section:
#   ## Routes API KEY
#   <the key>
ROUTES=$(awk '/^## Routes API KEY/{found=1; next} found && NF {print; exit}' "$SECRETS" | tr -d '\r')

[ -n "$GEMINI" ] || { echo "หา GEMINI_API_KEY ในไฟล์ secret ไม่เจอ"; exit 1; }
[ -n "$STT" ]    || { echo "หา GCS_STT_KEY ในไฟล์ secret ไม่เจอ"; exit 1; }

if [ -z "$ROUTES" ]; then
  # Not fatal — everything except Route Suggestion still builds and is worth
  # shipping. But it must be said loudly, because a build without this key looks
  # complete and silently drops half of task 2.4.
  echo
  echo "  ⚠️  ไม่พบ ROUTES_API_KEY — จะ build ต่อ แต่ฟีเจอร์แนะนำเส้นทาง (งาน 2.4) จะใช้ไม่ได้"
  echo "      แอปจะขึ้นว่า 'ฟีเจอร์เส้นทางยังไม่พร้อมใช้งานในแอปเวอร์ชันนี้'"
  echo "      เพิ่มลงไฟล์ secret แบบนี้แล้วรันใหม่:"
  echo
  echo "          ## Routes API KEY"
  echo "          <คีย์ที่ได้จาก Cloud Console>"
  echo
  ROUTES="__missing__"
fi

# ROUTES_API_KEY is deliberately absent: since 2026-08-29 it is a Cloud
# Functions secret, not a build flag. It is still read above so a missing one
# is noticed early — the deploy needs it even though the APK does not.
DEFINES=(
  "--dart-define=GEMINI_API_KEY=$GEMINI"
  "--dart-define=GCS_STT_KEY=$STT"
)

# Since 2026-08-29 the Routes key is a Functions secret and the app calls
# `computeRoute` instead of Google directly. A build made before that function
# is deployed looks perfect and has a dead Route Suggestion — the exact failure
# this whole delivery has already been caught by twice. So ask the function
# first, and refuse rather than warn: a warning in a long build log is a
# warning nobody reads.
echo "▸ ตรวจว่า Cloud Function เส้นทางถูก deploy แล้ว"
ROUTE_FN="https://asia-southeast1-thaishield-ai-790eb.cloudfunctions.net/computeRoute"
FN_CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 20 -X POST "$ROUTE_FN"   -H 'Content-Type: application/json' -d '{}' || echo 000)
# 400 is the healthy answer to a deliberately empty body: the function is up
# and rejecting bad input. 404 means it was never deployed; 000 means no
# network, which is not the function's fault and must not read as one.
if [ "$FN_CODE" = "400" ]; then
  echo "   ✅ function ตอบ 400 กับ body ว่าง = deploy แล้วและตรวจ input อยู่"
elif [ "$FN_CODE" = "000" ]; then
  echo "   ⚠️  ต่อเน็ตไม่ได้ ข้ามการตรวจนี้ — ยืนยันเองก่อนส่งไฟล์ให้ลูกค้า"
else
  echo
  echo "  ❌ Cloud Function ยังไม่พร้อม (ตอบ $FN_CODE)"
  echo "     ฟีเจอร์แนะนำเส้นทางจะใช้ไม่ได้ทั้งที่ build ผ่าน — หยุดไว้ก่อน"
  echo
  echo "     deploy ด้วย:"
  echo "       cd $REPO"
  echo "       firebase functions:secrets:set ROUTES_API_KEY"
  echo "       firebase deploy --only functions:computeRoute"
  echo
  exit 1
fi

echo "▸ ตรวจสอบโค้ดก่อน build"
flutter analyze
flutter test

echo "▸ build ตัวตรวจรับ (debug)"
flutter build apk --debug --split-per-abi "${DEFINES[@]}"

echo "▸ build เวอร์ชันจริง (release)"
flutter build apk --release --split-per-abi "${DEFINES[@]}"

mkdir -p "$DELIVERY"
cp build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk   "$DELIVERY/thaishield-2B-ตรวจรับ.apk"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$DELIVERY/thaishield-2B-เวอร์ชันจริง.apk"

echo
echo "▸ เสร็จแล้ว — ไฟล์อยู่ที่ $DELIVERY"
ls -la "$DELIVERY"/*.apk | awk '{printf "   %6.1f MB  %s\n", $5/1048576, $9}'
[ "$ROUTES" = "__missing__" ] && echo "   ⚠️  build นี้ยังไม่มี Routes API key — งาน 2.4 ตรวจรับไม่ได้"
echo "   คู่มือตรวจรับ: thaishield_ai/DELIVERY_2B.md"
