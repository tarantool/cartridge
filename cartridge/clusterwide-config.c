#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include <tarantool/module.h>
#include <tarantool/lua.h>
#include <tarantool/lauxlib.h>

// NOTE: Open flags like in clusterwide-config.save
// NOTE: Open mode value is ok for this purpose, i guess
static int file_write(const char* path, const char* data) {
  int fd = open(path, O_CREAT | O_EXCL | O_WRONLY | O_SYNC,
                S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
  if(fd == -1) {
    say_error("open() error: %s, path: %s", strerror(errno), path);
    return -1;
  }
  int count = strlen(data);
  ssize_t nr = write(fd, data, count);
  if(nr == -1){
    say_error("error while write(): %s", strerror(errno));
    return -1;
  }
  if(nr == 0 || nr != count) {
    say_warn("data wasn't written correctly, count of written bytes: %ld, expected: %d", nr, count);
  }
  if(close(fd) == -1) {
    say_error("close() error: %s", strerror(errno));
    return -1;
  }
  say_verbose("%s has written", path);
  return 0;
}

static int mktree(char* path) {
  char* tmp_path = strdup(path);
  // FIXME: here possible buffer overflow
  char current_dir[512] = "";
  char* ctxptr;
  struct stat st;
  char* dir = strtok(tmp_path, "/");
  while(dir != NULL) {
    char* tmp_dir = strdup(current_dir);
    sprintf(current_dir, "%s/%s", tmp_dir, dir);
    mode_t mode = 0744;
    int stat_rc = stat(current_dir, &st);
    say_info("current_dir: %s", current_dir);
    if(stat_rc == -1) {
      if(mkdir(current_dir, mode) ==  -1) {
        say_error("mkdir() error: %s, path: %s, mode: %x", strerror(errno), current_dir, mode);
        return -1;
      } else {
        say_info("Directory '%s' has created", current_dir);
      }
    } else if(!S_ISDIR(st.st_mode)) {
      say_warn("path: %s : %s", current_dir, strerror(EEXIST));
      return -1;
    }
    dir = strtok(NULL, "/");
  }
  return 0;
}

static int cw_save(char* path, char* random_path, char** sections_k, char** sections_v, int section_l, char* err) {
  if(mktree(random_path) == -1 ) {
    say_error("mktree() error");
    sprintf(err, "%s: %s", random_path, strerror(errno));
    return -1;
  }

  for (int i = 0; i < section_l; i++) {
    char tmp_path[512];
    sprintf(tmp_path, "%s/%s", random_path, sections_k[i]);
    if(file_write(tmp_path, sections_v[i]) == -1) {
      say_error("file_write() error: %s", strerror(errno));
      sprintf(err, "%s: %s", tmp_path, strerror(errno));
      goto rollback;
    }
  }

  if(rename(random_path, path) == -1) {
    say_error("rename() error: %s", strerror(errno));
    sprintf(err, "%s: %s", path, strerror(errno));
    goto rollback;
  }

  say_verbose("%s has renamed to %s", random_path, path);
  goto exit;
rollback:
  if(remove(random_path) == -1) {
    say_warn("remove error: %s, path: %s", strerror(errno), random_path);
  }
  return -1;
exit:
  return 0;
}

static ssize_t va_cw_save(va_list argp) {
  char* path = va_arg(argp, char*);
  char* random_path = va_arg(argp, char*);
  char** keys = va_arg(argp, char**);
  char** values = va_arg(argp, char**);
  int l = va_arg(argp, int);
  char* err = va_arg(argp, char*);
  return cw_save(path, random_path, keys, values, l, err);
}

static int lua_cw_save(lua_State *L) {
  const char* path = luaL_checkstring(L, 1);
  const char* random_path = luaL_checkstring(L, 2);
  int v = 1;
  const char* sections_v[100];
    do {
    lua_pushnumber(L, v);
    lua_gettable(L, 4);
    if(lua_isnoneornil(L, -1))
      break;

    if(!lua_isstring(L, -1)) {
      const char* _type = luaL_typename(L, -1);
      say_error("wrong format of table field at index %d: expect string, actual is %s", v, _type);
      lua_pushnil(L);
      lua_pushstring(L, "format error");
      return 2;
    }
    sections_v[v-1] = lua_tostring(L, -1);
    lua_pop(L, 1);
    v++;
  } while(true);

  const char* sections_k[100];
  int k = 1;
  do {
    lua_pushnumber(L, k);
    lua_gettable(L, 3);
    if(lua_isnoneornil(L, -1))
      break;

    if(!lua_isstring(L, -1)) {
      const char* _type = luaL_typename(L, -1);
      say_error("wrong format of table field at index %d: expect string, actual is %s", k, _type);
      lua_pushnil(L);
      lua_pushstring(L, "format error");
      return 2;
    }
    sections_k[k-1] = lua_tostring(L, -1);
    lua_pop(L, 1);
    k++;
  } while(true);

  if(k != v) {
    say_error("count of keys and count of values are different");
    lua_pushnil(L);
    lua_pushstring(L, "error");
    return 2;
  }

  char err[PATH_MAX];

  if(coio_call(va_cw_save, path, random_path, sections_k, sections_v, k-1, err) == -1) {
    say_error("coio_call() error");
    lua_pushnil(L);
    lua_pushstring(L, err);
    return 2;
  }

  lua_pushboolean(L, 1);
  lua_pushnil(L);
  return 2;
}

static const struct luaL_Reg functions[] = {
  {"save", lua_cw_save},
  {NULL, NULL}
};

// NOTE: why i need to use "luaopen_" prefix?
LUA_API int luaopen_cartridge_cwinternal(lua_State *L) {
  lua_newtable(L);
  luaL_register(L, NULL, functions);
  return 1;
}

