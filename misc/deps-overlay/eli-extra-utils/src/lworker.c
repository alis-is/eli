#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "c11threads.h"

#include <errno.h>
#include <stdlib.h>
#include <string.h>

#define ELI_WORKER_TASK_METATABLE "ELI_WORKER_TASK"
#define ELI_WORKER_CHANNEL_METATABLE "ELI_WORKER_CHANNEL"

typedef struct worker_channel worker_channel;
typedef struct worker_value worker_value;

typedef enum worker_value_type {
	WORKER_VALUE_NIL = 0,
	WORKER_VALUE_BOOLEAN,
	WORKER_VALUE_NUMBER,
	WORKER_VALUE_STRING,
	WORKER_VALUE_TABLE,
	WORKER_VALUE_CHANNEL,
} worker_value_type;

typedef struct worker_table_entry {
	worker_value *key;
	worker_value *value;
} worker_table_entry;

struct worker_value {
	worker_value_type type;
	union {
		int boolean_value;
		lua_Number number_value;
		struct {
			char *data;
			size_t length;
		} string_value;
		struct {
			worker_table_entry *entries;
			size_t length;
		} table_value;
		worker_channel *channel_value;
	} as;
};

typedef struct worker_message {
	worker_value value;
	struct worker_message *next;
} worker_message;

struct worker_channel {
	mtx_t mutex;
	cnd_t recv_cond;
	size_t refs;
	int closed;
	worker_message *head;
	worker_message *tail;
};

typedef struct worker_channel_ref {
	worker_channel *channel;
} worker_channel_ref;

typedef struct worker_task {
	thrd_t thread;
	mtx_t mutex;
	cnd_t done_cond;
	int started;
	int joined;
	int done;
	int mutex_ready;
	int done_cond_ready;
	char *error;
	worker_value *results;
	size_t result_count;
} worker_task;

typedef struct worker_visited_tables {
	const void **items;
	size_t count;
	size_t capacity;
} worker_visited_tables;

typedef struct worker_thread_context {
	worker_task *task;
	char *code;
	size_t code_length;
	size_t arg_count;
	worker_value *args;
} worker_thread_context;

static void worker_free_value(worker_value *value);
static int worker_push_value(lua_State *L, const worker_value *value);
static int worker_ensure_channel_metatable(lua_State *L);
int luaopen_eli_worker_extra(lua_State *L);

static char *worker_strdup_n(const char *value, size_t length)
{
	char *copy = (char *)malloc(length + 1);
	if (copy == NULL) {
		return NULL;
	}
	memcpy(copy, value, length);
	copy[length] = '\0';
	return copy;
}

static char *worker_strdup(const char *value)
{
	if (value == NULL) {
		return worker_strdup_n("", 0);
	}
	return worker_strdup_n(value, strlen(value));
}

static void worker_channel_retain(worker_channel *channel)
{
	if (channel == NULL) {
		return;
	}
	mtx_lock(&channel->mutex);
	channel->refs++;
	mtx_unlock(&channel->mutex);
}

static void worker_channel_release(worker_channel *channel)
{
	int should_destroy = 0;
	worker_message *message;

	if (channel == NULL) {
		return;
	}

	mtx_lock(&channel->mutex);
	if (channel->refs > 0) {
		channel->refs--;
	}
	should_destroy = channel->refs == 0;
	mtx_unlock(&channel->mutex);

	if (!should_destroy) {
		return;
	}

	message = channel->head;
	while (message != NULL) {
		worker_message *next = message->next;
		worker_free_value(&message->value);
		free(message);
		message = next;
	}

	cnd_destroy(&channel->recv_cond);
	mtx_destroy(&channel->mutex);
	free(channel);
}

static void worker_task_set_error(worker_task *task, const char *message)
{
	free(task->error);
	task->error = worker_strdup(message != NULL ? message : "worker error");
}

static int worker_table_path_contains(worker_visited_tables *visited, const void *pointer)
{
	size_t i;
	for (i = 0; i < visited->count; i++) {
		if (visited->items[i] == pointer) {
			return 1;
		}
	}
	return 0;
}

