#include <mmdeviceapi.h>
#include <audioclient.h>
#include <initguid.h>
#include <stdio.h>

int main() {
    const IID iid = __uuidof(IAudioCaptureClient);
    printf(
        "GUID{ .Data1 = 0x%08X, .Data2 = 0x%04X, .Data3 = 0x%04X, .Data4 = [_]u8{",
        iid.Data1, iid.Data2, iid.Data3
    );
    for (int i = 0; i < 8; ++i) {
        printf(" 0x%02X,", iid.Data4[i]);
    }
    printf(" } };\n");
}
