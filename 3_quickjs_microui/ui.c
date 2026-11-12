/* MicroUI <-> QuickJS bindings module.
 * Exposes immediate mode rendering as convenient JS module.
 *
 * All begin/end pairs take a function, etc.
 * instead of in C:
 *  mu_begin_panel(ctx,"my panel");
 *  ...contents...
 *  mu_end_panel(ctx)
 *
 * we call in JS:
 *  ctx.panel("my panel", ()=>{
 *    ...contents...
 *  });
*/
#include "microui.h"
#include "quickjs.h"
#include <stdbool.h>
#include "app.h"
#include "renderer.h"
#include <alloca.h>

static JSClassID js_context_class_id;

#define _tmp_size 4096
char _tmp[4096]; // tmp C string buffer to use during calls

#define TMP _tmp, _tmp_size


void js_context_finalizer(JSRuntime *rt, JSValue val) {
  // NOTE: Do nothing, we don't want mu_Context to be destroyed
}

static JSClassDef js_context_class = {.class_name = "Context",
                                      .finalizer = js_context_finalizer};

static JSValue js_context_ctor(JSContext *ctx, JSValue new_target, int argc,
                               JSValue *argv) {
  JSValue obj, proto;
  proto = JS_GetPropertyStr(ctx, new_target, "prototype");
  obj = JS_NewObjectProtoClass(ctx, proto, js_context_class_id);
  JS_FreeValue(ctx, proto);
  return obj;
}

static mu_Context *mctx;
void ui_set_mu_context(mu_Context *ctx) { mctx = ctx; }
JSClassID ui_get_context_class_id() { return js_context_class_id; }


#define ENSURE(x)                                                              \
  do {                                                                         \
    if ((x) < 0) {                                                             \
      fprintf(stderr, "Failed at " __FILE__ ", line: %d", __LINE__);           \
      success = false;                                                         \
      goto done;                                                               \
    }                                                                          \
  } while (false)


#define UI_INIT(num_args)                                                      \
  bool success = true;                                                         \
  ENSURE(argc < num_args ? -1 : 0)

#define UI_RETURN                                                              \
  done:                                                                        \
  if (!success) {                                                              \
    return JS_FALSE;                                                           \
  }                                                                            \
  return JS_NULL;

static JSValue ui_begin_window(JSContext *ctx, JSValue this_val, int argc,
                               JSValue *argv) {
  UI_INIT(5);
  JS_CopyToCString(ctx, argv[0], TMP);

  mu_Rect rect;
  ENSURE(JS_ToInt32(ctx, &rect.x, argv[1]));
  ENSURE(JS_ToInt32(ctx, &rect.y, argv[2]));
  ENSURE(JS_ToInt32(ctx, &rect.w, argv[3]));
  ENSURE(JS_ToInt32(ctx, &rect.h, argv[4]));

  if (mu_begin_window(mctx, _tmp, rect)) {
    mu_Container *win = mu_get_current_container(mctx);
    win->rect.w = mu_max(win->rect.w, rect.w); // apply min size
    win->rect.h = mu_max(win->rect.h, rect.h);
    return JS_TRUE;

    //mu_header(mctx, title);
    //mu_end_window(mctx);
  }
  return JS_FALSE;
  UI_RETURN
}

#define UI_DEF static JSValue
#define UI_ARGS JSContext *ctx, JSValue this_val, int argc, JSValue *argv
#define UI_ZERO_ARG(name)                                                      \
  static JSValue ui_##name(JSContext *ctx, JSValue this_val, int argc,         \
                           JSValue *argv) {                                    \
    UI_INIT(0);                                                                \
    mu_##name(mctx);                                                           \
    return JS_TRUE;                                                            \
    UI_RETURN                                                                  \
  }

UI_ZERO_ARG(end_window);
UI_ZERO_ARG(layout_begin_column);
UI_ZERO_ARG(layout_end_column);


UI_DEF ui_layout_row(UI_ARGS) {
  int cols = argc - 1;
  int *widths;
  int height;
  UI_INIT(2);
  widths = (int*) alloca(sizeof(int)*cols); // stack allocate
  for (int i = 0; i < argc - 1; i++) {
    ENSURE(JS_ToInt32(ctx, &widths[i], argv[i]));
  }
  ENSURE(JS_ToInt32(ctx, &height, argv[argc - 1]));
  //  printf("UI LAYOUT ROW cols=%d\n",
  mu_layout_row(mctx, cols, widths, height);
  return JS_TRUE;
  UI_RETURN
}

