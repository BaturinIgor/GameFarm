#include "localnotify_module.h"

#include "core/config/engine.h"

#include "localnotify.h"

LocalNotify *localnotify;

void register_localnotify_types() {
	localnotify = memnew(LocalNotify);
	Engine::get_singleton()->add_singleton(Engine::Singleton("LocalNotify", localnotify));
}

void unregister_localnotify_types() {
	if (localnotify) {
		memdelete(localnotify);
	}
}
