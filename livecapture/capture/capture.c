/* =========================================================================
 * Module Name     --  capture.cpp
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   This module implements a wrapper around the PrintWindow()
 *   facility introducced in Windows XP.  PrintWindow() is able to
 *   capture a window even if it is hidden under other windows on the
 *   desktop.  It presents itself with a little-weird interface so as
 *   to be easily interfaced from scripting languages that can declare
 *   commands equivalent for DLL entries.
 *
 *   The polling frequency is up to the caller, the latest resulting
 *   image being always available.  This library attempts to get
 *   around a bug in PrintWindow which seems to "miss" some zones of
 *   the windows sometime.  As a result, the latest capture will only
 *   erase totally the previous capture if there are not too many
 *   black pixels, otherwise the capture will only copy pixels that
 *   are not black.  It is also possible to zero completely the
 *   capture buffer from time to time to prevent too bad captures.
 *
 * ========================================================================= */


#include <windows.h>
#include <wingdi.h>
#include <winuser.h>
#include <stdio.h>
#include <malloc.h>
#include <Tchar.h>

#include "capture.h"

#define ERRBUF_SIZE (256)
#define SIGNATURE_SKIP (20)
#define CAPTURE_ERROR(c, msg) \
        __capture_store_error((c), (msg), __FILE__, __LINE__)

HINSTANCE g_hInstance;


/* + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +
 * Structure Name  --  LiveCapture
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   This structure holds the context of each on-going known live
 *   capture, including the RGB bits of the latest captured content of
 *   the window at any time.
 *
 * + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + */
struct LiveCapture {
  HWND	  win;              /* Handle of window being captured */
  int     getStyle;         /* Flags for get operations */
  int     leftOffset;       /* Offset from left when getStyle has RECT */
  int     topOffset;        /* Offset from top when getStyle has RECT */ 
  int     rightOffset;      /* Offset from right when getStyle has RECT */
  int     bottomOffset;     /* Offset from bottom when getStyle has RECT */
  float	  blackFault;       /* Ratio of black pixels to count as faulty */
  char    err[ERRBUF_SIZE]; /* Buffer for storing latest error */

  BYTE    *pic;             /* Pointer to latest updated capture */
  int	  width;            /* Current width */
  int	  height;           /* Current height */
  int     nbBlackPixels;    /* Number of black pixels at latest capture */
  int     successiveBlacks; /* Number of successive faulty (too black) pics */
  int     signature;        /* Signature of latest capture */
  int     forceBlack;       /* How often should we force to black on faulty */
  BYTE    *rawbits;         /* Raw bits for BitBlt copies from window DC */
  HBITMAP bmp;              /* Latest created bitmap */

  struct LiveCapture *next; /* Link to next capture */
};

struct LiveCapture *all_captures = NULL;


#ifdef _MANAGED
#pragma managed(push, off)
#endif

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
					 )
{
	switch (ul_reason_for_call)
	{
	case DLL_PROCESS_ATTACH:
		g_hInstance = hModule;
		break;
	case DLL_THREAD_ATTACH:
	case DLL_THREAD_DETACH:
	case DLL_PROCESS_DETACH:
		break;
	}
    return TRUE;
}

#ifdef _MANAGED
#pragma managed(pop)
#endif

static void __capture_store_error(struct LiveCapture *c, char *msg, char *fname,
				  int lineno);


/* ------------------------------------------------------------------------
 * Function Name   --  __capture_find
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Find if there an existing capture for a given window (handle) and
 *   return a pointer to it, NULL otherwise.
 *
 * ------------------------------------------------------------------------ */
static struct LiveCapture *
__capture_find(HWND hWnd)
{
  struct LiveCapture *c = NULL;

  for (c=all_captures; c; c = c->next) {
    if (c->win == hWnd) {
      return c;
    }
  }
		
  return NULL;
}



/* ------------------------------------------------------------------------
 * Function Name   --  __capture_exec
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Execute window capturing, this is a wrapper around PrintWindow().
 *   The implementation loads the function from the DLL dynamically,
 *   which allows the DLL to "scream" nicely on OSes that do not have
 *   the facility.
 *
 * ------------------------------------------------------------------------ */
