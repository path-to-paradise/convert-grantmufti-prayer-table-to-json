#!/usr/bin/env bash
# Fetches the current year's prayer times from grandmufti.bg (via this
# project's converter), validates the result, and — only if it looks
# correct — copies it into the Kalendarche-Za-Namaz app and pushes.
#
# Meant to be run once a year (see the crontab entry) shortly after
# January 1st, when the Grand Mufti's office publishes the new
# calendar. The converter has no "year" parameter of its own: it just
# returns whatever year grandmufti.bg is currently serving, so if the
# site hasn't published the new year yet, validation below will still
# pass (the data is just last year's, unchanged) and the "no changes"
# branch will correctly do nothing.

set -uo pipefail

CONVERTER_DIR="$HOME/Projects/convert-grantmufti-prayer-table-to-json"
APP_DIR="$HOME/Projects/Kalendarche-Za-Namaz"
TIME_TABLE_DIR="$APP_DIR/time-table"
LOG_FILE="$CONVERTER_DIR/update-and-deploy.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*" >>"$LOG_FILE"
}

fail() {
    log "FAILED: $*"
    exit 1
}

log "=== Starting yearly prayer time update ==="

cd "$CONVERTER_DIR" || fail "cannot cd into $CONVERTER_DIR"

log "Pulling latest converter code..."
git pull --ff-only >>"$LOG_FILE" 2>&1 || fail "git pull failed in converter repo"

log "Installing dependencies..."
npm install --no-audit --no-fund >>"$LOG_FILE" 2>&1 || fail "npm install failed"

log "Fetching prayer times from grandmufti.bg (this can take a few minutes)..."
rm -rf output
npm start >>"$LOG_FILE" 2>&1 || fail "npm start (converter) failed"

[ -d output ] || fail "no output/ directory was produced"

log "Validating fetched data..."
missing=0
for expected in "$TIME_TABLE_DIR"/*-time.json; do
    city_file=$(basename "$expected")
    if [ ! -f "output/$city_file" ]; then
        log "  missing: $city_file"
        missing=1
    fi
done
[ "$missing" -eq 0 ] || fail "one or more city files are missing from output/"

for file in output/*-time.json; do
    node -e "
        const data = require('$CONVERTER_DIR/$file');
        const months = Object.keys(data);
        if (months.length !== 12) {
            throw new Error('expected 12 months, got ' + months.length);
        }
        const timePattern = /^\\d{1,2}:\\d{2}\$/;
        for (const m of months) {
            const days = Object.keys(data[m]);
            if (days.length < 28) {
                throw new Error('month ' + m + ' has only ' + days.length + ' days');
            }
            for (const d of days) {
                const entry = data[m][d];
                for (const key of ['down', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']) {
                    if (!timePattern.test(entry[key] || '')) {
                        throw new Error('bad time for ' + key + ' on ' + m + '/' + d + ': ' + entry[key]);
                    }
                }
            }
        }
    " >>"$LOG_FILE" 2>&1 || fail "validation failed for $file"
done
log "All city files passed validation."

log "Copying validated files into the app's time-table directory..."
cp output/*-time.json "$TIME_TABLE_DIR/"

cd "$APP_DIR" || fail "cannot cd into $APP_DIR"

if git diff --quiet -- time-table; then
    log "No changes vs. what's already committed (grandmufti.bg is likely still serving last year's calendar). Nothing to do."
    log "=== Done (no update needed) ==="
    exit 0
fi

log "Changes detected, committing and pushing..."
git add time-table
git commit -m "Update prayer time tables for $(date +%Y)" >>"$LOG_FILE" 2>&1 || fail "git commit failed"
git push origin main >>"$LOG_FILE" 2>&1 || fail "git push failed"

log "=== Done: prayer times updated and pushed ==="
