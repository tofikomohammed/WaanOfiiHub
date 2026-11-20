-- ==============================================================================
-- 00001_profiles_and_public_id.sql
-- Profiles table, public_id generator, search RPC and RLS
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Function to generate unambiguous Public ID (WOH-XXXXXX)
CREATE OR REPLACE FUNCTION public.generate_public_id()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    chars TEXT := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    result TEXT := 'WOH-';
    i INTEGER;
BEGIN
    FOR i IN 1..6 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    RETURN result;
END;
$$;

-- Profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    public_id TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    username TEXT UNIQUE,
    avatar_url TEXT,
    about TEXT,
    phone_e164 TEXT,
    phone_hash TEXT,
    phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ,
    show_last_seen BOOLEAN NOT NULL DEFAULT TRUE,
    allow_phone_discovery BOOLEAN NOT NULL DEFAULT TRUE,
    is_banned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_public_id ON public.profiles(public_id);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_phone_hash ON public.profiles(phone_hash) WHERE allow_phone_discovery = TRUE;

-- Trigger to auto-create profile on auth.users signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    gen_id TEXT;
    loop_count INTEGER := 0;
    d_name TEXT;
    p_e164 TEXT;
    p_hash TEXT;
BEGIN
    -- Derive display name and phone details from user metadata
    d_name := COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1));
    p_e164 := NEW.raw_user_meta_data->>'phone_e164';
    p_hash := NEW.raw_user_meta_data->>'phone_hash';

    -- Loop to ensure uniqueness of public_id
    LOOP
        gen_id := public.generate_public_id();
        BEGIN
            INSERT INTO public.profiles (
                id,
                public_id,
                display_name,
                phone_e164,
                phone_hash,
                created_at,
                updated_at
            ) VALUES (
                NEW.id,
                gen_id,
                d_name,
                p_e164,
                p_hash,
                NOW(),
                NOW()
            );
            EXIT;
        EXCEPTION WHEN unique_violation THEN
            loop_count := loop_count + 1;
            IF loop_count > 10 THEN
                RAISE EXCEPTION 'Failed to generate unique public_id after 10 attempts.';
            END IF;
        END;
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Non-banned authenticated users can read all non-banned profiles
CREATE POLICY "Profiles are viewable by authenticated users"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (
        (is_banned = FALSE OR auth.uid() = id)
    );

-- Users can update only their own profile
CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (
        auth.uid() = id AND
        is_banned = FALSE
    );

-- RPC for safe user discovery (returns only minimal public info)
CREATE OR REPLACE FUNCTION public.search_users_by_query(query_text TEXT)
RETURNS TABLE (
    id UUID,
    public_id TEXT,
    display_name TEXT,
    username TEXT,
    avatar_url TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT 
        p.id,
        p.public_id,
        p.display_name,
        p.username,
        p.avatar_url
    FROM public.profiles p
    WHERE 
        p.is_banned = FALSE
        AND (
            p.public_id ILIKE query_text || '%'
            OR p.username ILIKE query_text || '%'
            OR p.display_name ILIKE '%' || query_text || '%'
        )
    LIMIT 25;
$$;
