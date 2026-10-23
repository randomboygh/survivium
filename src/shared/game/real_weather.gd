extends Node
## The weather of the real world, when the setting asks for it: finds roughly where the
## device is by its IP address, asks Open-Meteo for the weather there now every
## REFRESH seconds and pins the clock's weather and wind to it (Clock.set_real_weather).
## Without the network, or when it is off, the clock's own weather goes on. On a server
## it will run the same, for everyone.

const IP_SERVICES := ["https://ipapi.co/json/", "https://ipwho.is/"]
const FORECAST := "https://api.open-meteo.com/v1/forecast?latitude=%.2f&longitude=%.2f&current=weather_code,wind_speed_10m,wind_direction_10m&wind_speed_unit=ms"
const REFRESH := 1800.0
## Tries again this soon after a failed request.
const RETRY := 120.0

## The clock whose weather this pins.
var clock
var enabled := false:
	set(on):
		if on == enabled:
			return
		enabled = on
		_wait = 0.0
		if not on and clock != null:
			clock.clear_real_weather()
## Where the weather is taken: a place name and its latitude and longitude, found once.
var place := ""
var at := Vector2.INF
## What the last answer said, for the settings page: "" until there is one.
var status := ""
var _http: HTTPRequest
var _ip_try := 0
var _wait := 0.0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.request_completed.connect(_on_answer)
	add_child(_http)


func _process(delta: float) -> void:
	if not enabled or _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = RETRY
	var url: String = IP_SERVICES[_ip_try % IP_SERVICES.size()] if at == Vector2.INF else FORECAST % [at.x, at.y]
	if _http.request(url) != OK:
		_failed()


func _on_answer(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not enabled:
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
	if not (data is Dictionary):
		if at == Vector2.INF:
			_ip_try += 1
		_failed()
		return
	if at == Vector2.INF:
		if not (data.has("latitude") and data.has("longitude")):
			_ip_try += 1
			_failed()
			return
		at = Vector2(float(data.latitude), float(data.longitude))
		place = str(data.get("city", ""))
		_wait = 0.0
		return
	if not apply(data):
		_failed()
		return
	_wait = REFRESH


## Pins the clock to an Open-Meteo answer `data`; false when it has no current weather.
func apply(data: Dictionary) -> bool:
	var now: Variant = data.get("current")
	if not (now is Dictionary) or not now.has("weather_code"):
		return false
	clock.set_real_weather(int(now.weather_code), float(now.get("wind_speed_10m", 0.0)),
		float(now.get("wind_direction_10m", 0.0)))
	status = "%s, %s" % [place if place != "" else "рядом", clock.WEATHERS[clock.weather].name.to_lower()]
	print("real weather: %s (code %d)" % [status, int(now.weather_code)])
	return true


## No answer: the last real weather stays (or the clock's own goes on) until the
## next try.
func _failed() -> void:
	status = "нет связи"
