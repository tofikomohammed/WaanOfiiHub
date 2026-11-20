-- ==============================================================================
-- WAAN-OFIIHUB: SUPERADMIN BOOTSTRAP SCRIPT
-- ==============================================================================
-- Run this script once in your Supabase SQL Editor to grant superadmin privileges
-- to your primary administrator account.
--
-- Instructions:
-- 1. Replace 'YOUR_ADMIN_EMAIL_HERE' with your registered user's email address.
-- 2. Execute this script in the Supabase SQL Editor.
-- ==============================================================================

DO $$
DECLARE
    target_email TEXT := 'YOUR_ADMIN_EMAIL_HERE';
    target_user_id UUID;
    superadmin_role_id UUID;
BEGIN
    -- 1. Locate the user by email in auth.users
    SELECT id INTO target_user_id
    FROM auth.users
    WHERE email = target_email;

    IF target_user_id IS NULL THEN
        RAISE EXCEPTION 'User with email % not found in auth.users. Please register the user first.', target_email;
    END IF;

    -- 2. Locate the superadmin role
    SELECT id INTO superadmin_role_id
    FROM public.roles
    WHERE key = 'superadmin';

    IF superadmin_role_id IS NULL THEN
        RAISE EXCEPTION 'Superadmin role does not exist. Please run migration 00001_rbac_core.sql first.';
    END IF;

    -- 3. Assign superadmin role to user
    INSERT INTO public.user_roles (user_id, role_id, assigned_by)
    VALUES (target_user_id, superadmin_role_id, target_user_id)
    ON CONFLICT (user_id, role_id) DO NOTHING;

    -- 4. Record in audit_logs
    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (
        target_user_id,
        'bootstrap_superadmin',
        'user_roles',
        target_user_id::TEXT,
        jsonb_build_object('assigned_email', target_email, 'role', 'superadmin')
    );

    RAISE NOTICE 'Successfully granted superadmin role to user: % (%)', target_email, target_user_id;
END $$;
