/***************************************************************************
                    
    copyright            : (C) 2006 by mean
    email                : fixounet@free.fr
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#include <dirent.h>
#include <errno.h>
#include <copyfile.h>
#include <ftw.h>
#include <stdio.h>
#include <sys/stat.h>
#include <string>
#include <sys/stdio.h>
#include <Carbon/Carbon.h>
#include <unistd.h>

#include "ADM_default.h"
extern char *ADM_getRelativePath(const char *base0, const char *base1, const char *base2, const char *base3);

#define MAX_PATH_SIZE 4096

static char ADM_basedir[MAX_PATH_SIZE] = {0};
static std::string ADM_autodir;
static std::string ADM_systemPluginSettings;


#undef fread
#undef fwrite
#undef fopen
#undef fclose

/**
    \fn ADM_getAutoDir
    \brief  Get the  directory where auto script are stored. No need to free the string.
******************************************************/
const std::string ADM_getAutoDir(void)
{
    if (ADM_autodir.size())
        return ADM_autodir;

    const char *startDir="../lib";
    const char *s = ADM_getInstallRelativePath(startDir, ADM_PLUGIN_DIR, "autoScripts");
    ADM_autodir = s;
    delete [] s;
    s=NULL;
    return ADM_autodir;
}
/**
    \fn ADM_getPluginSettingsDir
    \brief Get the folder containing the plugin settings (presets etc..)
*/
const std::string ADM_getSystemPluginSettingsDir(void)
{
    if(ADM_systemPluginSettings.size())
        return ADM_systemPluginSettings;

    const char *startDir="../lib";
    const char *s = ADM_getInstallRelativePath(startDir, ADM_PLUGIN_DIR, "pluginSettings");
    ADM_systemPluginSettings = s;
    delete [] s;
    s=NULL;
    return ADM_systemPluginSettings;
}


static void AddSeparator(char *path)
{
    if (path && (strlen(path) < strlen(ADM_SEPARATOR) || strncmp(path + strlen(path) - strlen(ADM_SEPARATOR), ADM_SEPARATOR, strlen(ADM_SEPARATOR)) != 0))
        strcat(path, ADM_SEPARATOR);
}

static bool makeDirectories(const std::string &path)
{
    if (path.empty() || path.size() >= MAX_PATH_SIZE)
        return false;

    char mutablePath[MAX_PATH_SIZE];
    strcpy(mutablePath, path.c_str());
    for (char *cursor = mutablePath + 1; *cursor; ++cursor)
    {
        if (*cursor != '/')
            continue;
        *cursor = '\0';
        if (mkdir(mutablePath, 0755) != 0 && errno != EEXIST)
            return false;
        *cursor = '/';
    }
    if (mkdir(mutablePath, 0755) != 0 && errno != EEXIST)
        return false;

    struct stat info;
    return stat(mutablePath, &info) == 0 && S_ISDIR(info.st_mode);
}

static bool isDirectory(const std::string &path)
{
    struct stat info;
    return stat(path.c_str(), &info) == 0 && S_ISDIR(info.st_mode);
}

static int removeTreeEntry(const char *path, const struct stat *info, int type, struct FTW *walk)
{
    UNUSED_ARG(type);
    UNUSED_ARG(walk);
    if (info && S_ISDIR(info->st_mode))
        chmod(path, 0700);
    if (remove(path) == 0 || errno == ENOENT)
        return 0;
    return -1;
}

static void removeTree(const std::string &path)
{
    nftw(path.c_str(), removeTreeEntry, 16, FTW_DEPTH | FTW_PHYS);
}

/**
 *     \fn char *ADM_getHomeRelativePath(const char *base1, const char *base2=NULL,const char *base3=NULL);
 *  \brief Returns home directory +base 1 + base 2... The return value is a copy, and must be deleted []
 */
char *ADM_getHomeRelativePath(const char *base1, const char *base2, const char *base3)
{
    return ADM_getRelativePath(ADM_getBaseDir(), base1, base2, base3);
}

char *ADM_getInstallRelativePath(const char *base1, const char *base2, const char *base3)
{
    char buffer[MAX_PATH_SIZE];

    CFURLRef url(CFBundleCopyExecutableURL(CFBundleGetMainBundle()));
    buffer[0] = '\0';

    if (url)
    {
        CFURLGetFileSystemRepresentation(url, true, (UInt8*)buffer, MAX_PATH_SIZE);
        CFRelease(url);

        char *slash = strrchr(buffer, '/');
        
        if (slash)
            *slash = '\0';
    }

    return ADM_getRelativePath(buffer, base1, base2, base3);
}

