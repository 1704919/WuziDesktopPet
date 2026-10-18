// MIT. Windows shell presentation only; no file-operation logic.
#pragma once
#include <windows.h>
#include <shobjidl.h>
#include <wrl/client.h>
#include <cwchar>

static HRESULT hideWindowFromTaskbar(const wchar_t* handleText, const wchar_t* pidText) {
    wchar_t* end = nullptr;
    const auto rawHandle = _wcstoui64(handleText, &end, 10);
    if (!rawHandle || !end || *end) return E_INVALIDARG;
    const auto expectedPid = wcstoul(pidText, &end, 10);
    if (!expectedPid || !end || *end) return E_INVALIDARG;
    HWND window = reinterpret_cast<HWND>(static_cast<UINT_PTR>(rawHandle));
    DWORD actualPid = 0;
    GetWindowThreadProcessId(window, &actualPid);
    if (!IsWindow(window) || actualPid != expectedPid) return E_INVALIDARG;

    const LONG_PTR style = GetWindowLongPtrW(window, GWL_EXSTYLE);
    SetLastError(0);
    SetWindowLongPtrW(window, GWL_EXSTYLE,
        (style | WS_EX_TOOLWINDOW) & ~static_cast<LONG_PTR>(WS_EX_APPWINDOW));
    if (GetLastError()) return HRESULT_FROM_WIN32(GetLastError());
    // Keep keyboard/IME focus and topmost behavior unchanged. Called from a
    // short-lived helper, so the Godot UI thread must not wait for this process.
    SetWindowPos(window, nullptr, 0, 0, 0, 0,
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
        SWP_FRAMECHANGED | SWP_ASYNCWINDOWPOS);
    Microsoft::WRL::ComPtr<ITaskbarList> taskbar;
    HRESULT hr = CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                                   IID_PPV_ARGS(&taskbar));
    if (SUCCEEDED(hr)) hr = taskbar->HrInit();
    if (SUCCEEDED(hr)) hr = taskbar->DeleteTab(window);
    return hr;
}
