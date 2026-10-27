package main

import "C"
import (
	"image/color"
	"sync"
	"syscall"
	"unsafe"

	"github.com/lxn/win"
)

var (
	user32                       = syscall.MustLoadDLL("user32.dll")
	gdi32                        = syscall.MustLoadDLL("gdi32.dll")
	kernel32                     = syscall.MustLoadDLL("kernel32.dll")
	procSetLayerWindowAttributes = user32.MustFindProc("SetLayeredWindowAttributes")
	procFillRect                 = user32.MustFindProc("FillRect")
	procDrawTextW                = user32.MustFindProc("DrawTextW")
	procCreateSolidBrush         = gdi32.MustFindProc("CreateSolidBrush")
	procCreateFontW              = gdi32.MustFindProc("CreateFontW")
	procUpdateLayeredWindow      = user32.MustFindProc("UpdateLayeredWindow")
	procGetCurrentObject         = gdi32.MustFindProc("GetCurrentObject")
	procGetObjectW               = gdi32.MustFindProc("GetObjectW")
)

const (
	IDC_ARROW   = 32512
	IDC_HAND    = 32649
	OBJ_BITMAP  = 7
	ULW_ALPHA   = 2
	AC_SRC_OVER = 0x00
)

var (
	hCursorArrow win.HCURSOR
	hCursorHand  win.HCURSOR
)

var (
	mu          sync.Mutex
	hwnd        win.HWND
	lyric       string
	opacity     float64 = 100.0
	fontsize    int32   = 16
	strokeColor         = color.RGBA{R: 24, G: 144, B: 255, A: 255}
	isShown     bool
	mouseHover  bool
)

type CloseCallback func()

var closeCallbackFn CloseCallback
var onceInit sync.Once

//export ShowFloatLyric
func ShowFloatLyric(lyr *C.char, op float64, fs int32, r int32, g int32, b int32) {
	lyricStr := C.GoString(lyr)
	mu.Lock()
	lyric = lyricStr
	opacity = op
	if fs > 0 {
		fontsize = fs
	}
	strokeColor = color.RGBA{R: uint8(r), G: uint8(g), B: uint8(b), A: 255}
	isShown = true
	mu.Unlock()

	onceInit.Do(func() {
		go startWindowLoop()
	})

	mu.Lock()
	h := hwnd
	mu.Unlock()

	if h != 0 {
		win.ShowWindow(h, win.SW_SHOW)
		redraw()
	}
}

//export HideFloatLyric
func HideFloatLyric() {
	mu.Lock()
	isShown = false
	h := hwnd
	mu.Unlock()
	if h != 0 {
		win.ShowWindow(h, win.SW_HIDE)
	}
}

//export UpdateLyric
func UpdateLyric(lyr *C.char) {
	lyricStr := C.GoString(lyr)
	mu.Lock()
	lyric = lyricStr
	mu.Unlock()
	redraw()
}

//export UpdateOpacity
func UpdateOpacity(op float64) {
	mu.Lock()
	opacity = op
	mu.Unlock()
	redraw()
}

//export UpdateFontSize
func UpdateFontSize(fs int32) {
	mu.Lock()
	if fs > 0 {
		fontsize = fs
	}
	mu.Unlock()
	redraw()
}

//export UpdateStrokeColor
func UpdateStrokeColor(r int32, g int32, b int32) {
	mu.Lock()
	strokeColor = color.RGBA{R: uint8(r), G: uint8(g), B: uint8(b), A: 255}
	mu.Unlock()
	redraw()
}

//export RegisterCloseCallback
func RegisterCloseCallback(cb uintptr) {
	closeCallbackFn = CloseCallback(func() {
		syscall.Syscall(cb, 0, 0, 0, 0)
	})
}

