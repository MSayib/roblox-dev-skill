#!/usr/bin/env python3
"""Run evals from evals/evals.json against the installed skill through Claude Code, headless.

Usage:
    run_evals.py OUT_DIR ID [ID ...] [--parallel N] [--timeout SECONDS]

For each eval it runs, from an empty working directory:

    claude -p "<prompt>" --output-format stream-json --verbose --strict-mcp-config
           --allowedTools Skill,Read,Glob,Grep --disallowedTools Bash,Edit,Write

--strict-mcp-config with no config loads NO MCP servers, so an eval can never reach a Roblox Studio
you have open; only read tools are allowed, so it cannot change files. It records whether the skill
was invoked, which reference files were read, the final answer, and the cost, in OUT_DIR/<id>.json,
and prints a table. Grading the answer against the eval's `notes` is a judgement call and is left to
the reader (or another model); trigger accuracy is checked here.
"""
import concurrent.futures, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
EVALS = os.path.join(HERE, '..', '..', 'evals', 'evals.json')
SKILL = 'roblox-dev-skill'


def run_one(ev, out_dir, timeout):
    work = tempfile.mkdtemp(prefix=f'eval{ev["id"]}-')
    cmd = ['claude', '-p', ev['prompt'], '--output-format', 'stream-json', '--verbose',
           '--strict-mcp-config', '--allowedTools', 'Skill,Read,Glob,Grep',
           '--disallowedTools', 'Bash,Edit,Write']
    rec = dict(id=ev['id'], prompt=ev['prompt'], should_trigger=ev.get('should_trigger', True),
               expected_references=ev.get('expected_references', []), notes=ev.get('notes', ''),
               triggered=False, references_read=[], answer='', cost_usd=None, error=None)
    try:
        proc = subprocess.run(cmd, cwd=work, capture_output=True, text=True, timeout=timeout)
        for line in proc.stdout.splitlines():
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get('type') == 'assistant':
                for block in e.get('message', {}).get('content', []):
                    if block.get('type') != 'tool_use':
                        continue
                    inp = block.get('input', {})
                    if block.get('name') == 'Skill' and SKILL in str(inp.get('skill', '')):
                        rec['triggered'] = True
                    if block.get('name') == 'Read':
                        path = str(inp.get('file_path', ''))
                        if '/references/' in path:
                            rec['references_read'].append(os.path.basename(path))
            elif e.get('type') == 'result':
                rec['answer'] = e.get('result') or ''
                rec['cost_usd'] = e.get('total_cost_usd')
        if proc.returncode != 0 and not rec['answer']:
            rec['error'] = (proc.stderr or '')[-500:]
    except subprocess.TimeoutExpired:
        rec['error'] = f'timeout after {timeout}s'
    with open(os.path.join(out_dir, f'{ev["id"]}.json'), 'w', encoding='utf-8') as f:
        json.dump(rec, f, indent=1, ensure_ascii=False)
    return rec


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    out_dir = argv[0]
    opt = lambda k, d: int(argv[argv.index(k) + 1]) if k in argv else d
    parallel, timeout = opt('--parallel', 3), opt('--timeout', 600)
    skip = {argv[argv.index(k) + 1] for k in ('--parallel', '--timeout') if k in argv}
    ids = {int(a) for a in argv[1:] if a.isdigit() and a not in skip}
    os.makedirs(out_dir, exist_ok=True)
    evals = [e for e in json.load(open(EVALS, encoding='utf-8'))['evals'] if e['id'] in ids]
    with concurrent.futures.ThreadPoolExecutor(parallel) as pool:
        results = list(pool.map(lambda e: run_one(e, out_dir, timeout), evals))
    total = 0.0
    print(f'{"id":>3}  {"trigger":<16} {"refs read":<55} cost')
    for r in sorted(results, key=lambda r: r['id']):
        ok = r['triggered'] == r['should_trigger']
        trig = ('ok ' if ok else 'BAD ') + ('triggered' if r['triggered'] else 'not triggered')
        refs = ','.join(sorted(set(r['references_read'])))[:55]
        total += r['cost_usd'] or 0
        print(f'{r["id"]:>3}  {trig:<16} {refs:<55} {r["cost_usd"] or 0:.2f}' + (f'  ERROR {r["error"][:60]}' if r['error'] else ''))
    print(f'total cost ${total:.2f}; answers in {out_dir}/<id>.json')
    return 0 if all(r['triggered'] == r['should_trigger'] and not r['error'] for r in results) else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
