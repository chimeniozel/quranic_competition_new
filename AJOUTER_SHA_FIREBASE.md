# Guide : Ajouter les SHA dans Firebase Console pour Android

## 🔍 Le problème

L'erreur `AUTHENTICATION_FAILED` signifie que Firebase ne peut pas authentifier votre application Android car les **SHA certificate fingerprints** ne sont pas enregistrés.

## ✅ Solution en 3 étapes

### Étape 1 : Obtenir les SHA de votre application

Les SHA de votre application Android (debug) sont déjà connus :

**SHA-1:** `18:5B:CB:54:EA:2D:20:05:33:E5:F0:F3:E6:BA:56:D1:9B:A1:2E:58`

**SHA-256:** `16:8A:75:68:3D:67:51:DE:59:FD:B9:59:F4:72:0D:BD:4B:9A:4C:F1:63:4A:E3:83:1B:9B:E0:C1:F3:70:21:30`

### Étape 2 : Ajouter les SHA dans Firebase Console

1. **Aller dans Firebase Console** :
   - Ouvrir https://console.firebase.google.com/
   - Sélectionner votre projet **quranic-competition-supabase**

2. **Ouvrir les Project Settings** :
   - Cliquer sur l'icône ⚙️ (engrenage) en haut à gauche
   - Cliquer sur **Project settings**

3. **Aller dans l'onglet "Your apps"** :
   - En bas de la page, trouver la section **Your apps**
   - Sélectionner votre application **Android** avec le package name `com.coranehel.quranicCompetition`
   - Si elle n'existe pas, cliquer sur **Add app** → **Android** → Suivre les étapes

4. **Ajouter les SHA** :
   - Dans la section **SHA certificate fingerprints**, cliquer sur **Add fingerprint**
   - **Coller le SHA-1** : `18:5B:CB:54:EA:2D:20:05:33:E5:F0:F3:E6:BA:56:D1:9B:A1:2E:58`
   - Cliquer sur **Save**
   - Cliquer à nouveau sur **Add fingerprint**
   - **Coller le SHA-256** : `16:8A:75:68:3D:67:51:DE:59:FD:B9:59:F4:72:0D:BD:4B:9A:4C:F1:63:4A:E3:83:1B:9B:E0:C1:F3:70:21:30`
   - Cliquer sur **Save**

### Étape 3 : Télécharger le nouveau google-services.json

1. **Télécharger le nouveau fichier** :
   - Toujours dans **Project settings** → **Your apps**
   - Sélectionner votre application **Android**
   - Cliquer sur **Download google-services.json**

2. **Remplacer l'ancien fichier** :
   - Copier le fichier téléchargé
   - Le coller dans `android/app/google-services.json`
   - Remplacer l'ancien fichier

3. **Rebuild l'application** :
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## 🎯 Résultat attendu

Après avoir ajouté les SHA et mis à jour le fichier, vous devriez voir dans les logs :

```
✅ Token FCM obtenu: [token]
✅ Token FCM enregistré dans Supabase avec succès
```

Au lieu de :
```
❌ Erreur lors de l'obtention du token FCM: AUTHENTICATION_FAILED
```

## ⚠️ Important

1. **Attendre quelques minutes** après avoir ajouté les SHA dans Firebase avant de tester
2. **Le fichier google-services.json doit être mis à jour** après avoir ajouté les SHA
3. **Faire un clean build** (`flutter clean`) après avoir remplacé le fichier

## 🔧 Vérification

Pour vérifier que les SHA sont bien enregistrés :

1. Dans Firebase Console → **Project Settings** → **Your apps** → Sélectionner votre app Android
2. Vous devriez voir **2 fingerprints** dans la section **SHA certificate fingerprints** :
   - SHA-1: `18:5B:CB:54:EA:2D:20:05:33:E5:F0:F3:E6:BA:56:D1:9B:A1:2E:58`
   - SHA-256: `16:8A:75:68:3D:67:51:DE:59:FD:B9:59:F4:72:0D:BD:4B:9A:4C:F1:63:4A:E3:83:1B:9B:E0:C1:F3:70:21:30`

## 📝 Notes

- Si vous avez une clé de release, ajoutez aussi son SHA
- Les SHA doivent être ajoutés dans Firebase **avant** de pouvoir obtenir le token FCM
- Il peut prendre 1-2 minutes pour que Firebase reconnaisse les nouveaux SHA

