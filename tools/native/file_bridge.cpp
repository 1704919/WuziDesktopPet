// MIT. Small Windows-only bridge; codecs remain supplied by Windows.
#include <windows.h>
#include <wincodec.h>
#include <shlwapi.h>
#include <wrl/client.h>
#include <cstdio>
#include <string>
#include <vector>
using Microsoft::WRL::ComPtr;

static HRESULT transcode(IWICImagingFactory* factory, const wchar_t* source,
                         const wchar_t* target, bool heic, float quality) {
    ComPtr<IWICBitmapDecoder> decoder;
    HRESULT hr = factory->CreateDecoderFromFilename(source, nullptr, GENERIC_READ,
        WICDecodeMetadataCacheOnLoad, &decoder);
    if (FAILED(hr)) return hr;
    ComPtr<IWICBitmapFrameDecode> input;
    if (FAILED(hr = decoder->GetFrame(0, &input))) return hr;
    ComPtr<IWICBitmapEncoder> encoder;
    if (FAILED(hr = factory->CreateEncoder(heic ? GUID_ContainerFormatHeif : GUID_ContainerFormatPng,
                                          nullptr, &encoder))) return hr;
    // Reserve the output exclusively. WIC writes through this exact handle-backed stream.
    HANDLE file = CreateFileW(target, GENERIC_WRITE | GENERIC_READ, 0, nullptr,
                              CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return HRESULT_FROM_WIN32(GetLastError());
    ComPtr<IStream> memory;
    hr = CreateStreamOnHGlobal(nullptr, TRUE, &memory);
    if (SUCCEEDED(hr)) hr = encoder->Initialize(memory.Get(), WICBitmapEncoderNoCache);
    ComPtr<IWICBitmapFrameEncode> frame;
    ComPtr<IPropertyBag2> options;
    if (SUCCEEDED(hr)) hr = encoder->CreateNewFrame(&frame, &options);
    if (SUCCEEDED(hr) && heic && options) {
        PROPBAG2 prop = {}; prop.pstrName = const_cast<wchar_t*>(L"ImageQuality");
        VARIANT value; VariantInit(&value); value.vt = VT_R4; value.fltVal = quality;
        HRESULT optionResult = options->Write(1, &prop, &value);
        if (FAILED(optionResult) && optionResult != WINCODEC_ERR_PROPERTYNOTSUPPORTED) hr = optionResult;
    }
    UINT width = 0, height = 0;
    if (SUCCEEDED(hr)) hr = input->GetSize(&width, &height);
    if (SUCCEEDED(hr)) hr = frame->Initialize(options.Get());
    if (SUCCEEDED(hr)) hr = frame->SetSize(width, height);
    WICPixelFormatGUID format = heic ? GUID_WICPixelFormat24bppBGR : GUID_WICPixelFormat32bppBGRA;
    if (SUCCEEDED(hr)) hr = frame->SetPixelFormat(&format);
    ComPtr<IWICFormatConverter> converter;
    if (SUCCEEDED(hr)) hr = factory->CreateFormatConverter(&converter);
    if (SUCCEEDED(hr)) hr = converter->Initialize(input.Get(), format,
        WICBitmapDitherTypeNone, nullptr, 0, WICBitmapPaletteTypeCustom);
    if (SUCCEEDED(hr)) hr = frame->WriteSource(converter.Get(), nullptr);
    if (SUCCEEDED(hr)) hr = frame->Commit();
    if (SUCCEEDED(hr)) hr = encoder->Commit();
    if (SUCCEEDED(hr)) {
        LARGE_INTEGER zero = {}; hr = memory->Seek(zero, STREAM_SEEK_SET, nullptr);
        std::vector<BYTE> buffer(1024 * 1024);
        while (SUCCEEDED(hr)) {
            ULONG read = 0; hr = memory->Read(buffer.data(), (ULONG)buffer.size(), &read);
            if (FAILED(hr) || read == 0) break;
            DWORD written = 0;
            if (!WriteFile(file, buffer.data(), read, &written, nullptr) || written != read) {
                hr = HRESULT_FROM_WIN32(GetLastError() ? GetLastError() : ERROR_WRITE_FAULT); break;
            }
        }
        if (SUCCEEDED(hr) && !FlushFileBuffers(file)) hr = HRESULT_FROM_WIN32(GetLastError());
    }
    CloseHandle(file);
    if (FAILED(hr)) DeleteFileW(target); // Only the file this invocation created.
    return hr;
}

static bool decoderAvailable(IWICImagingFactory* factory) {
    ComPtr<IEnumUnknown> codecs;
    if (FAILED(factory->CreateComponentEnumerator(WICDecoder, WICComponentEnumerateDefault, &codecs))) return false;
    ComPtr<IUnknown> item;
    ULONG fetched = 0;
    while (codecs->Next(1, &item, &fetched) == S_OK) {
        ComPtr<IWICBitmapDecoderInfo> info;
        GUID container = {};
        if (SUCCEEDED(item.As(&info)) && SUCCEEDED(info->GetContainerFormat(&container))
            && container == GUID_ContainerFormatHeif) {
            ComPtr<IWICBitmapDecoder> decoder;
            if (SUCCEEDED(info->CreateInstance(&decoder))) return true;
        }
        item.Reset();
    }
    return false;
}

int wmain(int argc, wchar_t** argv) {
    HRESULT init = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    HRESULT hr = E_INVALIDARG;
    std::wstring op = argc > 1 ? argv[1] : L"";
    if (op == L"move" && argc == 4) {
        // Deliberately omit MOVEFILE_REPLACE_EXISTING and COPY_ALLOWED.
        hr = MoveFileExW(argv[2], argv[3], MOVEFILE_WRITE_THROUGH) ? S_OK : HRESULT_FROM_WIN32(GetLastError());
    } else if (op == L"copy" && argc == 4) {
        hr = CopyFileW(argv[2], argv[3], TRUE) ? S_OK : HRESULT_FROM_WIN32(GetLastError());
    } else if (op == L"probe" && argc == 3) {
        GUID id; CoCreateGuid(&id); wchar_t guid[40]; StringFromGUID2(id, guid, 40);
        std::wstring path = std::wstring(argv[2]) + L"\\.wuzi-probe-" + guid;
        HANDLE handle = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW,
                                   FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_DELETE_ON_CLOSE, nullptr);
        hr = handle == INVALID_HANDLE_VALUE ? HRESULT_FROM_WIN32(GetLastError()) : S_OK;
        if (handle != INVALID_HANDLE_VALUE) {
            DWORD count = 0;
            if (!WriteFile(handle, "wuzi", 4, &count, nullptr) || count != 4 || !FlushFileBuffers(handle))
                hr = HRESULT_FROM_WIN32(GetLastError() ? GetLastError() : ERROR_WRITE_FAULT);
            CloseHandle(handle);
        }
    } else {
        ComPtr<IWICImagingFactory> factory;
        hr = CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory));
        if (SUCCEEDED(hr) && op == L"caps") {
            ComPtr<IWICBitmapEncoder> encoder;
            bool write = SUCCEEDED(factory->CreateEncoder(GUID_ContainerFormatHeif, nullptr, &encoder));
            printf("{\"ok\":true,\"read\":%s,\"write\":%s}\n", decoderAvailable(factory.Get()) ? "true" : "false", write ? "true" : "false");
            factory.Reset(); encoder.Reset();
            if (SUCCEEDED(init)) CoUninitialize();
            return 0;
        }
        if (SUCCEEDED(hr) && (op == L"decode" || op == L"encode") && argc >= 4)
            hr = transcode(factory.Get(), argv[2], argv[3], op == L"encode",
                           argc == 5 ? (float)_wtof(argv[4]) : 0.92f);
        else if (SUCCEEDED(hr)) hr = E_INVALIDARG;
    }
    printf("{\"ok\":%s,\"error\":\"0x%08lX\"}\n", SUCCEEDED(hr) ? "true" : "false", (unsigned long)hr);
    if (SUCCEEDED(init)) CoUninitialize();
    return SUCCEEDED(hr) ? 0 : 1;
}