static int worker_table_path_push(worker_visited_tables *visited, const void *pointer)
{
	const void **items;

	if (visited->count == visited->capacity) {
		size_t capacity = visited->capacity == 0 ? 8 : visited->capacity * 2;
		items = (const void **)realloc(visited->items, capacity * sizeof(*items));
		if (items == NULL) {
			return 0;
		}
		visited->items = items;
		visited->capacity = capacity;
	}

	visited->items[visited->count++] = pointer;
	return 1;
}

static void worker_table_path_pop(worker_visited_tables *visited)
{
	if (visited->count > 0) {
		visited->count--;
	}
}

static void worker_table_path_free(worker_visited_tables *visited)
{
	free(visited->items);
	visited->items = NULL;
	visited->count = 0;
	visited->capacity = 0;
}

static int worker_channel_is_ref(lua_State *L, int index)
{
	int is_channel = 0;
	int absolute_index = lua_absindex(L, index);

	if (!lua_getmetatable(L, absolute_index)) {
		return 0;
	}

	luaL_getmetatable(L, ELI_WORKER_CHANNEL_METATABLE);
	is_channel = lua_rawequal(L, -1, -2);
	lua_pop(L, 2);
	return is_channel;
}

static worker_channel *worker_channel_check(lua_State *L, int index)
{
	worker_channel_ref *ref =
	   (worker_channel_ref *)luaL_checkudata(L, index, ELI_WORKER_CHANNEL_METATABLE);
	luaL_argcheck(L, ref != NULL && ref->channel != NULL, index, "invalid worker channel");
	return ref->channel;
}

static int worker_pack_key(lua_State *L, int index, worker_value *value, const char **error)
{
	int value_type = lua_type(L, index);
	size_t length;
	const char *string_value;

	switch (value_type) {
	case LUA_TBOOLEAN:
		value->type = WORKER_VALUE_BOOLEAN;
		value->as.boolean_value = lua_toboolean(L, index);
		return 1;
	case LUA_TNUMBER:
		value->type = WORKER_VALUE_NUMBER;
		value->as.number_value = lua_tonumber(L, index);
		return 1;
	case LUA_TSTRING:
		string_value = lua_tolstring(L, index, &length);
		value->type = WORKER_VALUE_STRING;
		value->as.string_value.length = length;
		value->as.string_value.data = worker_strdup_n(string_value, length);
		if (value->as.string_value.data == NULL) {
			*error = "out of memory while copying worker table key";
			return 0;
		}
		return 1;
	default:
		*error = "worker tables only support boolean, number, and string keys";
		return 0;
	}
}