func startWindowLoop() {
	className := syscall.StringToUTF16Ptr("FloatLyricWindow")
	var wc win.WNDCLASSEX
	wc.CbSize = uint32(unsafe.Sizeof(wc))
	wc.Style = win.CS_HREDRAW | win.CS_VREDRAW
	wc.LpfnWndProc = syscall.NewCallback(wndProc)
	wc.HInstance = win.GetModuleHandle(nil)
	hCursorArrow = win.LoadCursor(0, syscall.StringToUTF16Ptr("#32512"))
	hCursorHand = win.LoadCursor(0, syscall.StringToUTF16Ptr("#32649"))
	wc.HCursor = hCursorArrow
	wc.HbrBackground = win.HBRUSH(win.GetStockObject(win.BLACK_BRUSH))
	wc.LpszClassName = className

	win.RegisterClassEx(&wc)

	screenWidth := win.GetSystemMetrics(win.SM_CXSCREEN)
	screenHeight := win.GetSystemMetrics(win.SM_CYSCREEN)

	width := int32(800)
	height := int32(100)
	x := (screenWidth - width) / 2
	y := screenHeight - height - 120

	h := win.CreateWindowEx(
		win.WS_EX_LAYERED|win.WS_EX_TOPMOST|win.WS_EX_TOOLWINDOW,
		className,
		syscall.StringToUTF16Ptr("Float Lyric"),
		win.WS_POPUP,
		x, y, width, height,
		0, 0, wc.HInstance, nil,
	)

	mu.Lock()
	hwnd = h
	shown := isShown
	mu.Unlock()

	if shown {
		win.ShowWindow(h, win.SW_SHOW)
		redraw()
	}

	var msg win.MSG
	for win.GetMessage(&msg, 0, 0, 0) != 0 {
		win.TranslateMessage(&msg)
		win.DispatchMessage(&msg)
	}
}

func redraw() {
	mu.Lock()
	h := hwnd
	mu.Unlock()

	if h == 0 {
		return
	}
	win.InvalidateRect(h, nil, true)
}

func wndProc(hwnd win.HWND, msg uint32, wParam, lParam uintptr) uintptr {
	switch msg {
	case win.WM_PAINT:
		var ps win.PAINTSTRUCT
		hdc := win.BeginPaint(hwnd, &ps)
		defer win.EndPaint(hwnd, &ps)

		mu.Lock()
		text := lyric
		fs := fontsize
		sc := strokeColor
		hover := mouseHover
		mu.Unlock()

		drawLyricToHDC(hwnd, hdc, text, fs, sc, hover)
		return 0

	case win.WM_MOUSEMOVE:
		mu.Lock()
		hover := mouseHover
		mu.Unlock()

		if !hover {
			mu.Lock()
			mouseHover = true
			mu.Unlock()
			var tme win.TRACKMOUSEEVENT
			tme.CbSize = uint32(unsafe.Sizeof(tme))
			tme.DwFlags = win.TME_LEAVE
			tme.HwndTrack = hwnd
			win.TrackMouseEvent(&tme)
			redraw()
		}

		var pt win.POINT
		win.GetCursorPos(&pt)
		win.ScreenToClient(hwnd, &pt)
		var rect win.RECT
		win.GetClientRect(hwnd, &rect)
		closeBtnRect := win.RECT{
			Left:   rect.Right - 36,
			Top:    rect.Top + 6,
			Right:  rect.Right - 12,
			Bottom: rect.Top + 30,
		}
		if pt.X >= closeBtnRect.Left && pt.X <= closeBtnRect.Right && pt.Y >= closeBtnRect.Top && pt.Y <= closeBtnRect.Bottom {
			win.SetCursor(hCursorHand)
		} else {
			win.SetCursor(hCursorArrow)
		}
		return 0

	case win.WM_MOUSELEAVE:
		mu.Lock()
		mouseHover = false
		mu.Unlock()
		win.SetCursor(hCursorArrow)
		redraw()
		return 0

	case win.WM_SETCURSOR:
		if win.LOWORD(uint32(lParam)) == win.HTCLIENT {
			var pt win.POINT
			win.GetCursorPos(&pt)
			win.ScreenToClient(hwnd, &pt)
			var rect win.RECT
			win.GetClientRect(hwnd, &rect)
			closeBtnRect := win.RECT{
				Left:   rect.Right - 36,
				Top:    rect.Top + 6,
				Right:  rect.Right - 12,
				Bottom: rect.Top + 30,
			}
			if pt.X >= closeBtnRect.Left && pt.X <= closeBtnRect.Right && pt.Y >= closeBtnRect.Top && pt.Y <= closeBtnRect.Bottom {
				win.SetCursor(hCursorHand)
				return 1
			}
		}
		return win.DefWindowProc(hwnd, msg, wParam, lParam)

	case win.WM_LBUTTONDOWN:
		var pt win.POINT
		win.GetCursorPos(&pt)
		clientPt := pt
		win.ScreenToClient(hwnd, &clientPt)
		var rect win.RECT
		win.GetClientRect(hwnd, &rect)
		closeBtnRect := win.RECT{
			Left:   rect.Right - 36,
			Top:    rect.Top + 6,
			Right:  rect.Right - 12,
			Bottom: rect.Top + 30,
		}
		if clientPt.X >= closeBtnRect.Left && clientPt.X <= closeBtnRect.Right && clientPt.Y >= closeBtnRect.Top && clientPt.Y <= closeBtnRect.Bottom {
			HideFloatLyric()
			if closeCallbackFn != nil {
				go closeCallbackFn()
			}
			return 0
		}

		win.ReleaseCapture()
		return win.SendMessage(hwnd, win.WM_NCLBUTTONDOWN, win.HTCAPTION, 0)

	case win.WM_DESTROY:
		win.PostQuitMessage(0)
		return 0
	}
	return win.DefWindowProc(hwnd, msg, wParam, lParam)
}

