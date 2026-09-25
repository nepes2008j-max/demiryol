#!/usr/bin/env bash
# Puts RailSim on GitHub so GitHub's own Windows machine builds railsim.exe.
#
# Nothing is installed on your computer. No Visual Studio, no Flutter-for-
# Windows, no compiler. GitHub has all of that already; it compiles the program
# and hands back a finished .exe, exactly the way every other application you
# download was made.
#
#   ./tools/upload_to_github.sh
#
# It will open a browser once so you can sign in to GitHub. That is the only
# thing it needs from you.
set -euo pipefail
cd "$(dirname "$0")/.."

# KEEP the proxy. This machine reaches the internet only through
# 192.168.1.101:10808 — github.com is refused without it and answers in about
# forty seconds with it. (The proxy is unset for `flutter test`, which talks to
# localhost and breaks when it is set. Opposite needs, same machine.)
export GIT_HTTP_LOW_SPEED_LIMIT=1000
export GIT_HTTP_LOW_SPEED_TIME=300
git config --local http.postBuffer 524288000   # 58 MB push over a slow proxy

REPO=${1:-railsim}
VISIBILITY=${2:---private}

command -v gh >/dev/null || { echo "gh is not installed. apt install gh"; exit 1; }

if ! gh auth status >/dev/null 2>&1; then
  echo
  echo "  Signing in to GitHub. Choose:"
  echo "    GitHub.com  ->  HTTPS  ->  Login with a web browser"
  echo "  Then copy the code it shows you into the browser page it opens."
  echo "  It is slow — the proxy takes about 40 seconds per request. Wait."
  echo
  gh auth login
fi

# Refuse to run anywhere but this project. The Desktop is one big git repo
# holding personal documents, and a push from there would publish them.
root=$(git rev-parse --show-toplevel)
case "$root" in
  */railsim_future) ;;
  *) echo "refusing: this is not the railsim_future repo (got $root)"; exit 1 ;;
esac

git add -A
git diff --cached --quiet || git commit -q -m "Update before publishing"

echo "Creating $REPO ($VISIBILITY) and pushing..."
gh repo create "$REPO" "$VISIBILITY" --source=. --push --remote=origin 2>/dev/null \
  || { git push -u origin HEAD; }

echo
echo "Done. Now:"
echo "  1. gh run watch          # or open the repo's Actions tab"
echo "  2. When it finishes, download the RailSim-windows-x64 artifact."
echo "  3. Unzip it. Inside is railsim.exe — it runs on any Windows PC"
echo "     with nothing installed."
echo
gh repo view --web 2>/dev/null || true
