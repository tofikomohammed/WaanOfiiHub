# WAAN-OFIIHUB (Blog + Chat App)

A modern, cross-platform Flutter application (Android, iOS, Web) built with **Supabase Free Tier** and **Dynamic Role-Based Access Control (RBAC)**.

---

## 🚀 Scope: Strictly Two Core Modules

1. **Blog Module**: Admin-published posts (Text + Gallery, Single Image, Audio/Podcast), user comments, likes, and in-app audio player.
2. **Chat Module**: WhatsApp/Telegram-style messenger with direct 1-to-1 chats, user groups, community channels, voice notes, media sharing, and read receipts.
3. **Contact Sync**: Privacy-preserving discovery using salted SHA-256 phone hashes (no raw phone numbers or names uploaded) and Public ID (`WOH-XXXXXX`) search.

---

## 📁 Project Structure

```text
├── env.json                          # Supabase configuration (git-ignored)
├── env.example.json                  # Template configuration
├── lib/
│   ├── main.dart                     # App entry point & global error handling
│   ├── core/
│   │   ├── config/                   # EnvConfig and safe SupabaseClient loader
│   │   ├── errors/                   # AppException taxonomy & UI ErrorHandler
│   │   ├── router/                   # GoRouter navigation & route guards
│   │   ├── theme/                    # Material 3 light/dark themes
│   │   └── widgets/                  # Adaptive AppShell, EmptyState, ErrorView
│   └── features/
│       ├── auth/                     # Supabase authentication & registration
│       ├── profile/                  # Profile, public ID display & privacy toggles
│       ├── rbac/                     # Permissions provider & PermissionGate
│       ├── blog/                     # Feed, detail, comments, likes, admin creator
│       ├── chat/                     # 1-to-1, groups, communities, realtime messaging
│       ├── contacts/                 # Salted hash phonebook matching & public ID lookup
│       └── admin/                    # Users, roles, moderation & audit logs
└── supabase/
    ├── migrations/                   # Sequential SQL migrations (Tables, RLS, RPCs)
    │   ├── 00001_profiles_and_public_id.sql
    │   ├── 00002_rbac_system.sql
    │   ├── 00003_blog_module.sql
    │   ├── 00004_chat_module.sql
    │   ├── 00005_contact_sync.sql
    │   └── 00006_rls_security_tests.sql
    └── bootstrap_superadmin.sql      # One-time superadmin grant script
```

---

## 🛠️ Supabase Setup & Migrations

To configure your Supabase backend:

1. Open your Supabase project's **SQL Editor**.
2. Run the migration scripts in numerical sequence:
   - `00001_profiles_and_public_id.sql`
   - `00002_rbac_system.sql`
   - `00003_blog_module.sql`
   - `00004_chat_module.sql`
   - `00005_contact_sync.sql`
   - `00006_rls_security_tests.sql`
3. After registering your main admin account in the app, open `supabase/bootstrap_superadmin.sql`, replace `'YOUR_ADMIN_EMAIL_HERE'` with your email, and run it in the SQL Editor to grant superadmin rights.

---

## 🏃 Running the Application

Ensure `env.json` exists in the project root:
```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key"
}
```

Run on Chrome (Web):
```bash
flutter run -d chrome --dart-define-from-file=env.json
```

Or on Android / iOS:
```bash
flutter run --dart-define-from-file=env.json
```

---

## 🔒 Security & Privacy

- **Row Level Security (RLS)**: Enforced backend-side on all tables (`profiles`, `posts`, `post_media`, `post_likes`, `post_comments`, `conversations`, `conversation_members`, `messages`, `blocks`, `reports`, `audit_logs`).
- **Dynamic RBAC**: All permission gates use `has_permission(text)` `SECURITY DEFINER` functions.
- **Privacy-Safe Contact Sync**: Contacts are normalized to E.164 and hashed with a salted SHA-256 on-device before transmission. Raw contacts are never stored on the server.
