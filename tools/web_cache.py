"""Keeps the engine on the device between starts of the web build.

GitHub Pages lets a browser keep a file for ten minutes and then asks it again by a tag
made of the file's time and size. Every deploy writes every file anew, so the engine's
9 MB (38 MB unpacked) came by the network again after each merge, several times a day,
though its bytes change only with an engine upgrade: on the phone that was 2.7 s of the
start's 8.8 (2026-11-01, «Загрузка»: «wasm 9.0 МБ по сети»).

So the engine's files (index.js, index.wasm and the two audio worklets) are named by their
content, `engine-<hash>.*`, and the page asks for them by that name and for the game's pck
by its own (`mainPack`). A new engine is a new name, so a page never runs an old engine
with a new game. The page's own `fetch`, which the engine's loader uses for the wasm, keeps
the wasm in the browser's Cache Storage under its name and answers from there; the other
engines' caches are dropped (KEEPER, set before the engine's script).

The first try (#304) kept it by a service worker: the engine came from the cache, but on
the phone the page itself then came 10 s late (2026-11-01, «страница 10.4»), as every
navigation of the site waited for the worker to start. So there is no worker now:
engine.sw.js stays only as one that removes itself from the phones it was installed on,
and the page unregisters it too.

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
KEEPER = """<script>(function(){'use strict';
// Written by tools/web_cache.py: the engine's wasm is kept in Cache Storage under its name.
var S=window.svStart=window.svStart||{};
if(navigator.serviceWorker){navigator.serviceWorker.getRegistrations().then(function(rs){rs.forEach(function(r){r.unregister();});}).catch(function(){});}
if(!window.caches){return;}
var ENGINE='%s';
caches.keys().then(function(ks){ks.forEach(function(k){if(k.indexOf('engine-')===0&&k!==ENGINE){caches.delete(k);}});}).catch(function(){});
var net=window.fetch.bind(window);
window.fetch=function(input,init){
var url=typeof input==='string'?input:((input&&input.url)||'');
var name=url.split('?')[0].split('/').pop();
if(name!==ENGINE+'.wasm'){return net(input,init);}
return caches.open(ENGINE).then(function(c){return c.match(name).then(function(hit){
if(hit){S.wasm=performance.now();return hit;}
return net(input,init).then(function(r){if(r.ok){c.put(name,r.clone()).catch(function(){});}return r;});
});}).catch(function(){return net(input,init);});
};
})();</script>
"""

# Replaces the worker #304 installed: it unregisters itself and handles no fetch.
WORKER = """'use strict';
// Written by tools/web_cache.py: the engine is no longer kept by a worker (every visit
// waited for it to start); this one removes itself.
self.addEventListener('install', function () {
	self.skipWaiting();
});
self.addEventListener('activate', function (e) {
	e.waitUntil(self.registration.unregister());
});
"""


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
    html = swap(html, '<script src="index.js"></script>', (KEEPER % engine) + '<script src="%s.js"></script>' % engine)
    html = swap(html, '"executable":"index"', '"executable":"%s","mainPack":"index.pck"' % engine)
    html = swap(html, '"index.wasm":', '"%s.wasm":' % engine)
    page.write_text(html, encoding="utf-8")
    (out / SW).write_text(WORKER, encoding="utf-8")
    print("web_cache: the engine is %s" % engine)


if __name__ == "__main__":
    main()
