// Локальные уведомления (UNUserNotificationCenter) для Harvest Hollow: плагин Godot для iOS.
// Собирается вместе с godot-ios-plugins (tools/build_ios_plugins.sh), синглтон LocalNotify.
#ifndef LOCALNOTIFY_H
#define LOCALNOTIFY_H

#include "core/object/class_db.h"

class LocalNotify : public Object {
	GDCLASS(LocalNotify, Object);

	static LocalNotify *instance;
	static void _bind_methods();

	// -1 - ещё не знаем, 0 - не спрашивали, 1 - разрешено, 2 - запрещено
	int status = -1;

public:
	void refresh_status();
	int get_status();
	void request_permission();
	void schedule(String p_id, String p_title, String p_body, int p_seconds);
	void cancel_all();

	static LocalNotify *get_singleton();

	LocalNotify();
	~LocalNotify();
};

#endif
