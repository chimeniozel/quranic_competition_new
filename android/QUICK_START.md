# ⚡ Quick Start - Fastlane

## 🎯 Étapes rapides pour commencer

### 1. Obtenir le fichier JSON du Service Account

**Option rapide:**
1. Allez sur [Google Play Console](https://play.google.com/console/)
2. Votre app > **Setup** > **API access**
3. Créez un nouveau service account (ou utilisez un existant)
4. Téléchargez le fichier JSON depuis Google Cloud Console

### 2. Placer le fichier dans android/

```bash
# Copiez votre fichier JSON téléchargé vers android/
cp ~/Downloads/votre-fichier.json android/quranic-competition-service-account.json
```

### 3. Vérifier Appfile

Le fichier `android/fastlane/Appfile` devrait contenir:

```ruby
json_key_file("quranic-competition-supabase-5aa762608dee.json")
package_name("com.chemeni.quranic_competition")
```

### 4. Installer les dépendances

```bash
cd android
bundle install
```

### 5. Construire et déployer

```bash
# Construire l'AAB
bundle exec fastlane build_release

# Déployer en Internal Testing
bundle exec fastlane deploy_internal

# Déployer en Production
bundle exec fastlane deploy
```

---

## 📝 Notes importantes

- Le fichier JSON doit être dans `android/` (pas dans `android/fastlane/`)
- Le nom du fichier dans `Appfile` doit correspondre au nom réel du fichier
- Ne commitez JAMAIS le fichier JSON (il est dans `.gitignore`)

---

Pour plus de détails, consultez `FASTLANE_SETUP.md`