static BOOL
__capture_exec(HWND hwnd,HDC memDC,BOOL contentonly)
{
  int Ret = TRUE;
  HINSTANCE handle;

  typedef BOOL (WINAPI *tPrintWindow)( HWND, HDC,UINT);

  /* Find a handle to the PrintWindow function and store it in
     tPrintWindow */
  tPrintWindow pPrintWindow = 0;
  handle = LoadLibrary("User32.dll");
  if ( handle == 0 ) 
    return FALSE;

  pPrintWindow = (tPrintWindow)GetProcAddress(handle, "PrintWindow");

  /* Now capture the window in the DC passed as argument. */
  if ( pPrintWindow ) {
    if (contentonly) {
      Ret = pPrintWindow(hwnd, memDC,PW_CLIENTONLY);
    } else {
      Ret = pPrintWindow(hwnd, memDC, 0);
    }
  } else {
    Ret = FALSE;
  }
  FreeLibrary(handle);

  return (Ret? TRUE: FALSE);
}



/* ------------------------------------------------------------------------
 * Function Name   --  __get_24bit_bmp
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Convert (part of) the bitmap passed as a parameter to a 24bit BGR
 *   bitmap and store result into lpDesBits
 *
 * ------------------------------------------------------------------------ */
static void
__get_24bit_bmp(HBITMAP hBitmap, int x, int y, int dWidth, int dHeight,
		BYTE *lpDesBits)
{
  HDC hDC = GetDC( 0 );

  HDC memDC1 = CreateCompatibleDC ( hDC );
  HDC memDC2 = CreateCompatibleDC ( hDC );

  int bmWidth = (dWidth/4)*4;
  int i;

  BYTE *lpBits = NULL;

  BITMAPINFO bmi;
  ZeroMemory( &bmi, sizeof(BITMAPINFO) );
  bmi.bmiHeader.biSize        = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth       = bmWidth;
  bmi.bmiHeader.biHeight      = dHeight;
  bmi.bmiHeader.biPlanes      = 1;
  bmi.bmiHeader.biBitCount    = 24;
  bmi.bmiHeader.biCompression = BI_RGB;

  HBITMAP hDIBMemBM  = CreateDIBSection( 0, &bmi, DIB_RGB_COLORS,
					 (void**)&lpBits, NULL, 0L );
	
  HBITMAP hOldBmp1  = (HBITMAP)SelectObject(memDC1, hDIBMemBM );

  HBITMAP hOldBmp2  = (HBITMAP) SelectObject ( memDC2,hBitmap);

  BitBlt( memDC1, 0, 0, bmWidth, dHeight, memDC2, x, y, SRCCOPY );

  // Mirror content, and cut down oversized width.
  for (i = 0 ; i < dHeight ; i++)
    CopyMemory(&lpDesBits[i*3*dWidth],&lpBits[bmWidth*3*(dHeight-1-i)],
	       dWidth*3);

  // clean up
  SelectObject	( memDC1, hOldBmp1  );
  SelectObject	( memDC2,hOldBmp2  );
  ReleaseDC		( 0, hDC      );
  DeleteObject	( hDIBMemBM  );
  DeleteObject	( hOldBmp1  );
  DeleteObject	( hOldBmp2  );
  DeleteDC		( memDC1  );
  DeleteDC		( memDC2  );
}



/* ------------------------------------------------------------------------
 * Function Name   --  __get_bmp_from_DC
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   This function extracts a bitmap from the DC passed as a parameter
 *   and stores the extracted part as device independent bits in the
 *   current capture structure for further analysis and operation.
 *
 * ------------------------------------------------------------------------ */
