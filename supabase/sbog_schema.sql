-- =====================================================================
-- Sbog (سبوق) — Supabase schema, v2 (all features)
-- ---------------------------------------------------------------------
-- Sections
--   1. Players & sign-in      profiles (guest + Facebook)
--   2. Game content           challenges, round_types
--   3. Online rooms           rooms, room_players, room_rounds,
--                             round_submissions
--   4. AI photo check         photo_checks + "round-photos" bucket
--   5. شوط الحَكَم            judge_votes
--   6. المقالب                prank_types, room_prank_cards, prank_events
--   7. حوش الجمل              camels, foods, camel_meals, accessories,
--                             player_accessories, alaf_ledger
--   8. Views                  global_leaderboard, camel_status,
--                             camel_meal_counts, room_prank_stats
--   9. Game functions (RPC)
--  10. Row Level Security, Storage, Realtime
--
-- Game rules this follows (from GameManager.swift + the agreed designs):
--   • 2–5 players, one host, 10 rounds
--   • normal round: 10 s, 2 points to the first finder, 1 to the rest
--   • عجلة الشوط: each round gets a type (عادي، لون، ثنائي، خاطف، ذهبي)
--   • شوط الحَكَم: open prompt, players vote, +3 / +1
--   • المقالب: عجاج / عقال (3 s) and درع (blocks the next prank)
--   • حوش الجمل: score becomes «علف»; feed, dress, clean the camel;
--     a happy camel gives +1 once per game (host can turn it off)
--
-- Photo check: the app uploads the photo to Storage, then calls the
-- Edge Function "verify-photo". The function calls the AI API with a
-- secret key, writes a row in photo_checks, and if it matches calls
-- record_find(). Clients can never award themselves points.
-- =====================================================================

create extension if not exists pgcrypto;

create type room_status  as enum ('lobby', 'playing', 'finished', 'abandoned');
create type round_phase  as enum ('shooting', 'voting', 'done');
create type challenge_kind as enum ('object', 'color', 'open');


-- =====================================================================
-- 1. Players & sign-in
-- =====================================================================
-- Guest    → supabase.auth.signInAnonymously()
-- Facebook → supabase.auth.signInWithOAuth(provider: .facebook)
-- Guest → Facebook later: supabase.auth.linkIdentity(.facebook) keeps the
-- same user id, so stats, camel and items are kept.
create table public.profiles (
    id                 uuid primary key references auth.users (id) on delete cascade,
    username           text not null unique check (char_length(username) between 2 and 20),
    avatar_image_name  text not null default 'player1',      -- player1…player4
    is_guest           boolean not null default true,
    auth_provider      text not null default 'guest' check (auth_provider in ('guest', 'facebook')),
    facebook_photo_url text,
    total_games_played int  not null default 0,
    total_score        int  not null default 0,
    best_score         int  not null default 0,
    games_won          int  not null default 0,
    average_score      numeric(6,2) generated always as
                       (case when total_games_played > 0
                             then total_score::numeric / total_games_played else 0 end) stored,
    level              int generated always as (total_score / 100 + 1) stored,  -- every 100 points
    alaf               int  not null default 0 check (alaf >= 0),               -- علف balance
    tutorial_done_at   timestamptz,                                             -- تحدّي الشبح finished
    ghost_best_ms      int,                                                     -- best time vs the ghost
    created_at         timestamptz not null default now(),
    last_played_at     timestamptz
);


-- =====================================================================
-- 2. Game content (editable without an app update)
-- =====================================================================

-- What a round asks for. ai_labels are the words the AI may return for it.
--   object → a thing to find          (كتاب، كوب…)
--   color  → anything of that colour   (شي أحمر)
--   open   → a prompt for شوط الحَكَم   (صوّر شي يشبه الجمل)
create table public.challenges (
    id          smallint generated always as identity primary key,
    kind        challenge_kind not null default 'object',
    name_ar     text not null,
    name_en     text not null,
    ai_labels   text[] not null default '{}',
    difficulty  smallint not null default 1 check (difficulty between 1 and 3),
    is_active   boolean not null default true
);

insert into public.challenges (kind, name_en, name_ar, ai_labels) values
    ('object', 'book',         'كتاب',        '{book,notebook,binder}'),
    ('object', 'glasses',      'نظارة',       '{glasses,sunglasses,eyeglasses}'),
    ('object', 'water bottle', 'قارورة موية', '{water bottle,bottle}'),
    ('object', 'phone',        'جوال',        '{phone,cellular telephone,smartphone}'),
    ('object', 'cup',          'كوب',         '{cup,mug,coffee mug}'),
    ('object', 'bag',          'شنطة',        '{bag,backpack,handbag}'),
    ('object', 'shoes',        'جزمة',        '{shoe,sneaker,sandal}'),
    ('object', 'pen',          'قلم',         '{pen,pencil,ballpoint}'),
    ('object', 'watch',        'ساعة',        '{watch,wristwatch,clock}'),
    ('object', 'keys',         'مفاتيح',      '{key,keys,keychain}'),
    ('color',  'something red',    'شي أحمر',  '{red}'),
    ('color',  'something yellow', 'شي أصفر',  '{yellow}'),
    ('color',  'something green',  'شي أخضر',  '{green}'),
    ('open',   'looks like a camel', 'صوّر شي يشبه الجمل', '{}'),
    ('open',   'the oldest thing',   'صوّر أقدم شي عندك',   '{}');

