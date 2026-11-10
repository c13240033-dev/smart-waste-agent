-- Smart Waste Agent: starter schema for Supabase.
-- Run in Supabase Dashboard > SQL Editor only after reviewing the project.
-- RLS is enabled on every application table. No service_role key belongs in the browser.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  full_name text,
  company text,
  phone text,
  role text not null default 'operator' check (role in ('admin','operator','driver')),
  verification_status text not null default 'Menunggu verifikasi'
    check (verification_status in ('Menunggu verifikasi','Terverifikasi','Ditolak')),
  assigned_truck_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.bsu_locations (
  id text primary key,
  name text not null,
  address text,
  latitude double precision,
  longitude double precision,
  current_weight_ton numeric(10,3) not null default 0 check (current_weight_ton >= 0),
  capacity_ton numeric(10,3) not null default 2 check (capacity_ton > 0),
  waste_type text,
  status text not null default 'Normal',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.trucks (
  id text primary key,
  name text,
  capacity_ton numeric(10,3) not null default 0 check (capacity_ton >= 0),
  current_load_ton numeric(10,3) not null default 0 check (current_load_ton >= 0),
  status text not null default 'Menunggu verifikasi',
  verification_status text not null default 'Menunggu verifikasi'
    check (verification_status in ('Menunggu verifikasi','Terverifikasi','Ditolak')),
  latitude double precision,
  longitude double precision,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.destinations (
  id text primary key,
  name text not null,
  destination_type text not null default 'BSI',
  address text,
  latitude double precision,
  longitude double precision,
  capacity_ton numeric(10,3),
  accepted_waste_types text[] not null default '{}',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pickup_trips (
  id uuid primary key default gen_random_uuid(),
  truck_id text references public.trucks(id) on update cascade on delete set null,
  driver_id uuid references public.profiles(id) on delete set null,
  status text not null default 'Direkomendasikan',
  pickup_order jsonb not null default '[]'::jsonb,
  route jsonb not null default '[]'::jsonb,
  total_load_ton numeric(10,3) not null default 0,
  eta timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  approved_by uuid references public.profiles(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.truck_gps_positions (
  id bigint generated always as identity primary key,
  truck_id text not null references public.trucks(id) on update cascade on delete cascade,
  driver_id uuid references public.profiles(id) on delete set null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_m double precision,
  recorded_at timestamptz not null default now(),
  source text not null default 'device'
);
create index if not exists truck_gps_positions_truck_time_idx
  on public.truck_gps_positions (truck_id, recorded_at desc);

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  detail jsonb not null default '{}'::jsonb,
  status text not null default 'Tercatat',
  created_at timestamptz not null default now()
);

-- Authorization helpers. Security definer avoids recursive RLS when profiles is checked.
create or replace function public.current_app_role()
returns text language sql stable security definer
set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.current_user_verified()
returns boolean language sql stable security definer
set search_path = public
as $$ select coalesce((select verification_status = 'Terverifikasi' from public.profiles where id = auth.uid()), false) $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer
set search_path = public
as $$ select coalesce(public.current_app_role() = 'admin' and public.current_user_verified(), false) $$;

create or replace function public.is_operator_or_admin()
returns boolean language sql stable security definer
set search_path = public
as $$ select coalesce(public.current_app_role() in ('admin','operator') and public.current_user_verified(), false) $$;

-- A newly registered account is ALWAYS a pending operator by default.
-- Role/verification must be granted by an admin, not by client-provided signup metadata.
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, full_name, company, phone, role, verification_status)
  values (
    new.id,
    nullif(trim(new.raw_user_meta_data->>'username'), ''),
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(trim(new.raw_user_meta_data->>'company'), ''),
    nullif(trim(new.raw_user_meta_data->>'phone'), ''),
    'operator',
    'Menunggu verifikasi'
  ) on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_swa on auth.users;
create trigger on_auth_user_created_swa
after insert on auth.users
for each row execute procedure public.handle_new_auth_user();

-- Enable RLS everywhere.
alter table public.profiles enable row level security;
alter table public.bsu_locations enable row level security;
alter table public.trucks enable row level security;
alter table public.destinations enable row level security;
alter table public.pickup_trips enable row level security;
alter table public.truck_gps_positions enable row level security;
alter table public.app_settings enable row level security;
alter table public.audit_log enable row level security;

-- Profiles: users see their own profile; Admin sees all. Users cannot grant themselves roles.
drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin on public.profiles for select to authenticated
using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_update_admin_only on public.profiles;
create policy profiles_update_admin_only on public.profiles for update to authenticated
using (public.is_admin()) with check (public.is_admin());

-- Master data: Admin writes; verified operator/admin reads. Drivers don't read all master data.
 do $$ declare t text; begin
  foreach t in array array['bsu_locations','trucks','destinations'] loop
    execute format('drop policy if exists %I on public.%I', t || '_select_staff', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_operator_or_admin())', t || '_select_staff', t);
    execute format('drop policy if exists %I on public.%I', t || '_admin_write', t);
    execute format('create policy %I on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())', t || '_admin_write', t);
  end loop;
end $$;

-- Trips: verified Admin/Operator can manage; Driver only sees their own assigned trips.
drop policy if exists pickup_trips_select on public.pickup_trips;
create policy pickup_trips_select on public.pickup_trips for select to authenticated
using (public.is_operator_or_admin() or (public.current_user_verified() and driver_id = auth.uid()));
drop policy if exists pickup_trips_staff_write on public.pickup_trips;
create policy pickup_trips_staff_write on public.pickup_trips for all to authenticated
using (public.is_operator_or_admin()) with check (public.is_operator_or_admin());
drop policy if exists pickup_trips_driver_update_own on public.pickup_trips;
create policy pickup_trips_driver_update_own on public.pickup_trips for update to authenticated
using (public.current_user_verified() and driver_id = auth.uid())
with check (public.current_user_verified() and driver_id = auth.uid());

-- GPS: Admin/Operator see all; driver only sees GPS rows for trucks assigned in their profile.
drop policy if exists gps_select_staff_or_assigned_driver on public.truck_gps_positions;
create policy gps_select_staff_or_assigned_driver on public.truck_gps_positions for select to authenticated
using (
  public.is_operator_or_admin() or
  (public.current_user_verified() and exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.assigned_truck_id = truck_gps_positions.truck_id
  ))
);
drop policy if exists gps_insert_staff_or_assigned_driver on public.truck_gps_positions;
create policy gps_insert_staff_or_assigned_driver on public.truck_gps_positions for insert to authenticated
with check (
  public.is_operator_or_admin() or
  (public.current_user_verified() and driver_id = auth.uid() and exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.assigned_truck_id = truck_gps_positions.truck_id
  ))
);
drop policy if exists gps_admin_update_delete on public.truck_gps_positions;
create policy gps_admin_update_delete on public.truck_gps_positions for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists gps_admin_delete on public.truck_gps_positions;
create policy gps_admin_delete on public.truck_gps_positions for delete to authenticated using (public.is_admin());

-- Settings: staff can read; only Admin writes.
drop policy if exists app_settings_read_staff on public.app_settings;
create policy app_settings_read_staff on public.app_settings for select to authenticated using (public.is_operator_or_admin());
drop policy if exists app_settings_admin_write on public.app_settings;
create policy app_settings_admin_write on public.app_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Audit: staff can read; verified users can append their own audit entries; Admin can manage all.
drop policy if exists audit_read_staff on public.audit_log;
create policy audit_read_staff on public.audit_log for select to authenticated using (public.is_operator_or_admin());
drop policy if exists audit_insert_own_or_admin on public.audit_log;
create policy audit_insert_own_or_admin on public.audit_log for insert to authenticated
with check (actor_id = auth.uid() or public.is_admin());
drop policy if exists audit_admin_update_delete on public.audit_log;
create policy audit_admin_update_delete on public.audit_log for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists audit_admin_delete on public.audit_log;
create policy audit_admin_delete on public.audit_log for delete to authenticated using (public.is_admin());

-- Important: promote the first Admin manually only after creating its Supabase Auth account.
-- Replace the UUID with that user's id from Authentication > Users:
-- update public.profiles set role='admin', verification_status='Terverifikasi' where id='PASTE-AUTH-USER-UUID-HERE';