static BOOL
__get_bmp_from_DC (struct LiveCapture *c, int bpp, HDC hDC, int x, int y)
{
  HDC memDC1 = CreateCompatibleDC ( hDC );

  /* Create a DIB section that will hold the result of the extraction.
     By giving it a negative size, we force the BitBlt() call to
     mirror the content of the result for us.  We recreate the DIB
     section only when the image size has changed, which means only
     when c->bmp is zero. */
  if (c->bmp == 0) {
    BITMAPINFO bmi;
    ZeroMemory( &bmi, sizeof(BITMAPINFO) );
    bmi.bmiHeader.biSize        = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth       = c->width;
    bmi.bmiHeader.biHeight      = - c->height;
    bmi.bmiHeader.biPlanes      = 1;
    bmi.bmiHeader.biBitCount    = bpp;
    bmi.bmiHeader.biCompression = BI_RGB;
    c->rawbits = 0L;
    c->bmp = CreateDIBSection( hDC, &bmi, DIB_RGB_COLORS, (void**)&c->rawbits,
			       NULL, 0L );
    if (c->bmp == NULL) {
      CAPTURE_ERROR(c, "Could not create DIB section for DC content!");
      return FALSE;
    }
  }

  /* Now select the new/old bitmap and selects pixels from it.  This
     operation can be lengthy */
  HBITMAP hOldBmp1  = (HBITMAP)SelectObject(memDC1, c->bmp );
  BitBlt( memDC1, 0, 0, c->width, c->height, hDC, x, y, SRCCOPY );
  
  /* Ensure all the copy is done */
  GdiFlush();

  /* And cleanup */
  SelectObject	( memDC1, hOldBmp1  );
  //ReleaseDC		( 0, hDC      );
  //DeleteObject	( hOldBmp1  );
  DeleteDC		( memDC1  );

  return TRUE;
}



/* ------------------------------------------------------------------------
 * Function Name   --  CaptureNew
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Create a new capturing context or update an existing one.
 *
 * ------------------------------------------------------------------------ */
CAPTURE_API BOOL
CaptureNew(HWND hWnd, int getStyle, float blackFault,
	   int forceBlack)
{
  struct LiveCapture *c;

  c = __capture_find(hWnd);
  if (c) {
    c->getStyle = getStyle;
    c->blackFault = blackFault;
    c->forceBlack = forceBlack;
  } else {
      c = (struct LiveCapture *)malloc(sizeof(struct LiveCapture));
    if (!c)
      return FALSE;
    if (!IsWindow(hWnd))
      return FALSE;
    c->win = hWnd;
    c->getStyle = getStyle;
    c->leftOffset = 0;
    c->topOffset = 0;
    c->rightOffset = 0;
    c->bottomOffset = 0;
    c->pic = NULL;
    c->height = 0;
    c->width = 0;
    c->nbBlackPixels = -1;
    c->signature = -1;
    c->blackFault = blackFault;
    if (c->blackFault < 0.0)
      c->blackFault = 0.0;
    if (c->blackFault > 1.0)
      c->blackFault = 1.0;
    c->successiveBlacks = 0;
    c->forceBlack = forceBlack;
    ZeroMemory(c->err, ERRBUF_SIZE);

    c->next = all_captures;
    all_captures = c;
  }

  return TRUE;
}



/* ------------------------------------------------------------------------
 * Function Name   --  __capture_init
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   (re)initialise a capture, given the (new) size of a window.
 *   Whenever necessary, i.e. when forced to or when the size has
 *   changed, a new appropriate memory buffer for pixel operations is
 *   created and the previous bitmap for BitBlt operations is deleted.
 *
 * ------------------------------------------------------------------------ */
static BOOL
__capture_init(struct LiveCapture *c, int Width, int Height, BOOL force)
{
  /* Reinitialise capture structure and memory buffers for picture if
     necessary */
  if (c->height != Height || c->width != Width
      || (c->width == 0 && c->height == 0) || force) {
    if (c->pic)
      free(c->pic);
    c->height = Height;
    c->width = Width;
    c->pic = (BYTE*)malloc(c->width * c->height * 3);
    ZeroMemory(c->pic, c->width * c->height * 3);
    c->successiveBlacks = 0;
    if (c->bmp) DeleteObject(c->bmp); /* Delete the bitmap for bitblt
					 (and its associated bits */
    c->bmp = 0;

    return TRUE;
  }

  ZeroMemory(c->err, ERRBUF_SIZE);
  return FALSE;
}



/* ------------------------------------------------------------------------
 * Function Name   --  __capture_copy
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Copy pixel data from source buffer to destination buffer.
 *   Performs BGR->RGB permutation if necessary, as well as skipping
 *   (unused) alpha channels.
 *
 * ------------------------------------------------------------------------ */
