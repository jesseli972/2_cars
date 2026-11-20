-- 2 Cars push notifications setup.
-- Paste this whole file into Supabase: SQL Editor -> New query -> Run.
-- Safe to run more than once. Run supabase/chat.sql first.

-- Marks a message once its notification has gone out, so it can never be sent twice.
alter table public.chat_messages add column if not exists pushed boolean not null default false;

-- Phones that turned notifications on. Locked: only the functions below and the
-- chat-push Edge Function (which connects as the database owner) can touch it.
create table if not exists public.push_subscriptions (
  endpoint   text primary key check (endpoint ~ '^https://' and char_length(endpoint) < 1000),
  device     text not null check (char_length(device) between 8 and 40),
  p256dh     text not null check (char_length(p256dh) between 40 and 200),
  auth       text not null check (char_length(auth) between 10 and 100),
  created_at timestamptz not null default now()
);
alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from anon, authenticated;

-- The server's push signing keys. Created automatically by the Edge Function the first time it runs.
create table if not exists public.push_config (
  id          int primary key check (id = 1),
  public_key  text not null,
  private_key text not null
);
alter table public.push_config enable row level security;
revoke all on public.push_config from anon, authenticated;

create or replace function public.push_subscribe(p_endpoint text, p_p256dh text, p_auth text, p_device text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into public.push_subscriptions (endpoint, device, p256dh, auth)
  values (p_endpoint, p_device, p_p256dh, p_auth)
  on conflict (endpoint) do update set device = excluded.device, p256dh = excluded.p256dh, auth = excluded.auth;
  -- keep at most 3 subscriptions per phone
  delete from public.push_subscriptions
  where device = p_device and endpoint not in (
    select endpoint from public.push_subscriptions where device = p_device order by created_at desc limit 3);
end;
$$;

create or replace function public.push_unsubscribe(p_endpoint text)
returns void
language sql security definer set search_path = public as $$
  delete from public.push_subscriptions where endpoint = p_endpoint;
$$;

revoke all on function public.push_subscribe(text, text, text, text) from public;
revoke all on function public.push_unsubscribe(text) from public;
grant execute on function public.push_subscribe(text, text, text, text) to anon, authenticated;
grant execute on function public.push_unsubscribe(text) to anon, authenticated;
