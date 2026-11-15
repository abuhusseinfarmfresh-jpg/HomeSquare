# Supabase setup for HomeSquare

Project URL: https://lioxnrbaqjqehdnhhayv.supabase.co

## Activate the backend
1. In Supabase Dashboard → SQL Editor, run `supabase/schema.sql`. GitHub linking alone does not execute SQL.
2. In Supabase Dashboard → Project Settings → API Keys, copy the **publishable** key (or legacy `anon` key). Do not use a secret/service-role key.
3. Set `window.HOMESQUARE_SUPABASE_PUBLISHABLE_KEY` in `supabase/config.js`.
4. Configure Authentication → URL Configuration for your actual preview/production domain.
5. Test two different users: a seller creates a draft; a buyer cannot see it until a trusted moderator publishes it; a buyer can enquire about published listings, but cannot read another buyer's enquiries.
6. Do not enable public self-publishing without moderation and owner verification.

## Security notes
- Row-level security policies in the schema are mandatory.
- The current `index.html` is a local-only prototype; it does not yet import this configuration.
- Supabase GitHub integration does not grant ChatGPT Supabase dashboard access.
- Do not share passwords, service-role keys or secret API keys.
