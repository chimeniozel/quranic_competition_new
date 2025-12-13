#!/bin/bash

# سكريبت للحصول على SHA-1 و SHA-256 من keystore

echo "🔑 Certificate Fingerprint Generator"
echo "======================================"
echo ""

# قراءة معلومات keystore من key.properties
KEYSTORE_FILE=$(grep "storeFile" android/key.properties | cut -d'=' -f2 | tr -d ' ')
KEYSTORE_ALIAS=$(grep "keyAlias" android/key.properties | cut -d'=' -f2 | tr -d '"')
KEYSTORE_PASSWORD=$(grep "storePassword" android/key.properties | cut -d'=' -f2 | tr -d '"')

# تنظيف المسار
if [[ $KEYSTORE_FILE == app/* ]]; then
    KEYSTORE_PATH="android/$KEYSTORE_FILE"
else
    KEYSTORE_PATH="$KEYSTORE_FILE"
fi

echo "📁 Keystore file: $KEYSTORE_PATH"
echo "🔐 Alias: $KEYSTORE_ALIAS"
echo ""

# التحقق من وجود الملف
if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "❌ Keystore file not found at: $KEYSTORE_PATH"
    echo ""
    echo "💡 Please provide the full path to your keystore file:"
    read -p "Keystore path: " KEYSTORE_PATH
fi

# الحصول على SHA-1 و SHA-256
echo "🔍 Getting SHA-1 and SHA-256 fingerprints..."
echo ""

keytool -list -v -keystore "$KEYSTORE_PATH" -alias "$KEYSTORE_ALIAS" -storepass "$KEYSTORE_PASSWORD" 2>/dev/null

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Success! Copy the SHA-1 and SHA-256 values above."
    echo ""
    echo "📋 Next steps:"
    echo "1. Go to Firebase Console → Project Settings → Your apps"
    echo "2. Select your Android app"
    echo "3. Add SHA certificate fingerprints"
    echo "4. Paste the SHA-1 (and SHA-256) values"
else
    echo ""
    echo "❌ Error: Could not read keystore file"
    echo ""
    echo "💡 Try running manually:"
    echo "keytool -list -v -keystore $KEYSTORE_PATH -alias $KEYSTORE_ALIAS"
fi

