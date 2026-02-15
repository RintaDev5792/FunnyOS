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
void misc_initLua(void);

DllExport
int eventHandler(PlaydateAPI* pd, PDSystemEvent event, uint32_t arg)
{
    playdate = pd;
    eventHandler_pdnewlib(pd, event, arg);
    
    if (event == kEventInitLua)
    {
        zip_initLua();
        misc_initLua();
    }
    
    if (event == kEventTerminate)
    {
        #ifdef TARGET_PLAYDATE
        pdnewlib_quit();
        #endif
    }
    
    return 0;
}