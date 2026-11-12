#include <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>
#include "microui.h"
#include "renderer.h"

@interface MicroUIView : NSView
@property NSRect rect;
@property mu_Context *ctx;
@property RenderFunction render;
@property void *user_data; // the UI data pointer
@property NSImage *atlas;
@end

// attrs for font measurements
NSFont *font;
NSDictionary *attributes;

static int event_mouse_button(NSEvent *e) {
  //if(e.buttonNumber == 0) {
    return MU_MOUSE_LEFT;
    //}
}

static int event_key_code(NSEvent *e) {
  int k = 0;
  switch (e.keyCode) {
  case 36:
    k = MU_KEY_RETURN;
    break;
  case 51:
    k = MU_KEY_BACKSPACE;
    break;
  }
  return k;
}

#include "microui/demo/atlas.inl"

@implementation MicroUIView
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty {
  // Call the UI rendering function and then process the command array
  /*printf("DRAW! orig:(%.1f, %.1f) w: %.1f, h: %.1f\n", self.bounds.origin.x,
         self.bounds.origin.y, self.bounds.size.width,
         self.bounds.size.height);*/

  // clear bg
  [[NSColor blackColor] setFill];
  NSRectFill(self.frame);
  // printf("after fill bg, ctx is %p\n", self.ctx);
  //  Call render fn to create the UI
  mu_begin(self.ctx);
  bool rerender = self.render(self.ctx, self.user_data);
  mu_end(self.ctx);

  //printf("after render!\n");

  // Process MicroUI commands
  mu_Command *cmd = NULL;
  bool have_clip = false;
  [NSGraphicsContext saveGraphicsState];
  while (mu_next_command(self.ctx, &cmd)) {
    //printf("got cmd: %d\n", cmd->type);
    switch (cmd->type) {
    case MU_COMMAND_TEXT: {
      NSString *str = [NSString stringWithCString:cmd->text.str
                                         encoding:NSUTF8StringEncoding];
      [str drawAtPoint:NSMakePoint(cmd->text.pos.x, cmd->text.pos.y)
        withAttributes:attributes];

      // do we need to release or are they in the stack?
      //[attributes release];
      //[str release];
      break;
    }
    case MU_COMMAND_RECT: {
      mu_RectCommand r = cmd->rect;
      NSRect rect = NSMakeRect(r.rect.x, r.rect.y, r.rect.w, r.rect.h);
      //printf("draw rect x:%d,y:%d,w:%d,h:%d  \n", r.rect.x,r.rect.y,r.rect.w,r.rect.h);
      [[NSColor colorWithRed:(r.color.r/255.0)
                       green:(r.color.g/255.0)
                        blue:(r.color.b/255.0)
                       alpha:(r.color.a/255.0)] setFill];
      [NSBezierPath fillRect: rect];
      break;
    }
    case MU_COMMAND_ICON: {
      mu_IconCommand ic = cmd->icon;
      mu_Rect src = atlas[ic.id];
      NSRect at = NSMakeRect(ic.rect.x + (ic.rect.w - src.w) / 2,
                             ic.rect.y + (ic.rect.h - src.h) / 2,
                             src.w, src.h);
      NSRect from = NSMakeRect(src.x, ATLAS_HEIGHT-src.y-src.h , src.w, src.h);
      [[NSColor colorWithRed:(ic.color.r/255.0)
                       green:(ic.color.g/255.0)
                        blue:(ic.color.b/255.0)
                       alpha:(ic.color.a/255.0)] set];
      [self.atlas drawInRect:at
                    fromRect:from
                   operation:NSCompositingOperationSourceOver
                    fraction:1.0
              respectFlipped:YES
                       hints:nil];

      /*  printf("draw icon %d,\n  at:%.1f,%.1f (w:%.1f,h:%.1f)\nfrom:%.1f,%.1f "
             "(w:%.1f,h:%.1f)\n",
             ic.id, at.origin.x, at.origin.y, at.size.width,
             at.size.height,
             from.origin.x,from.origin.y,from.size.width,from.size.height
             );*/
      break;
    }
    case MU_COMMAND_CLIP: {
      if (have_clip)
        [NSGraphicsContext restoreGraphicsState];

      //mu_Rect r = cmd->clip.rect;
      //NSRect clip = NSMakeRect(r.x, r.y, r.w, r.h);
      //printf("set clip x:%d,y:%d,w:%d,h:%d\n", r.x, r.y, r.w, r.h);
      //[[NSColor redColor] setStroke];
      //[NSBezierPath strokeRect:clip];

      //NSRectClip(clip);
      break;
    }
    }
  }
  [NSGraphicsContext restoreGraphicsState];
  if (rerender) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsDisplay:YES];
      });
  }
}
- (BOOL)acceptsFirstResponder {
  return YES;
}