static int worker_pack_value(lua_State *L, int index, worker_value *value,
			     worker_visited_tables *visited, const char **error)
{
	int absolute_index = lua_absindex(L, index);
	int value_type = lua_type(L, absolute_index);
	size_t length;
	const char *string_value;
	size_t count = 0;
	size_t i = 0;
	const void *pointer;
	int has_table_value = 0;

	memset(value, 0, sizeof(*value));

	switch (value_type) {
	case LUA_TNIL:
		value->type = WORKER_VALUE_NIL;
		return 1;
	case LUA_TBOOLEAN:
		value->type = WORKER_VALUE_BOOLEAN;
		value->as.boolean_value = lua_toboolean(L, absolute_index);
		return 1;
	case LUA_TNUMBER:
		value->type = WORKER_VALUE_NUMBER;
		value->as.number_value = lua_tonumber(L, absolute_index);
		return 1;
	case LUA_TSTRING:
		string_value = lua_tolstring(L, absolute_index, &length);
		value->type = WORKER_VALUE_STRING;
		value->as.string_value.length = length;
		value->as.string_value.data = worker_strdup_n(string_value, length);
		if (value->as.string_value.data == NULL) {
			*error = "out of memory while copying worker string";
			return 0;
		}
		return 1;
	case LUA_TTABLE:
		if (lua_getmetatable(L, absolute_index)) {
			lua_pop(L, 1);
			*error = "worker cannot copy tables with metatables";
			return 0;
		}

		pointer = lua_topointer(L, absolute_index);
		if (worker_table_path_contains(visited, pointer)) {
			*error = "worker cannot copy recursive tables";
			return 0;
		}
		if (!worker_table_path_push(visited, pointer)) {
			*error = "out of memory while tracking worker tables";
			return 0;
		}

		lua_pushnil(L);
		while (lua_next(L, absolute_index) != 0) {
			count++;
			lua_pop(L, 1);
		}

		value->type = WORKER_VALUE_TABLE;
		value->as.table_value.length = count;
		value->as.table_value.entries =
		   count == 0 ? NULL : (worker_table_entry *)calloc(count, sizeof(worker_table_entry));
		if (count > 0 && value->as.table_value.entries == NULL) {
			worker_table_path_pop(visited);
			*error = "out of memory while copying worker table";
			return 0;
		}

		lua_pushnil(L);
		while (lua_next(L, absolute_index) != 0) {
			worker_table_entry *entry = &value->as.table_value.entries[i++];
			has_table_value = 1;
			entry->key = (worker_value *)calloc(1, sizeof(worker_value));
			entry->value = (worker_value *)calloc(1, sizeof(worker_value));
			if (entry->key == NULL || entry->value == NULL) {
				*error = "out of memory while copying worker table entry";
				goto table_error;
			}
			if (!worker_pack_key(L, -2, entry->key, error) ||
			    !worker_pack_value(L, -1, entry->value, visited, error)) {
				goto table_error;
			}
			lua_pop(L, 1);
			has_table_value = 0;
		}

		worker_table_path_pop(visited);
		return 1;
	table_error:
		if (has_table_value) {
			lua_pop(L, 1);
		}
		worker_table_path_pop(visited);
		return 0;
	case LUA_TUSERDATA:
		if (!worker_channel_is_ref(L, absolute_index)) {
			*error = "worker only supports worker channels as userdata values";
			return 0;
		}
		value->type = WORKER_VALUE_CHANNEL;
		value->as.channel_value = worker_channel_check(L, absolute_index);
		worker_channel_retain(value->as.channel_value);
		return 1;
	default:
		*error = "worker only supports nil, boolean, number, string, table, and worker channel values";
		return 0;
	}
}

static void worker_free_value(worker_value *value)
{
	size_t i;

	if (value == NULL) {
		return;
	}

	switch (value->type) {
	case WORKER_VALUE_STRING:
		free(value->as.string_value.data);
		break;
	case WORKER_VALUE_TABLE:
		for (i = 0; i < value->as.table_value.length; i++) {
			worker_table_entry *entry = &value->as.table_value.entries[i];
			worker_free_value(entry->key);
			worker_free_value(entry->value);
			free(entry->key);
			free(entry->value);
		}
		free(value->as.table_value.entries);
		break;
	case WORKER_VALUE_CHANNEL:
		worker_channel_release(value->as.channel_value);
		break;
	default:
		break;
	}

	memset(value, 0, sizeof(*value));
}

static int worker_push_channel_ref(lua_State *L, worker_channel *channel)
{
	worker_channel_ref *ref;

	if (!worker_ensure_channel_metatable(L)) {
		return 0;
	}

	ref = (worker_channel_ref *)lua_newuserdatauv(L, sizeof(*ref), 0);
	if (ref == NULL) {
		return 0;
	}
	ref->channel = channel;
	worker_channel_retain(channel);
	luaL_setmetatable(L, ELI_WORKER_CHANNEL_METATABLE);
	return 1;
}

