#include "../include/CSMC.h"

#include <IOKit/IOKitLib.h>
#include <string.h>

typedef struct {
    char major;
    char minor;
    char build;
    char reserved;
    unsigned short release;
} smc_vers_t;

typedef struct {
    unsigned short version;
    unsigned short length;
    unsigned int cpuPLimit;
    unsigned int gpuPLimit;
    unsigned int memPLimit;
} smc_plimit_t;

typedef struct {
    unsigned int dataSize;
    unsigned int dataType;
    char dataAttributes;
} smc_keyinfo_t;

typedef struct {
    unsigned int key;
    smc_vers_t vers;
    smc_plimit_t pLimitData;
    smc_keyinfo_t keyInfo;
    char result;
    char status;
    char data8;
    unsigned int data32;
    unsigned char data[32];
} smc_keydata_t;

#define SMC_KERNEL_INDEX 2
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_READ_KEYINFO 9
#define SMC_CMD_READ_KEYINFO_INDEX 8

static io_connect_t g_conn = 0;

static kern_return_t smc_call(int index, smc_keydata_t *input, smc_keydata_t *output) {
    size_t input_size = sizeof(smc_keydata_t);
    size_t output_size = sizeof(smc_keydata_t);
    return IOConnectCallStructMethod(g_conn, index, input, input_size, output, &output_size);
}

static uint32_t fourcc(const char *s) {
    return ((uint32_t)(unsigned char)s[0] << 24) |
           ((uint32_t)(unsigned char)s[1] << 16) |
           ((uint32_t)(unsigned char)s[2] << 8) |
           (uint32_t)(unsigned char)s[3];
}

static int read_key_info(uint32_t key, smc_keyinfo_t *out_info) {
    smc_keydata_t input;
    smc_keydata_t output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = key;
    input.data8 = SMC_CMD_READ_KEYINFO;

    if (smc_call(SMC_KERNEL_INDEX, &input, &output) != KERN_SUCCESS) {
        return -1;
    }
    if (output.result != 0) {
        return -2;
    }

    *out_info = output.keyInfo;
    return 0;
}

int macpulse_smc_open(void) {
    if (g_conn != 0) {
        return 0;
    }

    io_iterator_t iterator = 0;
    CFMutableDictionaryRef matching = IOServiceMatching("AppleSMC");
    if (matching == NULL) {
        return -1;
    }
    if (IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) != KERN_SUCCESS) {
        return -1;
    }

    io_service_t service = 0;
    while ((service = IOIteratorNext(iterator)) != 0) {
        char name[128] = {0};
        if (IORegistryEntryGetName(service, name) == KERN_SUCCESS && strcmp(name, "AppleSMCKeysEndpoint") == 0) {
            io_connect_t connection = 0;
            kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, &connection);
            IOObjectRelease(service);
            if (result == KERN_SUCCESS) {
                g_conn = connection;
                break;
            }
        } else {
            IOObjectRelease(service);
        }
    }

    IOObjectRelease(iterator);
    return g_conn != 0 ? 0 : -1;
}

void macpulse_smc_close(void) {
    if (g_conn != 0) {
        IOServiceClose(g_conn);
        g_conn = 0;
    }
}

uint32_t macpulse_smc_key_count(void) {
    if (g_conn == 0) {
        return 0;
    }

    smc_keyinfo_t info;
    if (read_key_info(fourcc("#KEY"), &info) != 0) {
        return 0;
    }

    smc_keydata_t input;
    smc_keydata_t output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = fourcc("#KEY");
    input.keyInfo = info;
    input.data8 = SMC_CMD_READ_BYTES;

    if (smc_call(SMC_KERNEL_INDEX, &input, &output) != KERN_SUCCESS || output.result != 0) {
        return 0;
    }
    if (info.dataSize < 4) {
        return 0;
    }

    return ((uint32_t)output.data[0] << 24) |
           ((uint32_t)output.data[1] << 16) |
           ((uint32_t)output.data[2] << 8) |
           (uint32_t)output.data[3];
}

int macpulse_smc_key_by_index(uint32_t index, char out_key[5]) {
    if (g_conn == 0 || out_key == NULL) {
        return -1;
    }

    smc_keydata_t input;
    smc_keydata_t output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.data8 = SMC_CMD_READ_KEYINFO_INDEX;
    input.data32 = index;

    if (smc_call(SMC_KERNEL_INDEX, &input, &output) != KERN_SUCCESS || output.result != 0) {
        return -1;
    }

    uint32_t key = output.key;
    out_key[0] = (char)((key >> 24) & 0xFF);
    out_key[1] = (char)((key >> 16) & 0xFF);
    out_key[2] = (char)((key >> 8) & 0xFF);
    out_key[3] = (char)(key & 0xFF);
    out_key[4] = '\0';
    return 0;
}

int macpulse_smc_read_key(const char *key,
                          uint32_t *out_data_size,
                          uint32_t *out_data_type,
                          uint8_t *out_bytes,
                          size_t out_capacity) {
    if (g_conn == 0 || key == NULL || strlen(key) != 4) {
        return -1;
    }
    if (out_data_size == NULL || out_data_type == NULL || out_bytes == NULL) {
        return -1;
    }

    uint32_t key_code = fourcc(key);
    smc_keyinfo_t info;
    int info_result = read_key_info(key_code, &info);
    if (info_result != 0) {
        return info_result;
    }
    if (info.dataSize > out_capacity || info.dataSize > 32) {
        return -3;
    }

    smc_keydata_t input;
    smc_keydata_t output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = key_code;
    input.keyInfo = info;
    input.data8 = SMC_CMD_READ_BYTES;

    if (smc_call(SMC_KERNEL_INDEX, &input, &output) != KERN_SUCCESS) {
        return -1;
    }
    if (output.result != 0) {
        return -2;
    }

    if (info.dataSize > 0) {
        memcpy(out_bytes, output.data, info.dataSize);
    }
    *out_data_size = info.dataSize;
    *out_data_type = info.dataType;
    return 0;
}
