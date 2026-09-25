#!/usr/bin/env python3
"""Split a Roblox Full-API-Dump.json into per-class and per-enum files plus light indexes.

Replaces the original jq-based split-api-dump.sh, which spawned three jq processes per class
(~2,800 for 924 classes) and required jq to be installed. This does the same work in one pass
with only the Python standard library, and produces the same layout:

    RobloxAPI/classes/<Name>.json      every class
    RobloxAPI/services/<Name>.json     classes whose name ends in "Service"
    RobloxAPI/deprecated/<Name>.json   classes tagged Deprecated
    RobloxAPI/enums/<Name>.json        every enum
    RobloxAPI/class-index.json         [{name, super, tags, memberCount}]
    RobloxAPI/enum-index.json          [{name, itemCount}]
    RobloxAPI/service-index.json       sorted service names
    RobloxAPI/deprecated-index.json    {classes: [...], members: [{class, name, type}]}

Usage: split-api-dump.py [DUMP] [--root DIR]
"""
import json, os, sys, glob

def string_tags(obj):
    return [t for t in (obj.get('Tags') or []) if isinstance(t, str)]

def write_json(path, data):
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')
    os.replace(tmp, path)

def main(argv):
    root = os.environ.get('ROBLOX_DOCS_HOME', os.path.expanduser('~/RobloxDocs'))
    dump = None
    i = 0
    while i < len(argv):
        if argv[i] == '--root':
            root = argv[i + 1]; i += 2; continue
        dump = argv[i]; i += 1
    api = os.path.join(root, 'RobloxAPI')
    dump = dump or os.path.join(api, 'dumps', 'latest.json')
    if not os.path.exists(dump):
        sys.exit(f"Error: dump file not found: {dump}")

    print(f"Splitting {os.path.basename(os.path.realpath(dump))}...")
    with open(dump, encoding='utf-8') as f:
        data = json.load(f)
    classes, enums = data.get('Classes', []), data.get('Enums', [])

    dirs = {k: os.path.join(api, k) for k in ('classes', 'enums', 'services', 'deprecated')}
    for d in dirs.values():
        os.makedirs(d, exist_ok=True)
        for old in glob.glob(os.path.join(d, '*.json')):
            os.remove(old)

    print(f"Processing {len(classes)} classes...")
    for c in classes:
        name = c['Name']
        write_json(os.path.join(dirs['classes'], f'{name}.json'), c)
        if name.endswith('Service'):
            write_json(os.path.join(dirs['services'], f'{name}.json'), c)
        if 'Deprecated' in string_tags(c):
            write_json(os.path.join(dirs['deprecated'], f'{name}.json'), c)

    print(f"Processing {len(enums)} enums...")
    for e in enums:
        write_json(os.path.join(dirs['enums'], f"{e['Name']}.json"), e)

    print("Generating indexes...")
    write_json(os.path.join(api, 'class-index.json'),
               [{'name': c['Name'], 'super': c.get('Superclass'), 'tags': string_tags(c),
                 'memberCount': len(c.get('Members') or [])} for c in classes])
    write_json(os.path.join(api, 'enum-index.json'),
               [{'name': e['Name'], 'itemCount': len(e.get('Items') or [])} for e in enums])
    write_json(os.path.join(api, 'service-index.json'),
               sorted(c['Name'] for c in classes if c['Name'].endswith('Service')))
    write_json(os.path.join(api, 'deprecated-index.json'), {
        'classes': [c['Name'] for c in classes if 'Deprecated' in string_tags(c)],
        'members': [{'class': c['Name'], 'name': m['Name'], 'type': m.get('MemberType')}
                    for c in classes for m in (c.get('Members') or [])
                    if 'Deprecated' in string_tags(m)],
    })

    def count(k):
        return len(glob.glob(os.path.join(dirs[k], '*.json')))
    print()
    print("✅ Split complete:")
    print(f"   Classes: {count('classes')} files")
    print(f"   Enums:   {count('enums')} files")
    print(f"   Services: {count('services')} files")
    print(f"   Deprecated: {count('deprecated')} files")
    print("   Indexes: class-index.json, enum-index.json, service-index.json, deprecated-index.json")
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