-- عجلة الشوط: round types and their rules.
create table public.round_types (
    code          text primary key,
    name_ar       text not null,
    duration_sec  smallint not null,
    points_first  smallint not null,
    points_other  smallint not null,
    targets       smallint not null default 1,      -- ثنائي needs 2 objects
    kind          challenge_kind not null default 'object',
    wheel_weight  smallint not null default 0       -- 0 = never picked by the wheel
);

insert into public.round_types values
    ('normal', 'عادي',  10, 2, 1, 1, 'object', 4),
    ('color',  'لون',   10, 2, 1, 1, 'color',  2),
    ('double', 'ثنائي', 15, 2, 1, 2, 'object', 2),
    ('flash',  'خاطف',   5, 2, 1, 1, 'object', 2),
    ('golden', 'ذهبي',  10, 4, 1, 1, 'object', 1),
    ('judge',  'الحَكَم', 15, 3, 1, 1, 'open',   0);   -- points_first/other = 1st/2nd by votes


-- =====================================================================
-- 3. Online rooms
-- =====================================================================
create table public.rooms (
    id                  uuid primary key default gen_random_uuid(),
    code                text not null unique check (code ~ '^[A-Z0-9]{5}$'),
    host_id             uuid not null references public.profiles (id),
    status              room_status not null default 'lobby',
    max_players         smallint not null default 5  check (max_players between 2 and 5),
    total_rounds        smallint not null default 10 check (total_rounds between 1 and 20),
    round_duration_sec  smallint not null default 10 check (round_duration_sec between 5 and 60),
    current_round       smallint not null default 0,
    -- إعدادات الشوط (lobby toggles)
    wheel_enabled       boolean not null default false,
    pranks_enabled      boolean not null default false,
    judge_enabled       boolean not null default false,
    pen_bonus_enabled   boolean not null default true,
    created_at          timestamptz not null default now(),
    started_at          timestamptz,
    finished_at         timestamptz
);
create index rooms_status_idx on public.rooms (status);

create table public.room_players (
    room_id          uuid not null references public.rooms (id) on delete cascade,
    player_id        uuid not null references public.profiles (id) on delete cascade,
    is_host          boolean not null default false,
    score            int not null default 0,
    final_rank       smallint,
    pen_bonus_ready  boolean not null default false,   -- camel was happy at start
    pen_bonus_used   boolean not null default false,
    shield_active    boolean not null default false,   -- درع is up
    joined_at        timestamptz not null default now(),
    left_at          timestamptz,
    primary key (room_id, player_id)
);
create index room_players_player_idx on public.room_players (player_id);

-- One row per round. ends_at / vote_ends_at come from the server clock.
create table public.room_rounds (
    room_id        uuid not null references public.rooms (id) on delete cascade,
    round_number   smallint not null,
    round_type     text not null default 'normal' references public.round_types (code),
    challenge_id   smallint not null references public.challenges (id),
    challenge2_id  smallint references public.challenges (id),   -- ثنائي only
    phase          round_phase not null default 'shooting',
    started_at     timestamptz not null default now(),
    ends_at        timestamptz not null,
    vote_ends_at   timestamptz,                                  -- شوط الحَكَم only
    primary key (room_id, round_number)
);

-- Points won in a round. Also the history for the race replay.
create table public.round_submissions (
    room_id        uuid not null,
    round_number   smallint not null,
    player_id      uuid not null references public.profiles (id) on delete cascade,
    photo_check_id bigint,
    response_ms    int  not null check (response_ms >= 0),
    points         smallint not null check (points between 0 and 5),
    submitted_at   timestamptz not null default now(),
    primary key (room_id, round_number, player_id),
    foreign key (room_id, round_number)
        references public.room_rounds (room_id, round_number) on delete cascade
);


-- =====================================================================
-- 4. AI photo check (written only by the verify-photo Edge Function)
-- =====================================================================
create table public.photo_checks (
    id              bigint generated always as identity primary key,
    room_id         uuid not null,
    round_number    smallint not null,
    player_id       uuid not null references public.profiles (id) on delete cascade,
    target_index    smallint not null default 1 check (target_index in (1, 2)),
    storage_path    text,                       -- round-photos/{room}/{round}/{player}.jpg
    ai_provider     text not null,              -- which API answered
    ai_labels       jsonb not null default '[]',-- raw labels + scores from the API
    best_label      text,
    confidence      real check (confidence between 0 and 1),
    is_match        boolean,                    -- null for شوط الحَكَم (people decide)
    latency_ms      int,
    created_at      timestamptz not null default now(),
    foreign key (room_id, round_number)
        references public.room_rounds (room_id, round_number) on delete cascade
);
create index photo_checks_round_idx on public.photo_checks (room_id, round_number);

alter table public.round_submissions
    add foreign key (photo_check_id) references public.photo_checks (id) on delete set null;


-- =====================================================================
-- 5. شوط الحَكَم — votes on anonymous photos
-- =====================================================================
create table public.judge_votes (
    room_id         uuid not null,
    round_number    smallint not null,
    voter_id        uuid not null references public.profiles (id) on delete cascade,
    photo_player_id uuid not null references public.profiles (id) on delete cascade,
    created_at      timestamptz not null default now(),
    primary key (room_id, round_number, voter_id),
    check (voter_id <> photo_player_id),                      -- no voting for yourself
    foreign key (room_id, round_number)
        references public.room_rounds (room_id, round_number) on delete cascade
);


-- =====================================================================
-- 6. المقالب
-- =====================================================================
create table public.prank_types (
    code          text primary key,
    name_ar       text not null,
    effect_sec    smallint not null default 0,
    is_defense    boolean not null default false,
    starting_qty  smallint not null default 1
);

