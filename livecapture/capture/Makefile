default: capture.dll

capture.o: capture.c
	gcc -c -O -DCAPTURE_EXPORTS -DWINVER=0x0501 capture.c

capture.dll: capture.o
	gcc -shared -o capture.dll capture.o -lgdi32 -Wl,--out-implib,libcapture_dll.a

clean:
	rm -f capture.dll libcapture_dll.a capture.o
