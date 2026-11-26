# Car Price Check

Site de test « Votre voiture est-elle au juste prix ? » et son tableau de bord de gestion.

- `index.html` : le site public (calcul du tarif, partage d'offre ou de facture, demande de courtier, offres de marques).
- `admin.html` (ou `/admin`) : le tableau de bord, protégé par e-mail et mot de passe.
- `confidentialite.html` : projet de politique de confidentialité, à faire valider par le DPO.
- `config.js` : les seuls réglages à modifier (connexion Supabase, chiffres du marché).
- `supabase/schema.sql` : la base de données et ses règles de sécurité.
- `vendor/` : la bibliothèque Supabase (version 2.45.4), incluse pour ne dépendre d'aucun CDN.

Aucune étape de compilation : ce sont des fichiers statiques.

## Ce qui est enregistré

| Action du visiteur | Table | Données personnelles |
|---|---|---|
| « Calculer mon tarif » | `simulations` | Aucune |
| Partage d'une offre ou facture | `shares` + fichier dans l'espace privé `documents` | E-mail, document |
| « Être rappelé » (courtier) | `broker_leads` | Téléphone ou e-mail |
| « Recevoir leurs offres » (marques) | `brand_leads` | E-mail |

Les visiteurs peuvent seulement ajouter des lignes. Ils ne peuvent rien lire, modifier ni supprimer. Seuls les comptes inscrits dans la table `admins` voient les données. Le site public ne dépose aucun cookie.

## Mise en ligne (environ 30 minutes)

### 1. Supabase (la base de données)

1. Créez un compte sur supabase.com, puis **New project**. Région : **Central EU (Frankfurt)**. Notez le mot de passe de la base dans un endroit sûr.
2. Ouvrez **SQL Editor > New query**. Collez tout le contenu de `supabase/schema.sql`, puis cliquez sur **Run**. Le message « Success » doit s'afficher.
3. Dans **Authentication > Sign In / Providers**, désactivez **Allow new users to sign up**. Ainsi, personne ne peut se créer un compte.
4. Dans **Authentication > Users > Add user > Create new user**, créez votre compte (e-mail + mot de passe solide), avec « Auto Confirm User » coché.
5. Retournez dans **SQL Editor** et exécutez cette ligne, avec votre adresse :
   ```sql
   insert into public.admins (user_id) select id from auth.users where email = 'votre-adresse@exemple.be';
   ```
6. Dans **Project Settings > API**, copiez l'**URL du projet** et la clé **anon public**. Collez-les dans `config.js`. Cette clé est faite pour être publique. Ne mettez **jamais** la clé `service_role` dans le site.

### 2. Netlify (l'hébergement)

1. Créez un compte sur netlify.com avec votre compte GitHub.
2. **Add new site > Import an existing project > GitHub**, puis choisissez le dépôt `car-price-check`. Laissez la commande de build vide et le dossier de publication à `.`, puis cliquez sur **Deploy**.
3. Netlify donne une adresse du type `https://nom-au-hasard.netlify.app`. Vous pouvez la renommer dans **Site configuration > Change site name**, par exemple `carpricecheck-test`.
4. Chaque modification envoyée sur GitHub met le site à jour automatiquement.

Le fichier `netlify.toml` empêche Google d'indexer cette version de test.

### 3. Vérification

1. Ouvrez le site, cliquez sur « Calculer mon tarif » et attendez le résultat.
2. Ouvrez `/admin`, puis connectez-vous. La simulation doit apparaître dans le tableau de bord.
3. Testez une demande de courtier et un partage de document, puis vérifiez-les dans les onglets correspondants.

Tant que `config.js` est vide, le site fonctionne en **mode démo** et n'envoie rien. Chaque message de confirmation le signale.

## Utiliser le tableau de bord

- **Période** : 7, 30 ou 90 jours, ou tout.
- **Indicateurs** : simulations, taux de leads, documents reçus, éléments à traiter.
- **Onglets** : changez le statut de chaque lead (nouveau, transmis, contacté…), notez le courtier, ajoutez une note.
- **Documents** : « Ouvrir » crée un lien valable 2 minutes et passe le partage en « lu ». « Supprimer » efface le fichier, comme le site le promet (« votre document est supprimé après lecture »).
- **Export CSV** : par onglet. Il s'ouvre dans Excel avec le séparateur `;`.

## À faire avant d'ouvrir au public

- [ ] Remplacer les chiffres d'exemple du marché (`config.js > market`) par de vrais chiffres issus des factures, puis passer `source` à `'reel'` et retirer les mentions « Exemple illustratif ».
- [ ] Faire valider `confidentialite.html` et les textes de consentement par le DPO, compléter les mentions légales (raison sociale, BCE, adresse, e-mail de contact).
- [ ] Vérifier le statut FSMA avant de transmettre ou vendre des leads à des courtiers.
- [ ] Justifier le « 3 000 € de moins » du bloc marques avec de vraies données (ou le calculer par visiteur), pour éviter une publicité trompeuse.
- [ ] Obtenir l'accord des marques pour l'usage de leurs logos, ou les remplacer par leurs noms.
- [ ] Remplacer les annonces d'exemple par de vraies annonces, ou les retirer.
- [ ] Héberger les polices localement au lieu de Google Fonts.
- [ ] Choisir le nom de domaine définitif et le relier dans Netlify (**Domain management**), puis retirer le `noindex` de `netlify.toml` et de `index.html`, et le `robots.txt`.
- [ ] Ajouter une protection anti-abus si des envois indésirables apparaissent (par exemple Cloudflare Turnstile).
