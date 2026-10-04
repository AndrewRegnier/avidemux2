#!/bin/bash
set -euo pipefail

APP="${1:-}"
[[ -d "$APP/Contents" ]] || { echo "Usage: $0 /path/to/Avidemux\ Mac.app" >&2; exit 2; }
APP="$(cd "$APP" && pwd -P)"
TARGET_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
[[ -n "$TARGET_MACOS" ]] || { echo "Bundle has no LSMinimumSystemVersion." >&2; exit 1; }
if [[ -n "${ADM_MACOSX_DEPLOYMENT_TARGET:-}" && "$ADM_MACOSX_DEPLOYMENT_TARGET" != "$TARGET_MACOS" ]]; then
    echo "ERROR: verifier target $ADM_MACOSX_DEPLOYMENT_TARGET does not match bundle minimum $TARGET_MACOS." >&2
    exit 1
fi

fail() { echo "ERROR: $*" >&2; exit 1; }
inside_bundle() {
    /usr/bin/python3 -c 'import os, sys; root = os.path.realpath(sys.argv[1]); path = os.path.realpath(sys.argv[2]); sys.exit(0 if path == root or path.startswith(root + os.sep) else 1)' "$APP" "$1"
}

echo "Checking bundle: $APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"

mach_count=0
max_major=0
max_minor=0
while IFS= read -r -d '' path; do
    description="$(/usr/bin/file -b "$path")"
    [[ "$description" == *"Mach-O"* ]] || continue
    mach_count=$((mach_count + 1))

    archs="$(/usr/bin/lipo -archs "$path" 2>/dev/null)" || fail "Cannot inspect architectures: $path"
    [[ " $archs " == *" arm64 "* ]] || fail "Missing arm64 slice ($archs): $path"

    rpaths="$(/usr/bin/otool -l "$path" | awk '
        /cmd LC_RPATH/ { want_path = 1; next }
        want_path && /path / { print $2; want_path = 0 }
    ')"
    while IFS= read -r rpath; do
        [[ -z "$rpath" ]] && continue
        case "$rpath" in
            /System/Library/*|/usr/lib/*)
                ;;
            @loader_path/*|@executable_path/*)
                if [[ "$rpath" == @loader_path/* ]]; then
                    rpath_base="$(dirname "$path")"
                    rpath_tail="${rpath#@loader_path/}"
                else
                    rpath_base="$APP/Contents/MacOS"
                    rpath_tail="${rpath#@executable_path/}"
                fi
                candidate="$rpath_base/$rpath_tail"
                [[ -d "$candidate" ]] || fail "Unresolved LC_RPATH in bundle: $path -> $rpath"
                inside_bundle "$candidate" || fail "LC_RPATH escapes the app bundle: $path -> $rpath"
                ;;
            *)
                fail "Unsupported LC_RPATH in bundle: $path -> $rpath"
                ;;
        esac
    done <<< "$rpaths"

    deps="$(/usr/bin/otool -L "$path" | tail -n +2)"
    if /usr/bin/otool -l "$path" | /usr/bin/grep -q 'cmd LC_ID_DYLIB'; then
        # The first entry after the otool header is a dylib's own install ID,
        # not one of its load dependencies.
        deps="$(printf '%s\n' "$deps" | tail -n +2)"
    fi
    while IFS= read -r line; do
        dep="$(printf '%s\n' "$line" | /usr/bin/sed -E 's/^[[:space:]]*([^ ]+).*/\1/')"
        [[ -z "$dep" ]] && continue
        case "$dep" in
            /System/Library/*|/System/iOSSupport/*|/usr/lib/*|@loader_path/*|@executable_path/*|@rpath/*)
                case "$dep" in
                    @loader_path/*)
                        candidate="$(dirname "$path")/${dep#@loader_path/}"
                        [[ -e "$candidate" ]] || fail "Unresolved dependency in bundle: $path -> $dep"
                        inside_bundle "$candidate" || fail "Dependency escapes the app bundle: $path -> $dep"
                        ;;
                    @executable_path/*)
                        candidate="$APP/Contents/MacOS/${dep#@executable_path/}"
                        [[ -e "$candidate" ]] || fail "Unresolved dependency in bundle: $path -> $dep"
                        inside_bundle "$candidate" || fail "Dependency escapes the app bundle: $path -> $dep"
                        ;;
                    @rpath/*)
                        suffix="${dep#@rpath/}"
                        resolved=0
                        while IFS= read -r rpath; do
                            case "$rpath" in
                                /System/Library/*|/usr/lib/*)
                                    [[ -e "$rpath/$suffix" ]] && resolved=1
                                    ;;
                                @loader_path/*)
                                    candidate="$(dirname "$path")/${rpath#@loader_path/}/$suffix"
                                    if [[ -e "$candidate" ]] && inside_bundle "$candidate"; then resolved=1; fi
                                    ;;
                                @executable_path/*)
                                    candidate="$APP/Contents/MacOS/${rpath#@executable_path/}/$suffix"
                                    if [[ -e "$candidate" ]] && inside_bundle "$candidate"; then resolved=1; fi
                                    ;;
                            esac
                        done <<< "$rpaths"
                        if (( resolved == 0 )); then
                            bundled_match="$(find "$APP" -type f -path "*/$suffix" -print -quit)"
                            [[ -n "$bundled_match" ]] && resolved=1
                        fi
                        (( resolved == 1 )) || fail "Unresolved @rpath dependency in bundle: $path -> $dep"
                        ;;
                esac
                ;;
            /*)
                fail "Non-system absolute dependency in bundle: $path -> $dep"
                ;;
            *)
                fail "Unrecognized dependency path in bundle: $path -> $dep"
                ;;
        esac
    done <<< "$deps"

    minos="$(/usr/bin/otool -l "$path" | awk '
        /cmd LC_BUILD_VERSION/ { command = "build"; next }
        /cmd LC_VERSION_MIN_MACOSX/ { command = "legacy"; next }
        command == "build" && /minos / { print $2; exit }
        command == "legacy" && /version / { print $2; exit }
    ')"
    if [[ -n "$minos" ]]; then
        awk -v actual="$minos" -v target="$TARGET_MACOS" 'BEGIN {
            split(actual, a, "."); split(target, t, ".");
            if ((a[1] + 0) > (t[1] + 0) || ((a[1] + 0) == (t[1] + 0) && (a[2] + 0) > (t[2] + 0))) exit 1;
        }' || fail "Dependency requires macOS $minos, above declared $TARGET_MACOS: $path"
        major="${minos%%.*}"
        minor="${minos#*.}"
        minor="${minor%%.*}"
        if (( major > max_major || (major == max_major && minor > max_minor) )); then
            max_major=$major
            max_minor=$minor
        fi
    fi
done < <(find "$APP" -type f -print0)

(( mach_count > 0 )) || fail "No Mach-O files were found in the app bundle."
echo "Verified $mach_count arm64 Mach-O files; highest embedded macOS minimum: ${max_major}.${max_minor}; declared minimum: $TARGET_MACOS."
