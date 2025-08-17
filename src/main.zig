const std = @import("std");

const win = @cImport({
    @cInclude("windows.h");
    @cInclude("mmdeviceapi.h");
    @cInclude("audioclient.h");
    @cInclude("avrt.h");
    @cInclude("stdio.h");
});

const raylib = @cImport({
    @cInclude("raylib.h");
});

// uuids generated using getUuid.cpp
// build using:
// zig c++ getUuid.cpp -o getUuid.exe

const CLSID_MMDeviceEnumerator = win.GUID{
    .Data1 = 0xBCDE0395,
    .Data2 = 0xE52F,
    .Data3 = 0x467C,
    .Data4 = [_]u8{ 0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E },
};

const IID_IMMDeviceEnumerator = win.GUID{
    .Data1 = 0xA95664D2,
    .Data2 = 0x9614,
    .Data3 = 0x4F35,
    .Data4 = [_]u8{ 0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6 },
};

const IID_IAudioClient = win.GUID{
    .Data1 = 0x1CB9AD4C,
    .Data2 = 0xDBFA,
    .Data3 = 0x4C32,
    .Data4 = [_]u8{ 0xB1, 0x78, 0xC2, 0xF5, 0x68, 0xA7, 0x03, 0xB2 },
};

const IID_IAudioCaptureClient = win.GUID{
    .Data1 = 0xC8ADBD64,
    .Data2 = 0xE71E,
    .Data3 = 0x48A0,
    .Data4 = [_]u8{ 0xA4, 0xDE, 0x18, 0x5C, 0x39, 0x5C, 0xD3, 0x17 },
};

// https://learn.microsoft.com/en-us/windows/win32/coreaudio/capturing-a-stream
// https://learn.microsoft.com/en-us/windows/win32/coreaudio/loopback-recording
// ported to zig

