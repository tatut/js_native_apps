#ifndef APP_H
#define APP_H
typedef struct {
  JSContext *js;
  JSValue m_obj;
  JSAtom main_name;
} App;
#endif
