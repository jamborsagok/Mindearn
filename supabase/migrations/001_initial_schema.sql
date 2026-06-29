-- ================================================================
-- MindEarn – Supabase initial schema
-- Migration : 001_initial_schema.sql
-- Run via   : Supabase Dashboard → SQL Editor → New query → Run
-- ================================================================

BEGIN;


-- ----------------------------------------------------------------
-- §0  HELPER: refresh updated_at on every UPDATE
-- ----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


-- ----------------------------------------------------------------
-- §1  PROFILES
-- ----------------------------------------------------------------

CREATE TABLE public.profiles (
  id         uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name       text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ----------------------------------------------------------------
-- §2  USER_ACCESS
-- ----------------------------------------------------------------

CREATE TABLE public.user_access (
  id         uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  resource   text        NOT NULL
               CHECK (resource IN ('book', 'workbook', 'course', 'audio', 'live')),
  status     text        NOT NULL DEFAULT 'waiting'
               CHECK (status IN ('active', 'building', 'planned', 'waiting')),
  granted_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, resource)
);


-- ----------------------------------------------------------------
-- §3  DAILY_ENTRIES
-- ----------------------------------------------------------------

CREATE TABLE public.daily_entries (
  id         uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid        NOT NULL DEFAULT auth.uid()
               REFERENCES auth.users(id) ON DELETE CASCADE,
  entry_date date        NOT NULL,
  period     text        NOT NULL
               CHECK (period IN ('morning', 'midday', 'evening')),
  teremteni  text        NOT NULL DEFAULT '',
  alkotni    text        NOT NULL DEFAULT '',
  adni       text        NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, entry_date, period)
);

CREATE TRIGGER trg_daily_entries_updated_at
  BEFORE UPDATE ON public.daily_entries
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ----------------------------------------------------------------
-- §4  WEEKLY_ENTRIES
-- ----------------------------------------------------------------

CREATE TABLE public.weekly_entries (
  id         uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid        NOT NULL DEFAULT auth.uid()
               REFERENCES auth.users(id) ON DELETE CASCADE,
  week_start date        NOT NULL,
  teremteni  text        NOT NULL DEFAULT '',
  alkotni    text        NOT NULL DEFAULT '',
  adni       text        NOT NULL DEFAULT '',
  figyelem   text        NOT NULL DEFAULT '',
  dontes     text        NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, week_start)
);

CREATE TRIGGER trg_weekly_entries_updated_at
  BEFORE UPDATE ON public.weekly_entries
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ----------------------------------------------------------------
-- §5  COMMITMENTS
-- ----------------------------------------------------------------

CREATE TABLE public.commitments (
  id           uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      uuid        NOT NULL DEFAULT auth.uid()
                 REFERENCES auth.users(id) ON DELETE CASCADE,
  period_start date        NOT NULL,
  period_weeks integer     NOT NULL CHECK (period_weeks IN (3, 6, 9)),
  allapot      text        NOT NULL DEFAULT '',
  valallalas   text        NOT NULL DEFAULT '',
  eredmeny     text        NOT NULL DEFAULT '',
  emlekeztet   text        NOT NULL DEFAULT '',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_commitments_updated_at
  BEFORE UPDATE ON public.commitments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ----------------------------------------------------------------
-- §6  SUBSCRIBERS
-- ----------------------------------------------------------------

CREATE TABLE public.subscribers (
  id            uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  email         text        NOT NULL UNIQUE,
  name          text,
  interest      text,
  source        text
                  CHECK (source IN ('inline-form', 'popup', 'profile')),
  status        text        NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'unsubscribed', 'bounced', 'pending')),
  tags          text[]      NOT NULL DEFAULT '{}',
  subscribed_at timestamptz NOT NULL DEFAULT now(),
  brevo_synced  boolean     NOT NULL DEFAULT false,
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_subscribers_updated_at
  BEFORE UPDATE ON public.subscribers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ----------------------------------------------------------------
-- §7  PAGE_EVENTS
-- ----------------------------------------------------------------

CREATE TABLE public.page_events (
  id         uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  event_name text        NOT NULL,
  detail     jsonb       NOT NULL DEFAULT '{}',
  page       text,
  created_at timestamptz NOT NULL DEFAULT now()
);


-- ----------------------------------------------------------------
-- §8  SIGNUP TRIGGER
-- Creates one profiles row and five user_access rows on every
-- new auth.users insert. ON CONFLICT DO NOTHING makes it idempotent.
-- SECURITY DEFINER bypasses RLS. SET search_path prevents injection.
-- ----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, name)
    VALUES (
      NEW.id,
      NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'name', '')), '')
    )
    ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_access (user_id, resource, status)
    VALUES
      (NEW.id, 'book',     'active'),
      (NEW.id, 'workbook', 'active'),
      (NEW.id, 'course',   'building'),
      (NEW.id, 'audio',    'building'),
      (NEW.id, 'live',     'planned')
    ON CONFLICT (user_id, resource) DO NOTHING;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ----------------------------------------------------------------
-- §9  ROW LEVEL SECURITY – enable on all seven tables
-- ----------------------------------------------------------------

ALTER TABLE public.profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_access    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_entries  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commitments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscribers    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.page_events    ENABLE ROW LEVEL SECURITY;


-- ----------------------------------------------------------------
-- §10  RLS POLICIES
-- ----------------------------------------------------------------

-- profiles -------------------------------------------------------

CREATE POLICY "profiles: select own row"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "profiles: update own row"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING      (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- user_access ----------------------------------------------------

CREATE POLICY "user_access: select own rows"
  ON public.user_access
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- daily_entries --------------------------------------------------

CREATE POLICY "daily_entries: all on own rows"
  ON public.daily_entries
  FOR ALL
  TO authenticated
  USING      (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- weekly_entries -------------------------------------------------

CREATE POLICY "weekly_entries: all on own rows"
  ON public.weekly_entries
  FOR ALL
  TO authenticated
  USING      (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- commitments ----------------------------------------------------

CREATE POLICY "commitments: all on own rows"
  ON public.commitments
  FOR ALL
  TO authenticated
  USING      (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- subscribers ----------------------------------------------------

CREATE POLICY "subscribers: public insert"
  ON public.subscribers
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- page_events ----------------------------------------------------

CREATE POLICY "page_events: public insert"
  ON public.page_events
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);


-- ----------------------------------------------------------------
-- §11  INDEXES
--
-- UNIQUE constraints already create B-tree indexes on:
--   daily_entries  (user_id, entry_date, period)
--   weekly_entries (user_id, week_start)
--   user_access    (user_id, resource)
--   subscribers    (email)
--
-- The explicit indexes below cover patterns not served by those.
-- ----------------------------------------------------------------

-- commitments: list a user's commitments newest-first
CREATE INDEX idx_commitments_user_created
  ON public.commitments (user_id, created_at DESC);

-- subscribers: Brevo sync queue – oldest unsynced rows first
--   Partial index stays small: only false rows are indexed.
CREATE INDEX idx_subscribers_sync_queue
  ON public.subscribers (subscribed_at ASC)
  WHERE brevo_synced = false;

-- subscribers: status filter for segmentation and Brevo webhooks
CREATE INDEX idx_subscribers_status
  ON public.subscribers (status);

-- page_events: time-range analytics queries, newest first
CREATE INDEX idx_page_events_created_at
  ON public.page_events (created_at DESC);

-- page_events: per-user event history (skip anonymous rows)
CREATE INDEX idx_page_events_user_id
  ON public.page_events (user_id)
  WHERE user_id IS NOT NULL;


COMMIT;
