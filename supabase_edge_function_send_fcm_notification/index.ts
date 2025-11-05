// Supabase Edge Function pour envoyer des notifications push via FCM HTTP v1 API
// Cette fonction utilise l'API HTTP v1 avec un Service Account (au lieu de l'API Legacy)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

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
  // La clé doit être en format PEM (déjà dans le bon format)
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  
  // Extraire la partie base64 de la clé PEM
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
      // Essayer de lire comme texte
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
      // Format du trigger SQL
      notificationId = body.notificationId
      console.log('Format trigger SQL détecté')
    } else if (body?.notification_id) {
      // Format alternatif (snake_case)
      notificationId = body.notification_id
      console.log('Format snake_case détecté')
    } else if (body?.record?.id && body?.table === 'notifications') {
      // Format du webhook Supabase
      notificationId = body.record.id
      console.log('Format webhook Supabase détecté')
      console.log('Record complet:', body.record)
    } else if (body?.id) {
      // Format direct avec id
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
        break // Notification trouvée
      }

      // Attendre un peu avant de réessayer (la notification peut prendre du temps à être disponible)
      if (retryCount < maxRetries - 1) {
        await new Promise(resolve => setTimeout(resolve, 500)) // Attendre 500ms
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

    // Récupérer tous les tokens FCM actifs de manière optimisée
    // Note: Si la fonction RPC n'existe pas, récupérons directement depuis la table
    let tokens = []
    try {
      // Essayer d'abord avec la fonction RPC (plus rapide si elle existe)
      const { data: rpcTokens, error: rpcError } = await supabaseClient
        .rpc('get_fcm_tokens_for_notification', {
          p_user_id: notification.user_id
        })
      
      if (!rpcError && rpcTokens && rpcTokens.length > 0) {
        tokens = rpcTokens
        console.log(`Found ${tokens.length} tokens via RPC function`)
      } else {
        // Fallback: récupérer directement depuis la table fcm_tokens avec une requête optimisée
        let query = supabaseClient
          .from('fcm_tokens')
          .select('fcm_token, platform, user_id, device_id')
          .eq('is_active', true)
        
        // Filtrer par user_id si disponible, sinon envoyer à tous
        if (notification.user_id) {
          // Envoyer à l'utilisateur spécifique OU aux notifications publiques (user_id = NULL)
          const { data: directTokens, error: directError } = await query
            .or(`user_id.eq.${notification.user_id},user_id.is.null`)
          
          if (!directError && directTokens) {
            tokens = directTokens
            console.log(`Found ${tokens.length} tokens via direct query (with user_id filter)`)
          }
        } else {
          // Notification publique: envoyer à tous les tokens actifs
          const { data: directTokens, error: directError } = await query
          
          if (!directError && directTokens) {
            tokens = directTokens
            console.log(`Found ${tokens.length} tokens via direct query (public notification)`)
          }
        }
      }
    } catch (e) {
      console.error('Error fetching FCM tokens:', e)
      // Continuer même si on ne trouve pas de tokens
    }

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

    // Utiliser l'API HTTP v1
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
    
    // Construire les messages pour tous les tokens en parallèle
    const sendPromises = tokens.map(async (tokenData) => {
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

        // Ajouter les configurations spécifiques à la plateforme
        if (platform === 'android') {
          message.android = {
            priority: notification.type === 'error' || notification.type === 'warning' ? 'high' : 'normal',
            notification: {
              sound: 'default',
              channel_id: 'app_notifications',
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
          return { token: fcmToken, success: false, error: result }
        }
      } catch (e) {
        console.error(`Error sending FCM to token ${fcmToken}:`, e)
        return { token: fcmToken, success: false, error: e.message }
      }
    })

    // Envoyer toutes les notifications en parallèle (au lieu de séquentiellement)
    const results = await Promise.all(sendPromises)

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
