"""Seed through Home's deploy API. Never log artifacts, credentials or API bodies."""
import json
import os
from pathlib import Path
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


class SeedError(Exception):
    pass


def run(base_url, artifact, token, timeout=300):
    deadline = time.monotonic() + timeout
    # No proxies or redirects: the deploy token stays on this loopback tunnel.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def request(path, body=None):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise SeedError('Timed out waiting for Home seed operations')
        req = urllib.request.Request(base_url + path, data=body, headers={
            'Authorization': 'Bearer ' + token,
            'Content-Type': 'application/json',
        })
        try:
            with opener.open(req, timeout=min(10, remaining)) as response:
                raw = response.read(1048577)
                if len(raw) > 1048576:
                    raise SeedError('Home response exceeded size limit')
                return response.status, json.loads(raw)
        except urllib.error.HTTPError as error:
            raise SeedError('Home API returned HTTP %d' % error.code) from None
        except (ValueError, UnicodeError):
            raise SeedError('Home returned an invalid JSON response') from None

    # GET may retry while the tunnel starts. POST is sent once: an ambiguous
    # connection failure must not silently resubmit account-writing operations.
    while True:
        try:
            request('/api/v1/health')
            break
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            if time.monotonic() >= deadline:
                raise SeedError('Timed out waiting for Home tunnel') from None
            time.sleep(1)
    if not isinstance(artifact, dict) or set(artifact) - {'roles', 'users', 'apps'}:
        raise SeedError('Invalid seed artifact fields')
    for kind in ('roles', 'users', 'apps'):
        entries = artifact.get(kind, [])
        if not isinstance(entries, list) or not all(isinstance(e, dict) for e in entries):
            raise SeedError('Seed entries must be arrays of objects')
    # Serialize entries and wait between phases. Role/user names can share the
    # app's target-lease namespace; bulk submission can otherwise collide.
    for kind in ('roles', 'users', 'apps'):
        for entry in artifact.get(kind, []):
            status, response = request('/api/v1/seed', json.dumps({kind: [entry]}).encode())
            ids = response.get('operation_ids')
            if status != 202 or not isinstance(ids, list) or not all(isinstance(i, str) and i for i in ids):
                raise SeedError('Invalid seed acceptance response')
            print('Seed accepted: %d operation(s)' % len(ids), flush=True)
            pending = set(ids)
            while pending:
                for operation_id in list(pending):
                    _, operation = request('/api/v1/operations/' + urllib.parse.quote(operation_id, safe=''))
                    outcome = operation.get('outcome')
                    if outcome in ('failed', 'partial_success', 'retry_required'):
                        raise SeedError('Seed operation %s ended with %s; inspect it before retrying' % (operation_id, outcome))
                    if outcome == 'success' and operation.get('ended_at'):
                        pending.remove(operation_id)
                        print('Operation %s succeeded' % operation_id, flush=True)
                if pending:
                    time.sleep(1)
    print('Seed complete', flush=True)


def main():
    try:
        artifact = json.loads(Path('/seed/seed.json').read_text())
        if not isinstance(artifact, dict) or not any(artifact.get(k) for k in ('roles', 'users', 'apps')):
            raise SeedError('Seed artifact must contain roles, users or apps')
        token = Path('/deploy/token').read_text().strip()
        if not token:
            raise SeedError('Deploy credential is empty')
        run('http://127.0.0.1:18090', artifact, token, int(os.environ['SEED_TIMEOUT_SECONDS']))
    except SeedError as error:
        print(str(error), file=sys.stderr)
        return 1
    except Exception:
        print('Seed request failed; inspect operation state before retrying. No credentials or artifact logged.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
