assets.h: asset/*
	cd asset && ~/projects/res2h/res2h ../assets.h *

app: main.c assets.h
	cc -o app main.c libwebui-2-static.a -framework Cocoa -framework WebKit
