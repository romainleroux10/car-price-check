// Car Price Check : réglages du site.
// 1. Collez ici l'URL du projet Supabase et la clé "anon public" (Supabase > Project Settings > API).
//    Cette clé est faite pour être publique : la sécurité vient des règles de la base (supabase/schema.sql).
//    Ne mettez JAMAIS ici la clé "service_role".
// 2. Tant que ces deux valeurs sont vides, le site fonctionne en mode démo et n'envoie rien.
window.CPC_CONFIG = {
  supabaseUrl: 'https://vqvtxxmepsvncedvnwuw.supabase.co',
  supabaseAnonKey: 'sb_publishable_Um7bN0VzJWt04XmtxLRDag_IU3bndhk',

  // Marché de référence utilisé pour le calcul. Ce sont des EXEMPLES tant que les vraies factures ne sont pas analysées.
  market: {
    avgDiscount: 0.12,  // remise moyenne sur le prix catalogue (12 %)
    sd: 0.035,          // dispersion des remises (3,5 points)
    n: 148,             // nombre de prix comparés affiché
    source: 'exemple'   // passer à 'reel' quand les chiffres viennent de vraies factures
  },

  // Version des textes de consentement, enregistrée avec chaque lead (preuve RGPD).
  // À changer à chaque modification d'une case à cocher.
  consentVersion: '2026-11-24'
};
