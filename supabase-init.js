/* Starter connection only. This does not yet replace Smart Waste Agent's localStorage auth/data flows. */
(function () {
  'use strict';
  const config = window.SWA_CONFIG || {};
  const ready = Boolean(
    config.SUPABASE_URL &&
    config.SUPABASE_PUBLISHABLE_KEY &&
    !config.SUPABASE_URL.includes('YOUR_PROJECT_REF') &&
    !config.SUPABASE_PUBLISHABLE_KEY.includes('YOUR_SUPABASE_')
  );

  const badge = document.createElement('div');
  badge.id = 'swa-supabase-status';
  badge.setAttribute('role', 'status');
  badge.style.cssText = 'position:fixed;right:12px;bottom:12px;z-index:99999;padding:9px 12px;border-radius:10px;font:700 12px/1.4 system-ui;box-shadow:0 4px 18px #0002;background:#fff7ed;color:#9a3412;border:1px solid #fed7aa;max-width:min(340px,calc(100vw - 24px))';
  badge.textContent = ready ? 'Supabase: konfigurasi tersedia, memeriksa koneksi…' : 'Supabase belum dikonfigurasi — isi config.js';
  document.addEventListener('DOMContentLoaded', () => document.body.appendChild(badge));

  if (!ready) return;
  if (!window.supabase || typeof window.supabase.createClient !== 'function') {
    badge.textContent = 'Supabase gagal dimuat. Periksa koneksi internet / CDN.';
    badge.style.background = '#fef2f2'; badge.style.color = '#991b1b';
    return;
  }

  const client = window.supabase.createClient(config.SUPABASE_URL, config.SUPABASE_PUBLISHABLE_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });
  window.swaSupabase = client;
  window.swaSupabaseConnectionTest = async function () {
    // Lightweight query: RLS may return zero rows for a signed-out visitor; that's not a connection failure.
    const { error } = await client.from('profiles').select('id').limit(1);
    if (error && !/JWT|permission|row-level security/i.test(error.message || '')) throw error;
    return { connected: true, signedIn: Boolean((await client.auth.getSession()).data.session) };
  };
  window.swaSupabaseConnectionTest().then(result => {
    badge.textContent = result.signedIn ? 'Supabase terhubung · sesi login Supabase aktif' : 'Supabase terhubung · belum login melalui Supabase';
    badge.style.background = '#ecfdf3'; badge.style.color = '#166534'; badge.style.borderColor = '#bbf7d0';
  }).catch(error => {
    console.error('Smart Waste Agent Supabase connection test failed:', error);
    badge.textContent = 'Supabase belum terverifikasi. Periksa URL, key, dan tabel profiles.';
    badge.style.background = '#fef2f2'; badge.style.color = '#991b1b'; badge.style.borderColor = '#fecaca';
  });
})();
