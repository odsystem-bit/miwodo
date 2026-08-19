import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MONEROO_API_BASE = 'https://api.moneroo.io/v1';
const MONEROO_SECRET_KEY = Deno.env.get('MONEROO_SECRET_KEY') || '';

// Supabase client for rate limiting
const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Domaines autorisés à appeler ce proxy
const ALLOWED_ORIGINS = [
  'https://odbdgbhfsrkbumjacxdj.supabase.co',
  'https://miwodo.app',
  'https://miwodo.tg',
  'http://localhost:8080',
  'http://localhost:3000',
];

function getCorsHeaders(origin: string | null): Record<string, string> {
  const allowedOrigin = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  };
}

// Endpoints Moneroo autorisés (whitelist)
const ALLOWED_ENDPOINTS = ['/payments/'];

// ─── RATE LIMITING ──────────────────────────────────────────────────────────
interface RateLimitConfig {
  maxRequests: number;
  windowMs: number;
}

const RATE_LIMITS: Record<string, RateLimitConfig> = {
  inscription: { maxRequests: 20, windowMs: 60 * 60 * 1000 },
  commande: { maxRequests: 30, windowMs: 60 * 60 * 1000 },
  publicite: { maxRequests: 15, windowMs: 60 * 60 * 1000 },
  verification: { maxRequests: 60, windowMs: 60 * 1000 },
};

async function checkRateLimit(type: string, identifier: string): Promise<boolean> {
  const config = RATE_LIMITS[type];
  if (!config) return true;

  const key = `${type}_${identifier}`;
  const now = Date.now();
  const windowStart = now - config.windowMs;

  try {
    // Récupérer les requêtes récentes
    const { data, error } = await supabase
      .from('rate_limits')
      .select('requests')
      .eq('key', key)
      .single();

    if (error && error.code !== 'PGRST116') {
      console.warn('Rate limit check error:', error.message);
      return true; // fail-open
    }

    const requests: number[] = data?.requests || [];
    const validRequests = requests.filter((ts: number) => ts > windowStart);

    if (validRequests.length >= config.maxRequests) {
      return false;
    }

    validRequests.push(now);

    // Upsert
    await supabase
      .from('rate_limits')
      .upsert({ key, requests: validRequests, updated_at: new Date().toISOString() }, { onConflict: 'key' });

    return true;
  } catch (err) {
    console.warn('Rate limit failed:', err);
    return true; // fail-open
  }
}

// ─── VALIDATION CUSTOMER ────────────────────────────────────────────────────
function validateCustomer(customer: any): string | null {
  if (!customer || typeof customer !== 'object') {
    return 'Customer manquant';
  }
  if (!customer.email || typeof customer.email !== 'string') {
    return 'Customer.email est requis';
  }
  if (!customer.first_name || typeof customer.first_name !== 'string') {
    return 'Customer.first_name est requis';
  }
  if (!customer.last_name || typeof customer.last_name !== 'string') {
    return 'Customer.last_name est requis';
  }
  return null;
}

// ─── VALIDATION MONTANT SELON PAYS ──────────────────────────────────────────
async function getPaysConfig(paysId: string): Promise<any | null> {
  try {
    const { data, error } = await supabase
      .from('pays_config')
      .select('*')
      .eq('id', 'pays')
      .single();

    if (error || !data) return null;

    const items = data.items || [];
    return items.find((p: any) => p.id === paysId && p.actif) || null;
  } catch (err) {
    console.error('Erreur lecture config pays:', err);
    return null;
  }
}

function getClientIP(req: Request): string {
  const xff = req.headers.get('x-forwarded-for');
  return xff ? xff.split(',')[0].trim() : 'unknown';
}

