# Correction des permissions IAM pour FCM API v1

## Problème
Erreur : `Permission 'cloudmessaging.messages.create' denied`

## Solution rapide (Recommandé)
Utilise l'API Legacy FCM au lieu de l'API v1. Voir `GUIDE_NOTIFICATIONS_IOS.md` - Option A.

## Solution : Corriger les permissions IAM (si tu veux utiliser l'API v1)

### Étape 1 : Vérifier le Service Account

1. Va dans [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionne ton projet Firebase
3. Va dans **IAM & Admin** > **Service Accounts**
4. Trouve le Service Account que tu as créé (celui avec `FCM_CLIENT_EMAIL`)

### Étape 2 : Ajouter les permissions nécessaires

1. Clique sur le Service Account
2. Va dans l'onglet **Permissions**
3. Clique sur **Grant Access** (ou **Grant Access**)
4. Ajoute ces rôles :
   - **Firebase Cloud Messaging Admin** (ou `roles/firebasemessaging.admin`)
   - **Firebase Admin SDK Administrator Service Agent** (ou `roles/firebase.adminsdk.adminServiceAgent`)
5. Clique sur **Save**

### Étape 3 : Activer l'API FCM

1. Va dans [Google Cloud Console APIs](https://console.cloud.google.com/apis/library)
2. Recherche "Firebase Cloud Messaging API"
3. Clique sur **Enable** si ce n'est pas déjà activé

### Étape 4 : Vérifier le projet ID

Assure-toi que `FCM_PROJECT_ID` dans Supabase correspond au **Project ID** (pas au Project Number) :
- Va dans [Google Cloud Console](https://console.cloud.google.com/) > **Settings**
- Copie le **Project ID** (pas le Project Number)
- Vérifie que c'est bien celui dans `FCM_PROJECT_ID`

### Étape 5 : Redéployer l'Edge Function

Après avoir corrigé les permissions, redéploie l'Edge Function dans Supabase Dashboard.

## Alternative : Utiliser l'API Legacy (Plus simple)

Si tu veux éviter ces problèmes de permissions, utilise l'API Legacy :
1. Utilise le fichier `index-legacy.ts` au lieu de `index.ts`
2. Configure seulement `FCM_SERVER_KEY` (pas besoin de Service Account)
3. Voir `GUIDE_NOTIFICATIONS_IOS.md` - Option A

