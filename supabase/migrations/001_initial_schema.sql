-- ============================================================
-- MySportsBuddies — Initial Schema
-- Mirrors all Firestore collections synced via Cloud Functions
-- ============================================================

-- ── Extensions ────────────────────────────────────────────────────────────────
create extension if not exists "pg_trgm";
create extension if not exists "unaccent";

-- ── Users ─────────────────────────────────────────────────────────────────────
create table if not exists users (
  id                    text        primary key,
  numeric_id            integer     unique,
  name                  text        not null default '',
  email                 text        not null default '',
  phone                 text        not null default '',
  location              text        not null default '',
  dob                   text        not null default '',
  bio                   text        not null default '',
  image_url             text,
  is_premium            boolean     not null default false,
  is_admin              boolean     not null default false,
  plan_tier             text        not null default 'free',
  subscription_status   text        not null default 'none',
  tournaments_played    integer     not null default 0,
  matches_played        integer     not null default 0,
  matches_won           integer     not null default 0,
  favorite_sports       text[]      not null default '{}',
  updated_at            timestamptz not null default now(),
  synced_at             timestamptz not null default now()
);

create index if not exists users_numeric_id_idx on users (numeric_id);
create index if not exists users_name_trgm_idx  on users using gin (name gin_trgm_ops);
create index if not exists users_email_idx      on users (email);

-- ── Venues ────────────────────────────────────────────────────────────────────
create table if not exists venues (
  id              text        primary key,
  owner_id        text        references users (id) on delete set null,
  name            text        not null default '',
  description     text,
  address         text        not null default '',
  lat             double precision,
  lng             double precision,
  sports          text[]      not null default '{}',
  photo_urls      text[]      not null default '{}',
  phone           text,
  email           text,
  price_per_hour  numeric(10,2) not null default 0,
  timings         jsonb,
  status          text        not null default 'active',
  is_verified     boolean     not null default false,
  rating          numeric(3,2) not null default 0,
  review_count    integer     not null default 0,
  created_at      timestamptz not null default now(),
  synced_at       timestamptz not null default now()
);

create index if not exists venues_status_idx  on venues (status);
create index if not exists venues_sports_idx  on venues using gin (sports);

-- ── Tournaments ───────────────────────────────────────────────────────────────
create table if not exists tournaments (
  id                      text        primary key,
  name                    text        not null default '',
  sport                   text        not null default '',
  format                  text        not null default 'knockout',
  status                  text        not null default 'open',
  location                text        not null default '',
  created_by              text        references users (id) on delete set null,
  created_by_name         text        not null default '',
  max_teams               integer     not null default 0,
  players_per_team        integer     not null default 0,
  entry_fee               numeric(10,2) not null default 0,
  service_fee             numeric(10,2) not null default 0,
  registered_teams        integer     not null default 0,
  enrolled_team_names     text[]      not null default '{}',
  prize_pool              text,
  rules                   text,
  description             text,
  banner_url              text,
  is_private              boolean     not null default false,
  join_code               text,
  bracket_generated       boolean     not null default false,
  has_groups              boolean     not null default false,
  group_count             integer     not null default 0,
  scoring_type            text        not null default 'standard',
  best_of                 integer     not null default 3,
  points_to_win           integer     not null default 21,
  win_points              integer     not null default 3,
  draw_points             integer     not null default 1,
  loss_points             integer     not null default 0,
  start_date              timestamptz,
  end_date                timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  synced_at               timestamptz not null default now()
);

create index if not exists tournaments_sport_idx      on tournaments (sport);
create index if not exists tournaments_status_idx     on tournaments (status);
create index if not exists tournaments_created_by_idx on tournaments (created_by);
create index if not exists tournaments_start_date_idx on tournaments (start_date);

-- ── Teams ─────────────────────────────────────────────────────────────────────
create table if not exists teams (
  id                    text        primary key,
  tournament_id         text        not null references tournaments (id) on delete cascade,
  team_name             text        not null default '',
  captain_name          text        not null default '',
  captain_user_id       text        references users (id) on delete set null,
  captain_phone         text,
  vice_captain_name     text,
  vice_captain_user_id  text        references users (id) on delete set null,
  enrolled_by           text        references users (id) on delete set null,
  seed                  integer,
  payment_confirmed     boolean     not null default false,
  enrolled_at           timestamptz not null default now(),
  synced_at             timestamptz not null default now()
);

create index if not exists teams_tournament_id_idx    on teams (tournament_id);
create index if not exists teams_captain_user_id_idx  on teams (captain_user_id);

