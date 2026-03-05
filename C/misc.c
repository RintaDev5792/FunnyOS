#include "pd_api.h"
#include "utility.h"

#include <stdio.h>
#include <time.h>

#define FILE_TYPE "fosfile"

#ifdef TARGET_SIMULATOR
static int l_get_env(lua_State* L)
{
    const char* env_arg = playdate->lua->getArgString(1);
    char* e = getenv(env_arg);
    playdate->lua->pushString(e);
    return 1;
}
#endif

int l_file_write_open(lua_State* L)
{
    const char* path = playdate->lua->getArgString(1);
    if (!path) return 0;
    
    SDFile* file = playdate->file->open(path, kFileWrite);
    if (!file)
    {
        playdate->lua->pushNil();
        const char* err = playdate->file->geterr();
        if (err)
        {
            playdate->lua->pushString(err);
            return 2;
        }
        return 1;
    }
    
    playdate->lua->pushObject(file, FILE_TYPE, 1);
    return 1;
}

int l_file_write(lua_State* L)
{
    SDFile* file = playdate->lua->getArgObject(1, FILE_TYPE, NULL);
    if (file)
    {
        int written = 0;
        size_t len;
        const char* bytes = playdate->lua->getArgBytes(2, &len);
        if (len == 0) goto ret_negative_1;
        while (written < len)
        {
            int w = playdate->file->write(file, bytes + written, len - written);
            if (w == 0) goto ret_negative_1;
            written += w;
        }
        
        playdate->lua->pushInt(written);
        return 1;
    }
    
ret_negative_1:;
    playdate->lua->pushInt(-1);
    return 1;
}

int l_file_flush(lua_State* L)
{
    SDFile* file = playdate->lua->getArgObject(1, FILE_TYPE, NULL);
    if (file)
    {
        playdate->file->flush(file);
    }
    return 0;
}


int l_file_close(lua_State* L)
{
    SDFile* file = playdate->lua->getArgObject(1, FILE_TYPE, NULL);
    if (file)
    {
        playdate->file->close(file);
    }
    return 0;
}

lua_reg file_reg[] = {
    {.name = "write", .func = l_file_write},
    {.name = "flush", .func = l_file_flush},
    {.name = "close", .func = l_file_close},
    {.name = NULL, .func = NULL}
};

void misc_initLua(void)
{
    #ifdef TARGET_SIMULATOR
    playdate->lua->addFunction(
        l_get_env, FOS_LUA_PACKAGE ".getenv", NULL
    );
    #endif
    
    playdate->lua->addFunction(
        l_file_write_open, FOS_LUA_PACKAGE ".file_open_write", NULL
    );
    
    playdate->lua->registerClass(
        FILE_TYPE, file_reg, NULL, false, NULL
    );
}