"""The helper's caps, trial and configure, with command doubles, never the real radio."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'userspace/omdrop-discoverable').read_text()
SUPPORT = SOURCE[SOURCE.index('# ------------------------------------------------------------- setup support'):
                 SOURCE.index('case "${1:-}" in')]

STUBS = r'''
set -uo pipefail
die() { echo "omdrop-discoverable: $1" >&2; exit "${2:-2}"; }
log() { :; }
need_root() { :; }
alive() { [ -n "${ALIVE:-}" ]; }
pid_of() { echo 1; }
station_iface() { echo wlan0; }
driver_of() { echo iwlwifi; }
load_profile() { PROF_STATUS=untested PROF_MODE=shared PROF_MONMAC=station PROF_RECONNECT=yes PROF_PM=no; }
visible() { [ -n "${VISIBLE:-}" ]; }
cmd_peers() { [ -n "${PEERS:-}" ] && printf '%s\n' "$PEERS"; true; }
cmd_stop() { echo "stop $1" >> "$CONF/calls"; }
cmd_start() { echo "start $TRIAL_MODE $1" >> "$CONF/calls"; [ -z "${FAIL:-}" ] || die "$FAIL" 3; }
ip() { echo "default via 192.168.1.1 dev eth0"; }
ping() { [ -z "${NOGW:-}" ]; }
sleep() { :; }
'''


class SetupSupportTests(unittest.TestCase):
    def run_sh(self, body, **env):
        with tempfile.TemporaryDirectory() as conf:
            script = STUBS + f'CONF={conf}\n' + SUPPORT + body + f'\ncat {conf}/calls >&2 2>/dev/null; cat {conf}/owl-profiles >&2 2>/dev/null; true'
            r = subprocess.run(['bash', '-c', script], env=dict(os.environ, **env),
                               capture_output=True, text=True, timeout=20)
            return r

    def test_trial_reports_awdl_peers_and_gateway(self):
        r = self.run_sh('cmd_trial exclusive 10', VISIBLE='1', PEERS='aa:bb rssi=?')
        out = json.loads(r.stdout)
        self.assertEqual((out['mode'], out['started'], out['awdl'], out['peers'], out['gateway']),
                         ('exclusive', True, True, 1, True))
        self.assertIn('start exclusive 40', r.stderr)
        self.assertIn('stop trial', r.stderr)

    def test_trial_that_cannot_start_says_why(self):
        r = self.run_sh('cmd_trial shared 10', FAIL='Wi-Fi isn\'t connected')
        out = json.loads(r.stdout)
        self.assertFalse(out['started'])
        self.assertEqual(out['reason'], "Wi-Fi isn't connected")
        self.assertNotIn('stop trial', r.stderr)

    def test_trial_without_the_gateway(self):
        out = json.loads(self.run_sh('cmd_trial exclusive 10', VISIBLE='1', NOGW='1').stdout)
        self.assertEqual((out['awdl'], out['peers'], out['gateway']), (True, 0, False))

    def test_trial_refuses_unknown_modes(self):
        r = self.run_sh('cmd_trial turbo')
        self.assertEqual(r.returncode, 2)

    def test_configure_writes_and_resets_the_card_line(self):
        r = self.run_sh('cmd_configure exclusive')
        self.assertRegex(r.stderr, r'iwlwifi tested exclusive station yes no set by Detect HW')
        r = self.run_sh('cmd_configure exclusive; cmd_configure shared')
        self.assertEqual(r.stderr.count('iwlwifi tested'), 1)
        self.assertIn('iwlwifi tested shared', r.stderr)
        r = self.run_sh('cmd_configure exclusive; cmd_configure reset')
        self.assertNotIn('iwlwifi', r.stderr)


if __name__ == '__main__':
    unittest.main()
