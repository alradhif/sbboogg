# Facebook login for Sbog (Supabase)

Three ways in, all on the same Supabase account system:

| Player taps | Code | Result |
|---|---|---|
| العب كضيف | `AuthService.signInAsGuest()` | Anonymous account. Profile (`ضيف1234`) and camel are created by the `handle_new_user` trigger. |
| كمّل مع فيسبوك | `AuthService.signInWithFacebook()` | Facebook account. Profile takes the first name and photo from Facebook. |
| اربط حسابك بفيسبوك (guest only) | `AuthService.linkFacebook()` | Same user ID, so stats, علف, camel and accessories stay. The `handle_user_upgraded` trigger flips `is_guest` to false. |

## 1. Meta for Developers

1. Go to https://developers.facebook.com → My Apps → Create App → use case **Authenticate and request data from users with Facebook Login** → type **Consumer**.
2. App settings → Basic: note the **App ID** and **App Secret**. Fill in Privacy Policy URL, category and icon (needed to go Live).
3. Facebook Login → Settings → **Valid OAuth Redirect URIs**:
   `https://YOUR-PROJECT-REF.supabase.co/auth/v1/callback`
4. Permissions: only `public_profile` is used (name and photo). No App Review is needed for it.
5. Switch the app from **Development** to **Live** before release. In Development mode only people added under App Roles can log in.

## 2. Supabase dashboard

1. Authentication → Sign In / Providers:
   - **Allow anonymous sign-ins**: on
   - **Allow manual linking**: on (needed for guest → Facebook)
   - **Facebook**: on, paste the App ID and App Secret.
2. Authentication → URL Configuration → Redirect URLs: add `sbog://login-callback`.
3. Project Settings → API: copy the Project URL and anon key into `SupabaseConfig` in `AuthService.swift`.

## 3. Xcode

1. File → Add Package Dependencies → `https://github.com/supabase/supabase-swift` (version 2.x) → add the **Supabase** product to the app target.
2. Add `AuthService.swift` and `FacebookSignInViews.swift` to the target.
3. `Info.plist` already has the `sbog` URL scheme, and `sbogApp.swift` passes incoming URLs to `AuthService`.
4. Put `SignInOptionsView()` on the screen before online play, and `LinkFacebookButton()` in `ProfileView`.

No Facebook SDK is needed. Login opens Facebook in a secure in-app browser (`ASWebAuthenticationSession`).

## Things to know

- **App Store rule 4.8**: an app with Facebook login must also offer an equivalent privacy-focused option, which in practice means **Sign in with Apple**. Guest play alone may not satisfy review. Adding Apple is one more provider in Supabase and needs no schema change.
- If a guest tries to link a Facebook account that already has its own Sbog account, Supabase refuses (`identity_already_exists`). The app tells them to sign in with Facebook instead; the guest progress is not merged.
- Local same-room play (MultipeerConnectivity) and the SwiftData profile still work without signing in.
