-- ==============================================================================
-- 00006_rls_security_tests.sql
-- Verification & Automated Test Script for Row Level Security (RLS)
-- ==============================================================================
-- Run this script in the Supabase SQL editor to test RLS boundaries.
-- ==============================================================================

DO $$
BEGIN
    RAISE NOTICE '--- Starting WAAN-OFIIHUB RLS Security Verification ---';

    -- Test 1: has_permission function exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc WHERE proname = 'has_permission'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: has_permission function does not exist.';
    END IF;

    -- Test 2: RLS enabled on all sensitive tables
    IF EXISTS (
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
          AND tablename IN ('profiles', 'roles', 'posts', 'messages', 'conversations')
          AND rowsecurity = FALSE
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: One or more tables do not have RLS enabled!';
    END IF;

    -- Test 3: System roles are present
    IF (SELECT count(*) FROM public.roles WHERE key IN ('user', 'admin', 'superadmin')) != 3 THEN
        RAISE EXCEPTION 'TEST FAILED: Core system roles are missing.';
    END IF;

    -- Test 4: Default permissions exist
    IF (SELECT count(*) FROM public.permissions WHERE module IN ('blog', 'chat', 'users', 'roles', 'community')) < 10 THEN
        RAISE EXCEPTION 'TEST FAILED: Essential permission keys are missing.';
    END IF;

    RAISE NOTICE '--- All RLS Security Invariants Passed Successfully ---';
END $$;