static int worker_push_value(lua_State *L, const worker_value *value)
{
	size_t i;

	switch (value->type) {
	case WORKER_VALUE_NIL:
		lua_pushnil(L);
		return 1;
	case WORKER_VALUE_BOOLEAN:
		lua_pushboolean(L, value->as.boolean_value);
		return 1;
	case WORKER_VALUE_NUMBER:
		lua_pushnumber(L, value->as.number_value);
		return 1;
	case WORKER_VALUE_STRING:
		lua_pushlstring(L, value->as.string_value.data, value->as.string_value.length);
		return 1;
	case WORKER_VALUE_TABLE:
		lua_createtable(L, 0, (int)value->as.table_value.length);
		for (i = 0; i < value->as.table_value.length; i++) {
			worker_table_entry *entry = &value->as.table_value.entries[i];
			if (!worker_push_value(L, entry->key) || !worker_push_value(L, entry->value)) {
				return 0;
			}
			lua_rawset(L, -3);
		}
		return 1;
	case WORKER_VALUE_CHANNEL:
		return worker_push_channel_ref(L, value->as.channel_value);
	default:
		return 0;
	}
}

static int worker_traceback(lua_State *L)
{
	const char *message = lua_tostring(L, 1);
	if (message != NULL) {
		luaL_traceback(L, L, message, 1);
	} else {
		lua_pushliteral(L, "worker error");
	}
	return 1;
}

static void worker_register_preload(lua_State *L)
{
	lua_getglobal(L, "package");
	lua_getfield(L, -1, "preload");
	lua_pushcfunction(L, luaopen_eli_worker_extra);
	lua_setfield(L, -2, "eli.worker.extra");
	lua_pop(L, 2);
}

static int worker_thread_main(void *arg)
{
	worker_thread_context *context = (worker_thread_context *)arg;
	worker_task *task = context->task;
	lua_State *L = luaL_newstate();
	size_t i;
	int status;
	int handler_index;

	if (L == NULL) {
		mtx_lock(&task->mutex);
		worker_task_set_error(task, "failed to create worker state");
		task->done = 1;
		cnd_broadcast(&task->done_cond);
		mtx_unlock(&task->mutex);
		goto cleanup;
	}

	luaL_openlibs(L);
	worker_register_preload(L);

	lua_pushcfunction(L, worker_traceback);
	handler_index = lua_gettop(L);

	status = luaL_loadbuffer(L, context->code, context->code_length, "=worker");
	if (status != LUA_OK) {
		mtx_lock(&task->mutex);
		worker_task_set_error(task, lua_tostring(L, -1));
		task->done = 1;
		cnd_broadcast(&task->done_cond);
		mtx_unlock(&task->mutex);
		lua_close(L);
		goto cleanup;
	}

	for (i = 0; i < context->arg_count; i++) {
		if (!worker_push_value(L, &context->args[i])) {
			mtx_lock(&task->mutex);
			worker_task_set_error(task, "failed to push worker argument");
			task->done = 1;
			cnd_broadcast(&task->done_cond);
			mtx_unlock(&task->mutex);
			lua_close(L);
			goto cleanup;
		}
	}

	status = lua_pcall(L, (int)context->arg_count, LUA_MULTRET, handler_index);
	if (status != LUA_OK) {
		mtx_lock(&task->mutex);
		worker_task_set_error(task, lua_tostring(L, -1));
		task->done = 1;
		cnd_broadcast(&task->done_cond);
		mtx_unlock(&task->mutex);
		lua_close(L);
		goto cleanup;
	}

	lua_remove(L, handler_index);

	mtx_lock(&task->mutex);
	task->result_count = (size_t)lua_gettop(L);
	task->results = task->result_count == 0 ? NULL :
	   (worker_value *)calloc(task->result_count, sizeof(worker_value));
	if (task->result_count > 0 && task->results == NULL) {
		worker_task_set_error(task, "out of memory while storing worker results");
		task->done = 1;
		cnd_broadcast(&task->done_cond);
		mtx_unlock(&task->mutex);
		lua_close(L);
		goto cleanup;
	}

	for (i = 0; i < task->result_count; i++) {
		worker_visited_tables visited = {0};
		const char *error = NULL;
		if (!worker_pack_value(L, (int)i + 1, &task->results[i], &visited, &error)) {
			size_t j;
			worker_table_path_free(&visited);
			worker_free_value(&task->results[i]);
			for (j = 0; j < i; j++) {
				worker_free_value(&task->results[j]);
			}
			free(task->results);
			task->results = NULL;
			task->result_count = 0;
			worker_task_set_error(task, error != NULL ? error : "failed to store worker result");
			task->done = 1;
			cnd_broadcast(&task->done_cond);
			mtx_unlock(&task->mutex);
			lua_close(L);
			goto cleanup;
		}
		worker_table_path_free(&visited);
	}

	task->done = 1;
	cnd_broadcast(&task->done_cond);
	mtx_unlock(&task->mutex);

	lua_close(L);

cleanup:
	for (i = 0; i < context->arg_count; i++) {
		worker_free_value(&context->args[i]);
	}
	free(context->args);
	free(context->code);
	free(context);
	return 0;
}

