# ANTIGRAVITY MASTER PROMPT: WAAN-OFIIHUB (Blog + Chat ONLY)
Flutter + Supabase (Free Tier) + Dynamic Role-Based Access

---

## 0. SCOPE: READ FIRST

Build a cross-platform Flutter app (Android, iOS, Web) with **ONLY TWO MODULES**:

1. **Blog**: posts published by admins (text with image, image only, or audio).
2. **Chat**: a WhatsApp/Telegram-style messenger (private chats, groups, community channels, contact sync).

Everything else (services, categories, homepage CMS, events, Ramadan, charity, etc.) is **OUT OF SCOPE**. Do not build it and do not create tables for it. Design so those modules can be added later without breaking changes.

### Working rules
1. Build **one phase at a time**. Do not start the next phase until I say "next phase".
2. **Do NOT build APK/IPA/web bundles.** I will build myself. After each phase, only run:
   - `flutter pub get`
   - `dart format .`
   - `flutter analyze` (must report **0 errors and 0 warnings**; fix all)
   - `flutter test` (only if tests exist)
   Report the actual output and any remaining limitations. Never claim a feature works if you did not verify it by analysis or tests.
3. To reduce analyzer/codegen errors: **no `freezed`, no `build_runner`, no code generation.** Use plain immutable Dart classes with manual `fromJson/toJson/copyWith`, and Riverpod without annotations.
4. Never put secrets in code. Only the Supabase URL and anon key go in a git-ignored `env.json` loaded via `--dart-define-from-file`. Never use the `service_role` key in the client.
5. Every database change is a **versioned SQL migration** in `supabase/migrations/`. Provide complete, runnable SQL (tables, indexes, RLS, functions, storage buckets and policies).
6. Enforce permissions on the **backend (RLS + SECURITY DEFINER functions)**. Frontend checks are UX only.
7. End every phase with a short **manual test checklist** (using test accounts: user A, user B, admin, superadmin).

---

## 1. TECH STACK

- Flutter stable, Dart 3, null-safety
- `flutter_riverpod`, `go_router`, `supabase_flutter`
- `cached_network_image`, `image_picker`, `flutter_image_compress`
- `record` (voice recording), `just_audio` (audio playback), `path_provider`
- `flutter_contacts` (contact sync), `crypto` (hashing), `permission_handler`
- `firebase_messaging` + `flutter_local_notifications` (push; FCM is free). Keep this in its own phase.
- `intl`, `url_launcher`, `shared_preferences`
- Feature-first structure:

```
lib/
  core/        (config, theme, router, errors, utils, shared widgets)
  features/
    auth/  profile/  rbac/  home/  blog/  chat/  contacts/  admin/
supabase/
  migrations/  functions/  bootstrap_superadmin.sql
test/
```

### Supabase free-tier constraints (design around them)
- ~500 MB DB, **1 GB storage**, ~5 GB egress/month, 50 MB max file upload, ~200 concurrent Realtime connections.
- Projects pause after ~1 week of inactivity. No automatic backups on the free plan.

Therefore:
- **Images:** compress client-side (max 1280 px, ~80% quality, max ~1 MB, jpeg/webp). Chat thumbnails are generated client-side as small previews.
- **Voice/audio:** record in AAC/Opus at low bitrate (~32 kbps mono). Max chat voice message 5 minutes. Max admin audio post 20 MB. Validate MIME and size on the client and in storage policies.
- Paginate all lists (keyset pagination, 20-30 items). Never `select *` unbounded; select only needed columns.
- Use Realtime only on open conversations, the conversation list, and notification counts. Always unsubscribe when leaving screens.
- Add a **media retention setting** design note (e.g. optional cleanup job for old chat media) to protect the 1 GB limit. Implement it as an optional SQL function, not automatic.
- Be honest: this is **not end-to-end encrypted**. Do not claim E2EE anywhere.

---

## 2. DYNAMIC ROLE-BASED ACCESS (NOT HARDCODED)

**Forbidden:** checks like `email == '...'` or `role == 'admin'` scattered in UI code, or hardcoded per-role menus.

### Tables
```
roles            (id, key unique, name, description, is_system bool, created_at)
permissions      (id, key unique, module, description)
role_permissions (role_id, permission_id, pk(role_id, permission_id))
user_roles       (user_id -> auth.users, role_id, assigned_by, assigned_at, pk(user_id, role_id))
audit_logs       (id, actor_id, action, target_type, target_id, metadata jsonb, created_at)
```
- Seed roles `user`, `admin`, `superadmin` (is_system = true). They are **data**: a superadmin can create new roles (e.g. `editor`, `chat_moderator`) and assign any permission combination from the UI.
- Seed permission keys for this scope only:
  `blog.create`, `blog.edit_own`, `blog.edit_any`, `blog.publish`, `blog.delete`,
  `users.view`, `users.manage`, `users.ban`, `roles.manage`,
  `chat.moderate`, `reports.review`, `community.manage`, `audit.view`.