static JSValue ui_textbox(UI_ARGS) {
  UI_INIT(1);
  JSValue obj = argv[0];
  JSValue value = JS_GetPropertyStr(ctx, obj, "value");
  JS_CopyToCString(ctx, value, TMP);
  JS_SetPropertyStr(ctx, obj, "submit", JS_FALSE);
  int ret = mu_textbox(mctx, _tmp, _tmp_size);
  JS_SetPropertyStr(ctx, obj, "value", JS_NewString(ctx, _tmp));
  //printf("textbox ret: %d\n", ret);
  JS_SetPropertyStr(ctx, obj, "submit", (ret & MU_RES_SUBMIT) ? JS_TRUE : JS_FALSE);
  UI_RETURN
}

static JSValue ui_checkbox(UI_ARGS) {
  UI_INIT(2);
  JS_CopyToCString(ctx, argv[0], TMP);
  int checked;
  ENSURE(JS_ToInt32(ctx, &checked, argv[1]));
  mu_push_id(mctx, TMP);
  mu_checkbox(mctx, _tmp, &checked);
  mu_pop_id(mctx);
  //printf("%s checked: %d\n", _tmp, checked);
  return checked ? JS_TRUE : JS_FALSE;
  UI_RETURN
}

static JSValue ui_button(UI_ARGS) {
  UI_INIT(1);
  JS_CopyToCString(ctx, argv[0], TMP);
  if (mu_button(mctx, _tmp))
    return JS_TRUE;
  else
    return JS_FALSE;
  UI_RETURN
}

UI_DEF ui_begin_panel(UI_ARGS) {
  UI_INIT(1);
  JS_CopyToCString(ctx, argv[0], TMP);
  mu_begin_panel(mctx, _tmp); // PENDING: keep current mu_Container ref, for scroll
  UI_RETURN
}

UI_ZERO_ARG(end_panel);

UI_DEF ui_text(UI_ARGS) {
  UI_INIT(1);
  JS_CopyToCString(ctx, argv[0], TMP);
  mu_text(mctx, _tmp);
  UI_RETURN
}

UI_DEF ui_label(UI_ARGS) {
  UI_INIT(1);
  JS_CopyToCString(ctx, argv[0], TMP);
  mu_label(mctx, _tmp);
  UI_RETURN
}


UI_DEF ui_log(UI_ARGS) {
  UI_INIT(1);
  JS_CopyToCString(ctx, argv[0], TMP);
  printf("UI: %s\n", _tmp);
  UI_RETURN
}

static JSValue ui_scrollable(JSContext *ctx, JSValue this_val, int argc,
                             JSValue *argv) {
  printf("scrollable!\n");
  UI_INIT(2);
  char title[64];
  ENSURE(argc == 3);
  JS_CopyToCString(ctx, argv[0], title, 64);
  mu_begin_panel(mctx, title);
  mu_Container *panel = mu_get_current_container(mctx);
  printf("js is array? %d\n", JS_IsArray(ctx, argv[1]));
         //mu_layout_row(mctx,

  //JS_EvalFunction(ctx, argv[1]);
  mu_end_panel(mctx);

 UI_RETURN
}

typedef struct UIFun {
  JSCFunction *fun;
  const char *name;
  int args;
} UIFun;

UIFun ui_functions[] = {
    {.name = "begin_window", .fun = ui_begin_window, .args = 5},
    {.name = "end_window", .fun = ui_end_window, .args = 0},
    {.name = "scrollable", .fun = ui_scrollable, .args = 3},
    {.name = "textbox", .fun = ui_textbox, .args = 1},
    {.name = "checkbox", .fun = ui_checkbox, .args = 2},
    {.name = "button", .fun = ui_button, .args = 1},
    {.name = "layout_row", .fun = ui_layout_row, .args = 2},
    {.name = "begin_panel", .fun = ui_begin_panel, .args = 1},
    {.name = "end_panel", .fun = ui_end_panel, .args = 0},
    {.name = "text", .fun = ui_text, .args = 1},
    {.name = "label", .fun = ui_label, .args = 1},
    {.name = "log", .fun = ui_log, .args = 1},
    {.name = "layout_begin_column", .fun = ui_layout_begin_column, .args = 0},
    {.name = "layout_end_column", .fun = ui_layout_end_column, .args = 0},
};
#define NUM_UI_FUNCTIONS (sizeof(ui_functions)/sizeof(UIFun))

void ui_js_bind(JSContext *ctx) {
  JSValue global, ui;
  global = JS_GetGlobalObject(ctx);
  ui = JS_NewObject(ctx);
  for (int i = 0; i < NUM_UI_FUNCTIONS; i++) {
    UIFun fn = ui_functions[i];
    //printf("setting ui function: %s\n", ui_functions[i].name);
    JS_SetPropertyStr(ctx, ui, fn.name,
                      JS_NewCFunction(ctx, fn.fun, fn.name, fn.args));
  }
  JS_SetPropertyStr(ctx, global, "ui", ui);
  JS_FreeValue(ctx, global);
}

void ui_init(MicroUI *mui) {
  mctx = mui->ctx;
  JSContext *ctx = ((App *)mui->data)->js;
  ui_js_bind(ctx);
}
