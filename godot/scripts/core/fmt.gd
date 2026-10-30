class_name Fmt
## Форматирование чисел, процентов и времени.


## Число с разделителями разрядов; большие числа сокращаются.
static func n(value: int) -> String:
	var a := absi(value)
	if a >= 1_000_000_000:
		return _short(value / 1_000_000_000.0) + "B"
	if a >= 1_000_000:
		return _short(value / 1_000_000.0) + "M"
	if a >= 100_000:
		return _short(value / 1000.0) + "K"
	return grouped(value)


## Короткая запись для шапки: с 10 000 - "12.3K", "1.2M".
static func compact(value: int) -> String:
	var a := absi(value)
	if a >= 10_000 and a < 100_000:
		return _short(floor(value / 100.0) / 10.0) + "K"
	return n(value)


static func _short(v: float) -> String:
	var s := "%.1f" % v
	if s.ends_with(".0"):
		s = s.substr(0, s.length() - 2)
	return s


static func grouped(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if value < 0 else "") + s + out


static func pct(v: float) -> String:
	var p := v * 100.0
	if absf(p - round(p)) < 0.05:
		return "%d%%" % int(round(p))
	return "%.1f%%" % p


static func seconds(s: float) -> String:
	if s < 60.0:
		return L.t("time.sec", [int(round(s))])
	var m := int(s / 60.0)
	if m < 60:
		return L.t("time.min", [m])
	var h := m / 60
	var rest := m % 60
	return L.t("time.hour", [h]) if rest == 0 else L.t("time.hourMin", [h, rest])
