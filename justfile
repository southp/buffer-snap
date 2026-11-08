# BufferSnap dev loop: generate → build → run → test → lint/format, all from the terminal.
# Run `just` to list recipes.

set shell := ["bash", "-euo", "pipefail", "-c"]

# Signing and App Store Connect details for `just deploy`. See .env.example.
set dotenv-load

# Pinned simulator model and runtime, shared by local runs and CI so snapshots stay identical.
# Override via env, e.g. `SIM_DEVICE="iPhone 17" just test`. Each git worktree gets its own device
# of this model ("iPhone 16 (worktree: <dir>)") so parallel agents never share a simulator.
# SIM_OS is the iOS runtime bundled with the pinned Xcode (27.2); bump both together.
# SIM_RUNTIME_BUILD is that runtime's exact build (`xcrun simctl runtime list`): snapshots only match on
# the same build, and it's how to download it (asking for the version can get a device-specific runtime).
SIM_DEVICE := env("SIM_DEVICE", "iPhone 16")
SIM_OS := env("SIM_OS", "27.2")
SIM_RUNTIME_BUILD := env("SIM_RUNTIME_BUILD", "24B8117")

project := "BufferSnap.xcodeproj"
scheme := "BufferSnap"
derived_data := "build/DerivedData"
app_path := derived_data / "Build/Products/Debug-iphonesimulator/BufferSnap.app"
bundle_id := "me.southp.buffersnap"

# List available recipes.
default:
    @just --list

# One-time setup: check Xcode and npx, install missing CLI tools, create the pinned simulator, enable git hooks.
bootstrap: _bootstrap-tools
    #!/usr/bin/env bash
    set -euo pipefail
    # Assign first: a failing $(...) inside echo's arguments wouldn't stop the script.
    sim_name="$(just _sim-name)"
    udid="$(just _sim-udid)"
    echo "✓ simulator ${sim_name} (iOS {{SIM_OS}}): ${udid}"
    git config core.hooksPath .githooks
    echo "✓ git hooks: .githooks"

# The part of bootstrap that needs no simulator: check Xcode and npx, install missing CLI tools.
# CI's fast path runs only this.
_bootstrap-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    dev_dir="$(xcode-select -p 2>/dev/null || true)"
    if [[ "$dev_dir" != *.app/Contents/Developer ]]; then
        echo "error: Xcode is not selected (xcode-select -p: '${dev_dir}')." >&2
        echo "       Run: sudo xcode-select -s /Applications/Xcode.app  (see #8)" >&2
        exit 1
    fi
    for tool in xcodegen swiftlint xcbeautify xcode-build-server; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "✓ $tool"
        else
            echo "→ installing $tool"
            brew install "$tool"
        fi
    done
    # XcodeBuildMCP (.mcp.json) runs through npx, which comes with Node.js.
    if command -v npx >/dev/null 2>&1; then
        echo "✓ npx"
    else
        echo "error: npx is missing; Claude Code needs it to start XcodeBuildMCP (.mcp.json)." >&2
        echo "       Install Node.js 18+, e.g. brew install node" >&2
        exit 1
    fi

# Generate BufferSnap.xcodeproj from project.yml. An unset team stays empty; XcodeGen alone would keep the literal variable.
gen:
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}" xcodegen generate --quiet

# Build the app for the iOS Simulator.
build: gen
    xcodebuild build \
        -project {{project}} \
        -scheme {{scheme}} \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath {{derived_data}} \
        | xcbeautify

# Run the Core package's unit tests on macOS with `swift test` (no simulator, no Xcode project).
test-core:
    swift test --package-path Packages/BufferSnapCore

# Run every test: Core's (test-core), then the app's unit and snapshot tests on the pinned simulator.
test: gen test-core
    #!/usr/bin/env bash
    set -euo pipefail
    udid="$(just _sim-udid)"
    TEST_RUNNER_SNAPSHOT_RECORD="${SNAPSHOT_RECORD:-0}" TEST_RUNNER_SNAPSHOT_ARTIFACTS="{{justfile_directory()}}/build/snapshot-failures" xcodebuild test \
        -project {{project}} \
        -scheme {{scheme}} \
        -destination "id=${udid}" \
        -derivedDataPath {{derived_data}} \
        | xcbeautify

