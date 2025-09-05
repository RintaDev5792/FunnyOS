#include "pd_api.h"
#include "utility.h"
#include "pdnewlib.h"

#include <stdio.h>
#include <time.h>

#ifdef _WINDLL
#define DllExport __declspec(dllexport)
#else
#define DllExport
#endif

#ifdef TARGET_SIMULATOR
#endif

void zip_initLua(void);

#ifdef TARGET_SIMULATOR
static int l_get_env(lua_State* L)
{
    const char* env_arg = playdate->lua->getArgString(1);
    char* e = getenv(env_arg);
    playdate->lua->pushString(e);
    return 1;
}
#endif

static void initLua(void)
{
    #ifdef TARGET_SIMULATOR
    playdate->lua->addFunction(
        l_get_env, FOS_LUA_PACKAGE ".getenv", NULL
    );
    #endif
}

DllExport
int eventHandler(PlaydateAPI* pd, PDSystemEvent event, uint32_t arg)
{
    playdate = pd;
    eventHandler_pdnewlib(pd, event, arg);
    
    if (event == kEventInitLua)
    {
        zip_initLua();
        initLua();
    }
    
    if (event == kEventTerminate)
    {
        #ifdef TARGET_PLAYDATE
        pdnewlib_quit();
        #endif
    }
    
    return 0;
}