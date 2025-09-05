#include "pd_api.h"
#include "utility.h"
#include "miniz.h"

#define ZIP_TYPE "zip"
#define ZIP_FILE_TYPE "zipfile"

static void* zip_alloc(void* opaque, size_t count, size_t n)
{
    return playdate->system->realloc(NULL, count * n);
}

static void zip_free(void* opaque, void* addr)
{
    playdate->system->realloc(addr, 0);
}

static void* zip_realloc(void* opaque, void* addr, size_t count, size_t n)
{
    return playdate->system->realloc(addr, count * n);
}

static size_t (zip_read)(void* file, uint64_t file_ofs, void* pBuf, size_t n)
{
    if (playdate->file->seek((SDFile*)file, file_ofs, SEEK_SET)) return 0;
    
    return playdate->file->read((SDFile*)file, pBuf, n);
}

static size_t (zip_write)(void* file, uint64_t file_ofs, const void* pBuf, size_t n)
{
    if (playdate->file->seek((SDFile*)file, file_ofs, SEEK_SET)) return 0;
    
    return playdate->file->write((SDFile*)file, pBuf, n);
}

int l_zip_open(lua_State* L)
{
    size_t size;
    mz_zip_archive* z;
    const char* path = playdate->lua->getArgString(1);
    
    SDFile* file = playdate->file->open(path, kFileReadData);
    if (!file)
    {
        playdate->system->logToConsole("Failed to open file: \"%s\"", path);
        return 0;
    }
    
    if (playdate->file->seek(file, 0, SEEK_END) != 0)
    {
        playdate->system->logToConsole("Failed to seek in zip file");
    err_file:
        playdate->file->close(file);
        return 0;
    }
    size = playdate->file->tell(file);
    if (playdate->file->seek(file, 0, SEEK_SET) != 0)
    {
        playdate->system->logToConsole("Failed to seek in zip file");
        goto err_file;
    }
    
    z = allocz(mz_zip_archive);
    
    z->m_pAlloc = zip_alloc;
    z->m_pFree = zip_free;
    z->m_pRealloc = zip_realloc;
    
    z->m_pRead = zip_read;
    z->m_pWrite = zip_write;
    z->m_pIO_opaque = file;
    
    mz_bool result = mz_zip_reader_init(z, size,
        MZ_ZIP_FLAG_CASE_SENSITIVE
    );
    
    if (!result)
    {
        playdate->system->logToConsole("Failed to init zip reader: \"%s\"", mz_zip_get_error_string(mz_zip_get_last_error(z)));
        playdate->system->realloc(z, 0);
        goto err_file;
    }
    
    playdate->lua->pushObject(z, ZIP_TYPE, 1);
    return 1;
}

int l_zip_get_file_count(lua_State* L)
{
    mz_zip_archive* pZip = playdate->lua->getArgObject(1, ZIP_TYPE, NULL);
    if (!pZip) return 0;
    
    size_t file_count = mz_zip_reader_get_num_files(pZip);
    
    playdate->lua->pushInt(file_count);
    
    return 1;
}

void normalize_path_separator(char* str) {
    while (*str) {
        if (*str == '\\') {
            *str = '/';
        }
        str++;
    }
}


int l_zip_get_file_name(lua_State* L)
{
    mz_zip_archive* pZip = playdate->lua->getArgObject(1, ZIP_TYPE, NULL);
    if (!pZip) return 0;
    
    size_t file_index = playdate->lua->getArgInt(2) - 1;
    
    char fname[MZ_ZIP_MAX_ARCHIVE_FILENAME_SIZE];
    size_t len = mz_zip_reader_get_filename(pZip, file_index, fname, sizeof(fname));
    fname[MZ_ZIP_MAX_ARCHIVE_FILENAME_SIZE-1] = 0;
    normalize_path_separator(fname);
    playdate->lua->pushString(fname);
    
    return 1;
}

int l_zip_get_file_is_directory(lua_State* L)
{
    mz_zip_archive* pZip = playdate->lua->getArgObject(1, ZIP_TYPE, NULL);
    if (!pZip) return 0;
    
    size_t file_index = playdate->lua->getArgInt(2) - 1;
    
    bool is_dir = mz_zip_reader_is_file_a_directory(pZip, file_index);
    
    playdate->lua->pushBool(is_dir);
    
    return 1;
}

int l_zip_get_file_is_encrypted(lua_State* L)
{
    mz_zip_archive* pZip = playdate->lua->getArgObject(1, ZIP_TYPE, NULL);
    if (!pZip) return 0;
    
    size_t file_index = playdate->lua->getArgInt(2) - 1;
    
    bool is_encrypted = mz_zip_reader_is_file_encrypted(pZip, file_index);
    
    playdate->lua->pushBool(is_encrypted);
    
    return 1;
}

