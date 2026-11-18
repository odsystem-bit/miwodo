-- Table pour le rate limiting du proxy Moneroo
CREATE TABLE IF NOT EXISTS public.rate_limits (
  key TEXT PRIMARY KEY,
  requests JSONB DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Activer RLS mais permettre l'accès au service role
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Service role full access" ON public.rate_limits;
CREATE POLICY "Service role full access" ON public.rate_limits
  FOR ALL USING (auth.role() = 'service_role');

-- Table pour la configuration des pays (miroir de Firestore config/pays)
-- Permet au proxy Supabase de valider montants et méthodes côté serveur
CREATE TABLE IF NOT EXISTS public.pays_config (
  id TEXT PRIMARY KEY DEFAULT 'pays',
  items JSONB DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.pays_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Service role full access" ON public.pays_config;
CREATE POLICY "Service role full access" ON public.pays_config
  FOR ALL USING (auth.role() = 'service_role');

-- Insérer les pays par défaut (sync avec Firestore config/pays)
-- IMPORTANT: Doit être synchronisé avec lib/services/config_service.dart
INSERT INTO public.pays_config (id, items) VALUES ('pays', '[
  {"id":"TG","nom":"Togo","actif":true,"devise":"XOF","symbole":"F CFA","inscription_montant":500,"gain_parrainage":100,"commission_fixe_commande":100,"pub_standard_montant":2000,"pub_premium_montant":5000,"retrait_minimum":500,"moneroo_methods":["moov_tg","togocel"]},
  {"id":"CI","nom":"Côte d''Ivoire","actif":true,"devise":"XOF","symbole":"F CFA","inscription_montant":500,"gain_parrainage":100,"commission_fixe_commande":100,"pub_standard_montant":2000,"pub_premium_montant":5000,"retrait_minimum":500,"moneroo_methods":["orange_ci","mtn_ci","moov_ci","wave_ci"]},
  {"id":"SN","nom":"Sénégal","actif":true,"devise":"XOF","symbole":"F CFA","inscription_montant":500,"gain_parrainage":100,"commission_fixe_commande":100,"pub_standard_montant":2000,"pub_premium_montant":5000,"retrait_minimum":500,"moneroo_methods":["orange_sn","wave_sn","freemoney_sn"]},
  {"id":"BJ","nom":"Bénin","actif":true,"devise":"XOF","symbole":"F CFA","inscription_montant":500,"gain_parrainage":100,"commission_fixe_commande":100,"pub_standard_montant":2000,"pub_premium_montant":5000,"retrait_minimum":500,"moneroo_methods":["mtn_bj","moov_bj"]},
  {"id":"GH","nom":"Ghana","actif":true,"devise":"GHS","symbole":"GH₵","inscription_montant":10,"gain_parrainage":5,"commission_fixe_commande":2,"pub_standard_montant":30,"pub_premium_montant":80,"retrait_minimum":10,"moneroo_methods":["mtn_gh","tigo_gh","vodafone_gh"]},
  {"id":"NG","nom":"Nigeria","actif":true,"devise":"NGN","symbole":"₦","inscription_montant":500,"gain_parrainage":200,"commission_fixe_commande":100,"pub_standard_montant":3000,"pub_premium_montant":8000,"retrait_minimum":1000,"moneroo_methods":["airtel_ng"]},
  {"id":"ML","nom":"Mali","actif":true,"devise":"XOF","symbole":"F CFA","inscription_montant":500,"gain_parrainage":100,"commission_fixe_commande":100,"pub_standard_montant":2000,"pub_premium_montant":5000,"retrait_minimum":500,"moneroo_methods":["orange_ml"]},
  {"id":"BF","nom":"Burkina Faso","actif":true,"devise":"XOF","symbole":"F CFA","inscription_montant":500,"gain_parrainage":100,"commission_fixe_commande":100,"pub_standard_montant":2000,"pub_premium_montant":5000,"retrait_minimum":500,"moneroo_methods":["orange_bf","moov_bf"]},
  {"id":"NE","nom":"Niger","actif":true,"devise":"XOF","symbole":"F CFA","inscription_montant":500,"gain_parrainage":100,"commission_fixe_commande":100,"pub_standard_montant":2000,"pub_premium_montant":5000,"retrait_minimum":500,"moneroo_methods":["airtel_ne"]},
  {"id":"GN","nom":"Guinée","actif":true,"devise":"GNF","symbole":"GNF","inscription_montant":5000,"gain_parrainage":1000,"commission_fixe_commande":500,"pub_standard_montant":20000,"pub_premium_montant":50000,"retrait_minimum":5000,"moneroo_methods":["mtn_gn"]},
  {"id":"CM","nom":"Cameroun","actif":true,"devise":"XAF","symbole":"F CFA","inscription_montant":500,"gain_parrainage":100,"commission_fixe_commande":100,"pub_standard_montant":2000,"pub_premium_montant":5000,"retrait_minimum":500,"moneroo_methods":[]},
  {"id":"GA","nom":"Gabon","actif":true,"devise":"XAF","symbole":"F CFA","inscription_montant":1000,"gain_parrainage":200,"commission_fixe_commande":200,"pub_standard_montant":4000,"pub_premium_montant":10000,"retrait_minimum":1000,"moneroo_methods":[]},
  {"id":"CD","nom":"RD Congo","actif":true,"devise":"CDF","symbole":"FC","inscription_montant":500,"gain_parrainage":100,"commission_fixe_commande":100,"pub_standard_montant":2000,"pub_premium_montant":5000,"retrait_minimum":500,"moneroo_methods":[]},
  {"id":"KE","nom":"Kenya","actif":true,"devise":"KES","symbole":"KSh","inscription_montant":100,"gain_parrainage":50,"commission_fixe_commande":20,"pub_standard_montant":500,"pub_premium_montant":1500,"retrait_minimum":100,"moneroo_methods":[]},
  {"id":"UG","nom":"Ouganda","actif":true,"devise":"UGX","symbole":"USh","inscription_montant":500,"gain_parrainage":100,"commission_fixe_commande":100,"pub_standard_montant":2000,"pub_premium_montant":5000,"retrait_minimum":500,"moneroo_methods":[]},
  {"id":"TZ","nom":"Tanzanie","actif":true,"devise":"TZS","symbole":"TSh","inscription_montant":500,"gain_parrainage":100,"commission_fixe_commande":100,"pub_standard_montant":2000,"pub_premium_montant":5000,"retrait_minimum":500,"moneroo_methods":[]},
  {"id":"FR","nom":"France","actif":true,"devise":"EUR","symbole":"€","inscription_montant":1,"gain_parrainage":0.15,"commission_fixe_commande":0,"pub_standard_montant":3,"pub_premium_montant":8,"retrait_minimum":5,"moneroo_methods":["card_eur","crypto_eur"]},
  {"id":"BE","nom":"Belgique","actif":true,"devise":"EUR","symbole":"€","inscription_montant":1,"gain_parrainage":0.15,"commission_fixe_commande":0,"pub_standard_montant":3,"pub_premium_montant":8,"retrait_minimum":5,"moneroo_methods":["card_eur","crypto_eur"]},
  {"id":"CA","nom":"Canada","actif":true,"devise":"CAD","symbole":"CA$","inscription_montant":2,"gain_parrainage":0.3,"commission_fixe_commande":0,"pub_standard_montant":5,"pub_premium_montant":12,"retrait_minimum":10,"moneroo_methods":["card_cad"]},
  {"id":"US","nom":"États-Unis","actif":true,"devise":"USD","symbole":"$","inscription_montant":2,"gain_parrainage":0.3,"commission_fixe_commande":0,"pub_standard_montant":5,"pub_premium_montant":12,"retrait_minimum":10,"moneroo_methods":["card_usd","crypto_usd"]}
]'::jsonb)
ON CONFLICT (id) DO UPDATE SET items = EXCLUDED.items, updated_at = now();
