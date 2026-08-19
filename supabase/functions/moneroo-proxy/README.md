# Edge Function Moneroo Proxy

Cette Edge Function sert de proxy sécurisé entre l'application Flutter et l'API Moneroo. La clé API Moneroo est stockée dans les variables d'environnement Supabase et n'est jamais exposée dans le code client.

## Déploiement

1. Assurez-vous d'avoir le CLI Supabase installé :
```bash
npm install -g supabase
```

2. Connectez-vous à votre projet Supabase :
```bash
supabase login
supabase link --project-ref odbdgbhfsrkbumjacxdj
```

3. Configurez la clé API Moneroo comme variable d'environnement :
```bash
supabase secrets set MONEROO_SECRET_KEY=votre_cle_secrete_ici
```

4. Déployez la fonction :
```bash
supabase functions deploy moneroo-proxy
```

## Utilisation

L'application Flutter appelle cette Edge Function via l'URL :
```
https://odbdgbhfsrkbumjacxdj.supabase.co/functions/v1/moneroo-proxy
```

La fonction reçoit :
- `endpoint`: L'endpoint Moneroo à appeler (ex: `/payments/initialize`)
- `method`: La méthode HTTP (POST ou GET)
- `body`: Le corps de la requête JSON

Et retourne la réponse de l'API Moneroo directement.