static void
__capture_copy(BYTE *dst, BYTE *src, int width, int height, BOOL skipAlpha,
	       BOOL reverse, BOOL skipBlack)
{
  int size, bpp;
  register int i, j;

  /* Compute total size of source buffer */
  bpp = skipAlpha ? 4 : 3;
  size = width * height * bpp;

  /* Copy into destination, permutating BGR to RGB if necessary. */
  if (reverse) {
    for (i=0,j=0; i<size; i+=bpp) {
      if ( ! (skipBlack && src[i+2]==0 && src[i+1]==0 && src[i+0]==0)) {
	dst[j+2] = src[i+0];
	dst[j+1] = src[i+1];
	dst[j+0] = src[i+2];
      }
      j += 3;
    }
  } else {
    for (i=0,j=0; i<size; i+=bpp) {
      if ( ! (skipBlack && src[i+2]==0 && src[i+1]==0 && src[i+0]==0)) {
	dst[j+2] = src[i+2];
	dst[j+1] = src[i+1];
	dst[j+0] = src[i+0];
      }
      j += 3;
    }
  }
}



/* ------------------------------------------------------------------------
 * Function Name   --  __capture_count_black
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Count the number of black pixels in a pixel buffer containing RGB
 *   or RGBA values.  This function also, on demand, computes a
 *   signature for the memory area by sub-sampling some of the pixels
 *   and using their values to count a cyclic int.  This signature is
 *   meant to be a unique identifier for the memory area.
 *
 * ------------------------------------------------------------------------ */
static int
__capture_count_black(BYTE *src, int size, int bpp, int *signature)
{
  register int BlackPixels = 0;
  register int i;
	
  if (signature) {
    *signature = 0;
    for (i=0; i<size; i+=bpp) {
      if ( src[i+2]==0 && src[i+1]==0 && src[i+0]==0) {
	BlackPixels++;
      }
      if (i%SIGNATURE_SKIP == 0) {
	*signature += src[i] + src[i+1] + src[i+2];
      }
    }
  } else {
    for (i=0; i<size; i+=bpp) {
      if ( src[i+2]==0 && src[i+1]==0 && src[i+0]==0) {
	BlackPixels++;
      }
    }
  }

  return BlackPixels;
}



/* ------------------------------------------------------------------------
 * Function Name   --  __capture_store
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Store the latest capture contained in <src> into the LiveCapture
 *   memory buffer for picture.  This function contains the core of
 *   the algorithm to work around the black pixels bug of
 *   PrintWindow() as explained in the introduction.
 *
 * ------------------------------------------------------------------------ */
static int
__capture_store(struct LiveCapture *c, BYTE *src, BOOL skipAlpha)
{
  int size, bpp;
  int signature;
  bpp = skipAlpha ? 4 : 3;
  size = c->width * c->height * bpp;

  /* Count the number of black pixels in the source buffer, i.e. the
     latest window capture */
  int BlackPixels = __capture_count_black(src, size, bpp, &signature);

  /* Update only if the signature of the memory area (picture) is
     different than last time.  This saves us an expensive copy at
     this point and can be used by external programs to known whenever
     the picture has changed. */
  if (signature != c->signature) {
    /* If there are not "too many" black pixels (expressed as a ratio
       of the surface of the picture), then we can copy everything
       into the destination. Ratio should be 0.10 (10%).  */
    if (BlackPixels <= (c->blackFault * c->width * c->height)) {
      CaptureClear(c->win);
      __capture_copy(c->pic, src, c->width, c->height, skipAlpha,
		     c->getStyle&CAPTURE_REVERSE, FALSE);
      c->successiveBlacks = 0;
    } else {
      /* Otherwise, count the number of times we have had too many
	 black pixels and clear the destination buffer from time to
	 time anyhow */
      /* XXX: We could perhaps apply some other algorithm here.  Since
	 capturing with black faults only occurs from time to time,
	 windows that always exhibit too many black pixels are
	 probably normal windows with a lot of black in them, and we
	 should adapt to that fact in some way. */
      c->successiveBlacks ++;
      if (c->forceBlack > 0) {
	if (c->successiveBlacks % c->forceBlack == 0)
	  CaptureClear(c->win);
      }
      __capture_copy(c->pic, src, c->width, c->height, skipAlpha,
		     c->getStyle&CAPTURE_REVERSE, TRUE);
    }
    /* remember the number of black pixels */
    c->nbBlackPixels = BlackPixels;
    c->signature = signature;
  }

  return BlackPixels;
}



/* ------------------------------------------------------------------------
 * Function Name   --  __init_DC (not used)
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Initialise the content of a DC to a given colour. 
 *
 * ------------------------------------------------------------------------ */