func drawLyricToHDC(hwnd win.HWND, hdc win.HDC, text string, fontsize int32, strokeColor color.RGBA, hover bool) {
	var rect win.RECT
	win.GetClientRect(hwnd, &rect)
	width := int(rect.Right - rect.Left)
	height := int(rect.Bottom - rect.Top)
	if width <= 0 || height <= 0 {
		return
	}

	memDC := win.CreateCompatibleDC(hdc)
	defer win.DeleteDC(memDC)

	var bmi win.BITMAPINFOHEADER
	bmi.BiSize = uint32(unsafe.Sizeof(bmi))
	bmi.BiWidth = int32(width)
	bmi.BiHeight = int32(-height)
	bmi.BiPlanes = 1
	bmi.BiBitCount = 32
	bmi.BiCompression = win.BI_RGB

	var pBits unsafe.Pointer
	hBitmap := win.CreateDIBSection(hdc, &bmi, win.DIB_RGB_COLORS, &pBits, 0, 0)
	if hBitmap == 0 {
		return
	}
	defer win.DeleteObject(win.HGDIOBJ(hBitmap))

	oldBitmap := win.SelectObject(memDC, win.HGDIOBJ(hBitmap))
	defer win.SelectObject(memDC, oldBitmap)

	brushRet, _, _ := procCreateSolidBrush.Call(uintptr(0x000000))
	brush := win.HBRUSH(brushRet)
	procFillRect.Call(uintptr(memDC), uintptr(unsafe.Pointer(&rect)), uintptr(brush))
	win.DeleteObject(win.HGDIOBJ(brush))

	if hover {
		closeBtnRect := win.RECT{
			Left:   rect.Right - 36,
			Top:    rect.Top + 6,
			Right:  rect.Right - 12,
			Bottom: rect.Top + 30,
		}
		btnBrush, _, _ := procCreateSolidBrush.Call(uintptr(0x3C4CE7)) // Red in BGR
		hBtnBrush := win.HBRUSH(btnBrush)
		procFillRect.Call(uintptr(memDC), uintptr(unsafe.Pointer(&closeBtnRect)), uintptr(hBtnBrush))
		win.DeleteObject(win.HGDIOBJ(hBtnBrush))

		var hFontVal int32 = -16
		fontRet2, _, _ := procCreateFontW.Call(
			uintptr(hFontVal),
			0, 0, 0,
			uintptr(win.FW_BOLD),
			0, 0, 0,
			uintptr(win.DEFAULT_CHARSET),
			uintptr(win.OUT_DEFAULT_PRECIS),
			uintptr(win.CLIP_DEFAULT_PRECIS),
			uintptr(win.ANTIALIASED_QUALITY),
			uintptr(win.DEFAULT_PITCH),
			uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr("Arial"))),
		)
		hFont2 := win.HFONT(fontRet2)
		if hFont2 != 0 {
			oldFont2 := win.SelectObject(memDC, win.HGDIOBJ(hFont2))
			win.SetBkMode(memDC, win.TRANSPARENT)
			win.SetTextColor(memDC, win.RGB(255, 255, 255))
			closeText, _ := syscall.UTF16FromString("×")
			procDrawTextW.Call(
				uintptr(memDC),
				uintptr(unsafe.Pointer(&closeText[0])),
				uintptr(len(closeText)-1),
				uintptr(unsafe.Pointer(&closeBtnRect)),
				uintptr(win.DT_CENTER|win.DT_VCENTER|win.DT_SINGLELINE),
			)
			win.SelectObject(memDC, oldFont2)
			win.DeleteObject(win.HGDIOBJ(hFont2))
		}
	}

	var fsVal int32 = -int32(fontsize)
	fontRet, _, _ := procCreateFontW.Call(
		uintptr(fsVal),
		0, 0, 0,
		uintptr(win.FW_BOLD),
		0, 0, 0,
		uintptr(win.DEFAULT_CHARSET),
		uintptr(win.OUT_DEFAULT_PRECIS),
		uintptr(win.CLIP_DEFAULT_PRECIS),
		uintptr(win.ANTIALIASED_QUALITY),
		uintptr(win.DEFAULT_PITCH),
		uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr("Microsoft YaHei"))),
	)
	hFont := win.HFONT(fontRet)
	if hFont != 0 {
		oldFont := win.SelectObject(memDC, win.HGDIOBJ(hFont))
		defer win.SelectObject(memDC, oldFont)
		defer win.DeleteObject(win.HGDIOBJ(hFont))
	}

	win.SetBkMode(memDC, win.TRANSPARENT)

	strokeCOLORREF := win.RGB(strokeColor.R, strokeColor.G, strokeColor.B)
	win.SetTextColor(memDC, strokeCOLORREF)

	utf16Text, err := syscall.UTF16FromString(text)
	if err != nil || len(utf16Text) == 0 {
		return
	}
	textLen := int32(len(utf16Text) - 1)

	offsets := []struct{ dx, dy int }{
		{-1, -1}, {0, -1}, {1, -1},
		{-1, 0}, {1, 0},
		{-1, 1}, {0, 1}, {1, 1},
	}

	flags := uintptr(win.DT_CENTER | win.DT_VCENTER | win.DT_SINGLELINE | win.DT_END_ELLIPSIS)

	for _, off := range offsets {
		rCopy := rect
		rCopy.Left += int32(off.dx * 2)
		rCopy.Right += int32(off.dx * 2)
		rCopy.Top += int32(off.dy * 2)
		rCopy.Bottom += int32(off.dy * 2)
		procDrawTextW.Call(
			uintptr(memDC),
			uintptr(unsafe.Pointer(&utf16Text[0])),
			uintptr(textLen),
			uintptr(unsafe.Pointer(&rCopy)),
			flags,
		)
	}

	win.SetTextColor(memDC, win.RGB(255, 255, 255))
	procDrawTextW.Call(
		uintptr(memDC),
		uintptr(unsafe.Pointer(&utf16Text[0])),
		uintptr(textLen),
		uintptr(unsafe.Pointer(&rect)),
		flags,
	)

	updateLayeredWindowWithAlpha(hwnd, hdc, memDC, width, height)
}

