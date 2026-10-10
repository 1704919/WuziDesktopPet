  1 | // MIT. Small Windows-only bridge; codecs remain supplied by Windows.
  2 | #include <windows.h>
  3 | #include <wincodec.h>
  4 | #include <shlwapi.h>
  5 | #include <wrl/client.h>
  6 | #include <cstdio>
  7 | #include <string>
  8 | #include <vector>
  9 | using Microsoft::WRL::ComPtr;
 10 | 
 11 | static HRESULT transcode(IWICImagingFactory* factory, const wchar_t* source,
 12 |                          const wchar_t* target, bool heic, float quality) {
 13 |     ComPtr<IWICBitmapDecoder> decoder;
 14 |     HRESULT hr = factory->CreateDecoderFromFilename(source, nullptr, GENERIC_READ,
 15 |         WICDecodeMetadataCacheOnLoad, &decoder);
 16 |     if (FAILED(hr)) return hr;
 17 |     ComPtr<IWICBitmapFrameDecode> input;
 18 |     if (FAILED(hr = decoder->GetFrame(0, &input))) return hr;
 19 |     ComPtr<IWICBitmapEncoder> encoder;
 20 |     if (FAILED(hr = factory->CreateEncoder(heic ? GUID_ContainerFormatHeif : GUID_ContainerFormatPng,
 21 |                                           nullptr, &encoder))) return hr;
 22 |     // Reserve the output exclusively. WIC writes through this exact handle-backed stream.
 23 |     HANDLE file = CreateFileW(target, GENERIC_WRITE | GENERIC_READ, 0, nullptr,
 24 |                               CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
 25 |     if (file == INVALID_HANDLE_VALUE) return HRESULT_FROM_WIN32(GetLastError());
 26 |     ComPtr<IStream> memory;
 27 |     hr = CreateStreamOnHGlobal(nullptr, TRUE, &memory);
 28 |     if (SUCCEEDED(hr)) hr = encoder->Initialize(memory.Get(), WICBitmapEncoderNoCache);
 29 |     ComPtr<IWICBitmapFrameEncode> frame;
 30 |     ComPtr<IPropertyBag2> options;
 31 |     if (SUCCEEDED(hr)) hr = encoder->CreateNewFrame(&frame, &options);
 32 |     if (SUCCEEDED(hr) && heic && options) {
 33 |         PROPBAG2 prop = {}; prop.pstrName = const_cast<wchar_t*>(L"ImageQuality");
 34 |         VARIANT value; VariantInit(&value); value.vt = VT_R4; value.fltVal = quality;
 35 |         HRESULT optionResult = options->Write(1, &prop, &value);
 36 |         if (FAILED(optionResult) && optionResult != WINCODEC_ERR_PROPERTYNOTSUPPORTED) hr = optionResult;
 37 |     }
 38 |     UINT width = 0, height = 0;
 39 |     if (SUCCEEDED(hr)) hr = input->GetSize(&width, &height);
 40 |     if (SUCCEEDED(hr)) hr = frame->Initialize(options.Get());
 41 |     if (SUCCEEDED(hr)) hr = frame->SetSize(width, height);
 42 |     WICPixelFormatGUID format = heic ? GUID_WICPixelFormat24bppBGR : GUID_WICPixelFormat32bppBGRA;
 43 |     if (SUCCEEDED(hr)) hr = frame->SetPixelFormat(&format);
 44 |     ComPtr<IWICFormatConverter> converter;
 45 |     if (SUCCEEDED(hr)) hr = factory->CreateFormatConverter(&converter);
 46 |     if (SUCCEEDED(hr)) hr = converter->Initialize(input.Get(), format,
 47 |         WICBitmapDitherTypeNone, nullptr, 0, WICBitmapPaletteTypeCustom);
 48 |     if (SUCCEEDED(hr)) hr = frame->WriteSource(converter.Get(), nullptr);
 49 |     if (SUCCEEDED(hr)) hr = frame->Commit();
 50 |     if (SUCCEEDED(hr)) hr = encoder->Commit();
 51 |     if (SUCCEEDED(hr)) {
 52 |         LARGE_INTEGER zero = {}; hr = memory->Seek(zero, STREAM_SEEK_SET, nullptr);
 53 |         std::vector<BYTE> buffer(1024 * 1024);
 54 |         while (SUCCEEDED(hr)) {
 55 |             ULONG read = 0; hr = memory->Read(buffer.data(), (ULONG)buffer.size(), &read);
 56 |             if (FAILED(hr) || read == 0) break;
 57 |             DWORD written = 0;
 58 |             if (!WriteFile(file, buffer.data(), read, &written, nullptr) || written != read) {
 59 |                 hr = HRESULT_FROM_WIN32(GetLastError() ? GetLastError() : ERROR_WRITE_FAULT); break;
 60 |             }
 61 |         }
 62 |         if (SUCCEEDED(hr) && !FlushFileBuffers(file)) hr = HRESULT_FROM_WIN32(GetLastError());
 63 |     }
 64 |     CloseHandle(file);
 65 |     if (FAILED(hr)) DeleteFileW(target); // Only the file this invocation created.
 66 |     return hr;
 67 | }
 68 | 
 69 | static bool decoderAvailable(IWICImagingFactory* factory) {
 70 |     ComPtr<IEnumUnknown> codecs;
 71 |     if (FAILED(factory->CreateComponentEnumerator(WICDecoder, WICComponentEnumerateDefault, &codecs))) return false;
 72 |     ComPtr<IUnknown> item;
 73 |     ULONG fetched = 0;
 74 |     while (codecs->Next(1, &item, &fetched) == S_OK) {
 75 |         ComPtr<IWICBitmapDecoderInfo> info;
 76 |         GUID container = {};
 77 |         if (SUCCEEDED(item.As(&info)) && SUCCEEDED(info->GetContainerFormat(&container))
 78 |             && container == GUID_ContainerFormatHeif) {
 79 |             ComPtr<IWICBitmapDecoder> decoder;
 80 |             if (SUCCEEDED(info->CreateInstance(&decoder))) return true;
 81 |         }
 82 |         item.Reset();
 83 |     }
 84 |     return false;
 85 | }
 86 | 
 87 | int wmain(int argc, wchar_t** argv) {
 88 |     HRESULT init = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
 89 |     HRESULT hr = E_INVALIDARG;
 90 |     std::wstring op = argc > 1 ? argv[1] : L"";
 91 |     if (op == L"move" && argc == 4) {
 92 |         // Deliberately omit MOVEFILE_REPLACE_EXISTING and COPY_ALLOWED.
 93 |         hr = MoveFileExW(argv[2], argv[3], MOVEFILE_WRITE_THROUGH) ? S_OK : HRESULT_FROM_WIN32(GetLastError());
 94 |     } else if (op == L"copy" && argc == 4) {
 95 |         hr = CopyFileW(argv[2], argv[3], TRUE) ? S_OK : HRESULT_FROM_WIN32(GetLastError());
 96 |     } else if (op == L"probe" && argc == 3) {
 97 |         GUID id; CoCreateGuid(&id); wchar_t guid[40]; StringFromGUID2(id, guid, 40);
 98 |         std::wstring path = std::wstring(argv[2]) + L"\\.wuzi-probe-" + guid;
 99 |         HANDLE handle = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW,
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