static int worker_task_join(lua_State *L)
{
	size_t i;
	worker_task *task =
	   (worker_task *)luaL_checkudata(L, 1, ELI_WORKER_TASK_METATABLE);

	if (!task->mutex_ready) {
		lua_pushboolean(L, 0);
		lua_pushliteral(L, "worker task is not initialized");
		return 2;
	}

	if (!task->joined && task->started) {
		if (thrd_join(task->thread, NULL) != thrd_success) {
			lua_pushboolean(L, 0);
			lua_pushliteral(L, "failed to join worker");
			return 2;
		}
		task->joined = 1;
	}

	mtx_lock(&task->mutex);
	if (task->error != NULL) {
		lua_pushboolean(L, 0);
		lua_pushstring(L, task->error);
		mtx_unlock(&task->mutex);
		return 2;
	}

	lua_pushboolean(L, 1);
	for (i = 0; i < task->result_count; i++) {
		if (!worker_push_value(L, &task->results[i])) {
			mtx_unlock(&task->mutex);
			return luaL_error(L, "failed to decode worker result");
		}
	}
	mtx_unlock(&task->mutex);
	return (int)task->result_count + 1;
}

static int worker_task_is_done(lua_State *L)
{
	int done;
	worker_task *task =
	   (worker_task *)luaL_checkudata(L, 1, ELI_WORKER_TASK_METATABLE);
	if (!task->mutex_ready) {
		lua_pushboolean(L, 0);
		return 1;
	}
	mtx_lock(&task->mutex);
	done = task->done;
	mtx_unlock(&task->mutex);
	lua_pushboolean(L, done);
	return 1;
}

static int worker_task_gc(lua_State *L)
{
	size_t i;
	worker_task *task =
	   (worker_task *)luaL_checkudata(L, 1, ELI_WORKER_TASK_METATABLE);

	if (task->started && !task->joined) {
		thrd_join(task->thread, NULL);
		task->joined = 1;
	}

	for (i = 0; i < task->result_count; i++) {
		worker_free_value(&task->results[i]);
	}
	free(task->results);
	task->results = NULL;
	task->result_count = 0;

	free(task->error);
	task->error = NULL;

	if (task->done_cond_ready) {
		cnd_destroy(&task->done_cond);
		task->done_cond_ready = 0;
	}
	if (task->mutex_ready) {
		mtx_destroy(&task->mutex);
		task->mutex_ready = 0;
	}
	return 0;
}

static int worker_channel_send(lua_State *L)
{
	worker_channel *channel = worker_channel_check(L, 1);
	worker_message *message = (worker_message *)calloc(1, sizeof(*message));
	worker_visited_tables visited = {0};
	const char *error = NULL;

	if (message == NULL) {
		lua_pushnil(L);
		lua_pushliteral(L, "out of memory while sending worker message");
		return 2;
	}

	if (!worker_pack_value(L, 2, &message->value, &visited, &error)) {
		worker_table_path_free(&visited);
		worker_free_value(&message->value);
		free(message);
		lua_pushnil(L);
		lua_pushstring(L, error != NULL ? error : "failed to copy worker message");
		return 2;
	}
	worker_table_path_free(&visited);

	mtx_lock(&channel->mutex);
	if (channel->closed) {
		mtx_unlock(&channel->mutex);
		worker_free_value(&message->value);
		free(message);
		lua_pushnil(L);
		lua_pushliteral(L, "worker channel is closed");
		return 2;
	}

	if (channel->tail != NULL) {
		channel->tail->next = message;
	} else {
		channel->head = message;
	}
	channel->tail = message;
	cnd_signal(&channel->recv_cond);
	mtx_unlock(&channel->mutex);

	lua_pushboolean(L, 1);
	return 1;
}

