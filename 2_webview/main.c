#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "webui.h"
#include "assets.h"

const char *not_found = "HTTP/1.1 404 Not Found\r\n\r\n";

const void *file_handler(size_t window, const char *filename, int *length) {
  printf("GET: %s\n", filename);
  size_t len;
  uint8_t *data;
  if (!get_resource(filename + 1, &len, &data)) {
    fprintf(stderr, "Resource not found: %s\n", filename + 1);
    *length = sizeof(not_found) - 1;
    return not_found;
  }

  char *header = webui_malloc(1024); // header
  char *type;
  if (strstr(filename, ".html"))
    type = "text/html";
  else if (strstr(filename, ".js"))
    type = "text/javascript";
  else if (strstr(filename, ".css"))
    type = "text/css";
  else
    type = "application/octet-stream";

  size_t header_len = snprintf(header, 1024,
                               "HTTP/1.1 200 OK\r\n"
                               "Content-Type: %s\r\n"
                               "Content-Length: %zu\r\n\r\n",
                               type, len);

  char *response = webui_malloc(header_len + len);
  memcpy(response, header, header_len);
  memcpy(response+header_len, data, len);
  *length = header_len + len;
  webui_free(header);

  return response;
}

int main(int argc, char **argv) {

  size_t app = webui_new_window();
  webui_set_file_handler_window(app, &file_handler);


  webui_show_wv(app, "/index.html");
  //webui_set_size(app, 600, 400);
  webui_wait();
  printf("done waiting!");
  return 0;
}
