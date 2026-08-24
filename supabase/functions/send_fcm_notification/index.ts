// Supabase Edge Function pour envoyer des notifications push via FCM HTTP v1 API
// Cette fonction utilise l'API HTTP v1 avec un Service Account (au lieu de l'API Legacy)
//
// Corrections appliquées (voir CHANGELOG en bas du fichier) :
//  1. channel_id aligné sur les canaux réellement créés par l'application
//  2. une notification destinée à un utilisateur n'est plus envoyée à tous
//     les appareils non connectés
//  3. l'auteur d'une publication ne reçoit plus sa propre notification
//  4. déduplication des tokens (un appareil ne reçoit qu'un seul push)
//  5. pagination : tous les appareils sont notifiés, plus seulement les 1000
//     premiers (limite de lignes de PostgREST)
//  6. envoi par lots de 100 au lieu d'un seul Promise.all géant

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Identifiants des canaux Android créés par l'application
// (voir NotificationService.defaultChannelId / importantChannelId).
// Un channel_id inconnu de l'application fait perdre le son et la priorité.
const DEFAULT_CHANNEL_ID = 'default_channel'
const IMPORTANT_CHANNEL_ID = 'important_channel'

// Fonction pour obtenir un access token OAuth2 avec les credentials du Service Account
async function getAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL')
  const privateKey = Deno.env.get('FCM_PRIVATE_KEY')

  if (!clientEmail || !privateKey) {
    throw new Error('FCM credentials not configured. Please set FCM_CLIENT_EMAIL and FCM_PRIVATE_KEY')
  }

  // Nettoyer la clé privée (remplacer \n littéraux par de vraies nouvelles lignes)
  const cleanedPrivateKey = privateKey.replace(/\\n/g, '\n')

  // Créer le JWT claim
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const claim = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  }

  // Encoder le header et le claim en base64url
  const encoder = new TextEncoder()
  const base64UrlEncode = (str: string) => {
    return btoa(str)
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '')
  }

  const encodedHeader = base64UrlEncode(JSON.stringify(header))
  const encodedClaim = base64UrlEncode(JSON.stringify(claim))
  const unsignedJWT = `${encodedHeader}.${encodedClaim}`

  // Importer la clé privée au format PEM
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'

  const keyBase64 = cleanedPrivateKey
    .replace(pemHeader, '')
    .replace(pemFooter, '')
    .replace(/\s/g, '')

  const keyBytes = Uint8Array.from(atob(keyBase64), c => c.charCodeAt(0))

  // Importer la clé avec Web Crypto API
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  )

  // Signer le JWT
  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    cryptoKey,
    encoder.encode(unsignedJWT)
  )

  // Encoder la signature en base64url
  const encodedSignature = base64UrlEncode(
    String.fromCharCode(...new Uint8Array(signature))
  )

  // Créer le JWT final
  const jwt = `${unsignedJWT}.${encodedSignature}`

  // Obtenir l'access token via OAuth2
  const tokenUrl = 'https://oauth2.googleapis.com/token'
  const tokenResponse = await fetch(tokenUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text()
    console.error('Error getting access token:', errorText)
    throw new Error(`Failed to get access token: ${tokenResponse.status} - ${errorText}`)
  }

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