int l_zip_get_file_is_supported(lua_State* L)
{
    mz_zip_archive* pZip = playdate->lua->getArgObject(1, ZIP_TYPE, NULL);
    if (!pZip) return 0;
    
    size_t file_index = playdate->lua->getArgInt(2) - 1;
    
    bool b = mz_zip_reader_is_file_supported(pZip, file_index);
    
    playdate->lua->pushBool(b);
    
    return 1;
}

typedef struct ZipFile
{
    mz_zip_archive_file_stat stat;
    mz_zip_archive* pZip;
} ZipFile;

int l_zip_get_file(lua_State* L)
{
    mz_zip_archive* pZip = playdate->lua->getArgObject(1, ZIP_TYPE, NULL);
    if (!pZip) return 0;
    
    size_t file_index = playdate->lua->getArgInt(2) - 1;
    
    ZipFile* zf = allocz(ZipFile);
    if (!zf) return 0;
    
    zf->pZip = pZip;
    if (mz_zip_reader_file_stat(pZip, file_index, &zf->stat))
    {
        normalize_path_separator(zf->stat.m_filename);
        playdate->lua->pushObject(zf, ZIP_FILE_TYPE, 1);
        return 1;
    }
    
    playdate->system->realloc(zf, 0);
    
    return 0;
}

int l_zip_get_error(lua_State* L)
{
    mz_zip_archive* pZip = playdate->lua->getArgObject(1, ZIP_TYPE, NULL);
    if (!pZip) return 0;
    
    mz_zip_error err = mz_zip_get_last_error(pZip);
    if (err == MZ_ZIP_NO_ERROR) return 0;
    
    const char* s = mz_zip_get_error_string(err);
    if (!s) return 0;
    
    playdate->lua->pushString(s);
    return 1;
}

int l_zip_get_archive_size(lua_State* L)
{
    mz_zip_archive* pZip = playdate->lua->getArgObject(1, ZIP_TYPE, NULL);
    if (!pZip) return 0;
    
    size_t size = mz_zip_get_archive_size(pZip);
    playdate->lua->pushInt(size);
    return 1;
}

int l_zip_close(lua_State* L)
{
    mz_zip_archive* pZip = playdate->lua->getArgObject(1, ZIP_TYPE, NULL);
    if (!pZip) return 0;
    
    mz_zip_reader_end(pZip);
    playdate->system->realloc(pZip, 0);
    return 0;
}

int index_reg(lua_State* L, lua_reg* reg, const char* key)
{
    while (reg->func || reg->name)
    {
        if (reg->name && !strcmp(reg->name, key))
        {
            playdate->lua->pushFunction(reg->func);
            return 1;
        }
        ++reg;
    }
    
    return 0;
}

int l_zip___index(lua_State* L);

static lua_reg zip_reg[] = {
    {.name = "open", .func = l_zip_open},
    {.name = "get_file_count", .func = l_zip_get_file_count},
    {.name = "get_file_name", .func = l_zip_get_file_name},
    {.name = "get_file_is_directory", .func = l_zip_get_file_is_directory},
    {.name = "get_file_is_encrypted", .func = l_zip_get_file_is_encrypted},
    {.name = "get_file_is_supported", .func = l_zip_get_file_is_supported},
    {.name = "get_file", .func = l_zip_get_file},
    {.name = "get_error", .func = l_zip_get_error},
    {.name = "close", .func = l_zip_close},
    {.name = "__index", .func = l_zip___index},
    {.name = "__gc", .func = l_zip_close},
    {.name = NULL, .func = NULL}
};

int l_zip___index(lua_State* L)
{
    mz_zip_archive* pZip = playdate->lua->getArgObject(1, ZIP_TYPE, NULL);
    if (!pZip) return 0;
    
    const char* key = playdate->lua->getArgString(2);
    if (!key) return 0;
    
    if (index_reg(L, zip_reg, key)) return 1;
    
    if (!strcmp(key, "archive_size"))
    {
        playdate->lua->pushInt(mz_zip_get_archive_size(pZip));
        return 1;
    }
    
    if (!strcmp(key, "is_zip64"))
    {
        playdate->lua->pushBool(mz_zip_is_zip64(pZip));
        return 1;
    }
    
    return 0;
}

int l_zip_file_extract(lua_State* L, bool toBytes);

int l_zip_file_extract_string(lua_State* L)
{
    return l_zip_file_extract(L, false);
}

int l_zip_file_extract_bytes(lua_State* L)
{
    return l_zip_file_extract(L, true);
}

