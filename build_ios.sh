#!/bin/bash
# Script pour builder iOS avec provisioning updates

echo "🚀 Building iOS app with provisioning updates enabled..."

# Nettoyer le build précédent
flutter clean

# Récupérer les dépendances
flutter pub get

# Installer les pods
cd ios
pod install
cd ..

# Build avec l'option permettant les mises à jour de provisioning
# On utilise xcodebuild directement avec l'option
export XCODE_BUILD_SETTINGS_PATH=ios/Runner.xcodeproj/project.pbxproj

# Essayer de build avec flutter, mais si ça échoue, utiliser xcodebuild directement
if flutter build ios --debug --no-codesign; then
    echo "✅ Build réussi sans code signing"
    echo "📱 Pour déployer sur l'appareil, utilisez Xcode ou flutter run avec -allowProvisioningUpdates"
else
    echo "⚠️ Build Flutter échoué, tentative avec xcodebuild direct..."
    xcodebuild -workspace ios/Runner.xcworkspace \
        -scheme Runner \
        -configuration Debug \
        -destination 'id=YOUR_DEVICE_ID' \
        -allowProvisioningUpdates
fi

