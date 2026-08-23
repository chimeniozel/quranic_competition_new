# Checklist : Configuration API HTTP v1 pour FCM

## ⚠️ Erreur actuelle
`FCM_SERVER_KEY not configured` - Cela signifie qu'une ancienne version du code a été déployée.

## ✅ Solution : Vérifier et redéployer

### 1. Vérifier les secrets dans Supabase

Dans **Supabase Dashboard > Settings > Edge Functions > Secrets**, tu dois avoir **3 secrets** (pas `FCM_SERVER_KEY`) :

- ✅ `FCM_PROJECT_ID` → Le Project ID de Firebase (pas le Project Number)
- ✅ `FCM_CLIENT_EMAIL` → Le `client_email` du Service Account JSON
- ✅ `FCM_PRIVATE_KEY` → Le `private_key` du Service Account JSON (avec les `\n`)

❌ **NE PAS avoir** : `FCM_SERVER_KEY` (c'est pour l'API Legacy)

### 2. Vérifier le code déployé

Dans **Supabase Dashboard > Edge Functions > send-fcm-notification**, vérifie que le code contient :

✅ `FCM_CLIENT_EMAIL` et `FCM_PRIVATE_KEY` (lignes 14-15)
✅ `getAccessToken()` function (ligne 13)
✅ `FCM_PROJECT_ID` (ligne 275)
✅ `https://fcm.googleapis.com/v1/projects/` (ligne 281)

❌ **NE DOIT PAS contenir** : `FCM_SERVER_KEY` ou `https://fcm.googleapis.com/fcm/send`

### 3. Redéployer le code correct

1. Va dans **Supabase Dashboard > Edge Functions**
2. Clique sur `send-fcm-notification`
3. **Supprime tout le code actuel**
4. **Copie-colle le code complet** de `supabase/functions/send-fcm-notification/index.ts`
5. Clique sur **Deploy** ou **Save**

### 4. Vérifier après déploiement

1. Crée une nouvelle notification depuis l'app
2. Va dans **Edge Functions > Logs**
3. Tu devrais voir :
   - ✅ `Found X tokens via...`
   - ✅ `FCM notifications sent: X success...`
   - ❌ Plus d'erreur `FCM_SERVER_KEY not configured`

## 🔍 Comment obtenir les secrets

### FCM_PROJECT_ID
1. Va dans [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionne ton projet Firebase
3. Va dans **Settings** (⚙️)
4. Copie le **Project ID** (pas le Project Number)

### FCM_CLIENT_EMAIL et FCM_PRIVATE_KEY
1. Va dans [Google Cloud Console](https://console.cloud.google.com/)
2. **IAM & Admin** > **Service Accounts**
3. Clique sur ton Service Account
4. **Keys** > **Add Key** > **Create new key** > **JSON**
5. Télécharge le fichier JSON
6. Ouvre le JSON et copie :
   - `client_email` → `FCM_CLIENT_EMAIL`
   - `private_key` → `FCM_PRIVATE_KEY` (garde les `\n`)

## ⚠️ Erreurs courantes

### "FCM_SERVER_KEY not configured"
→ Tu as déployé l'ancienne version (API Legacy). Redéploie avec `index.ts` (API v1).

### "FCM credentials not configured"
→ Vérifie que `FCM_CLIENT_EMAIL` et `FCM_PRIVATE_KEY` sont bien configurés dans Supabase.

### "FCM_PROJECT_ID not configured"
→ Vérifie que `FCM_PROJECT_ID` est bien configuré dans Supabase.

### "Permission 'cloudmessaging.messages.create' denied"
→ Consulte `FIX_PERMISSIONS_IAM.md` pour corriger les permissions IAM.

