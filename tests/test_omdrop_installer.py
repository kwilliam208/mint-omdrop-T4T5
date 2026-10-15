"""omdrop-installer's detect: which mode wins, against a stand-in helper."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SETUP = Path(__file__).resolve().parents[1] / 'tools/omdrop-installer'
STUB = '''#!/bin/bash
case "$1" in
  caps) echo "$CAPS" ;;
  trial) v="TRIAL_${2//-/_}"; echo "${!v}" ;;
esac
'''


def trial(mode, started=True, awdl=True, peers=0, gateway=True, reason=''):
    return json.dumps({'mode': mode, 'started': started, 'awdl': awdl, 'peers': peers,
                       'gateway': gateway, 'reason': reason})


def caps(profile='exclusive', tested=True, ibss=True, active=False):
    return json.dumps({'wifi': True, 'monitor': True, 'ibss': ibss, 'active_monitor': active,
                       'profile': profile, 'tested': tested})


class DetectTests(unittest.TestCase):
    def detect(self, caps_json, **trials):
        with tempfile.TemporaryDirectory() as d:
            helper = Path(d) / 'helper'
            helper.write_text(STUB)
            helper.chmod(0o755)
            env = dict(os.environ, OMDROP_HELPER=str(helper), OMDROP_ELEVATE='env', CAPS=caps_json,
                       PATH='/usr/bin:/bin', HOME=d,
                       **{f'TRIAL_{k}': v for k, v in trials.items()})
            r = subprocess.run([str(SETUP), 'detect', '--json'], env=env, capture_output=True, text=True, timeout=30)
            return r.returncode, json.loads(r.stdout)

    def test_the_mode_that_hears_the_phone_wins(self):
        rc, out = self.detect(caps(), shared=trial('shared', gateway=False), exclusive=trial('exclusive', peers=2))
        self.assertEqual((rc, out['recommended']), (0, 'exclusive'))

    def test_a_tie_goes_to_the_tested_profile(self):
        rc, out = self.detect(caps(), shared=trial('shared'), exclusive=trial('exclusive'))
        self.assertEqual(out['recommended'], 'exclusive')

    def test_a_tie_on_a_new_card_keeps_wifi(self):
        rc, out = self.detect(caps('shared', tested=False), shared=trial('shared'), exclusive=trial('exclusive'))
        self.assertEqual(out['recommended'], 'shared')

    def test_shared_that_cannot_start_loses(self):
        rc, out = self.detect(caps('shared', tested=False),
                              shared=trial('shared', started=False, awdl=False, reason="Wi-Fi isn't connected"),
                              exclusive=trial('exclusive', gateway=False))
        self.assertEqual(out['recommended'], 'exclusive')

    def test_nothing_works(self):
        rc, out = self.detect(caps(), shared=trial('shared', awdl=False), exclusive=trial('exclusive', started=False))
        self.assertNotEqual(rc, 0)
        self.assertEqual(out['recommended'], '')
        self.assertEqual(len(out['results']), 2)

    def test_active_monitor_is_the_single_radio_without_ibss(self):
        rc, out = self.detect(caps(ibss=False, active=True, tested=False),
                              shared=trial('shared', started=False), active_monitor=trial('active-monitor', peers=1))
        self.assertEqual([r['mode'] for r in out['results']], ['shared', 'active-monitor'])
        self.assertEqual(out['recommended'], 'active-monitor')


SOURCE = SETUP.read_text()
LEDGER_FNS = SOURCE[SOURCE.index('# --------------------------------------------------------------------- ledger'):
                    SOURCE.index('# -------------------------------------------------------------------- install')]


class LedgerTests(unittest.TestCase):
    def sh(self, body, d):
        script = 'set -uo pipefail\nsay() { echo "$*"; }\nwifi_iface() { echo wlan0; }\n' + LEDGER_FNS + body
        return subprocess.run(['bash', '-c', script], cwd=d, capture_output=True, text=True, timeout=20)

    def test_claim_records_once_and_keeps_what_was_there(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, 'old').write_text('mine')
            Path(d, 'src').write_text('ours')
            r = self.sh(f'ledger_open {d}/state\nplace 644 {d}/src {d}/old\nplace 644 {d}/src {d}/fresh\n'
                        f'place 644 {d}/src {d}/fresh\ncat {d}/state/ledger', d)
            lines = [l for l in r.stdout.splitlines() if not l.startswith('#')]
            self.assertEqual(lines, [f'saved {d}/old', f'new {d}/fresh'])
            self.assertEqual(Path(d, f'state/backup{d}/old').read_text(), 'mine')
            self.assertEqual(Path(d, 'old').read_text(), 'ours')

    def test_replay_undoes_backwards_within_its_prefix(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, 'old').write_text('mine')
            Path(d, 'src').write_text('ours')
            r = self.sh(f'ledger_open {d}/state\nplace 644 {d}/src {d}/old\nmkdir {d}/dir\nclaim {d}/dir2\n'
                        f'mkdir {d}/dir2\nled "pkg git"\nled "new /etc/elsewhere"\nled ufw\n'
                        f'replay {d}/state/ledger {d}/state/backup {d}\nprintf "%s\\n" "${{REST[@]}}"', d)
            self.assertEqual(Path(d, 'old').read_text(), 'mine')
            self.assertFalse(Path(d, 'dir2').exists())
            self.assertTrue(Path(d, 'dir').exists())
            # Paths outside the prefix are neither touched nor passed on.
            self.assertEqual(r.stdout.splitlines()[-2:], ['ufw', 'pkg git'])

    def test_user_uninstall_puts_home_back(self):
        with tempfile.TemporaryDirectory() as d:
            home, stubs = Path(d, 'home'), Path(d, 'stubs')
            stubs.mkdir()
            for name in ('omdrop', 'gdbus', 'systemctl', 'gtk-update-icon-cache'):
                f = stubs / name
                f.write_text(f'#!/bin/sh\necho "{name} $*" >> {d}/calls\n')
                f.chmod(0o755)
            state = home / '.local/state/omdrop-installer'
            (home / '.config/autostart').mkdir(parents=True)
            Path(home, '.config/autostart/omdrop-tray.desktop').write_text('ours')
            Path(state / 'backup' / str(home)[1:] / '.config/autostart').mkdir(parents=True)
            Path(state / 'backup' / str(home)[1:] / '.config/autostart/omdrop-tray.desktop').write_text('theirs')
            (home / '.local/bin').mkdir(parents=True)
            Path(home, '.local/bin/omdrop-tray').write_text('tray')
            Path(state / 'ledger').write_text(f'# before\nnew {home}/.local/bin/omdrop-tray\n'
                                              f'saved {home}/.config/autostart/omdrop-tray.desktop\n')
            env = dict(os.environ, HOME=str(home), PATH=f'{stubs}:/usr/bin:/bin',
                       OMDROP_STATE=f'{d}/nostate', OMDROP_LIB=f'{d}/nolib', XDG_STATE_HOME='', XDG_DATA_HOME='', XDG_CONFIG_HOME='')
            env = {k: v for k, v in env.items() if v != ''}
            r = subprocess.run([str(SETUP), 'uninstall'], env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertFalse(Path(home, '.local/bin/omdrop-tray').exists())
            self.assertEqual(Path(home, '.config/autostart/omdrop-tray.desktop').read_text(), 'theirs')
            self.assertFalse(state.exists())
            self.assertIn('omdrop off --force', Path(d, 'calls').read_text())


if __name__ == '__main__':
    unittest.main()
