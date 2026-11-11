extends RefCounted
## The playtest server on GitHub (.github/workflows/playtest.yml, «Тестирование» →
## «Тестовый сервер»): `open_page` opens the workflow's page, where «Run workflow» starts
## a server of the test world with bots for two hours; `find` asks GitHub's public API
## for the server running now and its address, which the workflow leaves as the status
## `playtest-link` of the commit it runs (the link of the web build, `?server=wss://…`).

const REPO := "randomboygh/survivium"
const PAGE := "https://github.com/%s/actions/workflows/playtest.yml" % REPO
const API := "https://api.github.com/repos/%s/" % REPO
const CONTEXT := "playtest-link"


static func open_page() -> void:
	OS.shell_open(PAGE)


## Finds the address of the playtest server running now and calls `done` with it
## (`wss://…`), or with "" and why not (a phrase to show) as the second argument.
static func find(host: Node, done: Callable) -> void:
	_fetch(host, API + "actions/workflows/playtest.yml/runs?status=in_progress&per_page=1", func(runs: Variant) -> void:
		var list: Array = runs.get("workflow_runs", []) if runs is Dictionary else []
		if runs == null:
			done.call("", "Нет связи с GitHub")
			return
		if list.is_empty():
			done.call("", "Тестовый сервер не запущен")
			return
		_fetch(host, API + "commits/%s/statuses" % str(list[0].get("head_sha", "")), func(statuses: Variant) -> void:
			var url := ""
			if statuses is Array:
				for s: Variant in statuses:
					if s is Dictionary and s.get("context") == CONTEXT:
						url = address_of(str(s.get("target_url", "")))
						break
			done.call(url, "" if url != "" else "Сервер ещё запускается — попробуйте через минуту")))


## The server's address in a link of the web build (`?server=…`), "" when it has none.
static func address_of(link: String) -> String:
	var at := link.find("server=")
	if at < 0:
		return ""
	return link.substr(at + "server=".length()).get_slice("&", 0).uri_decode()


## GETs `url` and calls `then` with the JSON it gives, or null on any failure.
static func _fetch(host: Node, url: String, then: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	host.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		var data: Variant = null
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			data = JSON.parse_string(body.get_string_from_utf8())
		then.call(data))
	if req.request(url, ["Accept: application/vnd.github+json"]) != OK:
		req.queue_free()
		then.call(null)