# Build, then install and launch the app on the pinned simulator.
run: build
    #!/usr/bin/env bash
    set -euo pipefail
    udid="$(just _sim-udid)"
    state="$(xcrun simctl list devices -j | jq -r --arg udid "$udid" \
        '.devices[][] | select(.udid == $udid) | .state')"
    if [[ "$state" != "Booted" ]]; then
        xcrun simctl boot "$udid"
    fi
    # Best effort: show the booted device. Xcode ≤26 ships Simulator.app; Xcode 27
    # replaced it with DeviceHub. The app runs either way.
    open -b com.apple.iphonesimulator --args -CurrentDeviceUDID "$udid" 2>/dev/null \
        || open -b com.apple.dt.Devices 2>/dev/null \
        || echo "note: no simulator UI found; the app is running headless" >&2
    xcrun simctl install "$udid" {{app_path}}
    xcrun simctl launch "$udid" {{bundle_id}}

# The phone must be connected, unlocked, in Developer Mode and registered once: README, "Testing on your iPhone".
# Build for the iPhone in DEVICE_ID, install and launch it: a fast loop with development signing, skipping TestFlight.
device:
    #!/usr/bin/env bash
    set -euo pipefail
    missing=()
    for name in DEVICE_ID DEVELOPMENT_TEAM ASC_KEY_ID ASC_ISSUER_ID; do
        if [[ -z "${!name:-}" ]]; then
            missing+=("$name")
        fi
    done
    if [[ "${#missing[@]}" -gt 0 ]]; then
        echo "error: not set: ${missing[*]}. Add to .env (template: .env.example) or the environment." >&2
        echo "       xcrun devicectl list devices shows each phone's identifier." >&2
        exit 1
    fi
    key_path="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
    # dotenv files don't expand "~".
    key_path="${key_path/#\~/$HOME}"
    if [[ ! -f "$key_path" ]]; then
        echo "error: no App Store Connect API key at $key_path. Set ASC_KEY_PATH or see #11." >&2
        exit 1
    fi
    just gen
    xcodebuild build \
        -project {{project}} \
        -scheme {{scheme}} \
        -configuration Debug \
        -destination "id=$DEVICE_ID" \
        -derivedDataPath {{derived_data}} \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$key_path" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
        | xcbeautify
    xcrun devicectl device install app --device "$DEVICE_ID" "{{derived_data}}/Build/Products/Debug-iphoneos/{{scheme}}.app"
    xcrun devicectl device process launch --device "$DEVICE_ID" {{bundle_id}}

