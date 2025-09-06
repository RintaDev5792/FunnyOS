#pragma once
#include "pd_api.h"

extern PlaydateAPI* playdate;

#define FOS_LUA_PACKAGE "fos"

// malloc and memset to zero
void* mallocz(size_t size);

#define allocz(Type) ((Type*)mallocz(sizeof(Type)))

// malloc array and memset to zero
#define allocza(Type, N) ((Type*)mallocz(sizeof(Type) * (N)));