"""Keeps the engine on the device between starts of the web build.

GitHub Pages lets a browser keep a file for ten minutes and then asks it again by a tag
made of the file's time and size. Every deploy writes every file anew, so the engine's
9 MB (38 MB unpacked) came by the network again after each merge, several times a day,
though its bytes change only with an engine upgrade: on the phone that was 2.7 s of the
start's 8.8 (2026-11-01, «Загрузка»: «wasm 9.0 МБ по сети»).

So the engine's files (index.js, index.wasm and the two audio worklets) are named by their
content, `engine-<hash>.*`, the page asks for them by that name and for the game's pck by
its own (`mainPack`), and a service worker (SW, served beside the page) keeps the files of
that name in the browser's Cache Storage and answers from it. A new engine is a new name,
so a page never runs an old engine with a new game; the worker drops the other engines'
caches when it is replaced. The worker is registered once the game has had time to load,
so its first copy of the engine does not compete with the game's own download (it comes
from the browser's HTTP cache then).

Run it after tools/web_patch.py (which changes index.js). It fails when the export's page
is not the one it knows, so an engine upgrade is noticed.

    python3 tools/web_cache.py [build/web]
"""

import hashlib
import sys
from pathlib import Path

# The engine's files the export writes, by their part after "index".
PARTS = [".js", ".wasm", ".audio.worklet.js", ".audio.position.worklet.js"]
SW = "engine.sw.js"
# Seconds after the page's load before the worker is registered.
REGISTER_AFTER = 20

WORKER = """'use strict';
// Written by tools/web_cache.py: keeps the engine's files, named by their content, in the
// browser's Cache Storage. The engine of this build:
const ENGINE = '%s';
const FILES = %s;

self.addEventListener('install', function (e) {
	self.skipWaiting();
	e.waitUntil(caches.open(ENGINE).then(function (c) {
		return c.addAll(FILES);
	}).catch(function () {}));
});

self.addEventListener('activate', function (e) {
	e.waitUntil(caches.keys().then(function (keys) {
		return Promise.all(keys.filter(function (k) {
			return k.indexOf('engine-') === 0 && k !== ENGINE;
		}).map(function (k) {
			return caches.delete(k);
		}));
	}).then(function () {
		return self.clients.claim();
	}));
});

self.addEventListener('fetch', function (e) {
	if (e.request.method !== 'GET') {
		return;
	}
	const name = new URL(e.request.url).pathname.split('/').pop();
	if (!/^engine-[0-9a-f]+\\./.test(name)) {
		return;
	}
	// Each engine's files in a cache of its name: a page of another build asks for its own.
	const engine = name.slice(0, name.indexOf('.'));
	e.respondWith(caches.open(engine).then(function (c) {
		return c.match(e.request, {ignoreSearch: true}).then(function (hit) {
			return hit || fetch(e.request).then(function (r) {
				if (r.ok) {
					c.put(e.request, r.clone());
				}
				return r;
			});
		});
	}));
});
"""

REGISTER = """<script>(function(){'use strict';if(!('serviceWorker' in navigator))return;window.addEventListener('load',function(){setTimeout(function(){navigator.serviceWorker.register('%s').catch(function(){});},%d);});})();</script>"""


def swap(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        sys.exit("web_cache: %r is not once in index.html: the export changed, check tools/web_cache.py" % old)
    return text.replace(old, new)


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    files = [out / ("index" + p) for p in PARTS]
    for f in files:
        if not f.is_file():
            sys.exit("web_cache: no %s" % f)
    digest = hashlib.sha256()
    for f in files:
        digest.update(f.read_bytes())
    engine = "engine-" + digest.hexdigest()[:12]
    for f, p in zip(files, PARTS):
        f.rename(out / (engine + p))

    page = out / "index.html"
    html = page.read_text(encoding="utf-8")
    html = swap(html, '<script src="index.js"></script>', '<script src="%s.js"></script>' % engine)
    html = swap(html, '"executable":"index"', '"executable":"%s","mainPack":"index.pck"' % engine)
    html = swap(html, '"index.wasm":', '"%s.wasm":' % engine)
    html = swap(html, "</body>", REGISTER % (SW, REGISTER_AFTER * 1000) + "\n</body>")
    page.write_text(html, encoding="utf-8")

    names = "[%s]" % ", ".join("'%s%s'" % (engine, p) for p in PARTS)
    (out / SW).write_text(WORKER % (engine, names), encoding="utf-8")
    print("web_cache: the engine is %s, kept by %s" % (engine, SW))


if __name__ == "__main__":
    main()
