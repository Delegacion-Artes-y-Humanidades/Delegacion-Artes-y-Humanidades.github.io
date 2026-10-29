-- Altar de Muertos Virtual: correcciones, borrado y panel de la organizadora.
-- Pégalo completo en Supabase → SQL Editor → New query → Run. No borra ni cambia las ofrendas que ya están.

-- 1. Quién es organizadora (entra al panel #admin con este correo)
create table if not exists public.organizadoras (email text primary key);
alter table public.organizadoras enable row level security;
insert into public.organizadoras (email) values ('adriana.villalvazo@academicos.udg.mx') on conflict do nothing;

create or replace function public.es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.organizadoras where email = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;

-- 2. La organizadora puede corregir y borrar ofrendas
drop policy if exists "organizadora corrige" on public.ofrendas;
create policy "organizadora corrige" on public.ofrendas
  for update to authenticated using (public.es_admin()) with check (public.es_admin());
drop policy if exists "organizadora borra" on public.ofrendas;
create policy "organizadora borra" on public.ofrendas
  for delete to authenticated using (public.es_admin());

-- 3. Solicitudes de corrección o borrado: cualquiera las envía, solo la organizadora las ve
create table if not exists public.solicitudes (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  ofrenda_id  uuid references public.ofrendas(id) on delete set null,
  nombre      text not null check (char_length(nombre) between 1 and 60),
  tipo        text not null check (tipo in ('corregir','borrar')),
  mensaje     text not null check (char_length(mensaje) between 1 and 400),
  contacto    text check (char_length(contacto) <= 80),
  atendida    boolean not null default false
);
alter table public.solicitudes enable row level security;
drop policy if exists "todos piden" on public.solicitudes;
create policy "todos piden" on public.solicitudes
  for insert to anon, authenticated with check (atendida = false);
drop policy if exists "organizadora ve" on public.solicitudes;
create policy "organizadora ve" on public.solicitudes
  for select to authenticated using (public.es_admin());
drop policy if exists "organizadora atiende" on public.solicitudes;
create policy "organizadora atiende" on public.solicitudes
  for update to authenticated using (public.es_admin()) with check (public.es_admin());
drop policy if exists "organizadora borra solicitudes" on public.solicitudes;
create policy "organizadora borra solicitudes" on public.solicitudes
  for delete to authenticated using (public.es_admin());

-- 4. Fotos: la organizadora puede ver la lista y borrar las de una ofrenda que quita
drop policy if exists "organizadora ve fotos" on storage.objects;
create policy "organizadora ve fotos" on storage.objects
  for select to authenticated using (bucket_id = 'fotos' and public.es_admin());
drop policy if exists "organizadora borra fotos" on storage.objects;
create policy "organizadora borra fotos" on storage.objects
  for delete to authenticated using (bucket_id = 'fotos' and public.es_admin());
