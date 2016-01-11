#ifndef _DEFINED_CAPTURE_H
#define _DEFINED_CAPTURE_H

#if _MSC_VER > 1000
#pragma once
#endif

#ifdef __cplusplus
extern "C" {
#endif

  /*
The following ifdef block is the standard way of creating macros which
make exporting from a DLL simpler. All files within this DLL are
compiled with the CAPTURE_EXPORTS symbol defined on the command
line. this symbol should not be defined on any project that uses this
DLL. This way any other project whose source files include this file
see CAPTURE_API functions as being imported from a DLL, whereas this
DLL sees symbols defined with this macro as being exported.
  */
#ifdef CAPTURE_EXPORTS
#define CAPTURE_API __declspec(dllexport)
#else
#define CAPTURE_API __declspec(dllimport)
#endif

#define CAPTURE_WINDOW   (0x0)
#define CAPTURE_CLIENT   (0x1)
#define CAPTURE_RECT     (0x2)
#define CAPTURE_REVERSE  (0x4)

CAPTURE_API BOOL CaptureNew(HWND hWnd, int getStyle,
			    float blackFault, int forceBlack);
CAPTURE_API BOOL CaptureSetRect(HWND hWnd,
				int leftOffset, int topOffset,
				int rightOffset, int bottomOffset);
CAPTURE_API BOOL CaptureSnap(HWND hWnd);
CAPTURE_API BOOL CaptureClear(HWND hWnd);
CAPTURE_API BOOL CaptureGetInfo(HWND hWnd,
				int *w, int *h, int *nbBlack, int *signature);
CAPTURE_API BOOL CaptureGetData(HWND hWnd, BYTE *dta);
CAPTURE_API char *CaptureGetLastError(HWND hWnd);
CAPTURE_API BOOL CaptureGetPPM(HWND hWnd, BYTE *dta);
CAPTURE_API BOOL CaptureDelete(HWND hWnd);
CAPTURE_API BOOL CaptureExists(HWND hWnd);


#ifdef __cplusplus
}
#endif

#endif