func updateLayeredWindowWithAlpha(hwnd win.HWND, hdc win.HDC, memDC win.HDC, width, height int) {
	mu.Lock()
	op := opacity
	mu.Unlock()

	bgAlpha := byte(op * 255 / 100)

	hBmpObj, _, _ := procGetCurrentObject.Call(uintptr(memDC), uintptr(OBJ_BITMAP))
	var bm win.BITMAP
	procGetObjectW.Call(hBmpObj, uintptr(unsafe.Sizeof(bm)), uintptr(unsafe.Pointer(&bm)))

	if bm.BmBits == nil {
		win.BitBlt(hdc, 0, 0, int32(width), int32(height), memDC, 0, 0, win.SRCCOPY)
		return
	}

	pixels := (*[1 << 30]byte)(bm.BmBits)[: width*height*4 : width*height*4]

	for i := 0; i < len(pixels); i += 4 {
		b := pixels[i]
		g := pixels[i+1]
		r := pixels[i+2]

		if r == 0 && g == 0 && b == 0 {
			pixels[i] = 0
			pixels[i+1] = 0
			pixels[i+2] = 0
			pixels[i+3] = bgAlpha
		} else {
			maxVal := r
			if g > maxVal {
				maxVal = g
			}
			if b > maxVal {
				maxVal = b
			}
			alpha := maxVal

			// 关键修复：必须进行预乘 Alpha 计算 (Color * Alpha / 255)
			pixels[i] = byte(uint32(b) * uint32(alpha) / 255)
			pixels[i+1] = byte(uint32(g) * uint32(alpha) / 255)
			pixels[i+2] = byte(uint32(r) * uint32(alpha) / 255)
			pixels[i+3] = alpha
		}
	}

	var ptSrc win.POINT
	psize := win.SIZE{CX: int32(width), CY: int32(height)}

	var blend struct {
		BlendOp             byte
		BlendFlags          byte
		SourceConstantAlpha byte
		AlphaFormat         byte
	}
	blend.BlendOp = AC_SRC_OVER
	blend.BlendFlags = 0
	blend.SourceConstantAlpha = 255
	blend.AlphaFormat = 0x01

	procUpdateLayeredWindow.Call(
		uintptr(hwnd),
		0,
		0,
		uintptr(unsafe.Pointer(&psize)),
		uintptr(memDC),
		uintptr(unsafe.Pointer(&ptSrc)),
		0,
		uintptr(unsafe.Pointer(&blend)),
		uintptr(2), // ULW_ALPHA
	)
}

func main() {}