int l_zip_file_extract_file(lua_State* L)
{
    ZipFile* zf = playdate->lua->getArgObject(1, ZIP_FILE_TYPE, NULL);
    if (!zf) return 0;
    
    const char* dst = playdate->lua->getArgString(2);
    if (!dst) return 0;
    
    SDFile* file = playdate->file->open(dst, kFileWrite);
    if (!file)
    {
        playdate->system->logToConsole("Failed to open file \"%s\" for writing", dst);
    }
    
    mz_zip_reader_extract_to_callback(zf->pZip, zf->stat.m_file_index, zip_write, file, 0);
    
    playdate->file->close(file);
    
    // success
    playdate->lua->pushBool(1);
    return 1;
}

int l_zip_file___gc(lua_State* L)
{
    ZipFile* zf = playdate->lua->getArgObject(1, ZIP_FILE_TYPE, NULL);
    if (zf)
    {
        playdate->system->realloc(zf, 0);
    }
    return 0;
}

int l_zip_file___index(lua_State* L);

lua_reg zip_file_reg[] = {
    {.name = "extract_to_string", .func = l_zip_file_extract_string},
    {.name = "extract_to_bytes", .func = l_zip_file_extract_bytes},
    {.name = "extract_to_file", .func = l_zip_file_extract_file},
    {.name = "__index", .func = l_zip_file___index},
    {.name = "__gc", .func = l_zip_file___gc},
    {.name = NULL, .func = NULL}
};

int l_zip_file___index(lua_State* L)
{
    ZipFile* zf = playdate->lua->getArgObject(1, ZIP_FILE_TYPE, NULL);
    if (!zf) return 0;
    
    const char* key = playdate->lua->getArgString(2);
    if (!key) return 0;
    
    if (index_reg(L, zip_file_reg, key)) return 1;
    
    if (!strcmp(key, "index"))
    {
        playdate->lua->pushInt(zf->stat.m_file_index + 1);
        return 1;
    }
    
    if (!strcmp(key, "crc32"))
    {
        // TODO: do encrypted and unsupported files have crc32?
        if (zf->stat.m_is_directory) return 0;
        
        char* s;
        playdate->system->formatString(&s, "%08X", zf->stat.m_crc32);
        playdate->lua->pushString(s);
        playdate->system->realloc(s, 0);
        return 1;
    }
    
    if (!strcmp(key, "comp_size"))
    {
        playdate->lua->pushInt(zf->stat.m_comp_size);
        return 1;
    }
    
    if (!strcmp(key, "uncomp_size"))
    {
        playdate->lua->pushInt(zf->stat.m_uncomp_size);
        return 1;
    }
    
    if (!strcmp(key, "is_directory"))
    {
        playdate->lua->pushBool(zf->stat.m_is_directory);
        return 1;
    }
    
    if (!strcmp(key, "is_encrypted"))
    {
        playdate->lua->pushBool(zf->stat.m_is_encrypted);
        return 1;
    }
    
    if (!strcmp(key, "is_supported"))
    {
        playdate->lua->pushBool(zf->stat.m_is_supported);
        return 1;
    }
    
    if (!strcmp(key, "filename"))
    {
        playdate->lua->pushString(zf->stat.m_filename);
        return 1;
    }
    
    if (!strcmp(key, "comment"))
    {
        playdate->lua->pushString(zf->stat.m_comment);
        return 1;
    }

    return 0;
}

int l_zip_file_extract(lua_State* L, bool toBytes)
{
    ZipFile* zf = playdate->lua->getArgObject(1, ZIP_FILE_TYPE, NULL);
    if (!zf) return 0;
    
    size_t size = zf->stat.m_uncomp_size;
    char* data = playdate->system->realloc(NULL, size+1);
    if (!data) return 0;
    
    bool result = mz_zip_reader_extract_to_mem(
        zf->pZip,
        zf->stat.m_file_index,
        data,
        size,
        0
    );
    if (!result) return 0;
    
    if (toBytes)
    {
        playdate->lua->pushBytes(data, size);
    }
    else
    {
        data[size] = 0;
        playdate->lua->pushString(data);
    }
    playdate->system->realloc(data, 0);
    return 1;
}

void zip_initLua(void)
{
    playdate->lua->registerClass(
        ZIP_TYPE, zip_reg, NULL, false, NULL
    );
    
    playdate->lua->registerClass(
        ZIP_FILE_TYPE, zip_file_reg, NULL, false, NULL
    );

    playdate->lua->addFunction(
        l_zip_open, FOS_LUA_PACKAGE ".zip_open", NULL
    );
}