- Superadmin automatically receives every permission (including future ones).
- `SECURITY DEFINER` functions with `set search_path = ''`:
  `has_permission(text)`, `my_permissions()`, `is_superadmin()`.
- **RLS on every table**, with policies built on `has_permission()`.
- Role/permission changes only through RPC functions that check `roles.manage`, prevent privilege escalation (cannot grant a permission you do not hold), forbid removing the last superadmin, and write to `audit_logs`.
- Clients can never write `user_roles` or `role_permissions` directly.
- **Superadmin bootstrap:** `supabase/bootstrap_superadmin.sql`. A one-time script I run manually in the SQL editor, with an email placeholder I replace. No credentials in source code.

### Frontend (UX only)
- After login, load `my_permissions()` into a `permissionsProvider`; refresh on auth/token change.
- Provide `PermissionGate(permission: ..., child: ...)`, `ref.can('blog.create')`, and a `go_router` guard that reads required permission from route metadata.
- Admin navigation entries are generated from a **module registry filtered by permissions**. Users without admin permissions never see admin screens.

---

## 3. AUTH, PROFILE, PUBLIC ID, HOME

### Registration & login
- Email + password via Supabase Auth (works on the free tier). Optional Google sign-in.
- **Phone number:** collect it at registration (with country code picker), normalize to **E.164**. IMPORTANT: Supabase phone OTP needs a paid SMS provider (e.g. Twilio), so by default store the phone as **unverified** (`phone_verified = false`) and design the code so OTP verification can be plugged in later. Contact matching must clearly treat unverified numbers as unverified (see section 5).
- After register/login, the user lands on the **Home Dashboard**. Logout is always available.

### Profile (auto-created by a database trigger on `auth.users` insert)
```
profiles (id = auth.users.id, public_id unique, display_name, username unique nullable,
          avatar_url, about text, phone_e164 nullable, phone_hash nullable,
          phone_verified bool default false, last_seen_at, show_last_seen bool,
          is_banned bool, created_at, updated_at)
```
- `public_id` format `WOH-XXXXXX` (unambiguous alphabet `23456789ABCDEFGHJKLMNPQRSTUVWXYZ`), generated **in Postgres** with a retry loop on the unique constraint. Never on the client. Users cannot choose or change it.
- Safe backfill for existing users (only where `public_id IS NULL`).
- Show the ID on the profile with a copy button. Users can be found by public ID or username through an RPC that returns only `id, public_id, display_name, avatar_url`. Never email or phone.
- Edit profile: name, about, avatar (compressed upload), privacy toggles (last seen, who can find me by phone).

### Home Dashboard
- Bottom navigation (mobile) / navigation rail (web/desktop): **Home (Blog feed)**, **Chats**, **Contacts**, **Profile**, plus **Admin** (only if the user has any admin permission).
- Home shows the latest published blog posts and quick access to recent chats and unread counts.

---

## 4. BLOG MODULE (Admin posts, users read and interact)

### Post types (admin-created)
1. **Text + image(s)**: title, body (plain text with simple formatting: bold, links, line breaks), one cover image or a small gallery (max 5).
2. **Image only**: one or more images with an optional caption.
3. **Audio**: audio file (mp3/m4a/aac/ogg, max 20 MB) with title, description, optional cover image. In-app player (play/pause, seek, speed, background-safe stop on leaving screen).