/// Identifiant de l'auteur de la notification, stocké dans le payload JSON.
function getCreatorId(payload: string | null): string | null {
  if (!payload) return null
  try {
    const data = JSON.parse(payload)
    return typeof data?.created_by === 'string' ? data.created_by : null
  } catch (_) {
    return null
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Lire le body de la requête
    let body
    try {
      body = await req.json()
      console.log('Body reçu:', body)
    } catch (e) {
      console.error('Erreur lors de la lecture du body:', e)
      const textBody = await req.text()
      console.log('Body texte:', textBody)
      try {
        body = JSON.parse(textBody)
      } catch (parseError) {
        console.error('Erreur lors du parsing JSON:', parseError)
        throw new Error('Invalid JSON body')
      }
    }

    // Extraire notificationId selon le format reçu
    // Format 1: { "notificationId": "..." } (trigger SQL)
    // Format 2: { "type": "INSERT", "table": "notifications", "record": { "id": "..." } } (webhook)
    let notificationId = null

    if (body?.notificationId) {
      notificationId = body.notificationId
      console.log('Format trigger SQL détecté')
    } else if (body?.notification_id) {
      notificationId = body.notification_id
      console.log('Format snake_case détecté')
    } else if (body?.record?.id && body?.table === 'notifications') {
      notificationId = body.record.id
      console.log('Format webhook Supabase détecté')
      console.log('Record complet:', body.record)
    } else if (body?.id) {
      notificationId = body.id
      console.log('Format direct avec id détecté')
    }

    if (!notificationId) {
      console.error('notificationId manquant. Body reçu:', JSON.stringify(body))
      throw new Error('notificationId is required. Body received: ' + JSON.stringify(body))
    }

    console.log('notificationId extrait:', notificationId)

    // Créer le client Supabase
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Récupérer la notification avec retry (car l'insertion peut prendre un peu de temps)
    let notification = null
    let notificationError = null
    const maxRetries = 3
    let retryCount = 0

    while (retryCount < maxRetries && !notification) {
      const result = await supabaseClient
        .from('notifications')
        .select('*')
        .eq('id', notificationId)
        .single()

      notification = result.data
      notificationError = result.error

      if (notification) {
        break
      }

      if (retryCount < maxRetries - 1) {
        await new Promise(resolve => setTimeout(resolve, 500))
      }

      retryCount++
    }

    if (notificationError || !notification) {
      console.error('Notification not found after retries:', {
        notificationId,
        error: notificationError,
        retries: retryCount
      })
      throw new Error(`Notification not found: ${notificationId}`)
    }

    // Récupérer les tokens FCM actifs concernés par cette notification.
    //
    // IMPORTANT : PostgREST plafonne toute réponse à 1000 lignes. Le projet
    // compte plus de 1900 appareils actifs : sans pagination, près de la
    // moitié d'entre eux ne recevait jamais rien (l'ancienne version passait
    // par une RPC qui renvoyait exactement 1000 lignes, silencieusement
    // tronquées).
    let tokens: any[] = []
    try {
      const pageSize = 1000
      for (let from = 0; ; from += pageSize) {
        let query = supabaseClient
          .from('fcm_tokens')
          .select('fcm_token, platform, user_id, device_id')
          .eq('is_active', true)

        if (notification.user_id) {
          // Notification personnelle : UNIQUEMENT les appareils de cet
          // utilisateur. (Auparavant les appareils non connectés — user_id
          // NULL — recevaient aussi les notifications privées des autres.)
          query = query.eq('user_id', notification.user_id)
        }

        const { data: page, error: pageError } = await query
          .order('updated_at', { ascending: false })
          .range(from, from + pageSize - 1)

        if (pageError) {
          console.error('Error fetching FCM tokens:', pageError)
          break
        }
        if (!page || page.length === 0) break

        tokens = tokens.concat(page)
        if (page.length < pageSize) break
      }

      console.log(`Found ${tokens.length} active tokens`)
    } catch (e) {
      console.error('Error fetching FCM tokens:', e)
    }

    // Ne pas notifier l'auteur de sa propre publication : l'application
    // filtre déjà côté client, mais quand elle est fermée c'est le système
    // qui affiche la notification, donc le filtrage doit se faire ici.
    const creatorId = getCreatorId(notification.payload)
    if (creatorId) {
      const before = tokens.length
      tokens = tokens.filter((t: any) => t.user_id !== creatorId)
      if (before !== tokens.length) {
        console.log(`Skipped ${before - tokens.length} token(s) of the author (${creatorId})`)
      }
    }

    // Un même appareil peut avoir plusieurs lignes : n'envoyer qu'une fois
    const seen = new Set<string>()
    tokens = tokens.filter((t: any) => {
      const value = t.fcm_token || t.token
      if (!value || seen.has(value)) return false
      seen.add(value)
      return true
    })

    if (!tokens || tokens.length === 0) {
      console.log('No FCM tokens found for this notification')
      return new Response(
        JSON.stringify({ success: true, message: 'No tokens to send' }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        },
      )
    }

    // Obtenir l'access token OAuth2
    let accessToken: string
    try {
      accessToken = await getAccessToken()
    } catch (error) {
      console.error('Error getting access token:', error)
      throw new Error(`Failed to get access token: ${error.message}`)
    }

    const projectId = Deno.env.get('FCM_PROJECT_ID')
    if (!projectId) {
      throw new Error('FCM_PROJECT_ID not configured')
    }

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    const isImportant =
      notification.type === 'error' || notification.type === 'warning'

    // Construire les messages pour tous les tokens en parallèle
    const sendPromises = tokens.map(async (tokenData: any) => {
      const fcmToken = tokenData.fcm_token || tokenData.token
      const platform = tokenData.platform || 'android'

      try {
        // Construire le message selon le format HTTP v1
        const message: any = {
          token: fcmToken,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: {
            notification_id: notification.id,
            type: notification.type || 'info',
            payload: notification.payload || '',
          },
        }

        if (platform === 'android') {
          message.android = {
            priority: isImportant ? 'high' : 'normal',
            notification: {
              sound: 'default',
              // Doit correspondre à un canal créé par l'application, sinon
              // Android retombe sur un canal générique et l'importance
              // configurée (son, bannière) est perdue.
              channel_id: isImportant ? IMPORTANT_CHANNEL_ID : DEFAULT_CHANNEL_ID,
            },
          }
        } else if (platform === 'ios') {
          message.apns = {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
                alert: {
                  title: notification.title,
                  body: notification.body,
                },
              },
            },
          }
        }

        const response = await fetch(fcmUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ message }),
        })

        const result = await response.json()

        if (response.ok) {
          return { token: fcmToken, success: true, result }
        } else {
          console.error(`Error sending FCM to token ${fcmToken}:`, result)

          // Si le token est invalide (UNREGISTERED), le marquer comme inactif
          if (result.error?.details?.[0]?.errorCode === 'UNREGISTERED' ||
              result.error?.code === 404 ||
              (result.error?.message && result.error.message.includes('not found'))) {
            console.log(`🗑️ Token invalide détecté, marquage comme inactif: ${fcmToken.substring(0, 20)}...`)
            try {
              await supabaseClient
                .from('fcm_tokens')
                .update({ is_active: false, updated_at: new Date().toISOString() })
                .eq('fcm_token', fcmToken)
              console.log(`✅ Token marqué comme inactif: ${fcmToken.substring(0, 20)}...`)
            } catch (cleanupError) {
              console.error(`⚠️ Erreur lors du nettoyage du token: ${cleanupError}`)
            }
          }

          return { token: fcmToken, success: false, error: result }
        }
      } catch (e) {
        console.error(`Error sending FCM to token ${fcmToken}:`, e)
        return { token: fcmToken, success: false, error: e.message }
      }
    })

    // Envoyer par lots : un Promise.all de ~2000 requêtes épuiserait les
    // ressources de la fonction et se ferait limiter par FCM.
    const results: any[] = []
    const batchSize = 100
    for (let i = 0; i < sendPromises.length; i += batchSize) {
      const batch = sendPromises.slice(i, i + batchSize)
      results.push(...(await Promise.all(batch)))
    }

    const successCount = results.filter(r => r.success).length
    const failureCount = results.filter(r => !r.success).length

    console.log(`FCM notifications sent: ${successCount} success, ${failureCount} failures (sent in parallel)`)

    return new Response(
      JSON.stringify({
        success: true,
        notification: notification.title,
        sent: successCount,
        failed: failureCount,
        total: tokens.length,
        results,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})