# Archive, sign and upload a build to TestFlight. One-time setup: README, "Deploying to TestFlight".
deploy:
    #!/usr/bin/env bash
    set -euo pipefail
    missing=()
    for name in DEVELOPMENT_TEAM ASC_KEY_ID ASC_ISSUER_ID; do
        if [[ -z "${!name:-}" ]]; then
            missing+=("$name")
        fi
    done
    if [[ "${#missing[@]}" -gt 0 ]]; then
        echo "error: not set: ${missing[*]}. Add to .env (template: .env.example) or the environment." >&2
        exit 1
    fi
    key_path="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
    # dotenv files don't expand "~".
    key_path="${key_path/#\~/$HOME}"
    if [[ ! -f "$key_path" ]]; then
        echo "error: no App Store Connect API key at $key_path. Set ASC_KEY_PATH or see #11." >&2
        exit 1
    fi
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "error: the git tree is dirty. Commit or remove your changes, so the build matches a commit:" >&2
        git status --short >&2
        exit 1
    fi
    just gen
    # A UTC timestamp always increases, on any machine, so local and CI builds never clash.
    build_number="$(date -u +%Y%m%d%H%M)"
    auth=(
        -allowProvisioningUpdates
        -authenticationKeyPath "$key_path"
        -authenticationKeyID "$ASC_KEY_ID"
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    )
    mkdir -p build
    # Archive unsigned: signing here would make each fresh CI machine create another development certificate.
    xcodebuild archive \
        -project {{project}} \
        -scheme {{scheme}} \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -derivedDataPath {{derived_data}} \
        -archivePath build/BufferSnap.xcarchive \
        CURRENT_PROJECT_VERSION="$build_number" \
        CODE_SIGNING_ALLOWED=NO \
        | xcbeautify
    # Export reads each target's entitlements from its signature, so ad hoc signatures carry them to the real signing.
    # The linker already signs every binary, so a target missed here would lose its entitlements without any error.
    app=build/BufferSnap.xcarchive/Products/Applications/BufferSnap.app
    for extension in "$app"/PlugIns/*; do
        case "$(basename "$extension")" in
            BufferSnapWidget.appex)
                entitlements=Widget/BufferSnapWidget.entitlements
                ;;
            *)
                echo "error: add $(basename "$extension") and its entitlements to the deploy recipe." >&2
                exit 1
                ;;
        esac
        codesign --force --sign - --entitlements "$entitlements" "$extension"
    done
    codesign --force --sign - --entitlements App/BufferSnap.entitlements "$app"
    plutil -replace teamID -string "$DEVELOPMENT_TEAM" -o build/ExportOptions.plist ExportOptions.plist
    xcodebuild -exportArchive \
        -archivePath build/BufferSnap.xcarchive \
        -exportPath build/export \
        -exportOptionsPlist build/ExportOptions.plist \
        "${auth[@]}" \
        | xcbeautify
    echo "Uploaded build $build_number. It reaches TestFlight once Apple has processed it (about 5-15 minutes)."

# Run the tests in record mode: rewrite every snapshot PNG under AppTests/__Snapshots__/. Read the PNGs before committing.
snapshots-record:
    SNAPSHOT_RECORD=1 just test

# Give editors project context: write buildServer.json for sourcekit-lsp and compile every target once.
lsp: gen
    #!/usr/bin/env bash
    set -euo pipefail
    # xcode-build-server reads compiler flags from the build logs under build_root, so point it
    # at our custom DerivedData rather than Xcode's default ~/Library/Developer/Xcode/DerivedData.
    xcode-build-server config \
        -project {{project}} \
        -scheme {{scheme}} \
        --build_root "{{justfile_directory()}}/{{derived_data}}"
    # build-for-testing compiles the test target too. `just build` only compiles the app,
    # which would leave AppTests/ without flags (no cross-target go-to-definition).
    udid="$(just _sim-udid)"
    xcodebuild build-for-testing \
        -project {{project}} \
        -scheme {{scheme}} \
        -destination "id=${udid}" \
        -derivedDataPath {{derived_data}} \
        | xcbeautify

# Check formatting (swift-format) and lint rules (SwiftLint) on every Swift file; fails on any violation.
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    files=()
    while IFS= read -r -d '' f; do files+=("$f"); done < <(just _swift-files)
    swift format lint --strict "${files[@]}"
    swiftlint lint --strict --quiet "${files[@]}"

# Fix formatting in place on every Swift file, then auto-correct what SwiftLint can.
format:
    #!/usr/bin/env bash
    set -euo pipefail
    files=()
    while IFS= read -r -d '' f; do files+=("$f"); done < <(just _swift-files)
    swift format -i "${files[@]}"
    swiftlint --fix --quiet "${files[@]}"

# Render the app icon's source, docs/design/app-icon.svg, to its PNG in the asset catalog. Needs Google Chrome and ffmpeg.
app-icon:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    { printf '<!doctype html><style>html,body{margin:0}svg{display:block}</style>'; cat docs/design/app-icon.svg; } > "$tmp/icon.html"
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
        --force-device-scale-factor=1 --window-size=1024,1024 --user-data-dir="$tmp/profile" \
        --screenshot="$tmp/icon.png" "file://$tmp/icon.html" > /dev/null 2>&1
    # rgb24 drops the alpha channel, which App Store Connect rejects in an app icon.
    ffmpeg -hide_banner -loglevel error -y -i "$tmp/icon.png" -frames:v 1 -update 1 -pix_fmt rgb24 \
        App/Assets.xcassets/AppIcon.appiconset/AppIcon.png

# App Store screenshots at both sizes App Store Connect takes, into build/store-screenshots/. Needs Google Chrome,
# ffmpeg and AXe. What each one shows and how to upload: docs/app-store/screenshots.md.
store-screenshots: build
    #!/usr/bin/env bash
    set -euo pipefail
    out="build/store-screenshots"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    # The AXe that XcodeBuildMCP bundles (App/CLAUDE.md), or one on the PATH.
    axe="$(find ~/.npm/_npx -path '*xcodebuildmcp/bundled/axe' -type f 2>/dev/null | head -n1 || true)"
    axe="${axe:-$(command -v axe || true)}"
    if [[ -z "$axe" ]]; then
        echo "error: no AXe. Start XcodeBuildMCP once (.mcp.json), or: brew install cameroncooke/axe/axe" >&2
        exit 1
    fi
    for tool in "$chrome" ffmpeg; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "error: $tool is missing." >&2
            exit 1
        fi
    done
    rm -rf "$out"

    # App Store Connect rejects an alpha channel, which simulator and Chrome PNGs carry.
    flatten() {
        ffmpeg -hide_banner -loglevel error -y -i "$1" -frames:v 1 -update 1 -pix_fmt rgb24 "$2"
    }

    # A caption over the snapshot tests' renders, for what the simulator can't show: the Live Activity and the widget.
    # Each render is cropped to what differs from its corner, so only the activity or the widget is kept.
    frame() {
        local width="$1" height="$2" title="$3" subtitle="$4" target="$5"
        shift 5
        local images=""
        while [[ $# -gt 0 ]]; do
            images+="[\"data:image/png;base64,$(base64 < "$1" | tr -d '\n')\",$2],"
            shift 2
        done
        cat > "$tmp/frame.html" <<HTML
    <!doctype html><meta charset="utf-8">
    <style>
    html,body{margin:0;width:${width}px;height:${height}px;overflow:hidden}
    body{box-sizing:border-box;padding:13vh 6vw 0;background:linear-gradient(180deg,#24345f,#0d1222);color:#fff;
      font-family:-apple-system,system-ui,sans-serif;text-align:center;display:flex;flex-direction:column;align-items:center}
    h1{margin:0;font-size:9vw;font-weight:800;letter-spacing:-0.02em;text-wrap:balance}
    p{margin:3vw 0 0;font-size:4.4vw;line-height:1.3;opacity:.8;text-wrap:balance}
    div{margin-top:9vh;width:100%;display:flex;flex-direction:column;align-items:center;gap:6vw}
    canvas{filter:drop-shadow(0 2vw 5vw rgba(0,0,0,.45))}
    </style>
    <h1>${title}</h1><p>${subtitle}</p><div id="shots"></div>
    <script>
    const shots = [${images}];
    const load = (src) => new Promise((done) => { const img = new Image(); img.onload = () => done(img); img.src = src; });
    (async () => {
      for (const [src, percent] of shots) {
        const img = await load(src);
        const full = document.createElement("canvas");
        full.width = img.width; full.height = img.height;
        const ctx = full.getContext("2d"); ctx.drawImage(img, 0, 0);
        const data = ctx.getImageData(0, 0, img.width, img.height), px = data.data;
        // Clear the background from the edges inwards, so white inside the render, such as Stop's label, stays.
        const isBackground = (i) => Math.abs(px[i] - px[0]) + Math.abs(px[i + 1] - px[1]) + Math.abs(px[i + 2] - px[2]) < 45;
        const seen = new Uint8Array(img.width * img.height), queue = [];
        for (let x = 0; x < img.width; x++) { queue.push(x, (img.height - 1) * img.width + x); }
        for (let y = 0; y < img.height; y++) { queue.push(y * img.width, y * img.width + img.width - 1); }
        while (queue.length) {
          const p = queue.pop();
          if (seen[p] || !isBackground(p * 4)) { continue; }
          seen[p] = 1; px[p * 4 + 3] = 0;
          const x = p % img.width;
          if (x > 0) { queue.push(p - 1); }
          if (x < img.width - 1) { queue.push(p + 1); }
          if (p >= img.width) { queue.push(p - img.width); }
          if (p < img.width * (img.height - 1)) { queue.push(p + img.width); }
        }
        ctx.putImageData(data, 0, 0);
        let top = img.height, left = img.width, bottom = 0, right = 0;
        for (let p = 0; p < seen.length; p++) {
          if (!seen[p]) {
            const x = p % img.width, y = (p - x) / img.width;
            top = Math.min(top, y); bottom = Math.max(bottom, y); left = Math.min(left, x); right = Math.max(right, x);
          }
        }
        const w = right - left + 1, h = bottom - top + 1;
        const shown = Math.round(${width} * percent / 100);
        const canvas = document.createElement("canvas");
        canvas.width = shown; canvas.height = Math.round(h * shown / w);
        const out = canvas.getContext("2d");
        out.imageSmoothingQuality = "high";
        out.drawImage(full, left, top, w, h, 0, 0, canvas.width, canvas.height);
        document.getElementById("shots").appendChild(canvas);
      }
    })();
    </script>
    HTML
        "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
            --window-size="${width},${height}" --virtual-time-budget=15000 --user-data-dir="$tmp/profile" \
            --screenshot="$tmp/frame.png" "file://$tmp/frame.html" > /dev/null 2>&1
        flatten "$tmp/frame.png" "$target"
    }

    # Sample captures in the app's store, dated from now: a batch still open, so "Send now" shows, and two sent ones.
    seed() {
        local container="$1" now
        now="$(( $(date +%s) - 978307200 ))"  # JSONEncoder's dates count from 2001.
        cat > "$container/captures-v2.json" <<JSON
    [
      {"id":"6F1C2A10-0000-4000-8000-000000000001","kind":"text","status":"pending","createdAt":$((now - 40)),
       "text":"Hook for Monday: the best ideas show up when your hands are full"},
      {"id":"6F1C2A10-0000-4000-8000-000000000002","kind":"text","status":"pending","createdAt":$((now - 150)),
       "text":"Thread idea: five things I learned shipping an app in two weeks"},
      {"id":"6F1C2A10-0000-4000-8000-000000000003","kind":"text","status":"submitted","createdAt":$((now - 3700)),
       "batchID":"6F1C2A10-0000-4000-8000-0000000000B1",
       "text":"Behind the scenes of today's shoot: the light at 6 a.m. was unreal"},
      {"id":"6F1C2A10-0000-4000-8000-000000000004","kind":"text","status":"submitted","createdAt":$((now - 3900)),
       "batchID":"6F1C2A10-0000-4000-8000-0000000000B1",
       "text":"Poll: do you plan your posts a week ahead, or the morning of?"},
      {"id":"6F1C2A10-0000-4000-8000-000000000005","kind":"text","status":"submitted","createdAt":$((now - 93600)),
       "batchID":"6F1C2A10-0000-4000-8000-0000000000B2",
       "text":"Post idea: the worst tofu I ever had, in the finest restaurant in town"}
    ]
    JSON
    }

    launch() {
        xcrun simctl terminate "$1" {{bundle_id}} 2>/dev/null || true
        # -batchWindow 300 is the standard window, whatever an earlier run chose. English, whatever the Mac's language.
        xcrun simctl launch "$1" {{bundle_id}} -mockAuth signedIn -batchWindow 300 \
            -AppleLanguages "(en-US)" -AppleLocale en_US > /dev/null
        sleep 4
    }

    # A physical tap: SwiftUI's buttons ignore AXe's simulated one (App/CLAUDE.md). Right after a first boot, AXe can time
    # out reaching the simulator, so it tries a few times.
    tap() {
        local attempt
        for attempt in 1 2 3 4 5; do
            if "$axe" tap --label "$2" --element-type Button --tap-style physical --wait-timeout 10 --udid "$1" > /dev/null; then
                return 0
            fi
            echo "  (tapping $2 failed, try $attempt of 5)" >&2
            sleep 5
        done
        return 1
    }

    # The simulator leaves a few black pixels in the top-left corner: cover them with the pixels just to their right.
    shoot() {
        xcrun simctl io "$1" screenshot "$tmp/shot.png" > /dev/null 2>&1
        ffmpeg -hide_banner -loglevel error -y -i "$tmp/shot.png" \
            -filter_complex "split[shot][source];[source]crop=6:6:6:0[patch];[shot][patch]overlay=0:0" \
            -frames:v 1 -update 1 -pix_fmt rgb24 "$2"
    }

    snapshots="AppTests/__Snapshots__"
    # The renders the captions frame. A renamed snapshot test must be renamed here too.
    for render in DictationActivityViewTests/listeningWithWords.listeningWithWords.png \
        DictationActivityViewTests/saved.saved.png WidgetViewTests/dictate.dictate.png; do
        if [[ ! -f "$snapshots/$render" ]]; then
            echo "error: no $snapshots/$render. Point the recipe at the snapshot that replaced it." >&2
            exit 1
        fi
    done
    # App Store Connect's iPhone sizes: 6.9" (iPhone with Dynamic Island, large) and 6.3" (medium), the one it requires.
    for size in "6.9:iPhone 17 Pro Max:1320:2868" "6.3:iPhone 17 Pro:1206:2622"; do
        IFS=: read -r inches model width height <<<"$size"
        dir="$out/$inches-inch"
        mkdir -p "$dir"
        echo "→ $inches\" on $model (${width}×${height})"

        frame "$width" "$height" "Press. Speak. Done." "Your idea goes to Buffer, without opening the app." \
            "$dir/1-dictate.png" \
            "$snapshots/DictationActivityViewTests/listeningWithWords.listeningWithWords.png" 88 \
            "$snapshots/DictationActivityViewTests/saved.saved.png" 88
        frame "$width" "$height" "One press away" "Control Center, the Action button, the Lock Screen or the Home Screen." \
            "$dir/4-widget.png" \
            "$snapshots/WidgetViewTests/dictate.dictate.png" 44

        # Its own simulator per model and worktree, as for tests, so nothing else's state shows.
        udid="$(SIM_DEVICE="$model" just _sim-udid)"
        if [[ "$(xcrun simctl list devices -j | jq -r --arg u "$udid" '.devices[][] | select(.udid == $u) | .state')" != "Booted" ]]; then
            xcrun simctl boot "$udid"
        fi
        xcrun simctl bootstatus "$udid" > /dev/null
        xcrun simctl ui "$udid" appearance light
        # The clock's real time, not 9:41, so it agrees with the list's "Sends at".
        xcrun simctl status_bar "$udid" override --time "$(date +%-I:%M)" --batteryState charged --batteryLevel 100 \
            --cellularBars 4 --wifiBars 3
        xcrun simctl terminate "$udid" {{bundle_id}} 2>/dev/null || true
        xcrun simctl install "$udid" {{app_path}}
        seed "$(xcrun simctl get_app_container "$udid" {{bundle_id}} group.me.southp.buffersnap)"

        launch "$udid"
        shoot "$udid" "$dir/3-capture.png"
        tap "$udid" Captures
        sleep 2
        shoot "$udid" "$dir/2-captures.png"
        tap "$udid" Account
        tap "$udid" Batching
        sleep 2
        shoot "$udid" "$dir/5-batching.png"
        xcrun simctl terminate "$udid" {{bundle_id}} 2>/dev/null || true
    done
    echo "Saved in $out:"
    find "$out" -name '*.png' | sort | while read -r f; do
        echo "  $f ($(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {printf "%s ", $2}'))"
    done

# Print every decision in docs/decisions/ as a table, oldest first.
decisions:
    #!/usr/bin/env bash
    set -euo pipefail
    {
        printf 'DATE\tISSUE\tSTATUS\tDECISION\tFILE\n'
        for f in docs/decisions/[0-9]*.md; do
            awk -v file="$(basename "$f")" '
                /^---$/ { fences++; next }
                fences == 1 && $1 == "date:" { date = $2 }
                fences == 1 && $1 == "issue:" { issue = $2 }
                fences == 1 && $1 == "status:" { status = $2 }
                fences >= 2 && /^# / { sub(/^# /, ""); title = $0; exit }
                END { printf "%s\t#%s\t%s\t%s\t%s\n", date, issue, status, title, file }
            ' "$f"
        done | sort -t $'\t' -k1,1 -k2.2n
    } | column -t -s $'\t'

# Delete per-worktree simulators whose worktree no longer exists.
sims-prune:
    #!/usr/bin/env bash
    set -euo pipefail
    live="$(git worktree list --porcelain | sed -n 's/^worktree //p' | xargs -I{} basename {})"
    xcrun simctl list devices -j \
        | jq -r '.devices[][] | select(.name | test(" \\(worktree: .+\\)$")) | "\(.udid)\t\(.name)"' \
        | while IFS=$'\t' read -r udid name; do
            dir="${name##*(worktree: }"
            dir="${dir%)}"
            if grep -qxF "$dir" <<<"$live"; then
                echo "keep    $name"
            else
                xcrun simctl shutdown "$udid" 2>/dev/null || true
                xcrun simctl delete "$udid"
                echo "deleted $name"
            fi
        done

# Remove build output and the generated Xcode project.
clean:
    rm -rf build {{project}}

# NUL-separated list of every Swift file git tracks or would track (so new, uncommitted files count).
# Gitignored paths like build/ and DerivedData are skipped, and new folders need no justfile edit.
_swift-files:
    #!/usr/bin/env bash
    set -euo pipefail
    found=0
    while IFS= read -r -d '' f; do
        # --cached still lists tracked files deleted from the working tree.
        if [[ -f "$f" ]]; then
            printf '%s\0' "$f"
            found=1
        fi
    done < <(git ls-files -z --cached --others --exclude-standard --deduplicate -- '*.swift')
    # An empty list would make swift-format read stdin and hang.
    if [[ "$found" == 0 ]]; then
        echo "error: no Swift files found" >&2
        exit 1
    fi

# Print this checkout's simulator name: SIM_DEVICE, plus the worktree's folder name in a linked worktree.
_sim-name:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(git rev-parse --path-format=absolute --git-dir)" == "$(git rev-parse --path-format=absolute --git-common-dir)" ]]; then
        echo "{{SIM_DEVICE}}"
    else
        echo "{{SIM_DEVICE}} (worktree: $(basename "$(git rev-parse --show-toplevel)"))"
    fi

# Print the UDID of this checkout's simulator, creating it if missing.
_sim-udid:
    #!/usr/bin/env bash
    set -euo pipefail
    sim_name="$(just _sim-name)"
    runtimes="$(xcrun simctl list runtimes -j)"
    device_type="$(xcrun simctl list devicetypes -j | jq -r --arg name "{{SIM_DEVICE}}" \
        '.devicetypes[] | select(.name == $name) | .identifier')"
    if [[ -z "$device_type" ]]; then
        echo "error: Xcode has no simulator device type named '{{SIM_DEVICE}}'." >&2
        exit 1
    fi
    # The pinned runtime build, if it's installed and runs this device type. Device-specific
    # runtimes (e.g. iOS-27-2-iPhone19-4) only list their own device type, and have their own build.
    runtime_ids="$(jq -r --arg os "{{SIM_OS}}" --arg build "{{SIM_RUNTIME_BUILD}}" --arg type "$device_type" \
        '.runtimes[] | select(.isAvailable and .version == $os and .buildversion == $build)
         | select(any(.supportedDeviceTypes[]; .identifier == $type)) | .identifier' <<<"$runtimes")"
    if [[ -z "$runtime_ids" ]]; then
        echo "error: the pinned iOS {{SIM_OS}} runtime (build {{SIM_RUNTIME_BUILD}}) for '{{SIM_DEVICE}}' isn't installed." >&2
        echo "       Run: xcodebuild -downloadPlatform iOS -buildVersion {{SIM_RUNTIME_BUILD}}" >&2
        exit 1
    fi
    udid="$(xcrun simctl list devices available -j | jq -r --arg name "$sim_name" \
        --argjson runtimes "$(jq -R . <<<"$runtime_ids" | jq -s .)" \
        '[.devices | to_entries[] | select(.key as $k | $runtimes | index($k))
          | .value[] | select(.name == $name) | .udid] | first // empty')"
    if [[ -z "$udid" ]]; then
        runtime="$(head -n1 <<<"$runtime_ids")"
        udid="$(xcrun simctl create "$sim_name" "$device_type" "$runtime")"
        echo "created simulator '$sim_name' on $runtime" >&2
    fi
    echo "$udid"
