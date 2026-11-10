# Smart Waste Agent — Supabase + GitHub starter

This folder contains the uploaded Smart Waste Agent HTML as `index.html`, a starter Supabase schema, and a small connection checker.

## Konfigurasi proyek yang diberikan

- Project URL yang digunakan di `config.js`: `https://tknrjngdezzmmchdpccu.supabase.co`
- URL yang dikirim berakhiran `/rest/v1/`; itu adalah endpoint REST, bukan base Project URL untuk `createClient`, sehingga akhiran tersebut sengaja tidak digunakan.
- `config.js` berisi anon key yang diberikan. Key ini publik untuk pemakaian browser; keamanan tetap bergantung pada RLS dan kebijakan database.

## Important status

- The current HTML uses browser-local persistence and a local demo login flow. Copying this starter into GitHub does **not** automatically synchronize application records across devices.
- `supabase-init.js` only initializes the Supabase client and shows a connection status badge. It is a safe first integration step, not a complete data/auth migration.
- The SQL schema creates normalized tables and row-level security (RLS) policies. The app's login, registration, role verification, master data, trip, GPS and audit functions still need to be migrated to these tables before using this as a production system.
- The SQL trigger makes new accounts pending Operators by default; a user cannot self-assign Admin using signup metadata.

## 1. Configure Supabase

1. Open the existing project at https://supabase.com/dashboard.
2. Go to **SQL Editor** and run `supabase/schema.sql` after reviewing it. If your project already has tables with these names, stop and reconcile the schema first rather than blindly re-running it.
3. Go to **Project Settings → API** (wording may vary) and copy the Project URL and publishable key, or legacy `anon` key.
4. `config.js` sudah disiapkan dengan Project URL dan anon key yang diberikan. Jika mengubah kredensial, salin `config.js.example` ke `config.js` lalu perbarui nilainya. File `config.js` masuk `.gitignore` agar tidak ikut ter-commit secara tidak sengaja.
5. Never use a `service_role` key or secret key in `config.js`, HTML, JavaScript, or GitHub.
6. Create the first account via Supabase Auth. In **Authentication → Users**, copy its UUID. In SQL Editor run the commented promotion statement at the bottom of `schema.sql`, replacing the placeholder UUID, to grant that account Admin and verified status.

## 2. Enable the connection badge in `index.html`

Add these three tags immediately before `</body>` in `index.html`, in this order:

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script src="config.js"></script>
<script src="supabase-init.js"></script>
```

Then open the site through a local web server or deployed HTTPS URL (not `file://`). A status badge appears at the bottom-right. Do not treat this as proof that the current simulator data is synchronized; it only checks that the Supabase client can reach the project.

## 3. Create GitHub repository and publish

1. Sign in at https://github.com and create a **new empty repository** named `smart-waste-agent` (do not add a README/license if you will upload this folder as-is).
2. Upload `index.html`, `supabase-init.js`, `README.md`, `.gitignore`, and the `supabase/` folder. Untuk GitHub Pages, `config.js` juga harus tersedia di folder website saat dipublikasikan. Karena key anon/publishable adalah key publik, kamu dapat mengunggah `config.js` jika memilih deployment statis langsung; pastikan tidak pernah menaruh service-role/secret key di dalamnya. Alternatifnya, simpan key di konfigurasi build layanan hosting yang mendukung environment variables.
3. Create `config.js` locally using `config.js.example`. Because `.gitignore` excludes it, it will not be committed. For a GitHub Pages static site, a browser-visible publishable/anon key is expected; RLS policies are what protect the data. Do not place secrets in client code.
4. In repository **Settings → Pages**, choose deployment from the `main` branch and `/ (root)`, then save. Wait for GitHub Pages to show the published URL.
5. Since GitHub Pages cannot securely inject private server secrets, keep only the public publishable/anon key in client config. Never put service-role keys in the repository.

## 4. Required before real multi-device use

- Replace local demo login/registration with `supabase.auth.signInWithPassword`, `signUp`, `signOut`, and `getSession`.
- Read role and verification status from `public.profiles`, never from client-provided role fields.
- Migrate BSU, trucks, destinations, trips, GPS updates, audit records, and settings to the matching Supabase tables.
- Add realtime subscriptions where needed for the driver map and operational updates; unsubscribe when leaving the view.
- Review RLS policies with separate Admin, Operator, Driver, and signed-out test accounts. The driver must only see their assigned trip and truck GPS.
- Test GPS permissions on HTTPS; browsers usually block geolocation on insecure origins except localhost.
- Back up existing local data before migration. Do not upload user passwords or local password hashes to Supabase.

## Files

- `index.html` — original uploaded prototype copied without modifying its application logic.
- `config.js.example` — safe placeholders for public Supabase settings.
- `supabase-init.js` — Supabase client initialization and connection badge only.
- `supabase/schema.sql` — starter tables, trigger, and RLS policies.
Deployment Smart Waste Agent
