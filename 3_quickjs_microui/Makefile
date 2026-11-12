libquickjs.a:
	cd quickjs-2026-06-04 && make
	cp quickjs-2026-06-04/libquickjs.a .

main: main.m ui.c ui.h renderer.m renderer.h microui.c microui.h quickjs-2026-06-04/libquickjs.a
	cc -gdwarf -fsanitize=address -DDEV -Iquickjs-2026-06-04 -o main main.m ui.c microui.c renderer.m quickjs-2026-06-04/libquickjs.a -framework Cocoa

assets.h: app.js
	./res2h/res2h assets.h app.js

release: assets.h main.m ui.c ui.h renderer.m renderer.h microui.c microui.h quickjs-2026-06-04/libquickjs.a
	cc -O3 -Ires2h -Iquickjs-2026-06-04 -o release main.m ui.c microui.c renderer.m quickjs-2026-06-04/libquickjs.a -framework Cocoa
