class_name HttpPool
extends Node
## Запросы к серверу по постоянным соединениям (keep-alive). HTTPRequest на каждый вызов заново открывает
## TCP и TLS - это 2-3 лишних круга до сервера, на телефоне полсекунды и больше. Здесь соединения живут
## и переиспользуются: вызов альянса - один круг. Если старое соединение сервер уже закрыл, запрос
## повторяется на новом.

const MAX_IDLE := 4
const TIMEOUT_MS := 10000

var host := ""
var port := 443
var tls := true
var _idle: Array = []


## Хост из адреса вида https://xxx.supabase.co.
func setup(url: String) -> void:
	var u := url.strip_edges()
	tls = u.begins_with("https://")
	u = u.trim_prefix("https://").trim_prefix("http://")
	var slash := u.find("/")
	if slash >= 0:
		u = u.left(slash)
	var colon := u.find(":")
	if colon >= 0:
		port = int(u.substr(colon + 1))
		u = u.left(colon)
	else:
		port = 443 if tls else 80
	host = u


## POST. Возвращает [ok: bool, код ответа, текст ответа]. ok = false - нет связи.
func post(path: String, headers: PackedStringArray, body: String) -> Array:
	for attempt in 2:
		var c: HTTPClient = _idle.pop_back() if not _idle.is_empty() else null
		var reused := c != null
		if c != null:
			c.poll()
		if c == null or c.get_status() != HTTPClient.STATUS_CONNECTED:
			if c != null:
				c.close()
			reused = false
			c = await _connect()
			if c == null:
				return [false, 0, ""]
		var res: Array = await _send(c, path, headers, body)
		if bool(res[0]):
			return res
		c.close()
		# Сервер закрыл старое соединение до ответа - пробуем на свежем. Ответ уже начал приходить -
		# не повторяем (вызов мог выполниться), иначе это правда нет сети
		if not reused or res.size() > 3:
			return res.slice(0, 3)
	return [false, 0, ""]


func _connect() -> HTTPClient:
	var c := HTTPClient.new()
	if c.connect_to_host(host, port, TLSOptions.client() if tls else null) != OK:
		return null
	var start := Time.get_ticks_msec()
	while c.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		c.poll()
		if Time.get_ticks_msec() - start > TIMEOUT_MS:
			c.close()
			return null
		await get_tree().process_frame
	if c.get_status() != HTTPClient.STATUS_CONNECTED:
		c.close()
		return null
	return c


func _send(c: HTTPClient, path: String, headers: PackedStringArray, body: String) -> Array:
	var h := headers.duplicate()
	h.append("Connection: keep-alive")
	if c.request(HTTPClient.METHOD_POST, path, h, body) != OK:
		return [false, 0, ""]
	var start := Time.get_ticks_msec()
	while c.get_status() == HTTPClient.STATUS_REQUESTING:
		c.poll()
		if Time.get_ticks_msec() - start > TIMEOUT_MS:
			return [false, 0, ""]
		if c.get_status() == HTTPClient.STATUS_REQUESTING:
			await get_tree().process_frame
	if not c.get_status() in [HTTPClient.STATUS_BODY, HTTPClient.STATUS_CONNECTED] or not c.has_response():
		return [false, 0, ""]
	var code := c.get_response_code()
	var bytes := PackedByteArray()
	while c.get_status() == HTTPClient.STATUS_BODY:
		c.poll()
		var chunk := c.read_response_body_chunk()
		if chunk.is_empty():
			if Time.get_ticks_msec() - start > TIMEOUT_MS:
				return [false, 0, "", "answered"]
			await get_tree().process_frame
		else:
			bytes.append_array(chunk)
	if c.get_status() == HTTPClient.STATUS_CONNECTED and _idle.size() < MAX_IDLE:
		_idle.append(c)
	else:
		c.close()
	return [true, code, bytes.get_string_from_utf8()]