static void
__init_DC(HDC hDC, int width, int height, BYTE red, BYTE green, BYTE blue)
{
  TRIVERTEX		vert[2];
  GRADIENT_RECT	gRect;

  vert[0].x = 0;
  vert[0].y = 0;
  vert[0].Red = red << 8;
  vert[0].Green = green << 8;
  vert[0].Blue = blue << 8;
  vert[0].Alpha = 0x0000;

  vert[1].x = width;
  vert[1].y = height;
  vert[1].Red = red << 8;
  vert[1].Green = green << 8;
  vert[1].Blue = blue << 8;
  vert[1].Alpha = 0x0000;

  gRect.UpperLeft = 0;
  gRect.LowerRight = 1;
  //GradientFill(hDC, vert, 2, &gRect, 1, GRADIENT_FILL_RECT_H);
}



/* ------------------------------------------------------------------------
 * Function Name   --  __capture_desktop
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Capture the desktop, this function has never been tested... 
 *
 * ------------------------------------------------------------------------ */
static BOOL
__capture_desktop() 
{
  struct LiveCapture *c = __capture_find(0);
  if (!c)
    return FALSE;

  RECT rc;
  HWND hWnd = GetDesktopWindow();
  GetWindowRect (hWnd,&rc); 

  int Width	= rc.right-rc.left;
  int Height	= rc.bottom-rc.top;

  __capture_init(c, Width, Height, FALSE);

  HDC hDC = GetDC(0);
  HDC memDC = CreateCompatibleDC ( hDC );
  HBITMAP memBM = CreateCompatibleBitmap ( hDC, Width, Width );
  HBITMAP OldBM = (HBITMAP)SelectObject(memDC, memBM );
  BitBlt( memDC, 0, 0, Width, Width , hDC, rc.left, rc.top , SRCCOPY );

  int Bpp			= GetDeviceCaps(hDC,BITSPIXEL);
  int size		= Bpp/8 * ( Width * Height );
  BYTE *lpBits1	= (BYTE*)malloc(size);
  GetBitmapBits( memBM, size, lpBits1 );

  if (Bpp ==32) {
    __capture_store(c, lpBits1, TRUE);
  } else {
    BYTE *lpBits2 = (BYTE*)malloc(Width * Height*3);    
    HBITMAP hBmp = CreateBitmap(Width,Height,1,Bpp,lpBits1);

    __get_24bit_bmp	(hBmp,0, 0, Width, Height, lpBits2);
    __capture_store(c, lpBits2, FALSE);
    free(lpBits2);
    DeleteObject(hBmp);
  }

  free(lpBits1);
  SelectObject(hDC, OldBM);
  DeleteObject(memBM);
  DeleteDC(memDC);
  ReleaseDC( 0, hDC );

  return TRUE;
}


/* ------------------------------------------------------------------------
 * Function Name   --  __capture_store_error
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Store an error as being the latest error in a given capture
 *   context.  This function accounts for the name of the file and the
 *   line number.
 *
 * ------------------------------------------------------------------------ */
static void
__capture_store_error(struct LiveCapture *c, char *msg, char *fname,
		      int lineno) 
{
  char sysmsg[ERRBUF_SIZE];
  char *dst = c ? c->err : sysmsg;
  DWORD err = GetLastError();

  snprintf(dst, ERRBUF_SIZE, "In %s (line %d): %s, Error#%d",
	   fname, lineno, msg, err);
}



/* ------------------------------------------------------------------------
 * Function Name   --  CaptureSnap
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Capture one window for which a capturing context has been created
 *   and possibly store the result of capturing in the context.
 *   Return FALSE on errors, TRUE on success.
 *
 * ------------------------------------------------------------------------ */