/*
      Get the root directory for .avidemux stuff
******************************************************/
const char *ADM_getBaseDir(void)
{
    return ADM_basedir;
}

/**
 * \fn ADM_getConfigBaseDir
 * \brief Get the root directory for avidemux configuration
 */
const char *ADM_getConfigBaseDir(void)
{
    return ADM_basedir;
}
/**
 */
void ADM_initBaseDir(int argc, char *argv[])
{
    UNUSED_ARG(argc);
    UNUSED_ARG(argv);

    const char* homeEnv = getenv("HOME");

    if (!homeEnv)
    {
        ADM_warning("Oops: can't determine $HOME.");
        return;
    }
    const std::string home(homeEnv);
    const std::string legacyDir = home + "/.avidemux6";
    const std::string appSupportDir = home + "/Library/Application Support";
    const std::string appDir = appSupportDir + "/Avidemux Mac";
    struct stat appDirInfo;

    // Keep the legacy tree intact. On first launch of this fork, copy the
    // complete user data tree so preferences, jobs, presets, scripts and
    // user-installed plugins are copied. Plugins for a different CPU
    // architecture are rejected later by the dynamic loader.
    bool useAppSupport = false;
    if (lstat(appDir.c_str(), &appDirInfo) == 0)
    {
        useAppSupport = S_ISDIR(appDirInfo.st_mode);
        if (!useAppSupport)
            ADM_warning("Avidemux Mac config path exists but is not a directory: %s\n", appDir.c_str());
    }
    else if (errno == ENOENT)
    {
        if (makeDirectories(appSupportDir) && isDirectory(legacyDir))
        {
            const std::string stagingDir = appSupportDir + "/Avidemux Mac.migration-" +
                std::to_string(static_cast<long long>(getpid()));
            removeTree(stagingDir);
            if (copyfile(legacyDir.c_str(), stagingDir.c_str(), NULL,
                         COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_NOFOLLOW_SRC | COPYFILE_EXCL) != 0)
            {
                ADM_warning("Could not migrate existing settings from %s to %s: %s\n",
                            legacyDir.c_str(), appDir.c_str(), strerror(errno));
                removeTree(stagingDir);
            }
            else
            {
                // Publish the complete copy atomically and never replace a
                // fork config created by another process.
                if (renamex_np(stagingDir.c_str(), appDir.c_str(), RENAME_EXCL) == 0)
                    useAppSupport = true;
                else if (errno == EEXIST && isDirectory(appDir))
                    useAppSupport = true;
                else
                {
                    ADM_warning("Could not publish migrated settings at %s: %s\n",
                                appDir.c_str(), strerror(errno));
                    removeTree(stagingDir);
                }
                if (useAppSupport)
                {
                    removeTree(stagingDir);
                    ADM_info("Copied existing user data from %s to %s\n",
                             legacyDir.c_str(), appDir.c_str());
                }
            }
        }
        else if (makeDirectories(appSupportDir) && !isDirectory(legacyDir))
        {
            useAppSupport = makeDirectories(appDir);
        }
    }

    std::string selectedPath = useAppSupport ? appDir : legacyDir;
    if (selectedPath.size() + strlen(ADM_SEPARATOR) >= sizeof(ADM_basedir))
    {
        ADM_error("Avidemux configuration path is too long: %s\n", selectedPath.c_str());
        return;
    }
    strcpy(ADM_basedir, selectedPath.c_str());
    AddSeparator(ADM_basedir);

    if (ADM_mkdir(ADM_basedir))
        ADM_info("Using \"%s\" as base directory for prefs, jobs, etc.\n", ADM_basedir);
    else
        ADM_error("Cannot create Avidemux configuration directory (\"%s\")\n", ADM_basedir);
}
/**
 * \fn ADM_getI8NDir
 */
const std::string ADM_getI8NDir(const std::string &flavor)
{
    std::string partialPath = flavor;
    partialPath += "/i18n";
#ifdef CREATE_BUNDLE
    char *ppath=ADM_getInstallRelativePath("../Resources/share","avidemux6",partialPath.c_str());
#else
    char *ppath=ADM_getInstallRelativePath("../share","avidemux6",partialPath.c_str());
#endif
    std::string r = ppath;
    delete [] ppath;
    ppath=NULL;
    return  r;
    
}

#include "ADM_folder_unix.cpp"
// EOF
