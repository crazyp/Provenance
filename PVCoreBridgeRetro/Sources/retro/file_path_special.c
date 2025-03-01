/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2011-2016 - Daniel De Matteis
 * 
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdlib.h>
#include <boolean.h>
#include <string.h>
#include <time.h>
#include <errno.h>

#ifdef _WIN32
#include <direct.h>
#else
#include <unistd.h>
#endif

#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#endif

#include <file/file_path.h>
#include <string/stdstring.h>

#include <compat/strl.h>
#include <compat/posix_string.h>
#include <retro_assert.h>
#include <retro_miscellaneous.h>

#include "configuration.h"
#include "file_path_special.h"

#include "runloop.h"
#include "verbosity.h"

void fill_pathname_expand_special(char *out_path,
      const char *in_path, size_t size)
{
#if !defined(RARCH_CONSOLE)
   if (*in_path == '~')
   {
      const char *home = getenv("HOME");
      if (home)
      {
         size_t src_size = strlcpy(out_path, home, size);
         retro_assert(src_size < size);

         out_path  += src_size;
         size      -= src_size;
         in_path++;
      }
   }
   else if ((in_path[0] == ':') &&
         (
         (in_path[1] == '/')
#ifdef _WIN32
         || (in_path[1] == '\\')
#endif
         )
            )
   {
      size_t src_size;
      char application_dir[PATH_MAX_LENGTH] = {0};

      fill_pathname_application_path(application_dir, sizeof(application_dir));
      path_basedir(application_dir);

      src_size   = strlcpy(out_path, application_dir, size);
      retro_assert(src_size < size);

      out_path  += src_size;
      size      -= src_size;
      in_path   += 2;
   }
#endif

   retro_assert(strlcpy(out_path, in_path, size) < size);
}


void fill_pathname_abbreviate_special(char *out_path,
      const char *in_path, size_t size)
{
#if !defined(RARCH_CONSOLE)
   unsigned i;
   const char *candidates[3];
   const char *notations[3];
   char application_dir[PATH_MAX_LENGTH] = {0};
   const char                      *home = getenv("HOME");

   /* application_dir could be zero-string. Safeguard against this.
    *
    * Keep application dir in front of home, moving app dir to a
    * new location inside home would break otherwise. */

   /* ugly hack - use application_dir pointer before filling it in. C89 reasons */
   candidates[0] = application_dir;
   candidates[1] = home;
   candidates[2] = NULL;

   notations [0] = ":";
   notations [1] = "~";
   notations [2] = NULL;

   fill_pathname_application_path(application_dir, sizeof(application_dir));
   path_basedir(application_dir);
   
   for (i = 0; candidates[i]; i++)
   {
      if (!string_is_empty(candidates[i]) && strstr(in_path, candidates[i]) == in_path)
      {
         size_t src_size  = strlcpy(out_path, notations[i], size);

         retro_assert(src_size < size);
      
         out_path        += src_size;
         size            -= src_size;
         in_path         += strlen(candidates[i]);
      
         if (!path_char_is_slash(*in_path))
         {
            retro_assert(strlcpy(out_path, path_default_slash(), size) < size);
            out_path++;
            size--;
         }

         break; /* Don't allow more abbrevs to take place. */
      }
   }
#endif

   retro_assert(strlcpy(out_path, in_path, size) < size);
}

bool fill_pathname_application_data(char *s, size_t len)
{
#if defined(_WIN32) && !defined(_XBOX)
   const char *appdata = getenv("APPDATA");

   if (appdata)
   {
      strlcpy(s, appdata, len);
      return true;
   }

#elif defined(OSX)
   const char *appdata = getenv("HOME");

   if (appdata)
   {
      fill_pathname_join(s, appdata,
            "Library/Application Support/RetroArch", len);
      return true;
   }
#elif !defined(RARCH_CONSOLE)
   const char *xdg     = getenv("XDG_CONFIG_HOME");
   const char *appdata = getenv("HOME");

   /* XDG_CONFIG_HOME falls back to $HOME/.config. */
   if (xdg)
   {
      fill_pathname_join(s, xdg, "retroarch", len);
      return true;
   }

   if (appdata)
   {
#ifdef __HAIKU__
      fill_pathname_join(s, appdata,
            "config/settings/retroarch/", len);
#else
      fill_pathname_join(s, appdata,
            ".config/retroarch/", len);
#endif
      return true;
   }
#endif

   return false;
}