function jsonResponse(body: any, status: number, corsHeaders: Record<string, string>): Response {
  return new Response(
    JSON.stringify(body),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

serve(async (req) => {
  const origin = req.headers.get('origin');
  const corsHeaders = getCorsHeaders(origin);
  const clientIP = getClientIP(req);

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // Refuser tout sauf POST
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Méthode non autorisée' }, 405, corsHeaders);
  }

  try {
    const { method, endpoint, body } = await req.json();

    // Valider l'endpoint (whitelist)
    if (!endpoint || !ALLOWED_ENDPOINTS.some(e => endpoint.startsWith(e))) {
      return jsonResponse({ error: 'Endpoint non autorisé' }, 403, corsHeaders);
    }

    if (!MONEROO_SECRET_KEY) {
      return jsonResponse({ error: 'MONEROO_SECRET_KEY non configuré' }, 500, corsHeaders);
    }

    // Construire l'URL Moneroo
    const url = `${MONEROO_API_BASE}${endpoint}`;

    // ─── Validation pour /payments/initialize ───────────────────────────
    if (endpoint === '/payments/initialize') {
      if (!body || !body.amount || !body.currency || !body.customer || !body.description) {
        return jsonResponse({ error: 'Données de paiement incomplètes (amount, currency, customer, description requis)' }, 400, corsHeaders);
      }

      // Valider le customer (last_name, first_name, email requis)
      const customerError = validateCustomer(body.customer);
      if (customerError) {
        return jsonResponse({ error: customerError }, 400, corsHeaders);
      }

      // Valider le montant
      if (typeof body.amount !== 'number' || body.amount <= 0 || body.amount > 10000000) {
        return jsonResponse({ error: 'Montant invalide' }, 400, corsHeaders);
      }

      // Rate limiting selon le type de paiement (metadata.type)
      const paymentType = body.metadata?.type || 'commande';
      const rateLimitKey = paymentType === 'inscription' ? 'inscription'
        : paymentType === 'publicite' ? 'publicite'
        : 'commande';

      const allowed = await checkRateLimit(rateLimitKey, clientIP);
      if (!allowed) {
        const config = RATE_LIMITS[rateLimitKey];
        return jsonResponse({
          error: `Trop de requêtes. Réessayez dans ${Math.ceil(config.windowMs / 60000)} minutes.`
        }, 429, corsHeaders);
      }

      // Validation côté serveur selon le pays
      const paysId = body.metadata?.pays_id || 'TG';
      const paysConfig = await getPaysConfig(paysId);

      if (paysConfig) {
        // Vérifier la devise
        if (body.currency !== paysConfig.devise) {
          return jsonResponse({
            error: `Devise invalide. Attendu: ${paysConfig.devise}`
          }, 400, corsHeaders);
        }

        // Pour les inscriptions, vérifier le montant
        if (paymentType === 'inscription') {
          const expected = paysConfig.inscription_montant;
          const tolerance = expected * 0.01;
          if (Math.abs(body.amount - expected) > tolerance) {
            return jsonResponse({
              error: `Montant invalide pour ${paysConfig.id}. Attendu: ${expected} ${paysConfig.devise}`
            }, 400, corsHeaders);
          }
        }

        // Pour les publicités, vérifier le montant
        if (paymentType === 'publicite') {
          const plan = body.metadata?.plan;
          const expected = plan === 'premium' ? paysConfig.pub_premium_montant : paysConfig.pub_standard_montant;
          const tolerance = expected * 0.01;
          if (Math.abs(body.amount - expected) > tolerance) {
            return jsonResponse({
              error: `Montant invalide pour la publicité ${plan}. Attendu: ${expected} ${paysConfig.devise}`
            }, 400, corsHeaders);
          }
        }

        // Vérifier les méthodes de paiement
        if (body.methods && Array.isArray(body.methods)) {
          const allowedMethods = paysConfig.moneroo_methods || [];
          const invalid = body.methods.filter((m: string) => !allowedMethods.includes(m));
          if (invalid.length > 0) {
            return jsonResponse({
              error: `Méthodes de paiement non autorisées pour ${paysConfig.id}: ${invalid.join(', ')}`
            }, 400, corsHeaders);
          }
        }
      }
    }

    // ─── Rate limiting pour /payments/verify (tout endpoint /payments/ sauf /payments/initialize) ──
    if (endpoint.startsWith('/payments/') && !endpoint.startsWith('/payments/initialize')) {
      const allowed = await checkRateLimit('verification', clientIP);
      if (!allowed) {
        return jsonResponse({
          error: 'Trop de vérifications. Réessayez dans 1 minute.'
        }, 429, corsHeaders);
      }
    }

    // S'assurer que amount est un entier (Moneroo exige integer, pas float)
    if (body && typeof body.amount === 'number' && !Number.isInteger(body.amount)) {
      body.amount = Math.floor(body.amount);
    }

    // Log détaillé pour debug
    console.log('[moneroo-proxy] Request:', JSON.stringify({
      endpoint,
      method: method || 'POST',
      amount: body?.amount,
      currency: body?.currency,
      methods: body?.methods,
      customer_email: body?.customer?.email,
      metadata: body?.metadata,
    }));

    // Appel à l'API Moneroo
    const response = await fetch(url, {
      method: method || 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${MONEROO_SECRET_KEY}`,
        'Accept': 'application/json',
      },
      body: method === 'GET' ? undefined : JSON.stringify(body),
    });

    // Lire le body raw d'abord
    const rawText = await response.text();
    console.log('[moneroo-proxy] Moneroo response status:', response.status, 'raw:', rawText.substring(0, 500));

    // Parser le JSON si possible
    let data: any = null;
    try {
      data = rawText ? JSON.parse(rawText) : null;
    } catch (_) {
      // Body non-JSON
      console.error('[moneroo-proxy] Non-JSON response from Moneroo:', rawText.substring(0, 200));
    }

    // Si Moneroo retourne une erreur, la transmettre avec le message
    if (!response.ok) {
      const errorMsg = data?.message || data?.error || data?.errors?.[0]?.message || rawText.substring(0, 200) || 'Erreur Moneroo';
      console.error('[moneroo-proxy] Moneroo error:', response.status, errorMsg);
      return jsonResponse({
        error: errorMsg,
        moneroo_status: response.status,
        moneroo_raw: rawText.substring(0, 500),
      }, response.status, corsHeaders);
    }

    // Moneroo retourne { message, data: { id, checkout_url, ... } }
    // Extraire le champ data pour le retourner à plat
    const result = (data && data.data) ? data.data : data;

    return jsonResponse(result, response.status, corsHeaders);
  } catch (error) {
    return jsonResponse({ error: 'Erreur interne du proxy' }, 500, corsHeaders);
  }
});