### Tables
```
posts (id, author_id, type text check in ('text','image','audio'), title, body,
       cover_url, status check in ('draft','published','archived'),
       published_at, created_at, updated_at, is_pinned bool)
post_media (id, post_id, kind ('image'|'audio'), storage_path, mime, size_bytes,
            duration_seconds nullable, sort_order)
post_likes (post_id, user_id, created_at, pk(post_id, user_id))
post_comments (id, post_id, user_id, body, created_at, is_hidden bool)
```
- Storage bucket `blog-media` (public read for published posts' media; **write only by users with `blog.create`**; enforce MIME and size limits in storage policies).
- RLS:
  - Everyone authenticated can read `published` posts.
  - Drafts/archived: visible only to the author and users with `blog.edit_any`.
  - Create requires `blog.create`; edit own requires `blog.edit_own` + ownership; edit others requires `blog.edit_any`; publish requires `blog.publish`; delete requires `blog.delete`.
  - Likes and comments: any authenticated, non-banned user; users can delete their own comment; `blog.edit_any` can hide/delete comments.
- Admin UI: post list with filters (status/type), create/edit form per type with upload progress and validation, publish/unpublish/archive/pin, delete with confirmation. All sensitive actions are written to `audit_logs`.
- User UI: infinite-scroll feed, post detail, like, comment, share (copy link / system share), image viewer with zoom, audio player.
- Add pull-to-refresh, loading/empty/error states, and cached images.

---

## 5. CHAT MODULE (WhatsApp/Telegram-like)

### Conversation types
1. **Direct (1-to-1)**: one conversation per user pair (enforced by a unique constraint on sorted user IDs).
2. **Group**: user-created, name, avatar, description, members, group admins.
3. **Community channels**: app-wide or topic rooms, **created and managed by users with `community.manage`**; users can join/leave open communities. Support an optional "announcement only" mode (only admins can post).

### Tables (suggested; refine as needed)
```
conversations (id, type check in ('direct','group','community'), title, avatar_url,
               description, created_by, is_announcement_only bool, is_open bool,
               last_message_id, last_message_at, created_at)
conversation_members (conversation_id, user_id, role check in ('member','admin','owner'),
                      joined_at, muted_until, last_read_message_id, last_read_at,
                      is_archived bool, pk(conversation_id, user_id))
messages (id, conversation_id, sender_id, type check in ('text','image','audio','system'),
          body, media_path, media_mime, media_size, media_duration_seconds,
          reply_to_id nullable, created_at, edited_at nullable,
          deleted_for_everyone bool default false)
message_receipts (message_id, user_id, delivered_at, read_at, pk(message_id, user_id))
message_deletions (message_id, user_id)          -- "delete for me"
blocks (blocker_id, blocked_id, created_at, pk(blocker_id, blocked_id))
reports (id, reporter_id, reported_user_id, conversation_id, message_id,
         reason, details, status check in ('open','reviewed','dismissed','actioned'),
         reviewed_by, created_at)
contact_matches (see section 6)
```
- Storage bucket `chat-media` is **private**. Use signed URLs. Path convention: `{conversation_id}/{message_id}.{ext}` with storage policies that allow access only to conversation members.

### Features (implement all, in phases)
- Real-time text messaging with optimistic UI, retry on failure, pagination of history (keyset), date separators.
- **Chats list:** last message preview, time, unread badge, pinned/archived, mute, search by name and message text.
- **Message status:** sending, sent, delivered, read (single/double tick style), tracked through `message_receipts`. Group chats show read-by list.
- **Typing indicator** and **online/last seen** using Realtime Presence on active screens; respect the user's `show_last_seen` privacy setting. If not reliable on a platform, degrade gracefully.
- **Images:** pick from gallery/camera, compress, preview before sending, caption, full-screen viewer.
- **Voice messages:** hold-to-record, slide-to-cancel, waveform or progress bar, playback speed (1x/1.5x/2x), duration shown. Max 5 minutes.
- **Reply to message**, **delete for me**, **delete for everyone** (sender only, within a time window, e.g. 1 hour; leave a "message deleted" tombstone), **copy text**, **forward** (to other chats).
- **Edit message** (text only, sender only, within 15 minutes; show "edited").
- **Groups:** create, add/remove members, leave, promote/demote group admins, edit name/avatar, member limit (e.g. 256).
- **Communities:** browse/join/leave, announcement mode, member list.
- **Block/unblock** user (blocked users cannot message or see presence). **Report** user/message with reason.
- **Mute** conversation, **archive** conversation.
- **Notifications:** FCM push for new messages (via a Supabase Edge Function triggered by a database webhook), with sender name and a text preview, which respects mute. In-app unread counts via Realtime.
- Responsive layout: phone (single pane), tablet/desktop/web (two-pane: list + conversation).

### Security (all enforced in the backend)
- Only authenticated, non-banned users can use chat.
- Only members can read or send messages in a conversation. `sender_id` must equal `auth.uid()` (enforced by RLS `with check`).
- Clients cannot alter messages except through allowed RPCs/policies (edit/delete-for-everyone rules above).
- Direct conversations are created via RPC `start_direct_conversation(target_user_id)` which checks blocks and prevents duplicates. Group/community membership changes go through RPCs that verify roles.
- Rate-limit sending (e.g. DB-side check: max N messages per minute per user).
- Moderators with `chat.moderate`/`reports.review` can see **only reported messages plus a small, limited context window** via an RPC, never browse private conversations. Every moderation action is written to `audit_logs`.
- Never expose email or phone numbers to other users (see section 6).

---

## 6. CONTACT SYNC (like WhatsApp/Telegram, privacy-safe)

Goal: after registration, the user can allow access to their phone contacts and see which contacts already use WOH, then start a chat in one tap.

Implementation requirements:
1. Ask for the contacts permission **only when the user taps "Sync contacts"**, with a clear explanation screen first. If denied, the app still works (search by public ID/username remains available).
2. On the device: read contacts, normalize each number to **E.164** (using the user's country as the default region), then compute a **salted SHA-256 hash**. Send **only hashes** to the server, in batches (e.g. 500), never raw names or numbers.
3. Server: RPC `match_contacts(hashes text[])` returns only the `id, public_id, display_name, avatar_url` of users whose `phone_hash` matches **and** who have enabled "allow others to find me by phone". Do not store the uploaded contact list (or, if caching is needed, store it only on the device).
4. Handle the unverified-phone limitation clearly: while `phone_verified = false`, matches are labeled **"unverified number"** and the UI must not present them as confirmed. Design `phone_verified` so OTP verification can be added later.
5. Local display name comes from the user's own address book (device-side), falling back to the profile name.
6. Contacts screen: list of matched contacts (A-Z), search, "Invite" button for non-users (system share sheet with a short invite text), pull-to-refresh to re-sync, and a privacy settings shortcut.
7. Add rate limits to `match_contacts` to prevent phone-number enumeration (e.g. max calls and hashes per hour per user).
8. Document in the README the privacy implications and what is stored.

---

## 7. PHASES (implement ONLY the phase I name)

| Phase | Scope |
|---|---|
| **1** | Project scaffold, theme (light/dark), router, env config, Supabase init, error handling, lint rules |
| **2** | Auth + profile + auto `public_id` + Home Dashboard shell + logout |
| **3** | RBAC core (tables, seed, functions, RLS, `permissionsProvider`, `PermissionGate`, route guards, bootstrap script) + Roles & Users admin screens + audit logs |
| **4** | Blog backend (tables, RLS, storage) + Admin post create/edit (text+image, image, audio) |
| **5** | Blog user side (feed, detail, likes, comments, audio player, share) |
| **6** | Chat core: direct conversations, realtime text messaging, chat list, unread counts, receipts |
| **7** | Chat media: images + voice messages, reply, edit, delete (me/everyone), forward |
| **8** | Groups + Community channels (+ announcement mode, member management) |
| **9** | Contact sync + contacts screen + user search by public ID |
| **10** | Presence, typing indicator, last seen, mute/archive, block/report + moderation queue and audit |
| **11** | Push notifications (FCM + Edge Function) |
| **12** | Security review, RLS test SQL scripts, responsive and accessibility polish, README (setup, free-tier notes, backup instructions) |

---

## 8. QUALITY REQUIREMENTS

- Every screen handles **loading, empty, error, and offline** states.
- Input validation on client and server (check constraints, length limits).
- Provide SQL **RLS test scripts** (phase 12, or earlier where relevant) showing that: user A cannot read user B's chats, a non-admin cannot publish a post or assign roles, a blocked user cannot message, a non-member cannot read community-private data.
- Keep the code analyzer-clean: **0 errors, 0 warnings** from `flutter analyze` before you finish any phase.
- Accessible UI (semantic labels, contrast, text scaling) and RTL-safe layouts.

---

## 9. FIRST TASK

Start with **Phase 1 only**:
1. Briefly show: folder structure, package list with versions, and any assumptions.
2. Ask me for anything missing (Supabase URL and anon key go in `env.json`, which stays out of git).
3. Implement, then run `flutter pub get`, `dart format .`, `flutter analyze`, and report the real results.
4. **Do not build an APK/IPA/web bundle.** Stop and wait for "next phase".

---

## 10. FOOTER TO USE ON EVERY FUTURE PHASE MESSAGE

> Continue from the current WAAN-OFIIHUB Flutter + Supabase project (Blog + Chat scope only). Do not rebuild or restructure it. Keep Logout, auth, routing, and completed modules working. Reuse the existing tables, RBAC system, audit logs, and storage buckets. Add changes only as new migrations. Enforce permissions in RLS via `has_permission()`. Implement **only** the phase I named. No code generation, no APK builds. Run `dart format .` and `flutter analyze` (0 errors, 0 warnings) and report real results and limitations.