#if !defined(RARCH_CONSOLE)
void fill_pathname_application_path(char *s, size_t len)
{
#ifdef __APPLE__
  CFBundleRef bundle = CFBundleGetMainBundle();
#endif
   size_t i;
   (void)i;

   if (!len)
      return;

#ifdef _WIN32
   DWORD ret = GetModuleFileName(GetModuleHandle(NULL), s, len - 1);
   s[ret] = '\0';
#elif defined(__APPLE__)
   if (bundle)
   {
      CFURLRef bundle_url = CFBundleCopyBundleURL(bundle);
      CFStringRef bundle_path = CFURLCopyPath(bundle_url);
      CFStringGetCString(bundle_path, s, len, kCFStringEncodingUTF8);
      CFRelease(bundle_path);
      CFRelease(bundle_url);
      
      retro_assert(strlcat(s, "nobin", len) < len);
      return;
   }
#elif defined(__HAIKU__)
   image_info info;
   int32 cookie = 0;

   while (get_next_image_info(0, &cookie, &info) == B_OK)
   {
      if (info.type == B_APP_IMAGE)
      {
         strlcpy(s, info.name, len);
         return;
      }
   }
#else
   {
      pid_t pid;
      static const char *exts[] = { "exe", "file", "path/a.out" };
      char link_path[PATH_MAX_LENGTH] = {0};

      *s        = '\0';
      pid       = getpid(); 

      /* Linux, BSD and Solaris paths. Not standardized. */
      for (i = 0; i < ARRAY_SIZE(exts); i++)
      {
         ssize_t ret;

         snprintf(link_path, sizeof(link_path), "/proc/%u/%s",
               (unsigned)pid, exts[i]);
         ret = readlink(link_path, s, len - 1);

         if (ret >= 0)
         {
            s[ret] = '\0';
            return;
         }
      }
   }
   
   ELOG(@"Cannot resolve application path! This should not happen.\n");
#endif
}
#endif

#ifdef HAVE_XMB
const char *xmb_theme_ident(void);
#endif

