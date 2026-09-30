extends RefCounted

## Every external address and tunable the app depends on, in one place.
## Moving hosting (a new repo, a new release tag for packs, a new Supabase
## project) should only ever mean editing this file.
##
## tools/hub.py reads the GITHUB_* and PACK_RELEASE_TAG constants below with a
## simple regex, so keep them as plain `const NAME := "value"` lines.

const GITHUB_OWNER := "voodoo-nicolas"
const GITHUB_REPO := "voodoo-game-hub"
const GITHUB_BRANCH := "master"
## GitHub release that hosts every game's .pck.
const PACK_RELEASE_TAG := "packs-v1"

const REPO_URL := "https://github.com/" + GITHUB_OWNER + "/" + GITHUB_REPO
const RELEASES_PAGE_URL := REPO_URL + "/releases/latest"
const LATEST_RELEASE_API := "https://api.github.com/repos/" + GITHUB_OWNER + "/" + GITHUB_REPO + "/releases/latest"
const MANIFEST_URL := "https://raw.githubusercontent.com/" + GITHUB_OWNER + "/" + GITHUB_REPO + "/" + GITHUB_BRANCH + "/manifest.json"
## Fallback when a manifest entry has no "url" of its own.
const PACK_BASE_URL := REPO_URL + "/releases/download/" + PACK_RELEASE_TAG + "/"

## Publishable/anon key only -- safe to ship, it grants nothing beyond what the
## project's Row Level Security allows. Never put the service_role key here.
const SUPABASE_URL := "https://swyzfsyvmqxabhvvhhtn.supabase.co"
const SUPABASE_ANON_KEY := "sb_publishable_uyB6Ssw-KTcOAAB-QJCRDQ_sTNfPuhT"

## Seconds before a small JSON request (manifest, update check, auth) gives up.
## Without a timeout, HTTPRequest waits forever on a dead connection.
const HTTP_TIMEOUT := 10.0
## Seconds a download may go without the transfer finishing. Generous on
## purpose: slow mobile data is fine, a connection that died is not.
const DOWNLOAD_TIMEOUT := 180.0
## How long a fetched manifest is trusted before a tile tap refetches it.
const MANIFEST_MAX_AGE_SEC := 300
