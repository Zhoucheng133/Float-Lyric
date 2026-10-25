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
)

var (
	mu          sync.Mutex
	hwnd        win.HWND
	lyric       string
	opacity     float64 = 100.0
	fontsize    int32   = 16
	strokeColor         = color.RGBA{R: 24, G: 144, B: 255, A: 255}
	isShown     bool
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
	setWindowOpacity()
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
	wc.HCursor = win.LoadCursor(0, syscall.StringToUTF16Ptr("IDC_ARROW"))
	wc.HbrBackground = win.HBRUSH(win.GetStockObject(win.BLACK_BRUSH))
	wc.LpszClassName = className

	win.RegisterClassEx(&wc)

	screenWidth := win.GetSystemMetrics(win.SM_CXSCREEN)
	screenHeight := win.GetSystemMetrics(win.SM_CYSCREEN)

	width := int32(600)
	height := int32(80)
	x := (screenWidth - width) / 2
	y := screenHeight - height - 120

	h := win.CreateWindowEx(
		win.WS_EX_LAYERED|win.WS_EX_TOPMOST|win.WS_EX_TOOLWINDOW|win.WS_EX_TRANSPARENT,
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
		setWindowOpacity()
		redraw()
	}

	var msg win.MSG
	for win.GetMessage(&msg, 0, 0, 0) != 0 {
		win.TranslateMessage(&msg)
		win.DispatchMessage(&msg)
	}
}

func setWindowOpacity() {
	mu.Lock()
	h := hwnd
	op := opacity
	mu.Unlock()

	if h == 0 {
		return
	}
	alpha := byte(255)
	if op >= 0 && op <= 100 {
		alpha = byte(op * 255 / 100)
	}
	procSetLayerWindowAttributes.Call(
		uintptr(h),
		0,
		uintptr(alpha),
		2,
	)
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
		mu.Unlock()

		drawLyricToHDC(hwnd, hdc, text, fs, sc)
		return 0

	case win.WM_LBUTTONDOWN:
		win.ReleaseCapture()
		win.SendMessage(hwnd, 0xA1, 2, 0)
		return 0

	case win.WM_DESTROY:
		win.PostQuitMessage(0)
		if closeCallbackFn != nil {
			closeCallbackFn()
		}
		return 0
	}
	return win.DefWindowProc(hwnd, msg, wParam, lParam)
}

func drawLyricToHDC(hwnd win.HWND, hdc win.HDC, text string, fontsize int32, strokeColor color.RGBA) {
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

	fontRet, _, _ := procCreateFontW.Call(
		uintptr(-int32(fontsize)),
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
			uintptr(win.DT_CENTER|win.DT_VCENTER|win.DT_SINGLELINE),
		)
	}

	win.SetTextColor(memDC, win.RGB(255, 255, 255))
	procDrawTextW.Call(
		uintptr(memDC),
		uintptr(unsafe.Pointer(&utf16Text[0])),
		uintptr(textLen),
		uintptr(unsafe.Pointer(&rect)),
		uintptr(win.DT_CENTER|win.DT_VCENTER|win.DT_SINGLELINE),
	)

	win.BitBlt(hdc, 0, 0, int32(width), int32(height), memDC, 0, 0, win.SRCCOPY)
}

func main() {}