insert into public.prank_types values
    ('dust',   'عجاج', 3, false, 1),   -- covers the target's camera
    ('iqal',   'عقال', 3, false, 1),   -- locks the target's shutter button
    ('shield', 'درع',  0, true,  1);   -- blocks the next prank

create table public.room_prank_cards (
    room_id    uuid not null references public.rooms (id) on delete cascade,
    player_id  uuid not null references public.profiles (id) on delete cascade,
    prank_code text not null references public.prank_types (code),
    remaining  smallint not null default 0 check (remaining >= 0),
    primary key (room_id, player_id, prank_code)
);

-- Each throw. The target's app listens over Realtime and plays the effect.
create table public.prank_events (
    id            bigint generated always as identity primary key,
    room_id       uuid not null references public.rooms (id) on delete cascade,
    round_number  smallint not null,
    from_player   uuid not null references public.profiles (id) on delete cascade,
    to_player     uuid not null references public.profiles (id) on delete cascade,
    prank_code    text not null references public.prank_types (code),
    blocked       boolean not null default false,             -- hit a درع
    created_at    timestamptz not null default now()
);
create unique index prank_one_per_round on public.prank_events (room_id, round_number, from_player);


-- =====================================================================
-- 7. حوش الجمل
-- =====================================================================
create table public.camels (
    player_id           uuid primary key references public.profiles (id) on delete cascade,
    name                text,
    satiety             smallint not null default 60 check (satiety between 0 and 100),  -- الشبع
    satiety_updated_at  timestamptz not null default now(),
    cleanliness         smallint not null default 100 check (cleanliness between 0 and 100), -- النظافة
    last_meal_id        bigint,
    created_at          timestamptz not null default now()
);

create table public.foods (
    id            smallint generated always as identity primary key,
    code          text not null unique,
    name_ar       text not null,
    price_alaf    smallint not null check (price_alaf >= 0),
    satiety_gain  smallint not null check (satiety_gain between 1 and 100),
    image_name    text not null,              -- asset in Media.xcassets
    sort_order    smallint not null default 0,
    is_active     boolean not null default true
);

insert into public.foods (code, name_ar, price_alaf, satiety_gain, image_name, sort_order) values
    ('mafto7',   'مفطح',      30, 40, 'food_mafto7',   1),
    ('kabsa',    'كبسة',      20, 25, 'food_kabsa',    2),
    ('jareesh',  'جريش',      12, 15, 'food_jareesh',  3),
    ('luqaimat', 'لقيمات',     8, 10, 'food_luqaimat', 4),
    ('tamr',     'تمر',        5,  5, 'food_tamr',     5),
    ('haleeb',   'حليب ناقة', 10, 10, 'food_haleeb',   6);

-- Meal history: "آخر وجبة" and "وجبات جملك".
create table public.camel_meals (
    id          bigint generated always as identity primary key,
    player_id   uuid not null references public.camels (player_id) on delete cascade,
    food_id     smallint not null references public.foods (id),
    alaf_spent  smallint not null,
    eaten_at    timestamptz not null default now()
);
create index camel_meals_player_idx on public.camel_meals (player_id, eaten_at desc);

alter table public.camels
    add foreign key (last_meal_id) references public.camel_meals (id) on delete set null;

create table public.accessories (
    id            smallint generated always as identity primary key,
    code          text not null unique,
    name_ar       text not null,
    slot          text not null check (slot in ('head', 'eyes', 'neck')),
    price_alaf    smallint,                  -- null = not for sale
    unlock_level  smallint,                  -- null = no level needed
    image_name    text not null,             -- one layer per character: {image_name}_{player1…4}
    is_active     boolean not null default true
);

insert into public.accessories (code, name_ar, slot, price_alaf, unlock_level, image_name) values
    ('taqiyah',  'طاقية', 'head', 10,   null, 'acc_taqiyah'),
    ('shemagh',  'شماغ',  'head', 20,   null, 'acc_shemagh'),
    ('iqal',     'عقال',  'head', null, 3,    'acc_iqal'),
    ('glasses',  'نظارة', 'eyes', 15,   null, 'acc_glasses'),
    ('flower',   'وردة',  'neck', 8,    null, 'acc_flower');

create table public.player_accessories (
    player_id     uuid not null references public.profiles (id) on delete cascade,
    accessory_id  smallint not null references public.accessories (id),
    slot          text not null,
    is_equipped   boolean not null default false,
    acquired_at   timestamptz not null default now(),
    primary key (player_id, accessory_id)
);
-- one equipped item per slot
create unique index one_equipped_per_slot
    on public.player_accessories (player_id, slot) where is_equipped;

-- Every علف change, so balances can be audited.
create table public.alaf_ledger (
    id          bigint generated always as identity primary key,
    player_id   uuid not null references public.profiles (id) on delete cascade,
    amount      int not null,                -- + earned, − spent
    reason      text not null check (reason in ('game', 'meal', 'accessory', 'gift')),
    ref_id      text,                        -- room id, meal id or accessory code
    created_at  timestamptz not null default now()
);
create index alaf_ledger_player_idx on public.alaf_ledger (player_id, created_at desc);


-- =====================================================================
-- 8. Views
-- =====================================================================
create view public.global_leaderboard with (security_invoker = true) as
select p.id, p.username, p.avatar_image_name, p.facebook_photo_url, p.is_guest,
       p.level, p.total_score, p.games_won, p.best_score, p.total_games_played,
       rank() over (order by p.total_score desc, p.games_won desc) as rank
