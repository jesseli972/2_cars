-- 2 Cars chat setup.
-- Paste this whole file into Supabase: SQL Editor -> New query -> Run.
-- Safe to run more than once. Run supabase/setup.sql first if you haven't.

-- The game uses a single room, 'global', so everyone playing shares one chat.
-- The table itself is locked: the app can only read or post through the two functions below.
create table if not exists public.chat_messages (
  id         bigint generated always as identity primary key,
  room       text        not null check (room ~ '^[a-z0-9-]{4,32}$'),
  name       text        not null check (char_length(name) between 1 and 16 and name ~ '^[A-Za-z0-9 _.\-]+$'),
  device     text        not null check (char_length(device) between 8 and 40),
  body       text        not null check (char_length(body) between 1 and 300),
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_room_id on public.chat_messages (room, id);

alter table public.chat_messages enable row level security;  -- no policies: no direct access
revoke all on public.chat_messages from anon, authenticated;

-- Messages in one room newer than p_after (up to 100, last 7 days).
create or replace function public.chat_fetch(p_room text, p_after bigint default 0)
returns table (id bigint, name text, device text, body text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select * from (
    select m.id, m.name, m.device, m.body, m.created_at
    from public.chat_messages m
    where m.room = lower(p_room) and m.id > coalesce(p_after, 0)
      and m.created_at > now() - interval '7 days'
    order by m.id desc
    limit 100
  ) recent order by id;
$$;

-- Post a message. At most 5 messages per phone per 10 seconds; messages older than 7 days are cleared out.
create or replace function public.chat_send(p_room text, p_name text, p_device text, p_body text)
returns bigint
language plpgsql security definer set search_path = public as $$
declare new_id bigint;
begin
  if (select count(*) from public.chat_messages
      where device = p_device and created_at > now() - interval '10 seconds') >= 5 then
    raise exception 'Slow down a little' using errcode = 'P0001';
  end if;
  delete from public.chat_messages where created_at < now() - interval '7 days';
  insert into public.chat_messages (room, name, device, body)
  values (lower(p_room), p_name, p_device, btrim(p_body))
  returning id into new_id;
  return new_id;
end;
$$;

revoke all on function public.chat_fetch(text, bigint) from public;
revoke all on function public.chat_send(text, text, text, text) from public;
grant execute on function public.chat_fetch(text, bigint) to anon, authenticated;
grant execute on function public.chat_send(text, text, text, text) to anon, authenticated;
