# Social provider setup checklist

Status on 2026-11-15: **no provider credentials are configured. No channel is
connected.** A healthy web app does not mean any provider works.

Derived from Postiz v2.26.0 source
(`libraries/nestjs-libraries/src/integrations/social/*.provider.ts`): each
provider redirects to `${FRONTEND_URL}/integrations/social/<identifier>`.

| Provider | Env vars (app.env) | Callback / redirect URL | Requested scopes (v2.26.0) | Approval |
| --- | --- | --- | --- | --- |
| Facebook Pages | `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | `https://social.appsdoc.com/integrations/social/facebook` | pages_show_list, business_management, pages_manage_posts, pages_manage_engagement, pages_read_engagement, read_insights | Meta App Review + Business verification for non-dev users |
| Instagram (via Facebook) | same Facebook app | `https://social.appsdoc.com/integrations/social/instagram` | instagram_basic, pages_show_list, pages_read_engagement, business_management, instagram_content_publish, instagram_manage_comments, instagram_manage_insights | Meta App Review |
| Instagram (standalone) | `INSTAGRAM_APP_ID`, `INSTAGRAM_APP_SECRET` | `https://social.appsdoc.com/integrations/social/instagram-standalone` | instagram_business_basic, instagram_business_content_publish, instagram_business_manage_comments, instagram_business_manage_insights | Meta App Review |
| Threads | `THREADS_APP_ID`, `THREADS_APP_SECRET` | `https://social.appsdoc.com/integrations/social/threads` | threads_basic, threads_content_publish, threads_manage_replies, threads_manage_insights | Meta App Review |
| LinkedIn (profile) | `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET` | `https://social.appsdoc.com/integrations/social/linkedin` | openid, profile, w_member_social, r_basicprofile, rw_organization_admin, w_organization_social, r_organization_social | Both LinkedIn variants request organization scopes → **Community Management API** access (review) |
| LinkedIn (page) | same app | `https://social.appsdoc.com/integrations/social/linkedin-page` | same as above | same app and review |
| TikTok | `TIKTOK_CLIENT_ID`, `TIKTOK_CLIENT_SECRET` | `https://social.appsdoc.com/integrations/social/tiktok` | video.list, user.info.basic, video.publish, video.upload, user.info.profile, user.info.stats | Content Posting API audit; unaudited apps post private-only |
| YouTube | `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET` | `https://social.appsdoc.com/integrations/social/youtube` | userinfo.profile, userinfo.email, youtube, youtube.force-ssl, youtube.readonly, youtube.upload, youtubepartner, yt-analytics.readonly | Google OAuth verification for sensitive scopes (or Internal audience) |
| Pinterest | `PINTEREST_CLIENT_ID`, `PINTEREST_CLIENT_SECRET` | `https://social.appsdoc.com/integrations/social/pinterest` | boards:read/write, pins:read/write, user_accounts:read | Trial access → Standard access request |
| X | `X_API_KEY`, `X_API_SECRET` (OAuth 1.0a consumer keys) | `https://social.appsdoc.com/integrations/social/x` | read+write app permissions | Paid X API tier required for posting volume |
| Slack | `SLACK_ID`, `SLACK_SECRET`, `SLACK_SIGNING_SECRET` | `https://social.appsdoc.com/integrations/social/slack` | channels:read, chat:write, users:read, channels:join, chat:write.customize | Internal app install by a workspace admin |

Steps for every provider:

1. Create the developer app under the AppsDoc business/account; add the exact
   callback URL above and `https://social.appsdoc.com` as the site/domain.
2. Put the values in `/opt/appsdoc/postiz/shared/app.env` on the server
   (`ssh root@<host>`, edit with `umask 077`; values with `$` must be single-quoted).
3. `make deploy` (or `cd /opt/appsdoc/postiz/current && bash scripts/compose.sh up -d --wait postiz`).
4. In Postiz: **Add Channel** → provider → complete consent. Then create a
   **draft** only; do not publish until you choose to.

Media pull-from-URL: providers fetch uploads from
`https://social.appsdoc.com/uploads/...` (public, verified by `make smoke`).
Cloudflare Free limits a proxied upload request to 100 MB; Postiz v2.26.0 local
storage uploads through the app, so larger videos need R2 storage (see
OPERATIONS.md) — not enabled.

Google login for Postiz users reuses the YouTube OAuth client
(`apps/backend/src/services/auth/providers/google.provider.ts`, redirect
`/integrations/social/youtube`); it is not configured.

Optional paid features (OpenAI, Polotno, video generation, short-link services)
are left unset on purpose. Add `OPENAI_API_KEY` / `NEXT_PUBLIC_POLOTNO` later
only when you decide to pay for them.
