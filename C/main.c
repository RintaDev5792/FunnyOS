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

void zip_initLua(void);

static int l_get_launch_args(lua_State* L)
{
    const char* args = NULL;
    playdate->system->getLaunchArgs(&args);
    if (args)
    {
        playdate->lua->pushString(args);
        return 1;
    }
    return 0;
}

static void initLua(void)
{
    playdate->lua->addFunction(
        l_get_launch_args, FOS_LUA_PACKAGE ".get_launch_args", NULL
    );
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