- (void)mouseMoved:(NSEvent *)e {
  NSPoint p = [self convertPoint:e.locationInWindow fromView:nil];
  //printf("mouse moved x: %.1f, y: %.1f\n",  p.x, p.y);
  mu_input_mousemove(self.ctx, p.x, p.y);
  [self setNeedsDisplay:YES];
}
- (void)mouseDragged:(NSEvent *)e {
  NSPoint p = [self convertPoint:e.locationInWindow fromView:nil];
  //printf("%p move x: %.1f, y: %.1f\n", self.ctx, p.x, p.y);
  mu_input_mousemove(self.ctx, p.x, p.y);
  [self setNeedsDisplay:YES];
}
- (void)mouseUp:(NSEvent *)e {
  NSPoint p = [self convertPoint:e.locationInWindow fromView:nil];
  //printf("mouse UP %d\n", event_mouse_button(e));
  mu_input_mouseup(self.ctx, p.x, p.y, event_mouse_button(e));
  [self setNeedsDisplay:YES];
}
- (void)mouseDown:(NSEvent *)e {
  NSPoint p = [self convertPoint:e.locationInWindow fromView:nil];
  //printf("mouse down %d\n", event_mouse_button(e));
  mu_input_mousedown(self.ctx, p.x, p.y, event_mouse_button(e));
  [self setNeedsDisplay:YES];
}
- (void)keyDown:(NSEvent *)e {
  int k = event_key_code(e);
  if (k) {
    mu_input_keydown(self.ctx, k);
  } else {
    NSString *chars = e.charactersIgnoringModifiers;
    char buf[512];
    [chars getCString:buf maxLength:512 encoding:NSUTF8StringEncoding];

    if (strlen(buf)) {
      mu_input_text(self.ctx, buf);
    }
  }
  [self setNeedsDisplay:YES];
}
- (void)keyUp:(NSEvent *)e {
  printf("key up: %d\n", e.keyCode);
  int k = event_key_code(e);
  if (k) {
    mu_input_keyup(self.ctx, e.keyCode);
    [self setNeedsDisplay:YES];
  }
}
// - (void)viewDidEndLiveResize {
//   printf("RESIZE END!\n");
//   [super viewDidEndLiveResize];
//   [self setNeedsDisplay:YES];

// }
@end


static NSApplication *app;
static NSWindow *window;
static MicroUIView *view;


int text_width(mu_Font mfont, const char *text, int len) {

  NSString *txt = [NSString stringWithCString:text
                                      encoding:NSUTF8StringEncoding];
  NSSize size = [txt sizeWithAttributes:attributes];

  CGFloat width = size.width;
  //[txt release];
  //[attributes release];
  //[font release];
  return (int)width;
}

int text_height(mu_Font font) {
  return 12;
}

NSImage *prepare_atlas() {
  // Create the bitmap representation
  int width = ATLAS_WIDTH;
  int height = ATLAS_HEIGHT;
  unsigned char *pixels = atlas_texture;

  NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
                            initWithBitmapDataPlanes:NULL
                                          pixelsWide:width
                                          pixelsHigh:height
                                       bitsPerSample:8
                                     samplesPerPixel:1          // grayscale
                                            hasAlpha:NO         // ← must be NO
                                            isPlanar:NO
                                      colorSpaceName:NSDeviceWhiteColorSpace
                                         bytesPerRow:width
                                        bitsPerPixel:8];

  memcpy([rep bitmapData], pixels, width * height);

  NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
  [image addRepresentation:rep];
  return image;
}

void run_microui(MicroUI *opts) {
  font = [NSFont systemFontOfSize:12.0];
  attributes = @{NSFontAttributeName : font, NSForegroundColorAttributeName: [NSColor whiteColor]};

  /* init SDL window */
  app = [NSApplication sharedApplication];
  [app setActivationPolicy:NSApplicationActivationPolicyRegular];


  NSRect frame = NSMakeRect(0, 0, opts->width, opts->height);
  window = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [window setAcceptsMouseMovedEvents:YES];
  // Create and add our MicroUIView to the window
  view = [[MicroUIView alloc] initWithFrame:frame];
  view.ctx = malloc(sizeof(mu_Context));
  view.rect = frame;
  view.user_data = opts->data;
  view.render = opts->render;
  view.atlas = prepare_atlas();
  mu_init(view.ctx);
  opts->ctx = view.ctx;
  if(opts->init) {
    opts->init(opts);
  }
  view.ctx->text_width = text_width;
  view.ctx->text_height = text_height;

  [window setAcceptsMouseMovedEvents:YES];
  [window setContentView: view];

  // Set window title by converting from given C string
  [window setTitle:[NSString stringWithCString:opts->title
                                      encoding: NSUTF8StringEncoding]];

  [window center];
  [window makeKeyAndOrderFront:nil];
  [app run];

}
