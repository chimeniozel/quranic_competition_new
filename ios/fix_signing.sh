#!/bin/bash
# Script pour fixer la signature automatique iOS

echo "🔧 Fix de la signature automatique iOS..."

# Ouvrir Xcode workspace pour permettre à l'utilisateur de configurer manuellement
open ios/Runner.xcworkspace

echo "✅ Xcode workspace ouvert."
echo ""
echo "📋 Instructions:"
echo "1. Dans Xcode, sélectionnez le projet 'Runner' dans le navigateur"
echo "2. Sélectionnez le target 'Runner'"
echo "3. Allez dans l'onglet 'Signing & Capabilities'"
echo "4. Cochez 'Automatically manage signing'"
echo "5. Sélectionnez votre Team: J9P5HCMXJW"
echo "6. Vérifiez que le Bundle Identifier est: com.coranehel.quranicCompetition"
echo ""
echo "Xcode générera automatiquement les profils de provisioning nécessaires."