CAPTURE_API BOOL
CaptureSnap(HWND hWndSrc)
{
  if (hWndSrc == 0)
    return __capture_desktop();

  struct LiveCapture *c = __capture_find(hWndSrc);
  if (!c)
    return FALSE;

  WINDOWINFO wi={0};
  wi.cbSize = sizeof(WINDOWINFO);
  GetWindowInfo(hWndSrc, &wi);

  int captureWidth	= wi.rcWindow.right-wi.rcWindow.left;
  int captureHeight	= wi.rcWindow.bottom-wi.rcWindow.top;
  int storeWidth, storeHeight;
  int storeX, storeY;

  if (c->getStyle & CAPTURE_CLIENT) {
    int title_height = GetSystemMetrics(SM_CYCAPTION);
    int menu_height = GetSystemMetrics(SM_CYMENU);

    /* When we wish to capture the content only of windows, we will
       have problems with some older applications for which the menu
       is owned by the system while the client area starts immediately
       beneath it.  We wish to grab the menu, so we have to account
       for these in our computations. */
    if (wi.rcWindow.top+title_height+menu_height+wi.cyWindowBorders 
	== wi.rcClient.top) {
      storeX = wi.cxWindowBorders;
      storeY = wi.cyWindowBorders + title_height;
      storeWidth = wi.rcWindow.right - wi.rcWindow.left - 2*wi.cxWindowBorders;
      storeHeight = wi.rcWindow.bottom - wi.rcWindow.top 
	- wi.cyWindowBorders - storeY;
    } else {
      storeX = wi.rcClient.left - wi.rcWindow.left;
      storeY = wi.rcClient.top - wi.rcWindow.top;
      storeWidth = wi.rcClient.right - wi.rcClient.left;
      storeHeight = wi.rcClient.bottom - wi.rcClient.top;
    }
  } else {
    storeWidth = captureWidth;
    storeHeight = captureHeight;
    storeX = 0;
    storeY = 0;
  }

  if (c->getStyle & CAPTURE_RECT) {
    storeX += c->leftOffset;
    if (storeX < 0)
      storeX = 0;
    storeY += c->topOffset;
    if (storeY < 0)
      storeY = 0;
    storeWidth -= c->leftOffset + c->rightOffset;
    if (storeWidth > captureWidth)
      storeWidth = captureWidth;
    storeHeight -= c->topOffset + c->bottomOffset;
    if (storeHeight > captureHeight)
      storeHeight = captureHeight;

  }

  storeWidth = ((storeWidth+3)/4)*4;
  captureWidth = ((captureWidth+3)/4)*4;
  __capture_init(c, storeWidth, storeHeight, FALSE);

  HDC		hdc		= GetDC(hWndSrc);
  if (!hdc) {
    CAPTURE_ERROR(c, "Could not get DC for entire screen!"); return FALSE;
  }
  HDC		memDC	= CreateCompatibleDC ( hdc );
  if (!memDC) {
    CAPTURE_ERROR(c, "Could not create compatible DC"); return FALSE;
  }
  HBITMAP memBM	= CreateCompatibleBitmap ( hdc, captureWidth, captureHeight );
  if (!memBM) {
    CAPTURE_ERROR(c, "Could not create compatible bitmap"); return FALSE;
  }
  HBITMAP hOld	= (HBITMAP)SelectObject ( memDC, memBM );
  if (!hOld) {
    CAPTURE_ERROR(c, "Could not select new bitmap"); return FALSE;
  }

  int Bpp = GetDeviceCaps(hdc,BITSPIXEL);
  int size = (Bpp/8) * ( captureWidth * captureHeight );
    
  BOOL Ret=TRUE;

  /* Capture the window */
  //__init_DC(memDC, Width, Height, 0xff, 0, 0xff);
  Ret = __capture_exec(hWndSrc,memDC,FALSE);
  if (!Ret) {
    CAPTURE_ERROR(c, "Could not capture window");
  } else {
    /* Request a 24 bit bitmap, that saves some copying and quickens
       things (profiled!) */
    Ret = __get_bmp_from_DC(c, 24, memDC, storeX, storeY);
    if (Ret) {
      __capture_store(c, c->rawbits, FALSE);
    }
  }

  SelectObject(memDC,hOld);
  DeleteObject(memBM);
  //DeleteObject(hOld);
  DeleteDC(memDC);
  ReleaseDC( hWndSrc, hdc );

  return Ret;
}


/* ------------------------------------------------------------------------
 * Function Name   --  CaptureGetInfo
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Return information about an existing capture.
 *
 * ------------------------------------------------------------------------ */
CAPTURE_API BOOL
CaptureGetInfo(HWND hWnd, int *w, int *h, int *nbBlack, int *signature)
{
  struct LiveCapture *c = __capture_find(hWnd);

  if (!c)
    return FALSE;

  *w = c->width;
  *h = c->height;
  *nbBlack = c->nbBlackPixels;
  *signature = c->signature;

  return TRUE;
}


