#!/bin/sh
set -e

# Parse configuration
server_repo=$(cat /data/options.json | jq -r .server_repo)

echo ""
echo "-----------------------------------------------------------"
echo "Music Assistant BETA Add-on (from source)"
echo "-----------------------------------------------------------"
echo ""

# Check if server_repo is empty or null
if [ -z "$server_repo" ] || [ "$server_repo" = "null" ]; then
    build_from_source=false
    echo "No server_repo specified - using latest beta release from GitHub"
else
    build_from_source=true
    echo "Building from source using server_repo: $server_repo"
fi
echo ""

# Function to parse repository reference and return owner/repo@ref
parse_repo_ref() {
    local input="$1"
    local default_owner="$2"
    local default_repo="$3"

    # If input starts with "pr-", convert to pull request reference
    if echo "$input" | grep -q "^pr-"; then
        pr_number=$(echo "$input" | sed 's/pr-//')
        echo "${default_owner}/${default_repo}@refs/pull/${pr_number}/head"
        return
    fi

    # If input contains "/" (fork reference)
    if echo "$input" | grep -q "/"; then
        # Check if it already has @ for branch
        if echo "$input" | grep -q "@"; then
            echo "$input"
        else
            # It's just owner/repo, use default branch
            echo "${input}@main"
        fi
        return
    fi

    # Otherwise, it's just a branch/commit reference
    echo "${default_owner}/${default_repo}@${input}"
}

# Function to build git URL from parsed reference
build_git_url() {
    local parsed="$1"
    echo "git+https://github.com/${parsed}"
}

# Activate virtual environment
. $VIRTUAL_ENV/bin/activate

echo "-----------------------------------------------------------"
echo "Step 1: Installing Music Assistant Server"
echo "-----------------------------------------------------------"
echo ""

if [ "$build_from_source" = true ]; then
    # Parse server repository reference
    server_ref=$(parse_repo_ref "$server_repo" "music-assistant" "server")
    server_url=$(build_git_url "$server_ref")

    echo "Server repository: $server_ref"
    echo "Server URL: $server_url"
    echo ""

    # Build requirements URL from the same reference
    req_owner=$(echo "$server_ref" | cut -d'/' -f1)
    req_repo=$(echo "$server_ref" | cut -d'/' -f2 | cut -d'@' -f1)
    req_ref=$(echo "$server_ref" | cut -d'@' -f2)
    requirements_url="https://raw.githubusercontent.com/${req_owner}/${req_repo}/${req_ref}/requirements_all.txt"

    echo "Installing dependencies from: $requirements_url"
    echo ""

    # Install dependencies from the branch's requirements_all.txt
    uv pip install \
        --no-cache \
        --link-mode=copy \
        -r "$requirements_url"

    echo "✓ Dependencies installed"
    echo ""

    # Install server from specified repository
    uv pip install \
        --no-cache \
        --link-mode=copy \
        "$server_url"
else
    # Install latest beta release from GitHub
    echo "Fetching latest beta release from GitHub..."
    echo ""

    tmp_releases="/tmp/releases.json"
    curl -s "https://api.github.com/repos/music-assistant/server/releases?per_page=30" > "$tmp_releases"
    # Find the latest release with a beta tag (contains "b" in the version, e.g. 2.8.0b12)
    release_tag=$(jq -r '[.[] | select(.tag_name | test("b[0-9]+$"))] | first | .tag_name' < "$tmp_releases")
    wheel_url=$(jq -r --arg tag "$release_tag" '[.[] | select(.tag_name == $tag)] | first | .assets[] | select(.name | endswith(".whl")) | .browser_download_url' < "$tmp_releases")
    rm -f "$tmp_releases"

    if [ -z "$wheel_url" ] || [ "$wheel_url" = "null" ]; then
        echo "ERROR: Could not find wheel in latest beta release"
        echo "Falling back to stable PyPI release..."
        uv pip install \
            --no-cache \
            --link-mode=copy \
            music-assistant
    else
        echo "Found beta release: $release_tag"
        echo "Wheel URL: $wheel_url"
        echo ""
        echo "Downloading and installing beta wheel..."
        uv pip install \
            --no-cache \
            --link-mode=copy \
            "$wheel_url"
    fi
fi

echo ""
echo "✓ Server installation complete"
echo ""

echo "-----------------------------------------------------------"
echo "Starting Music Assistant"
echo "-----------------------------------------------------------"
echo ""

# export jemalloc path
for path in /usr/lib/*/libjemalloc.so.2; do
    [ -f "$path" ] && export LD_PRELOAD="$path" && break
done
# Start Music Assistant
exec mass --data-dir /data --cache-dir /data/.cache