from public.profiles p
where p.total_games_played > 0;

-- Hunger goes down 1 point per hour since the last meal; no background job.
create view public.camel_status with (security_invoker = true) as
select c.player_id,
       c.name,
       greatest(0, c.satiety - floor(extract(epoch from now() - c.satiety_updated_at) / 3600))::int as satiety,
       c.cleanliness,
       f.name_ar      as last_meal_name,
       f.image_name   as last_meal_image,
       m.eaten_at     as last_meal_at,
       (greatest(0, c.satiety - floor(extract(epoch from now() - c.satiety_updated_at) / 3600)) >= 80
        and c.cleanliness >= 80) as is_happy
from public.camels c
left join public.camel_meals m on m.id = c.last_meal_id
left join public.foods f on f.id = m.food_id;

create view public.camel_meal_counts with (security_invoker = true) as
select m.player_id, f.code, f.name_ar, f.image_name, count(*) as times
from public.camel_meals m join public.foods f on f.id = m.food_id
group by m.player_id, f.code, f.name_ar, f.image_name;

-- «أكبر مقلّب» on the results screen
create view public.room_prank_stats with (security_invoker = true) as
select room_id, from_player as player_id,
       count(*) as thrown,
       count(*) filter (where not blocked) as landed
from public.prank_events
group by room_id, from_player;


-- =====================================================================
-- Sign-in triggers: create the profile + camel, upgrade guest → Facebook
-- =====================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    v_is_guest boolean := coalesce(new.is_anonymous, false);
    v_base text;
    v_name text;
begin
    if v_is_guest then
        v_base := 'ضيف';
    else
        v_base := left(split_part(coalesce(new.raw_user_meta_data ->> 'full_name',
                                           new.raw_user_meta_data ->> 'name', 'لاعب'), ' ', 1), 14);
        if char_length(v_base) < 2 then v_base := 'لاعب'; end if;
    end if;
    loop
        v_name := v_base || lpad((floor(random() * 10000))::int::text, 4, '0');
        exit when not exists (select 1 from profiles where username = v_name);
    end loop;

    insert into profiles (id, username, is_guest, auth_provider, facebook_photo_url)
    values (new.id, v_name, v_is_guest,
            case when v_is_guest then 'guest' else 'facebook' end,
            case when v_is_guest then null else new.raw_user_meta_data ->> 'avatar_url' end);
    insert into camels (player_id) values (new.id);
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.handle_user_upgraded()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    update profiles set is_guest = false, auth_provider = 'facebook',
           facebook_photo_url = coalesce(facebook_photo_url, new.raw_user_meta_data ->> 'avatar_url')
    where id = new.id;
    return new;
end;
$$;

create trigger on_auth_user_upgraded
    after update of is_anonymous on auth.users for each row
    when (old.is_anonymous is true and new.is_anonymous is false)
    execute function public.handle_user_upgraded();


-- =====================================================================
-- 9. Game functions (RPC)
-- =====================================================================
create or replace function public.is_room_member(p_room uuid)
returns boolean language sql stable security definer set search_path = public as $$
    select exists (select 1 from room_players
                   where room_id = p_room and player_id = auth.uid() and left_at is null);
$$;

-- ---------- lobby ----------
create or replace function public.create_room(
    p_total_rounds smallint default 10,
    p_round_duration_sec smallint default 10
)
returns table (room_id uuid, code text)
language plpgsql security definer set search_path = public as $$
declare v_code text; v_room uuid;
begin
    loop
        v_code := (select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                                            1 + floor(random() * 32)::int, 1), '')
                   from generate_series(1, 5));
        exit when not exists (select 1 from rooms r where r.code = v_code);
    end loop;
    insert into rooms (code, host_id, total_rounds, round_duration_sec)
    values (v_code, auth.uid(), p_total_rounds, p_round_duration_sec)
    returning id into v_room;
    insert into room_players (room_id, player_id, is_host) values (v_room, auth.uid(), true);
    return query select v_room, v_code;
end;
$$;

-- إعدادات الشوط: host flips the lobby toggles.
create or replace function public.update_room_settings(
    p_room uuid, p_wheel boolean, p_pranks boolean, p_judge boolean, p_pen_bonus boolean
)
returns void language plpgsql security definer set search_path = public as $$
begin
    update rooms set wheel_enabled = p_wheel, pranks_enabled = p_pranks,
                     judge_enabled = p_judge, pen_bonus_enabled = p_pen_bonus
    where id = p_room and host_id = auth.uid() and status = 'lobby';
    if not found then raise exception 'not_host_or_started'; end if;
end;
$$;

