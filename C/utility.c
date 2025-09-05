#include "utility.h"

PlaydateAPI* playdate;

void* mallocz(size_t size)
{
    void* v = playdate->system->realloc(NULL, size);
    if (!v)
        return NULL;

    memset(v, 0, size);
    return v;
}
