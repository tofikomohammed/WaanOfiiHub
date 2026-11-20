-- ==============================================================================
-- 00002_rbac_system.sql
-- Dynamic Role-Based Access Control (RBAC) & Audit Logs
-- ==============================================================================

-- 1. Tables
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    module TEXT NOT NULL,
    description TEXT
);

CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS public.user_roles (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON public.audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);

-- 2. Seed System Roles
INSERT INTO public.roles (key, name, description, is_system)
VALUES
    ('user', 'User', 'Standard platform user with blog read/react and chat capabilities', TRUE),
    ('admin', 'Admin', 'Staff member with content moderation and blog publishing privileges', TRUE),
    ('superadmin', 'Super Administrator', 'Full administrative authority across all modules and roles', TRUE)
ON CONFLICT (key) DO NOTHING;

-- 3. Seed Permissions
INSERT INTO public.permissions (key, module, description)
VALUES
    ('blog.create', 'blog', 'Create new blog posts (drafts)'),
    ('blog.edit_own', 'blog', 'Edit blog posts created by self'),
    ('blog.edit_any', 'blog', 'Edit or unpublish any blog post'),
    ('blog.publish', 'blog', 'Publish draft blog posts to public feed'),
    ('blog.delete', 'blog', 'Permanently delete blog posts'),
    ('users.view', 'users', 'View user lists and administrative profile metadata'),
    ('users.manage', 'users', 'Update user profiles and roles'),
    ('users.ban', 'users', 'Ban and unban platform users'),
    ('roles.manage', 'roles', 'Create roles and modify role permission assignments'),
    ('chat.moderate', 'chat', 'Review reported messages in context'),
    ('reports.review', 'reports', 'Review and action moderation reports'),
    ('community.manage', 'community', 'Create and administer community channels'),
    ('audit.view', 'audit', 'View system audit logs')
ON CONFLICT (key) DO NOTHING;

-- 4. Assign default permissions to 'admin' role
DO $$
DECLARE
    admin_id UUID;
BEGIN
    SELECT id INTO admin_id FROM public.roles WHERE key = 'admin';
    IF admin_id IS NOT NULL THEN
        INSERT INTO public.role_permissions (role_id, permission_id)
        SELECT admin_id, id FROM public.permissions
        WHERE key IN (
            'blog.create', 'blog.edit_own', 'blog.edit_any', 'blog.publish',
            'users.view', 'chat.moderate', 'reports.review', 'community.manage'
        )
        ON CONFLICT (role_id, permission_id) DO NOTHING;
    END IF;
END $$;

-- 5. Helper Functions (SECURITY DEFINER with empty search_path)
CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.roles r ON ur.role_id = r.id
        WHERE ur.user_id = auth.uid()
          AND r.key = 'superadmin'
    );
$$;

