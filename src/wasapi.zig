const std = @import("std");

const win = @cImport({
    @cInclude("windows.h");
    @cInclude("mmdeviceapi.h");
    @cInclude("audioclient.h");
    @cInclude("avrt.h");
    @cInclude("stdio.h");
});

// https://learn.microsoft.com/en-us/windows/win32/coreaudio/capturing-a-stream
// https://learn.microsoft.com/en-us/windows/win32/coreaudio/loopback-recording
// ported to zig

const Self = @This();

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

const refTimesPerSec = 10000000;
const refTimesPerMillisec = 10000;

pEnumerator: *win.IMMDeviceEnumerator,
pDevice: *win.IMMDevice,
pAudioClient: *win.IAudioClient,
pwfx: *win.WAVEFORMATEX,
pCaptureClient: *win.IAudioCaptureClient,
frameSize: usize,

pub fn init() !Self {
    var hr: win.HRESULT = 0;

    hr = win.CoInitialize(null);
    if (win.FAILED(hr)) return error.CoInitFailed;

    var pEnumerator: *win.IMMDeviceEnumerator = undefined;

    hr = win.CoCreateInstance(
        &CLSID_MMDeviceEnumerator,
        null,
        win.CLSCTX_ALL,
        &IID_IMMDeviceEnumerator,
        @ptrCast(&pEnumerator),
    );
    if (win.FAILED(hr)) return error.CoCreateFailed;

    var pDevice: *win.IMMDevice = undefined;

    hr = pEnumerator.lpVtbl.*.GetDefaultAudioEndpoint.?(
        pEnumerator,
        win.eRender,
        win.eConsole,
        @ptrCast(&pDevice),
    );
    if (win.FAILED(hr)) return error.GetDefaultAudioEndpointFailed;

    var pAudioClient: *win.IAudioClient = undefined;

    hr = pDevice.lpVtbl.*.Activate.?(
        pDevice,
        &IID_IAudioClient,
        win.CLSCTX_ALL,
        null,
        @ptrCast(&pAudioClient),
    );
    if (win.FAILED(hr)) return error.ActivateFailed;

    var pwfx: *win.WAVEFORMATEX = undefined;

    hr = pAudioClient.lpVtbl.*.GetMixFormat.?(
        pAudioClient,
        @ptrCast(&pwfx),
    );
    if (win.FAILED(hr)) return error.GetMixFormatFailed;

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

    hr = pAudioClient.lpVtbl.*.Start.?(pAudioClient);
    if (win.FAILED(hr)) return error.AudioClientStartFailed;

    return .{
        .pEnumerator = pEnumerator,
        .pDevice = pDevice,
        .pAudioClient = pAudioClient,
        .pwfx = pwfx,
        .pCaptureClient = pCaptureClient,
        .frameSize = @as(usize, pwfx.nChannels) * @divExact(pwfx.wBitsPerSample, 8),
    };
}

pub fn deinit(self: Self) void {
    _ = self.pAudioClient.lpVtbl.*.Stop.?(self.pAudioClient);
    win.CoUninitialize();
    _ = self.pEnumerator.lpVtbl.*.Release.?(self.pEnumerator);
    _ = self.pDevice.lpVtbl.*.Release.?(self.pDevice);
    _ = self.pAudioClient.lpVtbl.*.Release.?(self.pAudioClient);
    win.CoTaskMemFree(self.pwfx);
    _ = self.pCaptureClient.lpVtbl.*.Release.?(self.pCaptureClient);
}

const Buffer = struct {
    value: []const u8,
    pCaptureClient: *win.IAudioCaptureClient,
    numFramesAvailable: win.UINT32,

    pub fn deinit(self: Buffer) void {
        _ = self.pCaptureClient.lpVtbl.*.ReleaseBuffer.?(self.pCaptureClient, self.numFramesAvailable);
    }
};

pub fn getBuffer(self: *Self) !?Buffer {
    var hr: win.HRESULT = 0;

    var packetLength: win.UINT32 = 0;
    var flags: win.DWORD = undefined;
    var pData: [*]win.BYTE = undefined;
    var numFramesAvailable: win.UINT32 = 0;

    hr = self.pCaptureClient.lpVtbl.*.GetNextPacketSize.?(self.pCaptureClient, &packetLength);
    if (win.FAILED(hr)) return error.GetNextPacketSizeFailed;

    if (packetLength == 0) {
        numFramesAvailable = 0;
        return null;
    }

    hr = self.pCaptureClient.lpVtbl.*.GetBuffer.?(
        self.pCaptureClient,
        @ptrCast(&pData),
        @ptrCast(&numFramesAvailable),
        @ptrCast(&flags),
        null,
        null,
    );
    if (win.FAILED(hr)) return error.GetBufferFailed;

    return .{
        .value = pData[0 .. numFramesAvailable * self.frameSize],
        .pCaptureClient = self.pCaptureClient,
        .numFramesAvailable = numFramesAvailable,
    };
}