static int worker_channel_recv(lua_State *L)
{
	worker_channel *channel = worker_channel_check(L, 1);
	worker_message *message;

	mtx_lock(&channel->mutex);
	while (channel->head == NULL && !channel->closed) {
		cnd_wait(&channel->recv_cond, &channel->mutex);
	}

	message = channel->head;
	if (message == NULL) {
		mtx_unlock(&channel->mutex);
		lua_pushboolean(L, 0);
		lua_pushliteral(L, "closed");
		return 2;
	}

	channel->head = message->next;
	if (channel->head == NULL) {
		channel->tail = NULL;
	}
	mtx_unlock(&channel->mutex);

	lua_pushboolean(L, 1);
	if (!worker_push_value(L, &message->value)) {
		worker_free_value(&message->value);
		free(message);
		return luaL_error(L, "failed to decode worker message");
	}

	worker_free_value(&message->value);
	free(message);
	return 2;
}

static int worker_channel_close(lua_State *L)
{
	worker_channel *channel = worker_channel_check(L, 1);
	mtx_lock(&channel->mutex);
	channel->closed = 1;
	cnd_broadcast(&channel->recv_cond);
	mtx_unlock(&channel->mutex);
	lua_pushboolean(L, 1);
	return 1;
}

static int worker_channel_gc(lua_State *L)
{
	worker_channel_ref *ref =
	   (worker_channel_ref *)luaL_checkudata(L, 1, ELI_WORKER_CHANNEL_METATABLE);
	if (ref->channel != NULL) {
		worker_channel_release(ref->channel);
		ref->channel = NULL;
	}
	return 0;
}

static const luaL_Reg worker_task_methods[] = {
	{"join", worker_task_join},
	{"is_done", worker_task_is_done},
	{"__gc", worker_task_gc},
	{NULL, NULL},
};

static const luaL_Reg worker_channel_methods[] = {
	{"send", worker_channel_send},
	{"recv", worker_channel_recv},
	{"close", worker_channel_close},
	{"__gc", worker_channel_gc},
	{NULL, NULL},
};