CREATE OR REPLACE FUNCTION public.has_permission(perm_key TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT (
        -- Superadmin possesses every permission automatically
        public.is_superadmin()
        OR EXISTS (
            SELECT 1
            FROM public.user_roles ur
            JOIN public.role_permissions rp ON ur.role_id = rp.role_id
            JOIN public.permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = auth.uid()
              AND p.key = perm_key
        )
    );
$$;

CREATE OR REPLACE FUNCTION public.my_permissions()
RETURNS TEXT[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    res TEXT[];
BEGIN
    IF public.is_superadmin() THEN
        SELECT array_agg(key) INTO res FROM public.permissions;
        RETURN COALESCE(res, ARRAY[]::TEXT[]);
    END IF;

    SELECT array_agg(DISTINCT p.key)
    INTO res
    FROM public.user_roles ur
    JOIN public.role_permissions rp ON ur.role_id = rp.role_id
    JOIN public.permissions p ON rp.permission_id = p.id
    WHERE ur.user_id = auth.uid();

    RETURN COALESCE(res, ARRAY[]::TEXT[]);
END;
$$;

-- 6. Trigger to automatically assign 'user' role on signup
CREATE OR REPLACE FUNCTION public.assign_default_user_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    user_role_id UUID;
BEGIN
    SELECT id INTO user_role_id FROM public.roles WHERE key = 'user';
    IF user_role_id IS NOT NULL THEN
        INSERT INTO public.user_roles (user_id, role_id)
        VALUES (NEW.id, user_role_id)
        ON CONFLICT (user_id, role_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_profile_assign_role ON public.profiles;
CREATE TRIGGER on_profile_assign_role
    AFTER INSERT ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.assign_default_user_role();

-- 7. Role Management RPCs
CREATE OR REPLACE FUNCTION public.assign_user_role(target_user_id UUID, role_key TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    target_role_id UUID;
BEGIN
    IF NOT public.has_permission('roles.manage') THEN
        RAISE EXCEPTION 'Access denied: requires roles.manage permission.';
    END IF;

    -- Only superadmins can assign superadmin
    IF role_key = 'superadmin' AND NOT public.is_superadmin() THEN
        RAISE EXCEPTION 'Access denied: only superadmins can assign the superadmin role.';
    END IF;

    SELECT id INTO target_role_id FROM public.roles WHERE key = role_key;
    IF target_role_id IS NULL THEN
        RAISE EXCEPTION 'Role with key % does not exist.', role_key;
    END IF;

    INSERT INTO public.user_roles (user_id, role_id, assigned_by)
    VALUES (target_user_id, target_role_id, auth.uid())
    ON CONFLICT (user_id, role_id) DO NOTHING;

    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (auth.uid(), 'assign_role', 'user_roles', target_user_id::TEXT, jsonb_build_object('role', role_key));
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_user_role(target_user_id UUID, role_key TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    target_role_id UUID;
    superadmin_count INTEGER;
BEGIN
    IF NOT public.has_permission('roles.manage') THEN
        RAISE EXCEPTION 'Access denied: requires roles.manage permission.';
    END IF;

    -- Forbid removing the last superadmin
    IF role_key = 'superadmin' THEN
        SELECT COUNT(*) INTO superadmin_count
        FROM public.user_roles ur
        JOIN public.roles r ON ur.role_id = r.id
        WHERE r.key = 'superadmin';

        IF superadmin_count <= 1 THEN
            RAISE EXCEPTION 'Action rejected: cannot remove the last superadmin.';
        END IF;
    END IF;

    SELECT id INTO target_role_id FROM public.roles WHERE key = role_key;
    IF target_role_id IS NOT NULL THEN
        DELETE FROM public.user_roles
        WHERE user_id = target_user_id AND role_id = target_role_id;

        INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
        VALUES (auth.uid(), 'revoke_role', 'user_roles', target_user_id::TEXT, jsonb_build_object('role', role_key));
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_user_ban_status(target_user_id UUID, ban_state BOOLEAN, ban_reason TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT public.has_permission('users.ban') THEN
        RAISE EXCEPTION 'Access denied: requires users.ban permission.';
    END IF;

    IF target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Action rejected: cannot ban yourself.';
    END IF;

    UPDATE public.profiles
    SET is_banned = ban_state, updated_at = NOW()
    WHERE id = target_user_id;

    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (
        auth.uid(),
        CASE WHEN ban_state THEN 'ban_user' ELSE 'unban_user' END,
        'profiles',
        target_user_id::TEXT,
        jsonb_build_object('reason', ban_reason, 'banned', ban_state)
    );
END;
$$;

-- 8. Row Level Security Policies
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Read roles & permissions
CREATE POLICY "Authenticated users can view roles"
    ON public.roles FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Authenticated users can view permissions"
    ON public.permissions FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Authenticated users can view role_permissions"
    ON public.role_permissions FOR SELECT TO authenticated USING (TRUE);

-- User roles: users can view own roles, users.view can view all
CREATE POLICY "Users can view own roles"
    ON public.user_roles FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.has_permission('users.view'));

-- Audit logs: readable by audit.view only
CREATE POLICY "Audit logs viewable by auditors"
    ON public.audit_logs FOR SELECT TO authenticated
    USING (public.has_permission('audit.view'));