void fill_pathname_application_special(char *s, size_t len, enum application_special_type type)
{
   switch (type)
   {
      case APPLICATION_SPECIAL_DIRECTORY_AUTOCONFIG:
         {
            settings_t *settings     = config_get_ptr();
            fill_pathname_join(s,
                  settings->directory.autoconfig,
                  settings->input.joypad_driver,
                  len);
         }
         break;
      case APPLICATION_SPECIAL_DIRECTORY_CONFIG:
         {
            settings_t *settings     = config_get_ptr();
            global_t *global         = global_get_ptr();
            /* Try config directory setting first,
             * fallback to the location of the current configuration file. */
            if (!string_is_empty(settings->directory.menu_config))
               strlcpy(s, settings->directory.menu_config, len);
            else if (!string_is_empty(global->path.config))
               fill_pathname_basedir(s, global->path.config, len);
         }
         break;
      case APPLICATION_SPECIAL_DIRECTORY_ASSETS_ZARCH_ICONS:
#ifdef HAVE_ZARCH
         {
         }
#endif
         break;
      case APPLICATION_SPECIAL_DIRECTORY_ASSETS_ZARCH_FONT:
#ifdef HAVE_ZARCH
         {
            char s1[PATH_MAX_LENGTH] = {0};
            fill_pathname_application_special(s1, sizeof(s1),
                  APPLICATION_SPECIAL_DIRECTORY_ASSETS_ZARCH);
            fill_pathname_join(s,
                  s1, "Roboto-Condensed.ttf", len);
         }
#endif
         break;
      case APPLICATION_SPECIAL_DIRECTORY_ASSETS_ZARCH:
#ifdef HAVE_ZARCH
         {
            settings_t *settings     = config_get_ptr();
            fill_pathname_join(s, 
                  settings->directory.assets,
                  "zarch",
                  len);
         }
#endif
         break;
      case APPLICATION_SPECIAL_DIRECTORY_ASSETS_XMB_ICONS:
#ifdef HAVE_XMB
         {
            char s1[PATH_MAX_LENGTH] = {0};
            char s2[PATH_MAX_LENGTH] = {0};
            fill_pathname_application_special(s1, sizeof(s1),
                  APPLICATION_SPECIAL_DIRECTORY_ASSETS_XMB);
            fill_pathname_join(s2, s1, "png",
                  sizeof(s2));
            fill_pathname_slash(s2, sizeof(s2));
            strlcpy(s, s2, len);
         }
#endif
         break;
      case APPLICATION_SPECIAL_DIRECTORY_ASSETS_XMB_BG:
#ifdef HAVE_XMB
         {
            settings_t *settings     = config_get_ptr();

            if (!string_is_empty(settings->path.menu_wallpaper))
               strlcpy(s, settings->path.menu_wallpaper, len);
            else
            {
               char s1[PATH_MAX_LENGTH] = {0};
               fill_pathname_application_special(s1, sizeof(s1),
                     APPLICATION_SPECIAL_DIRECTORY_ASSETS_XMB_ICONS);
               fill_pathname_join(s, s1,
                     file_path_str(FILE_PATH_BACKGROUND_IMAGE),
                     len);
            }
         }
#endif
         break;
      case APPLICATION_SPECIAL_DIRECTORY_ASSETS_XMB:
#ifdef HAVE_XMB
         {
            char s1[PATH_MAX_LENGTH] = {0};
            char s2[PATH_MAX_LENGTH] = {0};
            settings_t *settings     = config_get_ptr();

            fill_pathname_join(
                  s1,
                  settings->directory.assets,
                  "xmb",
                  sizeof(s1));
            fill_pathname_join(s2,
                  s1, xmb_theme_ident(), sizeof(s2));
            strlcpy(s, s2, len);
         }
#endif
         break;
      case APPLICATION_SPECIAL_DIRECTORY_ASSETS_MATERIALUI:
#ifdef HAVE_MATERIALUI
         {
            settings_t *settings = config_get_ptr();

            fill_pathname_join(
                  s,
                  settings->directory.assets,
                  "glui",
                  len);
         }
#endif
         break;
      case APPLICATION_SPECIAL_DIRECTORY_ASSETS_MATERIALUI_ICONS:
#ifdef HAVE_MATERIALUI
         {
            char s1[PATH_MAX_LENGTH] = {0};
            fill_pathname_application_special(s1,
                  sizeof(s1), APPLICATION_SPECIAL_DIRECTORY_ASSETS_MATERIALUI);
            fill_pathname_slash(s1, sizeof(s1));
            strlcpy(s, s1, len);
         }
#endif
         break;
      case APPLICATION_SPECIAL_DIRECTORY_ASSETS_MATERIALUI_FONT:
#ifdef HAVE_MATERIALUI
         {
            char s1[PATH_MAX_LENGTH] = {0};
            fill_pathname_application_special(s1, sizeof(s1),
                  APPLICATION_SPECIAL_DIRECTORY_ASSETS_MATERIALUI);
            fill_pathname_join(s, s1, "Roboto-Regular.ttf", len);
         }
#endif
         break;
      case APPLICATION_SPECIAL_DIRECTORY_ASSETS_XMB_FONT:
#ifdef HAVE_XMB
         {
            settings_t *settings = config_get_ptr();

            if (!string_is_empty(settings->menu.xmb.font))
               strlcpy(s, settings->menu.xmb.font, len);
            else
            {
               char s1[PATH_MAX_LENGTH] = {0};
               fill_pathname_application_special(s1, sizeof(s1),
                     APPLICATION_SPECIAL_DIRECTORY_ASSETS_XMB);
               fill_pathname_join(s, s1,
                     file_path_str(FILE_PATH_TTF_FONT),
                     len);
            }
         }
#endif
         break;
      case APPLICATION_SPECIAL_NONE:
      default:
         break;
   }
}
