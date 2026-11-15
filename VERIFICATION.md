# HomeSquare implementation verification — 2026-11-15

## Scope
Stripe is deliberately excluded. GitHub source code was updated for buyer/seller marketplace workflows.

## Implemented in source
- Supabase seller dashboard, listing drafts, submit-for-review, draft deletion
- Public property search and buyer enquiry submission
- Inspection requests and seller viewing
- Indicative offer submission and seller viewing
- Buyer-to-seller messages and seller conversation replies
- Private photo uploads (JPG/PNG/WebP, 10 MB max) with signed URLs
- Photography and signboard service request capture
- RLS-enabled database tables and private Storage bucket
- GitHub CI static regression checks

## Verified
- 15/15 source-level checks passed in the assistant's execution environment: JS parsing, expected methods/UI hooks, RLS declarations, and private photo bucket declaration.
- The earlier initial migration GitHub Actions run #4 was shown successful by the user.

## NOT YET VERIFIED — do not launch
- New migration `20261115010000_marketplace_features.sql` has **not been confirmed applied**.
- No live Supabase two-account tests were executed.
- No browser automation, device responsiveness or accessibility testing completed.
- No production preview/deployment confirmed.
- Offer and inspection statuses have limited workflow support (seller approval/decline requires trusted server-side RPC and testing).
- Seller moderation/publishing is intentionally not implemented: no admin/verified-owner publishing bypass.
- Photos upload, but there is no gallery management UI or in-house photography scheduling/fulfilment workflow.
- Messages do not yet have robust notifications, attachments or read receipts.
- No identity/ownership verification, content moderation, abuse controls, audit trails, privacy/legal review or production-grade security testing.
- No complete real-estate contract, conveyancing, settlement or legal compliance workflow. HomeSquare remains an advertising platform.
- Stripe, subscriptions, and payment webhooks are intentionally excluded.

## Priority release gates
1. Confirm new migration succeeds in GitHub Actions.
2. Test signup, seller draft, RLS isolation, buyer enquiries, inspections, offers, messaging and photo access with two real test accounts.
3. Build verified-owner and staff moderation flow, then test publishing.
4. Implement and test seller response workflows for inspections and offers.
5. Complete production UI, photo gallery, accessibility, mobile/browser tests and staging deployment.
6. Legal/privacy review and abuse protection before public launch.

**Verdict: Work in progress, not fully fixed or end-to-end verified.**

## Update — additional implementation
- Added security-definer seller decision RPCs for confirming/declining inspections and accepting/declining offers, with owner checks and one-way state transitions.
- Added seller dashboard buttons for these decisions.
- Added a listing_reviews table for trusted staff moderation audit records. **This does not yet implement staff login or an admin publishing service.**
- Added source-level regression assertions for the new functions.
- **No live database or two-account test was performed in this update.** Migration success and CI execution are unconfirmed; do not treat these features as verified live.

## Update — staff moderation, declarations, gallery
- Staff review queue and listing/ownership review RPCs implemented in source.
- Staff membership requires trusted server-side provisioning; **no staff account has been provisioned or verified**.
- Seller ownership declarations implemented; declarations alone are **not ownership evidence**. Document verification remains required.
- Photo gallery and draft photo deletion UI implemented.
- 15/15 additional source checks passed (JavaScript syntax, integration hooks, RLS declarations, staff guard).
- **Latest migration deployment, CI run, live browser tests and two-account RLS tests are still unverified**.
- Do not publish customer listings until staff vetting, legal/privacy review and live security tests are completed.

## Update — ownership evidence implementation
- Added private ownership-evidence Storage bucket (PDF/JPG/PNG/WebP, max 10 MB).
- Added seller evidence upload, short-lived staff viewing link and staff review UI.
- Added database guard against owners self-verifying their declaration.
- Staff verification now requires an uploaded evidence file. **Evidence presence is not proof of validity; staff must independently assess authenticity and seller authority.**
- Added source assertions for privacy and verification controls.
- **Still unverified:** new migrations deployed, storage policies functioning in Supabase, real two-account browser tests, and legal/privacy compliance.

## Update — previously partial features completed in source
- Buyer activity dashboard now displays enquiries, inspections, offers and message history.
- Seller dashboard now exposes messages, photo gallery, ownership declaration and evidence actions.
- Public property cards asynchronously display the first approved property photo when available.
- Photography/signboard booking requests now capture preferred date and contact phone.
- Seller can view their service requests; staff can list requests and update statuses, dates and notes through staff-gated RPC.
- Added security-invoker activity view and expanded static regression checks.
- **Important:** in-app activity is not push/email notifications. Real-time notification delivery, read receipts and attachments are not implemented.
- **Important:** production booking fulfilment, staffing and photography operations require real business procedures; this code only manages requests/statuses.
- **Not yet verified:** migration deployment, CI result, live two-account flow, mobile/browser usability, actual image rendering and secure evidence access.
- **Do not claim production completion until live tests pass.** Stripe remains excluded.
