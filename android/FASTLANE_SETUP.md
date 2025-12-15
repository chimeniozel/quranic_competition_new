# 🚀 Guide de Configuration Fastlane pour Google Play

## 📋 Prérequis

1. **Compte Google Play Console** avec accès développeur
2. **Service Account JSON** pour l'authentification
3. **Flutter SDK** installé
4. **Ruby** et **Bundler** installés

---

## 🔑 Étape 1: Créer un Service Account JSON

### Option A: Via Google Cloud Console

1. Allez sur [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionnez votre projet (ou créez-en un nouveau)
3. Allez dans **IAM & Admin** > **Service Accounts**
4. Cliquez sur **Create Service Account**
5. Donnez un nom (ex: `fastlane-service-account`)
6. Cliquez sur **Create and Continue**
7. Dans **Grant this service account access to project**, sélectionnez:
   - **Role**: `Service Account User`
8. Cliquez sur **Continue** puis **Done**
9. Cliquez sur le service account créé
10. Allez dans l'onglet **Keys**
11. Cliquez sur **Add Key** > **Create new key**
12. Sélectionnez **JSON** et cliquez sur **Create**
13. Le fichier JSON sera téléchargé automatiquement

### Option B: Via Google Play Console

1. Allez sur [Google Play Console](https://play.google.com/console/)
2. Sélectionnez votre application
3. Allez dans **Setup** > **API access**
4. Cliquez sur **Create new service account**
5. Suivez les instructions pour créer le service account dans Google Cloud
6. Revenez à Google Play Console
7. Cliquez sur **Grant access** à côté du service account créé
8. Sélectionnez les permissions nécessaires:
   - ✅ View app information and download bulk reports
   - ✅ Manage production releases
   - ✅ Manage testing track releases
   - ✅ Manage app content and pricing
9. Cliquez sur **Invite user**
10. Téléchargez le fichier JSON depuis Google Cloud Console (voir Option A, étape 12)

---

## 📁 Étape 2: Placer le fichier JSON

Placez le fichier JSON téléchargé dans le dossier `android/`:

```bash
cp ~/Downloads/your-service-account-*.json android/quranic-competition-service-account.json
```

**⚠️ IMPORTANT:** Ajoutez ce fichier à `.gitignore` pour ne pas le commiter!

---

## ⚙️ Étape 3: Configurer Appfile

Le fichier `android/fastlane/Appfile` devrait ressembler à ceci:

```ruby
json_key_file("quranic-competition-supabase-5aa762608dee.json") # Chemin relatif depuis android/
package_name("com.chemeni.quranic_competition")
```

Si votre fichier JSON a un nom différent, mettez à jour `json_key_file` avec le bon nom.

---

## 🏗️ Étape 4: Installer les dépendances

Dans le dossier `android/`:

```bash
cd android
bundle install
```

---

## ✅ Étape 5: Tester la configuration

Testez la connexion à Google Play:

```bash
cd android
bundle exec fastlane run validate_play_store_json_key json_key:quranic-competition-service-account.json
```

Si tout est correct, vous devriez voir un message de succès.

---

## 📦 Commandes Fastlane disponibles

### Construire l'application

```bash
# Build AAB (recommandé pour Google Play)
bundle exec fastlane build_release

# Build APK
bundle exec fastlane build_apk
```

### Déployer sur Google Play

```bash
# Déployer en Internal Testing
bundle exec fastlane deploy_internal

# Déployer en Alpha
bundle exec fastlane deploy_alpha

# Déployer en Beta
bundle exec fastlane deploy_beta

# Déployer en Production
bundle exec fastlane deploy
```

---

## 🔧 Configuration avancée

### Ajouter des métadonnées automatiques

Créez un dossier `android/fastlane/metadata/` et ajoutez vos métadonnées:

```
fastlane/
  metadata/
    android/
      ar/
        title.txt
        short_description.txt
        full_description.txt
      en/
        title.txt
        short_description.txt
        full_description.txt
```

Puis modifiez le Fastfile pour inclure les métadonnées:

```ruby
upload_to_play_store(
  track: "production",
  aab: "../build/app/outputs/bundle/release/app-release.aab",
  skip_upload_apk: true,
  skip_upload_metadata: false, # Activer les métadonnées
  skip_upload_images: false,    # Activer les images
  skip_upload_screenshots: false # Activer les screenshots
)
```

### Ajouter des notes de version

Créez `android/fastlane/metadata/android/ar/changelogs/8.txt` (8 = version code):

```
إصلاحات وتحسينات عامة
- تحسين الأداء
- إصلاح الأخطاء
```

---

## 🐛 Dépannage

### Erreur: "Could not find service account json file"

Vérifiez que:
1. Le fichier JSON existe dans `android/`
2. Le nom dans `Appfile` correspond au nom du fichier
3. Le chemin est relatif depuis `android/`

### Erreur: "Authentication failed"

Vérifiez que:
1. Le service account a les bonnes permissions dans Google Play Console
2. Le fichier JSON n'est pas corrompu
3. Le package name dans `Appfile` correspond à celui de votre app

### Erreur: "Package not found"

Vérifiez que:
1. L'application existe dans Google Play Console
2. Le package name est correct: `com.chemeni.quranic_competition`

---

## 📚 Ressources

- [Documentation Fastlane](https://docs.fastlane.tools/)
- [Guide Google Play Console](https://support.google.com/googleplay/android-developer/answer/6112435)
- [Service Account Setup](https://docs.fastlane.tools/actions/supply/#setup)

---

## 🔒 Sécurité

**⚠️ NE COMMITEZ JAMAIS:**
- Le fichier JSON du service account
- Les fichiers de clés (keystore)
- Les mots de passe

Assurez-vous que `.gitignore` contient:
```
**/*.json
**/*.keystore
**/*.jks
key.properties
```

