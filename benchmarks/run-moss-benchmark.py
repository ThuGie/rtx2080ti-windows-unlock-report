import json
import pathlib
import time
import urllib.request
import urllib.error
import argparse

ROOT = pathlib.Path(__file__).resolve().parent
BASE = 'http://127.0.0.1:8188'
parser = argparse.ArgumentParser()
parser.add_argument('--label', choices=['baseline', 'unlocked'], default='baseline')
parser.add_argument('--model', choices=['moss', 'zimage'], default='moss')
args = parser.parse_args()
results_path = ROOT / f'{args.model}-{args.label}-results.json'
if results_path.exists():
    raise SystemExit(f'Refusing to overwrite {results_path.name}; archive it before repeating.')

def request(path, data=None):
    payload = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(BASE + path, data=payload, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)

for attempt in range(120):
    try:
        request('/system_stats')
        break
    except (OSError, urllib.error.URLError):
        time.sleep(5)
else:
    raise RuntimeError('ComfyUI did not start within ten minutes')

graph = json.loads((ROOT / f'{args.model}-benchmark-prompt.json').read_text())
graph['50']['inputs']['filename_prefix'] = f'rtx-unlock-benchmark/{args.model}-{args.label}'
results = []
for run in range(3):
    # Changing the seed ensures ComfyUI executes sampling instead of reusing cached output.
    graph['16']['inputs']['seed'] = 208011 + run
    started = time.monotonic()
    try:
        submitted = request('/prompt', {'prompt': graph, 'client_id': 'rtx-unlock-benchmark'})
    except urllib.error.HTTPError as error:
        (ROOT / 'moss-validation-error.json').write_bytes(error.read())
        raise
    prompt_id = submitted['prompt_id']
    print(f'Run {run + 1} submitted: {prompt_id}', flush=True)
    (ROOT / 'moss-active-run.json').write_text(json.dumps({'prompt_id': prompt_id, 'run': run + 1}))
    while True:
        history = request('/history/' + prompt_id)
        if prompt_id in history:
            record = history[prompt_id]
            elapsed = time.monotonic() - started
            results.append({'run': run + 1, 'seed': 208011 + run, 'wall_seconds': elapsed, 'history': record})
            results_path.write_text(json.dumps(results, indent=2))
            print(f'Run {run + 1}: {elapsed:.2f}s, {record.get("status")}', flush=True)
            if record.get('status', {}).get('status_str') == 'error':
                raise RuntimeError('ComfyUI execution failed; see results')
            break
        time.sleep(2)
