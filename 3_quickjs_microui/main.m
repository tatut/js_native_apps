#include "microui.h"
#import <Cocoa/Cocoa.h>
#include <Foundation/Foundation.h>
#include "renderer.h"
#include "quickjs.h"
#include "quickjs-libc.h"
#include <string.h>
#include <stdlib.h>
#include "ui.h"
#include <stdio.h>
#include <sys/stat.h>
#include <time.h>
#include <pthread.h>
#include "app.h"

void ui(mu_Context *ctx) {
  if (mu_begin_window(ctx, "testing 1 2 3", mu_rect(40, 40, 500, 300))) {
    mu_Container *win = mu_get_current_container(ctx);
    win->rect.w = mu_max(win->rect.w, 240); // apply min size
    win->rect.h = mu_max(win->rect.h, 300);

    if (mu_header(ctx, "jotain")) {
      mu_layout_row(ctx, 2, (int[]){100, -1}, 0);
      mu_label(ctx, "Position:");
      char buf[64];
      snprintf(buf, 64, "%d, %d", win->rect.x, win->rect.y);
      mu_label(ctx, buf);
      mu_label(ctx, "Size:");
      snprintf(buf, 64, "%d, %d", win->rect.w, win->rect.h);
      mu_label(ctx, buf);
    }
    mu_end_window(ctx);
  }
}

bool render(mu_Context *ctx, void *data) {
  App *app = (App*)data;
  //xui(ctx);
  JSValue ret = JS_Call(app->js, app->m_obj, app->m_obj, 0, NULL);
  if (JS_IsException(ret)) {
    JSValue ex = JS_GetException(app->js);
    const char *ex_msg = JS_ToCString(app->js, ex);
    printf("m_str: %s\n", ex_msg);
    JS_FreeCString(app->js, ex_msg);
  } else if (ret.tag == JS_TAG_STRING) {
    char buf[64];
    int len = JS_CopyToCString(app->js, ret, buf, 64);
    printf("returned: '%.*s'\n", len, buf);
  }
  // If boolean true, return true to rerender
  return (JS_IsBool(ret) && ret.u.uint64);
}

// In dev mode, load directly from app.js file
#ifdef DEV

void *hot_reload_thread(void *app_ptr) {
  App *app = (App*)app_ptr;
  struct timespec rqtp;
  struct stat st;
  time_t loaded = 0;

  while (1) {
    rqtp = (struct timespec){.tv_nsec = 100000000};
    nanosleep(&rqtp, NULL);

    stat("app.js", &st);

    //printf("mtime %d > loaded %d  ? %d\n", st.st_mtime, loaded, st.st_mtime>loaded);
    if (!loaded) {
      loaded = st.st_mtime;
    } else if (st.st_mtime > loaded) {
      FILE *f = fopen("app.js", "r");
      if (!f) goto fail;
      size_t sz = st.st_size;
      char *src = malloc(sz);
      if (!src)
        goto fail;
      if (sz != fread(src, 1, sz, f))
        goto fail;

      JSRuntime *rt = JS_NewRuntime();
      JSContext *js = JS_NewContext(rt);

      js_std_add_helpers(js, 0, NULL);

      JS_Eval(js, src, sz, "app.js", JS_EVAL_TYPE_GLOBAL);
      JSAtom main_name = JS_NewAtom(js, "main");

      JSValue global = JS_GetGlobalObject(js);
      app->js = js;
      app->main_name = main_name;
      app->m_obj = JS_GetProperty(app->js, global, app->main_name);
      ui_js_bind(js);
      const char *m_str = JS_ToCString(app->js, app->m_obj);
      printf("new main m_str: %s\n", m_str);
      JS_FreeCString(app->js, m_str);
      free(src);
      loaded = st.st_mtime;
      fclose(f);
    }

  }
  return NULL;
 fail:
  fprintf(stderr,"Failed to read app.js!\n");
  return NULL;
}

void load_app_js(App *app) {
  JSContext *ctx = app->js;
  FILE *f = fopen("app.js", "r");
  if (!f) goto fail;
  struct stat stat;
  fstat(fileno(f), &stat);

  size_t sz = stat.st_size;
  char *src = malloc(sz);
  if (!src)
    goto fail;
  if (sz != fread(src, 1, sz, f))
    goto fail;

  printf("JS src:\n-------\n%.*s\n--------\n", sz, src);
  JS_Eval(ctx, src, sz, "app.js", JS_EVAL_TYPE_GLOBAL);
  pthread_t t;
  pthread_create(&t, NULL, hot_reload_thread, app);
  return;
fail:
  fprintf(stderr, "Couldn't load app.js");
  if (src)
    free(src);
  if(f) fclose(f);
}
#endif

// If not dev mode, load from included assets.h file
#ifndef DEV
#include "assets.h"
void load_app_js(App *app) {
  JSContext *ctx = app->js;
  char *src;
  size_t len;
  get_resource("app.js", &len, (uint8_t**)&src);
  JS_Eval(ctx, src, len, "app.js", JS_EVAL_TYPE_GLOBAL);
  printf("GOT APP JS\n-------\n%.*s\n----------\n", len, src);
}
#endif


int main(int argc, char **argv) {
  /* init JS */
  JSRuntime *rt = JS_NewRuntime();
  JSContext *js = JS_NewContext(rt);

  js_std_add_helpers(js, 0, NULL);

  App app = (App){.js = js, .main_name=JS_NewAtom(js, "main")};
  load_app_js(&app);

  app.m_obj = JS_GetGlobalObject(js);
  app.m_obj = JS_GetProperty(js, app.m_obj, app.main_name);

  const char *m_str = JS_ToCString(js, app.m_obj);
  printf("m_str: %s\n", m_str);

  size_t len;

  /* init microui */
  MicroUI opts = {
    .width = 800,
    .height = 600,
    .render = render,
    .init = ui_init,
    .title = "Todo MicroUI+Cocoa+JS",
    .data = &app
  };
  run_microui(&opts);

}
