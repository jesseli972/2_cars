-- 2 Cars leaderboard setup.
-- Paste this whole file into Supabase: SQL Editor -> New query -> Run.
-- Safe to run more than once.

-- Every personal best that a phone posts. Rows can be added and read, never edited or deleted.
create table if not exists public.scores (
  id         bigint generated always as identity primary key,
  name       text        not null check (char_length(name) between 1 and 16 and name ~ '^[A-Za-z0-9 _.\-]+$'),
  mode       text        not null check (mode in ('easy', 'hard')),
  score      integer     not null check (score between 1 and 5000),
  seconds    real        not null check (seconds > 0 and seconds < 7200),
  device     text        not null check (char_length(device) between 8 and 40),
  created_at timestamptz not null default now(),
  -- sanity check: nobody can score faster than objects actually spawn
  constraint plausible_score check (score <= seconds * 7 + 5)
);

create index if not exists scores_mode_score on public.scores (mode, score desc);

alter table public.scores enable row level security;

drop policy if exists "anyone can read scores" on public.scores;
create policy "anyone can read scores" on public.scores
  for select to anon, authenticated using (true);

drop policy if exists "anyone can add a score" on public.scores;
create policy "anyone can add a score" on public.scores
  for insert to anon, authenticated with check (true);

grant select, insert on public.scores to anon, authenticated;

-- One row per player (phone) per mode: their best score and the name they used for it.
create or replace view public.leaderboard
with (security_invoker = true) as
select distinct on (mode, device)
  mode, name, score, device, created_at
from public.scores
order by mode, device, score desc, created_at asc;

grant select on public.leaderboard to anon, authenticated;
