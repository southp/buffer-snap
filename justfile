# BufferSnap dev loop: generate → build → run → test → lint/format, all from the terminal.
# Run `just` to list recipes.

set shell := ["bash", "-euo", "pipefail", "-c"]

# Pinned simulator, shared by local runs and CI so snapshots stay identical.
# Override via env, e.g. `SIM_DEVICE="iPhone 17" just test`.
# SIM_OS is the iOS runtime bundled with the pinned Xcode (27.2); bump both together.
SIM_DEVICE := env("SIM_DEVICE", "iPhone 16")
SIM_OS := env("SIM_OS", "27.2")

# Source folders checked by `lint` and `format`. Later issues append their folders.
# swift-format has no exclude option, so `-r .` would walk build/ and DerivedData.
src_dirs := "App AppTests"

project := "BufferSnap.xcodeproj"
scheme := "BufferSnap"
derived_data := "build/DerivedData"
app_path := derived_data / "Build/Products/Debug-iphonesimulator/BufferSnap.app"
bundle_id := "me.southp.buffersnap"

# List available recipes.
default:
    @just --list

# One-time setup: check Xcode, install missing CLI tools, create the pinned simulator, enable git hooks.
bootstrap:
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
    echo "✓ simulator {{SIM_DEVICE}} (iOS {{SIM_OS}}): $(just _sim-udid)"
    git config core.hooksPath .githooks
    echo "✓ git hooks: .githooks"

# Generate BufferSnap.xcodeproj from project.yml.
gen:
    xcodegen generate --quiet

# Build the app for the iOS Simulator.
build: gen
    xcodebuild build \
        -project {{project}} \
        -scheme {{scheme}} \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath {{derived_data}} \
        | xcbeautify

# Run the unit tests on the pinned simulator.
test: gen
    #!/usr/bin/env bash
    set -euo pipefail
    udid="$(just _sim-udid)"
    xcodebuild test \
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

# Check formatting (swift-format) and lint rules (SwiftLint); fails on any violation.
lint:
    swift format lint --strict -r {{src_dirs}}
    swiftlint --strict --quiet

# Fix formatting in place, then auto-correct what SwiftLint can.
format:
    swift format -i -r {{src_dirs}}
    swiftlint --fix --quiet

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

# Remove build output and the generated Xcode project.
clean:
    rm -rf build {{project}}

# Print the UDID of the pinned simulator, creating it if missing.
_sim-udid:
    #!/usr/bin/env bash
    set -euo pipefail
    runtimes="$(xcrun simctl list runtimes -j)"
    device_type="$(xcrun simctl list devicetypes -j | jq -r --arg name "{{SIM_DEVICE}}" \
        '.devicetypes[] | select(.name == $name) | .identifier')"
    if [[ -z "$device_type" ]]; then
        echo "error: Xcode has no simulator device type named '{{SIM_DEVICE}}'." >&2
        exit 1
    fi
    # Runtimes that run this device type on the pinned iOS version. Device-specific
    # runtimes (e.g. iOS-27-2-iPhone19-4) only list their own device type, so this
    # also picks the general runtime for most devices.
    runtime_ids="$(jq -r --arg os "{{SIM_OS}}" --arg type "$device_type" \
        '.runtimes[] | select(.isAvailable and .version == $os)
         | select(any(.supportedDeviceTypes[]; .identifier == $type)) | .identifier' <<<"$runtimes")"
    if [[ -z "$runtime_ids" ]]; then
        echo "error: no available iOS {{SIM_OS}} runtime supports '{{SIM_DEVICE}}'." >&2
        echo "       Run: xcodebuild -downloadPlatform iOS  (see #8)" >&2
        exit 1
    fi
    udid="$(xcrun simctl list devices available -j | jq -r --arg name "{{SIM_DEVICE}}" \
        --argjson runtimes "$(jq -R . <<<"$runtime_ids" | jq -s .)" \
        '[.devices | to_entries[] | select(.key as $k | $runtimes | index($k))
          | .value[] | select(.name == $name) | .udid] | first // empty')"
    if [[ -z "$udid" ]]; then
        runtime="$(head -n1 <<<"$runtime_ids")"
        udid="$(xcrun simctl create "{{SIM_DEVICE}}" "$device_type" "$runtime")"
        echo "created simulator '{{SIM_DEVICE}}' on $runtime" >&2
    fi
    echo "$udid"