pub fn main() !void {
    // raylib.InitWindow(800, 450, "raylib [core] example - basic window");
    //
    // while (!raylib.WindowShouldClose()) {
    //     raylib.BeginDrawing();
    //     raylib.ClearBackground(raylib.RAYWHITE);
    //     raylib.DrawText("Congrats! You created your first window!", 190, 200, 20, raylib.LIGHTGRAY);
    //     raylib.EndDrawing();
    // }
    //
    // raylib.CloseWindow();
    // _ = win.CoInitialize(null);

    const refTimesPerSec = 10000000;
    const refTimesPerMillisec = 10000;

    var hr: win.HRESULT = 0;

    hr = win.CoInitialize(null);
    if (win.FAILED(hr)) return error.CoInitFailed;
    defer win.CoUninitialize();

    var pEnumerator: *win.IMMDeviceEnumerator = undefined;

    hr = win.CoCreateInstance(
        &CLSID_MMDeviceEnumerator,
        null,
        win.CLSCTX_ALL,
        &IID_IMMDeviceEnumerator,
        @ptrCast(&pEnumerator),
    );
    if (win.FAILED(hr)) return error.CoCreateFailed;
    defer _ = pEnumerator.lpVtbl.*.Release.?(pEnumerator);

    var pDevice: *win.IMMDevice = undefined;

    hr = pEnumerator.lpVtbl.*.GetDefaultAudioEndpoint.?(
        pEnumerator,
        win.eRender,
        win.eConsole,
        @ptrCast(&pDevice),
    );
    if (win.FAILED(hr)) return error.GetDefaultAudioEndpointFailed;
    defer _ = pDevice.lpVtbl.*.Release.?(pDevice);

    var pAudioClient: *win.IAudioClient = undefined;

    hr = pDevice.lpVtbl.*.Activate.?(
        pDevice,
        &IID_IAudioClient,
        win.CLSCTX_ALL,
        null,
        @ptrCast(&pAudioClient),
    );
    if (win.FAILED(hr)) return error.ActivateFailed;
    defer _ = pAudioClient.lpVtbl.*.Release.?(pAudioClient);

    var pwfx: *win.WAVEFORMATEX = undefined;

    hr = pAudioClient.lpVtbl.*.GetMixFormat.?(
        pAudioClient,
        @ptrCast(&pwfx),
    );
    if (win.FAILED(hr)) return error.GetMixFormatFailed;
    defer win.CoTaskMemFree(pwfx);

    const hnsRequestedDuration = refTimesPerSec;

    hr = pAudioClient.lpVtbl.*.Initialize.?(
        pAudioClient,
        win.AUDCLNT_SHAREMODE_SHARED,
        win.AUDCLNT_STREAMFLAGS_LOOPBACK,
        hnsRequestedDuration,
        0,
        pwfx,
        null,
    );
    if (win.FAILED(hr)) return error.AudioClientInitFailed;

    var bufferFrameCount: win.UINT32 = undefined;

    hr = pAudioClient.lpVtbl.*.GetBufferSize.?(
        pAudioClient,
        @ptrCast(&bufferFrameCount),
    );
    if (win.FAILED(hr)) return error.GetBufferSizeFailed;

    var pCaptureClient: *win.IAudioCaptureClient = undefined;

    hr = pAudioClient.lpVtbl.*.GetService.?(
        pAudioClient,
        &IID_IAudioCaptureClient,
        @ptrCast(&pCaptureClient),
    );
    if (win.FAILED(hr)) return error.GetServiceFailed;
    defer _ = pCaptureClient.lpVtbl.*.Release.?(pCaptureClient);

    const hnsActualDuration: f64 = @as(f64, refTimesPerSec) * @as(f64, @floatFromInt(bufferFrameCount)) / @as(f64, @floatFromInt(pwfx.nSamplesPerSec));

    hr = pAudioClient.lpVtbl.*.Start.?(pAudioClient);
    if (win.FAILED(hr)) return error.AudioClientStartFailed;

    var bDone = false;
    var packetLength: win.UINT32 = 0;
    var numFramesAvailable: win.UINT32 = 0;
    var flags: win.DWORD = undefined;
    var pData: [*]win.BYTE = undefined;

    while (!bDone) {
        std.time.sleep(@intFromFloat((hnsActualDuration / refTimesPerMillisec / 2) * std.time.ns_per_ms));

        hr = pCaptureClient.lpVtbl.*.GetNextPacketSize.?(pCaptureClient, &packetLength);
        if (win.FAILED(hr)) return error.GetNextPacketSizeFailed;

        std.debug.print("packetLength: {d}\n", .{packetLength});

        while (packetLength != 0) {
            hr = pCaptureClient.lpVtbl.*.GetBuffer.?(
                pCaptureClient,
                @ptrCast(&pData),
                @ptrCast(&numFramesAvailable),
                @ptrCast(&flags),
                null,
                null,
            );
            if (win.FAILED(hr)) return error.GetBufferFailed;

            // NOTE: i do not care
            // if (flags & win.AUDCLNT_BUFFERFLAGS_SILENT) {
            //     pData = null;
            // }
            //

            const data = pData[0..numFramesAvailable];

            // TODO: draw data, dont care about thread for now

            var acc: i64 = 0;
            for (data) |sample| {
                acc += (@as(i64, sample) - 128);
            }
            std.debug.print("average {d}\n", .{@divFloor(acc, @as(i64, @intCast(data.len)))});
            // std.debug.print("{any}\n", .{data[0..10]});

            hr = pCaptureClient.lpVtbl.*.ReleaseBuffer.?(pCaptureClient, numFramesAvailable);
            if (win.FAILED(hr)) return error.ReleaseBufferFailed;

            hr = pCaptureClient.lpVtbl.*.GetNextPacketSize.?(pCaptureClient, &packetLength);
            if (win.FAILED(hr)) return error.GetNextPacketSizeFailed;

            // break;
        }

        bDone = true;
    }

    hr = pAudioClient.lpVtbl.*.Stop.?(pAudioClient);
    if (win.FAILED(hr)) return error.AudioClientStopFailed;
}
