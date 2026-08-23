# Guide : Activer les notifications FCM sur iOS (app fermée)

## ✅ Ce qui fonctionne déjà
- ✅ Notifications Realtime (quand l'app est ouverte)
- ✅ Token FCM enregistré dans Supabase
- ✅ Configuration iOS de base

## ❌ Ce qui manque
- ❌ Supabase Edge Function pour envoyer les notifications FCM
- ❌ Configuration du secret FCM_SERVER_KEY

## 📋 Étapes pour activer les notifications quand l'app est fermée

## ⚠️ IMPORTANT : Commence par l'Option A

**Recommandation** : Commence toujours par l'**Option A (API Legacy)** car elle est plus simple et fonctionne immédiatement. Utilise l'**Option B (API HTTP v1)** seulement si l'Option A ne fonctionne pas ou si tu as des besoins spécifiques.

---

## Option A : Configuration avec API Legacy (Recommandé - Commence ici)

✅ **Avantages** :
- Configuration simple (un seul secret)
- Pas de problèmes de permissions IAM
- Fonctionne immédiatement
- API stable et fiable

❌ **Inconvénients** :
- API dépréciée (mais toujours supportée par Google)

### Étape 1 : Obtenir la clé serveur Firebase

1. Va dans [Firebase Console](https://console.firebase.google.com/)
2. Sélectionne ton projet
3. Va dans **⚙️ Project Settings** > **Cloud Messaging**
4. Dans la section **Cloud Messaging API (Legacy)**, copie la **Server key**

⚠️ Si tu ne vois pas la Server key, active d'abord l'API "Cloud Messaging API (Legacy)" dans [Google Cloud Console](https://console.cloud.google.com/apis/library/fcm.googleapis.com)

### Étape 2 : Configurer le secret dans Supabase

1. Supabase Dashboard > **Settings** > **Edge Functions** > **Secrets**
2. Ajoute un secret :
   - **Name** : `FCM_SERVER_KEY`
   - **Value** : Colle la Server key

### Étape 3 : Déployer l'Edge Function Legacy

1. Dans Supabase Dashboard > **Edge Functions**
2. Crée une nouvelle fonction `send-fcm-notification`
3. Copie le code de `supabase/functions/send-fcm-notification/index-legacy.ts`
4. Déploie

---

## Option B : Configuration avec API HTTP v1 (Alternative - Utilise seulement si Option A ne fonctionne pas)

⚠️ **Important** : Utilise cette option seulement si l'Option A ne fonctionne pas ou si tu as des besoins spécifiques nécessitant l'API v1.

✅ **Avantages** :
- API moderne et recommandée par Google
- Plus de fonctionnalités avancées

❌ **Inconvénients** :
- Configuration plus complexe (Service Account + 3 secrets)
- Nécessite des permissions IAM correctes
- Plus de risques d'erreurs de configuration

### Quand utiliser l'Option B ?
- Si l'Option A ne fonctionne pas après plusieurs tentatives
- Si tu as besoin de fonctionnalités avancées de l'API v1
- Si tu préfères utiliser l'API moderne pour des raisons de conformité

### ⚠️ Problèmes courants avec l'Option B
Si tu rencontres l'erreur `Permission 'cloudmessaging.messages.create' denied`, consulte le fichier `FIX_PERMISSIONS_IAM.md` pour corriger les permissions IAM.

### Étape 1 : Créer un Service Account dans Firebase

Cette Edge Function utilise l'API FCM HTTP v1 (moderne) qui nécessite un Service Account.

1. Va dans [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionne ton projet Firebase
3. Va dans **IAM & Admin** > **Service Accounts**
4. Clique sur **Create Service Account**
5. Donne un nom (ex: `fcm-notifications`)
6. Clique sur **Create and Continue**
7. Donne le rôle **Firebase Cloud Messaging Admin** (ou **Firebase Admin SDK Administrator Service Agent**)
8. Clique sur **Done**
9. Clique sur le service account créé
10. Va dans l'onglet **Keys**
11. Clique sur **Add Key** > **Create new key**
12. Choisis **JSON**
13. Télécharge le fichier JSON

### Étape 2 : Extraire les informations du Service Account

Ouvre le fichier JSON téléchargé et note :
- `project_id` → C'est ton **FCM_PROJECT_ID**
- `client_email` → C'est ton **FCM_CLIENT_EMAIL**
- `private_key` → C'est ton **FCM_PRIVATE_KEY** (garde les `\n` dans la clé)

### Étape 3 : Configurer les secrets dans Supabase

1. Va dans ton [Dashboard Supabase](https://supabase.com/dashboard)
2. Sélectionne ton projet
3. Va dans **Settings** (⚙️) > **Edge Functions** > **Secrets**
4. Ajoute **3 secrets** :

   **Secret 1 :**
   - **Name** : `FCM_PROJECT_ID`
   - **Value** : Le `project_id` du fichier JSON

   **Secret 2 :**
   - **Name** : `FCM_CLIENT_EMAIL`
   - **Value** : Le `client_email` du fichier JSON

   **Secret 3 :**
   - **Name** : `FCM_PRIVATE_KEY`
   - **Value** : Le `private_key` du fichier JSON (copie toute la clé avec les `\n`)

### Étape 4 : Déployer l'Edge Function

#### Option A : Via Supabase Dashboard (Recommandé)

1. Dans Supabase Dashboard, va dans **Edge Functions**
2. Clique sur **Create a new function**
3. Nomme-la : `send-fcm-notification`
4. Copie-colle le code du fichier `supabase/functions/send-fcm-notification/index.ts`
5. Clique sur **Deploy**

#### Option B : Via Supabase CLI

```bash
# Installer Supabase CLI si ce n'est pas déjà fait
npm install -g supabase

# Se connecter à Supabase
supabase login

# Lier le projet (remplace <ton-project-ref> par ton project ref)
supabase link --project-ref <ton-project-ref>

# Déployer la fonction
supabase functions deploy send-fcm-notification
```

### Étape 5 : Vérifier la configuration APNs dans Firebase

Pour iOS, tu dois aussi configurer APNs dans Firebase :

1. Dans Firebase Console > **Project Settings** > **Cloud Messaging**
2. Dans la section **Apple app configuration**, vérifie que :
   - Le **Bundle ID** correspond à celui de ton app iOS
   - Une **APNs Auth Key** ou un certificat APNs est configuré

Si ce n'est pas configuré :
- Va dans [Apple Developer](https://developer.apple.com/account/resources/authkeys/list)
- Crée une nouvelle **Key** avec les permissions **Apple Push Notifications service (APNs)**
- Télécharge le fichier `.p8`
- Dans Firebase, upload ce fichier et entre le **Key ID** et **Team ID**

### Étape 6 : Tester

1. **Ferme complètement l'app** sur ton iPhone/iPad (swipe up depuis le multitasking)
2. Crée une nouvelle notification depuis l'app (par exemple, crée une nouvelle version)
3. Tu devrais recevoir la notification même si l'app est fermée

### Vérification des logs

Pour vérifier que tout fonctionne :

1. Dans Supabase Dashboard > **Edge Functions** > **Logs**
2. Tu devrais voir des logs comme :
   - `📬 Envoi de X notification(s) FCM`
   - `✅ Notification FCM envoyée avec succès à ios`
   - `📊 Résultats: X réussies, 0 échouées`

## 🔧 Dépannage

### Les notifications ne s'affichent toujours pas quand l'app est fermée

1. **Vérifie les logs Supabase** : Va dans Edge Functions > Logs pour voir les erreurs
2. **Vérifie la configuration APNs** : Assure-toi que la clé APNs est bien configurée dans Firebase
3. **Vérifie les permissions iOS** : Va dans Réglages > ton app > Notifications et vérifie que tout est activé
4. **Teste avec un vrai appareil** : Les notifications push ne fonctionnent pas sur le simulateur iOS
5. **Vérifie le token FCM** : Dans Supabase, vérifie que la table `fcm_tokens` contient bien des tokens avec `platform = 'ios'` et `is_active = true`

### Erreur "FCM credentials not configured" (Option B uniquement)

- Vérifie que tu as bien ajouté les 3 secrets dans Supabase Dashboard > Settings > Edge Functions > Secrets :
  - `FCM_PROJECT_ID`
  - `FCM_CLIENT_EMAIL`
  - `FCM_PRIVATE_KEY`
- Assure-toi que la `FCM_PRIVATE_KEY` contient bien les `\n` (ne les supprime pas)
- 💡 **Conseil** : Si tu rencontres des problèmes avec l'Option B, essaie l'Option A (API Legacy) qui est plus simple

### Erreur "Permission 'cloudmessaging.messages.create' denied" (Option B uniquement)

- C'est une erreur de permissions IAM du Service Account
- Consulte le fichier `FIX_PERMISSIONS_IAM.md` pour corriger les permissions
- 💡 **Conseil** : L'Option A (API Legacy) ne nécessite pas de permissions IAM complexes, essaie-la d'abord

### Erreur "Invalid registration token"

- Le token FCM peut être expiré ou invalide
- L'app doit se reconnecter pour obtenir un nouveau token
- Vérifie que le token dans `fcm_tokens` correspond bien au token de l'appareil

## 📝 Notes importantes

- **Recommandation** : Commence toujours par l'**Option A (API Legacy)** car elle est plus simple et fonctionne immédiatement
- Les notifications FCM fonctionnent seulement sur **de vrais appareils iOS**, pas sur le simulateur
- Les notifications peuvent prendre quelques secondes à arriver
- Si l'app est fermée depuis longtemps, iOS peut limiter les notifications pour économiser la batterie

## 🎯 Résumé rapide

1. **Commence par l'Option A** (API Legacy) - Plus simple, fonctionne immédiatement
2. **Si l'Option A ne fonctionne pas**, essaie l'Option B (API HTTP v1)
3. **Si l'Option B donne des erreurs de permissions**, consulte `FIX_PERMISSIONS_IAM.md` ou reviens à l'Option A