create or replace function public.join_room(p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_room rooms%rowtype; v_count int;
begin
    select * into v_room from rooms where code = upper(p_code) and status = 'lobby' for update;
    if not found then raise exception 'room_not_found'; end if;
    select count(*) into v_count from room_players where room_id = v_room.id and left_at is null;
    if v_count >= v_room.max_players then raise exception 'room_full'; end if;
    insert into room_players (room_id, player_id) values (v_room.id, auth.uid())
    on conflict (room_id, player_id) do update set left_at = null;
    return v_room.id;
end;
$$;

create or replace function public.leave_room(p_room uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
    update room_players set left_at = now() where room_id = p_room and player_id = auth.uid();
    update rooms set status = 'abandoned', finished_at = now()
    where id = p_room and host_id = auth.uid() and status = 'lobby';
end;
$$;

-- ---------- game ----------
-- Host starts: deals prank cards, checks who has a happy camel, opens round 1.
create or replace function public.start_game(p_room uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_room rooms%rowtype; v_count int;
begin
    select * into v_room from rooms where id = p_room for update;
    if v_room.host_id is distinct from auth.uid() then raise exception 'not_host'; end if;
    if v_room.status <> 'lobby' then raise exception 'already_started'; end if;
    select count(*) into v_count from room_players where room_id = p_room and left_at is null;
    if v_count < 2 then raise exception 'need_at_least_2_players'; end if;

    update rooms set status = 'playing', started_at = now() where id = p_room;

    if v_room.pen_bonus_enabled then
        update room_players rp set pen_bonus_ready = cs.is_happy
        from camel_status cs
        where rp.room_id = p_room and cs.player_id = rp.player_id;
    end if;

    if v_room.pranks_enabled then
        insert into room_prank_cards (room_id, player_id, prank_code, remaining)
        select p_room, rp.player_id, pt.code, pt.starting_qty
        from room_players rp cross join prank_types pt
        where rp.room_id = p_room and rp.left_at is null;
    end if;

    perform public.next_round(p_room);
end;
$$;

-- Host opens the next round (or finishes the game after the last one).
-- With the wheel on, the type is picked by weight; ذهبي is guaranteed once
-- in the last 3 rounds (on the last non-judge round if the wheel skipped it); شوط الحَكَم lands on rounds 5 and 10.
create or replace function public.next_round(p_room uuid)
returns smallint language plpgsql security definer set search_path = public as $$
declare
    v_room rooms%rowtype;
    v_next smallint;
    v_type round_types%rowtype;
    v_ch1 smallint;
    v_ch2 smallint;
    v_dur smallint;
    v_last_free smallint;   -- last round that is not a judge round
begin
    select * into v_room from rooms where id = p_room for update;
    if v_room.host_id is distinct from auth.uid() then raise exception 'not_host'; end if;
    if v_room.status <> 'playing' then raise exception 'not_playing'; end if;
    if exists (select 1 from room_rounds where room_id = p_room
               and round_number = v_room.current_round and round_type = 'judge'
               and phase <> 'done') then
        raise exception 'judge_round_not_closed';
    end if;

    v_next := v_room.current_round + 1;
    if v_next > v_room.total_rounds then
        perform public.finish_game(p_room);
        return null;
    end if;

    v_last_free := v_room.total_rounds;
    if v_room.judge_enabled and v_room.total_rounds in (5, 10) then
        v_last_free := v_room.total_rounds - 1;
    end if;

    -- pick the round type
    if v_room.judge_enabled and v_next in (5, 10) then
        select * into v_type from round_types where code = 'judge';
    elsif v_room.wheel_enabled
          and v_next = v_last_free
          and not exists (select 1 from room_rounds where room_id = p_room and round_type = 'golden') then
        select * into v_type from round_types where code = 'golden';
    elsif v_room.wheel_enabled then
        select * into v_type from round_types
        where wheel_weight > 0
          and (code <> 'golden' or v_next > v_room.total_rounds - 3)
          and not (code = 'golden' and exists (select 1 from room_rounds
                   where room_id = p_room and round_type = 'golden'))
        order by -ln(random()) / wheel_weight      -- weighted random
        limit 1;
    else
        select * into v_type from round_types where code = 'normal';
    end if;

    -- pick objects not used yet in this room
    select c.id into v_ch1 from challenges c
    where c.is_active and c.kind = v_type.kind
      and c.id not in (select challenge_id from room_rounds where room_id = p_room)
    order by random() limit 1;
    if v_ch1 is null then
        select id into v_ch1 from challenges where is_active and kind = v_type.kind
        order by random() limit 1;
    end if;
    if v_type.targets = 2 then
        select id into v_ch2 from challenges
        where is_active and kind = 'object' and id <> v_ch1 order by random() limit 1;
    end if;

    v_dur := case when v_type.code = 'normal' then v_room.round_duration_sec else v_type.duration_sec end;

    insert into room_rounds (room_id, round_number, round_type, challenge_id, challenge2_id, ends_at)
    values (p_room, v_next, v_type.code, v_ch1, v_ch2, now() + make_interval(secs => v_dur));

    update rooms set current_round = v_next where id = p_room;
    return v_next;
end;
$$;

-- Called by the verify-photo Edge Function (service role) after the AI says
-- the photo matches. Awards points by round type; ثنائي needs both objects;
-- a happy camel adds +1 to the player's first find of the game.
create or replace function public.record_find(p_check_id bigint)
returns smallint language plpgsql security definer set search_path = public as $$
declare
    v_check photo_checks%rowtype;
    v_round room_rounds%rowtype;
    v_type  round_types%rowtype;
    v_points smallint;
    v_bonus  boolean;
begin
    select * into v_check from photo_checks where id = p_check_id;
    if not found or v_check.is_match is not true then raise exception 'not_a_match'; end if;

    select * into v_round from room_rounds
    where room_id = v_check.room_id and round_number = v_check.round_number
    for update;                                              -- serialises "who was first"
    select * into v_type from round_types where code = v_round.round_type;

    if v_type.code = 'judge' then raise exception 'judge_round_uses_votes'; end if;
    if v_check.created_at > v_round.ends_at + interval '1 second' then
        raise exception 'round_over';
    end if;

    -- ثنائي: wait until both objects have a matching photo
    if (select count(distinct target_index) from photo_checks
        where room_id = v_check.room_id and round_number = v_check.round_number
          and player_id = v_check.player_id and is_match) < v_type.targets then
        return 0;
    end if;

    v_points := case when exists (select 1 from round_submissions
                                  where room_id = v_check.room_id
                                    and round_number = v_check.round_number)
                     then v_type.points_other else v_type.points_first end;

    select pen_bonus_ready and not pen_bonus_used into v_bonus
    from room_players where room_id = v_check.room_id and player_id = v_check.player_id;
    if v_bonus then v_points := v_points + 1; end if;

    insert into round_submissions (room_id, round_number, player_id, photo_check_id, response_ms, points)
    values (v_check.room_id, v_check.round_number, v_check.player_id, v_check.id,
            greatest(0, (extract(epoch from v_check.created_at - v_round.started_at) * 1000)::int),
            v_points)
    on conflict do nothing;
    if not found then return 0; end if;                      -- already scored this round

    update room_players set score = score + v_points,
                           pen_bonus_used = pen_bonus_used or v_bonus
    where room_id = v_check.room_id and player_id = v_check.player_id;
    return v_points;
end;
$$;

-- Interim path until the verify-photo Edge Function exists: the phone's own
-- Vision check reports the find. It is stored in photo_checks like an AI result
-- (ai_provider = 'device'), so switching to the server AI later changes nothing
-- else. A player can fake this call, so turn it off once verify-photo is live:
--   revoke execute on function public.submit_device_find(uuid, smallint, text, real) from authenticated;
create or replace function public.submit_device_find(
    p_room uuid, p_round smallint, p_label text, p_confidence real)
returns smallint language plpgsql security definer set search_path = public as $$
declare v_check bigint; v_target int;
begin
    if not public.is_room_member(p_room) then raise exception 'not_in_room'; end if;
    if not exists (select 1 from rooms r join room_rounds rr
                   on rr.room_id = r.id and rr.round_number = r.current_round
                   where r.id = p_room and r.status = 'playing'
                     and rr.round_number = p_round and rr.phase = 'shooting'
                     and rr.round_type <> 'judge') then
        raise exception 'round_not_open';
    end if;
    -- one row per target, so a ثنائي round counts both objects
    for v_target in 1 .. (select rt.targets from round_types rt join room_rounds rr on rr.round_type = rt.code
                          where rr.room_id = p_room and rr.round_number = p_round) loop
        insert into photo_checks (room_id, round_number, player_id, target_index,
                                  ai_provider, best_label, confidence, is_match)
        values (p_room, p_round, auth.uid(), v_target, 'device', left(p_label, 80), p_confidence, true)
        returning id into v_check;
    end loop;
    return public.record_find(v_check);
end;
$$;

-- ---------- شوط الحَكَم ----------
create or replace function public.start_voting(p_room uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_round smallint;
begin
    select current_round into v_round from rooms where id = p_room and host_id = auth.uid();
    if not found then raise exception 'not_host'; end if;
    update room_rounds set phase = 'voting', vote_ends_at = now() + interval '10 seconds'
    where room_id = p_room and round_number = v_round and round_type = 'judge' and phase = 'shooting';
    if not found then raise exception 'not_a_shooting_judge_round'; end if;
end;
$$;

create or replace function public.cast_vote(p_room uuid, p_round smallint, p_photo_player uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
    if not public.is_room_member(p_room) then raise exception 'not_in_room'; end if;
    if p_photo_player = auth.uid() then raise exception 'cannot_vote_for_yourself'; end if;
    if not exists (select 1 from room_players where room_id = p_room and player_id = p_photo_player) then
        raise exception 'not_in_room';
    end if;
    if not exists (select 1 from room_rounds where room_id = p_room and round_number = p_round
                   and phase = 'voting') then
        raise exception 'not_voting';
    end if;
    insert into judge_votes (room_id, round_number, voter_id, photo_player_id)
    values (p_room, p_round, auth.uid(), p_photo_player)
    on conflict (room_id, round_number, voter_id)
    do update set photo_player_id = excluded.photo_player_id, created_at = now();
end;
$$;

-- Most votes +3, second +1. A tie at the top shares: each gets +2, no second place.
create or replace function public.close_voting(p_room uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_round smallint; v_top_count int;
begin
    select current_round into v_round from rooms where id = p_room and host_id = auth.uid();
    if not found then raise exception 'not_host'; end if;
    update room_rounds set phase = 'done'
    where room_id = p_room and round_number = v_round and phase = 'voting';
    if not found then raise exception 'not_voting'; end if;

    create temp table _tally on commit drop as
    select photo_player_id as player_id, count(*) as votes,
           dense_rank() over (order by count(*) desc) as place
    from judge_votes where room_id = p_room and round_number = v_round
    group by photo_player_id;

    select count(*) into v_top_count from _tally where place = 1;

    insert into round_submissions (room_id, round_number, player_id, response_ms, points)
    select p_room, v_round, player_id, 0,
           case when place = 1 and v_top_count = 1 then 3
                when place = 1 then 2
                else 1 end
    from _tally
    where place = 1 or (place = 2 and v_top_count = 1);

    update room_players rp set score = rp.score + s.points
    from round_submissions s
    where s.room_id = p_room and s.round_number = v_round
      and rp.room_id = p_room and rp.player_id = s.player_id;
end;
$$;

-- ---------- المقالب ----------
create or replace function public.use_shield(p_room uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
    update room_prank_cards set remaining = remaining - 1
    where room_id = p_room and player_id = auth.uid() and prank_code = 'shield' and remaining > 0;
    if not found then raise exception 'no_shield_card'; end if;
    update room_players set shield_active = true where room_id = p_room and player_id = auth.uid();
end;
$$;

-- One prank per player per round, never the same target twice in a row.
-- Returns false when the target's درع blocked it.
create or replace function public.throw_prank(p_room uuid, p_target uuid, p_prank text)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_round smallint; v_last_target uuid; v_blocked boolean;
begin
    if p_target = auth.uid() then raise exception 'cannot_prank_yourself'; end if;
    if not public.is_room_member(p_room) then raise exception 'not_in_room'; end if;
    select current_round into v_round from rooms where id = p_room and status = 'playing';
    if not found then raise exception 'not_playing'; end if;

    select to_player into v_last_target from prank_events
    where room_id = p_room and from_player = auth.uid() order by id desc limit 1;
    if v_last_target = p_target then raise exception 'same_target_twice'; end if;

    update room_prank_cards set remaining = remaining - 1
    where room_id = p_room and player_id = auth.uid() and prank_code = p_prank
      and remaining > 0 and prank_code <> 'shield';
    if not found then raise exception 'no_card'; end if;

    update room_players set shield_active = false
    where room_id = p_room and player_id = p_target and shield_active
    returning true into v_blocked;

    insert into prank_events (room_id, round_number, from_player, to_player, prank_code, blocked)
    values (p_room, v_round, auth.uid(), p_target, p_prank, coalesce(v_blocked, false));
    return not coalesce(v_blocked, false);
end;
$$;

-- ---------- end of game ----------
-- Ranks, lifetime stats, علف earned (= score), and a little dust on the camel.
create or replace function public.finish_game(p_room uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_top int;
begin
    update rooms set status = 'finished', finished_at = now()
    where id = p_room and status = 'playing';
    if not found then return; end if;

    update room_players rp set final_rank = r.rnk
    from (select player_id, rank() over (order by score desc) as rnk
          from room_players where room_id = p_room and left_at is null) r
    where rp.room_id = p_room and rp.player_id = r.player_id;

    select max(score) into v_top from room_players where room_id = p_room and left_at is null;

    update profiles p set
        total_games_played = p.total_games_played + 1,
        total_score        = p.total_score + rp.score,
        best_score         = greatest(p.best_score, rp.score),
        games_won          = p.games_won + case when rp.score = v_top and v_top > 0 then 1 else 0 end,
        alaf               = p.alaf + rp.score,
        last_played_at     = now()
    from room_players rp
    where rp.room_id = p_room and rp.left_at is null and rp.player_id = p.id;

    insert into alaf_ledger (player_id, amount, reason, ref_id)
    select player_id, score, 'game', p_room::text
    from room_players where room_id = p_room and left_at is null and score > 0;

    update camels c set cleanliness = greatest(0, c.cleanliness - 10)
    from room_players rp
    where rp.room_id = p_room and rp.left_at is null and rp.player_id = c.player_id;
end;
$$;

-- ---------- حوش الجمل ----------
create or replace function public.feed_camel(p_food_code text)
returns table (satiety int, alaf int, meal_id bigint)
language plpgsql security definer set search_path = public as $$
declare v_food foods%rowtype; v_now int; v_meal bigint;
begin
    select * into v_food from foods where code = p_food_code and is_active;
    if not found then raise exception 'unknown_food'; end if;

    update profiles set alaf = profiles.alaf - v_food.price_alaf
    where id = auth.uid() and profiles.alaf >= v_food.price_alaf;
    if not found then raise exception 'not_enough_alaf'; end if;

    select cs.satiety into v_now from camel_status cs where cs.player_id = auth.uid();

    insert into camel_meals (player_id, food_id, alaf_spent)
    values (auth.uid(), v_food.id, v_food.price_alaf) returning id into v_meal;

    update camels set satiety = least(100, v_now + v_food.satiety_gain),
                      satiety_updated_at = now(), last_meal_id = v_meal
    where player_id = auth.uid();

    insert into alaf_ledger (player_id, amount, reason, ref_id)
    values (auth.uid(), -v_food.price_alaf, 'meal', v_meal::text);

    return query select least(100, v_now + v_food.satiety_gain)::int,
                        (select p.alaf from profiles p where p.id = auth.uid()), v_meal;
end;
$$;

-- Called when the finger-wipe reaches 100 %.
create or replace function public.clean_camel()
returns void language sql security definer set search_path = public as $$
    update camels set cleanliness = 100 where player_id = auth.uid();
$$;

create or replace function public.buy_accessory(p_code text)
returns void language plpgsql security definer set search_path = public as $$
declare v_acc accessories%rowtype; v_level int;
begin
    select * into v_acc from accessories where code = p_code and is_active;
    if not found then raise exception 'unknown_item'; end if;
    if exists (select 1 from player_accessories where player_id = auth.uid() and accessory_id = v_acc.id) then
        raise exception 'already_owned';
    end if;
    select level into v_level from profiles where id = auth.uid();
    if v_acc.unlock_level is not null and v_level < v_acc.unlock_level then
        raise exception 'level_too_low';
    end if;
    if v_acc.price_alaf is not null then
        update profiles set alaf = alaf - v_acc.price_alaf
        where id = auth.uid() and alaf >= v_acc.price_alaf;
        if not found then raise exception 'not_enough_alaf'; end if;
        insert into alaf_ledger (player_id, amount, reason, ref_id)
        values (auth.uid(), -v_acc.price_alaf, 'accessory', v_acc.code);
    end if;
    insert into player_accessories (player_id, accessory_id, slot)
    values (auth.uid(), v_acc.id, v_acc.slot);
end;
$$;

-- ثبّت اللبس: wear one item (replaces whatever is in that slot) or take it off.
create or replace function public.equip_accessory(p_code text, p_wear boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare v_acc accessories%rowtype;
begin
    select * into v_acc from accessories where code = p_code;
    if not exists (select 1 from player_accessories where player_id = auth.uid() and accessory_id = v_acc.id) then
        raise exception 'not_owned';
    end if;
    update player_accessories set is_equipped = false
    where player_id = auth.uid() and slot = v_acc.slot and is_equipped;
    if p_wear then
        update player_accessories set is_equipped = true
        where player_id = auth.uid() and accessory_id = v_acc.id;
    end if;
end;
$$;

-- ---------- تحدّي الشبح (tutorial, played offline) ----------
create or replace function public.complete_tutorial(p_time_ms int)
returns void language sql security definer set search_path = public as $$
    update profiles set tutorial_done_at = coalesce(tutorial_done_at, now()),
                        ghost_best_ms = least(coalesce(ghost_best_ms, p_time_ms), p_time_ms)
    where id = auth.uid();
$$;

-- Server-only functions
revoke execute on function public.finish_game(uuid)   from public, anon, authenticated;
revoke execute on function public.record_find(bigint) from public, anon, authenticated;


-- =====================================================================
-- 10. Row Level Security
-- Reads go to whoever needs them. Writes go through the functions above,
-- except a player editing their own name/avatar and camel name.
-- =====================================================================
alter table public.profiles           enable row level security;
alter table public.challenges         enable row level security;
alter table public.round_types        enable row level security;
alter table public.rooms              enable row level security;
alter table public.room_players       enable row level security;
alter table public.room_rounds        enable row level security;
alter table public.round_submissions  enable row level security;
alter table public.photo_checks       enable row level security;
alter table public.judge_votes        enable row level security;
alter table public.prank_types        enable row level security;
alter table public.room_prank_cards   enable row level security;
alter table public.prank_events       enable row level security;
alter table public.camels             enable row level security;
alter table public.foods              enable row level security;
alter table public.camel_meals        enable row level security;
alter table public.accessories        enable row level security;
alter table public.player_accessories enable row level security;
alter table public.alaf_ledger        enable row level security;

-- public catalogs and profiles (others see your camel and what it wears)
create policy "read profiles"        on public.profiles           for select using (true);
create policy "read challenges"      on public.challenges         for select using (is_active);
create policy "read round types"     on public.round_types        for select using (true);
create policy "read prank types"     on public.prank_types        for select using (true);
create policy "read foods"           on public.foods              for select using (is_active);
create policy "read accessories"     on public.accessories        for select using (is_active);
create policy "read camels"          on public.camels             for select using (true);
create policy "read worn items"      on public.player_accessories for select using (true);

-- private to the player
create policy "own meals"  on public.camel_meals for select using (player_id = auth.uid());
create policy "own ledger" on public.alaf_ledger for select using (player_id = auth.uid());
create policy "own cards"  on public.room_prank_cards for select using (player_id = auth.uid());

-- room members only
create policy "members read room"        on public.rooms             for select using (public.is_room_member(id));
create policy "members read players"     on public.room_players      for select using (public.is_room_member(room_id));
create policy "members read rounds"      on public.room_rounds       for select using (public.is_room_member(room_id));
create policy "members read submissions" on public.round_submissions for select using (public.is_room_member(room_id));
create policy "members read checks"      on public.photo_checks      for select using (public.is_room_member(room_id));
create policy "members read pranks"      on public.prank_events      for select using (public.is_room_member(room_id));
-- votes stay secret until the round is closed
create policy "members read votes after close" on public.judge_votes for select using (
    public.is_room_member(room_id) and exists (
        select 1 from public.room_rounds r
        where r.room_id = judge_votes.room_id and r.round_number = judge_votes.round_number
          and r.phase = 'done'));

-- column-level edits
create policy "edit own profile" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy "name own camel"   on public.camels   for update using (player_id = auth.uid()) with check (player_id = auth.uid());
revoke update on public.profiles from anon, authenticated;
revoke update on public.camels   from anon, authenticated;
grant  update (username, avatar_image_name) on public.profiles to authenticated;
grant  update (name)                         on public.camels   to authenticated;


-- =====================================================================
-- Storage: round photos
-- Path: {room_id}/{round_number}/{player_id}.jpg
-- Room members can read (needed for شوط الحَكَم and the round album);
-- each player uploads only their own file. Delete after 24 h with a
-- scheduled job if you want to keep storage small.
-- =====================================================================
insert into storage.buckets (id, name, public) values ('round-photos', 'round-photos', false);

create policy "upload own round photo" on storage.objects for insert to authenticated
with check (
    bucket_id = 'round-photos'
    and public.is_room_member(((storage.foldername(name))[1])::uuid)
    and split_part(storage.filename(name), '.', 1) = auth.uid()::text
);

create policy "members view round photos" on storage.objects for select to authenticated
using (
    bucket_id = 'round-photos'
    and public.is_room_member(((storage.foldername(name))[1])::uuid)
);


-- =====================================================================
-- Realtime: lobby, timer, live race strip, pranks, votes
-- =====================================================================
alter publication supabase_realtime add table
    public.rooms,
    public.room_players,
    public.room_rounds,
    public.round_submissions,
    public.prank_events,
    public.judge_votes;
