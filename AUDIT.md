# HomeSquare — Source Audit (2026-11-15)

Scope: reviewed current GitHub source `index.html`, `supabase/client.js`, `supabase/schema.sql`, `supabase/config.js`, and deployment workflow. This is a **static source audit**, not a live end-to-end test. The user's GitHub screenshot shows migration workflow #4 succeeded; this does not independently prove runtime features.

## Release verdict: NOT READY

| Area | Result | Evidence / next action |
|---|---|---|
| Database migration | CI success reported | Screenshot of run #4 green; no direct database introspection performed |
| Login/signup | Implemented, unverified | UI and auth calls exist; no automated sign-in test |
| Public browsing | Partial | Reads first 100 published rows, filters client-side; no pagination or location/price indexing beyond basic index |
| Seller draft creation | Partial | Inserts remote draft but seller dashboard reads localStorage only |
| Seller dashboard | FAIL | Does not query remote seller-owned properties |
| Publication | BLOCKED | RLS deliberately prohibits clients publishing; moderation service not implemented |
| Buyer enquiries | Partial | Remote insert exists, but seller inbox reads only localStorage |
| Inspection scheduling | NOT BUILT | Enquiry kind only, no availability/calendar/confirmation |
| Offers | NOT BUILT | Enquiry kind only; no price input, status, negotiation, withdrawal or acceptance |
| Property images | NOT BUILT | Placeholder emoji; no Storage bucket/upload rules |
| Identity/ownership verification | NOT BUILT | No identity verification workflow |
| Payments/subscriptions | NOT BUILT | No Stripe checkout or webhook verification |
| Photography/signboards | NOT BUILT | No ordering/fulfilment flow |
| Messaging | NOT BUILT | No shared message threads |
| Automated test suite | NOT PRESENT | Add static tests and browser E2E/integration tests |
| Deployment | NOT VERIFIED | No confirmed public preview URL |

## High-priority defects

1. **Mixed data sources:** `renderDashboard()`, `togglePublish()`, `removeListing()`, and `viewEnquiries()` use localStorage even after backend activation. Remote seller drafts do not appear.
2. **False publication semantics:** local prototype's publish toggle does not publish Supabase rows. Backend has no trusted moderation flow.
3. **Misleading UI:** dashboard and enquiry forms still claim browser-only operation, even when remote API calls are enabled.
4. **No meaningful offers:** form captures name/email/message but no proposed amount, while remote insert ignores those identity fields.
5. **No automated regression coverage:** backend changes can ship without catching broken user flows.
6. **Auth UX:** account form sits below the footer, with no navigation link to it; sign-in is hard to discover.
7. **Data validation:** basic SQL checks exist but no upper bounds on listing text, prices or enquiry size; rate limiting and abuse controls not implemented.
8. **No pagination:** published property query caps results at 100; later listings become undiscoverable.

## Security review

Positive: RLS is enabled for all three tables; users can create only their own drafts; buyers cannot enquire about their own properties; direct publication is denied. Publishable key is safe for browser use when RLS is correct.

Risks: RLS has not been tested with separate real accounts. No verification/moderation implementation; no abuse/rate limits; no account deletion or data retention policy; public listing address visibility needs product/privacy review. A previously shared personal access token should be rotated.

## Release gates

- [ ] Run real two-account auth and RLS tests in a non-production environment
- [ ] Replace localStorage paths with remote seller listings and inbox
- [ ] Build moderated publish flow
- [ ] Add real inspection booking and offer records
- [ ] Implement photo storage and upload validation
- [ ] Add automated E2E and security tests
- [ ] Verify responsive layout and keyboard accessibility in real browsers
- [ ] Deploy staging preview, test across devices
- [ ] Complete privacy, legal and payments review before launch

## Conclusion

Migration success establishes only that the deployment job finished successfully. The product is a functional-looking prototype with partial backend integration, not a tested production marketplace.