static int worker_ensure_task_metatable(lua_State *L)
{
	if (luaL_newmetatable(L, ELI_WORKER_TASK_METATABLE)) {
		luaL_setfuncs(L, worker_task_methods, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_pop(L, 1);
	return 1;
}

static int worker_ensure_channel_metatable(lua_State *L)
{
	if (luaL_newmetatable(L, ELI_WORKER_CHANNEL_METATABLE)) {
		luaL_setfuncs(L, worker_channel_methods, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_pop(L, 1);
	return 1;
}

static int worker_new_channel(lua_State *L)
{
	worker_channel *channel = (worker_channel *)calloc(1, sizeof(*channel));
	int mutex_ready = 0;
	if (channel == NULL) {
		lua_pushnil(L);
		lua_pushliteral(L, "out of memory while creating worker channel");
		return 2;
	}
	if (mtx_init(&channel->mutex, mtx_plain) == thrd_success) {
		mutex_ready = 1;
	}
	if (!mutex_ready || cnd_init(&channel->recv_cond) != thrd_success) {
		if (mutex_ready) {
			mtx_destroy(&channel->mutex);
		}
		free(channel);
		lua_pushnil(L);
		lua_pushliteral(L, "failed to initialize worker channel");
		return 2;
	}

	channel->refs = 0;
	channel->closed = 0;
	channel->head = NULL;
	channel->tail = NULL;

	if (!worker_push_channel_ref(L, channel)) {
		worker_channel_release(channel);
		lua_pushnil(L);
		lua_pushliteral(L, "failed to create worker channel handle");
		return 2;
	}

	return 1;
}

static int worker_spawn(lua_State *L)
{
	size_t arg_count;
	size_t i;
	size_t code_length = 0;
	const char *code = luaL_checklstring(L, 1, &code_length);
	char *code_copy = worker_strdup_n(code, code_length);
	worker_value *args;
	worker_task *task;
	worker_thread_context *context;

	if (code_copy == NULL) {
		lua_pushnil(L);
		lua_pushliteral(L, "out of memory while copying worker code");
		return 2;
	}

	arg_count = (size_t)lua_gettop(L) - 1;
	args = arg_count == 0 ? NULL : (worker_value *)calloc(arg_count, sizeof(worker_value));
	if (arg_count > 0 && args == NULL) {
		free(code_copy);
		lua_pushnil(L);
		lua_pushliteral(L, "out of memory while copying worker arguments");
		return 2;
	}

	for (i = 0; i < arg_count; i++) {
		worker_visited_tables visited = {0};
		const char *error = NULL;
		if (!worker_pack_value(L, (int)i + 2, &args[i], &visited, &error)) {
			size_t j;
			worker_table_path_free(&visited);
			worker_free_value(&args[i]);
			for (j = 0; j < i; j++) {
				worker_free_value(&args[j]);
			}
			free(args);
			free(code_copy);
			lua_pushnil(L);
			lua_pushstring(L, error != NULL ? error : "failed to copy worker argument");
			return 2;
		}
		worker_table_path_free(&visited);
	}

	worker_ensure_task_metatable(L);
	task = (worker_task *)lua_newuserdatauv(L, sizeof(*task), 0);
	memset(task, 0, sizeof(*task));
	if (mtx_init(&task->mutex, mtx_plain) == thrd_success) {
		task->mutex_ready = 1;
	}
	if (!task->mutex_ready || cnd_init(&task->done_cond) != thrd_success) {
		for (i = 0; i < arg_count; i++) {
			worker_free_value(&args[i]);
		}
		free(args);
		free(code_copy);
		if (task->mutex_ready) {
			mtx_destroy(&task->mutex);
			task->mutex_ready = 0;
		}
		lua_pop(L, 1);
		lua_pushnil(L);
		lua_pushliteral(L, "failed to initialize worker task");
		return 2;
	}
	task->done_cond_ready = 1;
	luaL_setmetatable(L, ELI_WORKER_TASK_METATABLE);

	context = (worker_thread_context *)calloc(1, sizeof(*context));
	if (context == NULL) {
		for (i = 0; i < arg_count; i++) {
			worker_free_value(&args[i]);
		}
		free(args);
		free(code_copy);
		cnd_destroy(&task->done_cond);
		task->done_cond_ready = 0;
		mtx_destroy(&task->mutex);
		task->mutex_ready = 0;
		lua_pop(L, 1);
		lua_pushnil(L);
		lua_pushliteral(L, "out of memory while starting worker");
		return 2;
	}

	context->task = task;
	context->code = code_copy;
	context->code_length = code_length;
	context->arg_count = arg_count;
	context->args = args;

	if (thrd_create(&task->thread, worker_thread_main, context) != thrd_success) {
		free(context);
		for (i = 0; i < arg_count; i++) {
			worker_free_value(&args[i]);
		}
		free(args);
		free(code_copy);
		cnd_destroy(&task->done_cond);
		task->done_cond_ready = 0;
		mtx_destroy(&task->mutex);
		task->mutex_ready = 0;
		lua_pop(L, 1);
		lua_pushnil(L);
		lua_pushliteral(L, "failed to create worker thread");
		return 2;
	}

	task->started = 1;
	return 1;
}

static const luaL_Reg worker_lib[] = {
	{"spawn", worker_spawn},
	{"channel", worker_new_channel},
	{NULL, NULL},
};

int luaopen_eli_worker_extra(lua_State *L)
{
	worker_ensure_task_metatable(L);
	worker_ensure_channel_metatable(L);
	lua_newtable(L);
	luaL_setfuncs(L, worker_lib, 0);
	return 1;
}