-- ── Team Players ──────────────────────────────────────────────────────────────
create table if not exists team_players (
  team_id         text        not null references teams (id) on delete cascade,
  tournament_id   text        not null references tournaments (id) on delete cascade,
  user_id         text        references users (id) on delete set null,
  player_name     text        not null default '',
  position        integer,
  primary key (team_id, player_name)
);

create index if not exists team_players_user_id_idx on team_players (user_id);

-- ── Matches (tournament sub-collection) ──────────────────────────────────────
create table if not exists matches (
  id              text        primary key,
  tournament_id   text        references tournaments (id) on delete cascade,
  round           integer     not null default 1,
  match_index     integer     not null default 0,
  team_a_id       text        references teams (id) on delete set null,
  team_a_name     text,
  team_b_id       text        references teams (id) on delete set null,
  team_b_name     text,
  winner_id       text        references teams (id) on delete set null,
  winner_name     text,
  score_a         integer,
  score_b         integer,
  result          text        not null default 'pending',
  is_bye          boolean     not null default false,
  is_live         boolean     not null default false,
  note            text,
  group_id        text,
  venue_id        text        references venues (id) on delete set null,
  venue_name      text,
  live_stream_url text,
  scorecard_data  jsonb,
  scheduled_at    timestamptz,
  updated_at      timestamptz not null default now(),
  synced_at       timestamptz not null default now()
);

create index if not exists matches_tournament_id_idx on matches (tournament_id);
create index if not exists matches_result_idx        on matches (result);
create index if not exists matches_scheduled_at_idx  on matches (scheduled_at);

-- ── Scoreboards (flat top-level matches collection) ───────────────────────────
create table if not exists scoreboards (
  id              text        primary key,
  tournament_id   text        references tournaments (id) on delete cascade,
  sport           text,
  score_data      jsonb,
  team_a_id       text,
  team_a_name     text,
  team_b_id       text,
  team_b_name     text,
  score_a         integer,
  score_b         integer,
  winner_id       text,
  is_live         boolean     not null default false,
  updated_at      timestamptz not null default now(),
  synced_at       timestamptz not null default now()
);

create index if not exists scoreboards_tournament_id_idx on scoreboards (tournament_id);
create index if not exists scoreboards_is_live_idx       on scoreboards (is_live);

-- ── Game Listings ─────────────────────────────────────────────────────────────
create table if not exists game_listings (
  id              text        primary key,
  organizer_id    text        references users (id) on delete set null,
  organizer_name  text,
  sport           text        not null default '',
  venue_name      text,
  address         text,
  lat             double precision,
  lng             double precision,
  scheduled_at    timestamptz,
  max_players     integer,
  current_players integer     not null default 0,
  fee             numeric(10,2) not null default 0,
  description     text,
  status          text        not null default 'open',
  created_at      timestamptz not null default now(),
  synced_at       timestamptz not null default now()
);

create index if not exists game_listings_sport_idx        on game_listings (sport);
create index if not exists game_listings_status_idx       on game_listings (status);
create index if not exists game_listings_scheduled_at_idx on game_listings (scheduled_at);
create index if not exists game_listings_organizer_id_idx on game_listings (organizer_id);

-- ── Follows ───────────────────────────────────────────────────────────────────
create table if not exists follows (
  follower_id   text        not null references users (id) on delete cascade,
  followed_id   text        not null references users (id) on delete cascade,
  created_at    timestamptz not null default now(),
  synced_at     timestamptz not null default now(),
  primary key (follower_id, followed_id)
);

create index if not exists follows_follower_id_idx on follows (follower_id);
create index if not exists follows_followed_id_idx on follows (followed_id);

-- ── Views ─────────────────────────────────────────────────────────────────────

create or replace view v_player_stats as
  select
    id,
    numeric_id,
    name,
    image_url,
    tournaments_played,
    matches_played,
    matches_won,
    case
      when matches_played > 0
      then round(matches_won::numeric / matches_played * 100, 1)
      else 0
    end as win_rate_pct
  from users
  order by matches_won desc, matches_played asc;

create or replace view v_tournament_summary as
  select
    t.id,
    t.name,
    t.sport,
    t.format,
    t.status,
    t.start_date,
    t.end_date,
    t.location,
    t.max_teams,
    t.registered_teams,
    t.entry_fee,
    t.prize_pool,
    u.name as organizer_name,
    count(distinct m.id)                                               as total_matches,
    count(distinct case when m.result != 'pending' then m.id end)     as completed_matches
  from tournaments t
  left join users u  on u.id = t.created_by
  left join matches m on m.tournament_id = t.id
  group by t.id, u.name;

create or replace view v_follow_counts as
  select
    u.id,
    u.name,
    (select count(*) from follows where followed_id = u.id) as follower_count,
    (select count(*) from follows where follower_id = u.id) as following_count
  from users u;