/* ------------------------------------------------------------------------
 * Function Name   --  CaptureGetData
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Return the content of the picture buffer of a capturing context
 *   in RGB format.
 *
 * ------------------------------------------------------------------------ */
CAPTURE_API BOOL
CaptureGetData(HWND hWnd, BYTE *dta)
{
  struct LiveCapture *c = __capture_find(hWnd);

  if (!c)
    return FALSE;

  CopyMemory(dta, c->pic, c->width * c->height * 3);
  return TRUE;
}


/* ------------------------------------------------------------------------
 * Function Name   --  CaptureClear
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Clear the content of a capture context (make it black).
 *
 * ------------------------------------------------------------------------ */
CAPTURE_API BOOL
CaptureClear(HWND hWnd)
{
  struct LiveCapture *c = __capture_find(hWnd);

  if (!c)
    return FALSE;

  if (c->pic) {
    c->nbBlackPixels = -1;
    c->signature = -1;
    c->successiveBlacks = 0;
    ZeroMemory(c->pic, c->width * c->height * 3);
  }

  return TRUE;
}


/* ------------------------------------------------------------------------
 * Function Name   --  CaptureGetPPM
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Store the content of the capture buffer in PPM format.
 *
 * ------------------------------------------------------------------------ */
CAPTURE_API BOOL
CaptureGetPPM(HWND hWnd, BYTE *dta)
{
  struct LiveCapture *c = __capture_find(hWnd);
  char header[128];

  if (!c)
    return FALSE;

  sprintf(header, "P6\n%d %d\n255\n", c->width, c->height);
  CopyMemory(dta, header, strlen(header));
  CopyMemory(dta + strlen(header), c->pic, c->width * c->height * 3);

  return TRUE;
}


/* ------------------------------------------------------------------------
 * Function Name   --  CaptureDelete
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Delete a capture, its context and all its data.
 *
 * ------------------------------------------------------------------------ */
CAPTURE_API BOOL
CaptureDelete(HWND hWnd)
{
  struct LiveCapture *toremove = __capture_find(hWnd);
  struct LiveCapture *c, *c_next, **cp;

  if (!toremove)
    return FALSE;

  cp = &all_captures;
  for (c = all_captures; c; c=c_next) {
    c_next = c->next;
    if (c == toremove) {
      *cp = c->next;
      if (c->pic)
	free(c->pic);
      if (c->bmp) DeleteObject(c->bmp);
      free(c);
    } else {
      cp = &c->next;
    }
  }

  return TRUE;
}


/* ------------------------------------------------------------------------
 * Function Name   --  CaptureExists
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Decide if a capture exists or not.
 *
 * ------------------------------------------------------------------------ */
CAPTURE_API BOOL
CaptureExists(HWND hWnd)
{
  struct LiveCapture *c = __capture_find(hWnd);

  return (c) ? TRUE : FALSE;
}


/* ------------------------------------------------------------------------
 * Function Name   --  CaptureSetRect
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Set the offset from CAPTURE_WINDOW or CAPTURE_AREA that will be
 *   used when the get style is set to CAPTURE_RECT.
 *
 * ------------------------------------------------------------------------ */
CAPTURE_API BOOL
CaptureSetRect(HWND hWnd,
	       int leftOffset, int topOffset,
	       int rightOffset, int bottomOffset)
{
  struct LiveCapture *c = __capture_find(hWnd);

  if (!c)
    return FALSE;

  c->leftOffset = leftOffset;
  c->topOffset = topOffset;
  c->rightOffset = rightOffset;
  c->bottomOffset = bottomOffset;

  return TRUE;
}


/* ------------------------------------------------------------------------
 * Function Name   --  CaptureGetLastError
 * Original Author --  Emmanuel Frecon - emmanuel@sics.se
 * Description:
 *
 *   Retrieve last error from capture, if any.
 *
 * ------------------------------------------------------------------------ */
CAPTURE_API char *
CaptureGetLastError(HWND hWnd)
{
  struct LiveCapture *c = __capture_find(hWnd);

  if (c) {
    return (char *)c->err;
  } else {
    return NULL;
  }
}
