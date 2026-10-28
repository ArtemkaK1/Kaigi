# Security and privacy

Do not put sensitive vulnerability details or private user data in public issues. Use GitHub private vulnerability reporting after the owner enables it, or contact the repository owner privately through their published GitHub profile. No security email address is fabricated here.

Kaigi uses EventKit only to read system calendars. macOS calls the necessary permission “Full Access”; the production gateway contains no calendar-writing API. The calendar entitlement is required by EventKit and does not itself enforce read-only access. A separate local QA executable can create only its own synthetic test fixtures and is excluded from production targets.

Notes and revisions use a local SwiftData store in the app sandbox. CloudKit is explicitly disabled. There is no backend, authentication service, analytics SDK, recording, microphone access, external LLM, or network-client entitlement. Foundation Models uses the on-device system model. Opening a conference/calendar HTTPS link intentionally hands that URL to the system browser or provider; the destination's own privacy practices apply.

Notes are not separately encrypted by the app. Protect the Mac account and use FileVault as appropriate. OS backups may include the sandbox. Markdown export is an explicit user action and creates an ordinary plaintext file. Reminder notifications omit meeting titles and note content.

Only HTTPS URLs without embedded credentials or unusual ports are accepted. Provider names require domain-boundary matching; unknown HTTPS URLs require explicit selection from a destination-labelled menu. Remote sites may redirect, and link recognition does not attest to the destination's trustworthiness.

The model can make mistakes. Review every AI preview; exact-excerpt validation prevents invented text in Structure but cannot prove semantic category accuracy. Clean Up still requires human review. Neither action confirms future context automatically.

Calendar identities can change. Matching requires the same calendar and external event identity, plus the original occurrence slot for recurring meetings. One-time meetings use their external event identity across date changes. Uncertain identities stay separate, and existing notes remain in Saved notes. No title-similarity merges or silent deletion occur.

Before any public push, repeat the history and working-tree audit, including untracked files. Exclude stores, calendar fixtures with private data, signing keys/profiles, build products, user state, and screenshots. Publication requires the owner's explicit authorization.
