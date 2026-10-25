// Shared definitions for the qtf C ABI shim.
#pragma once

// Every shim function is exported from the qtf shared library.
#if defined(_WIN32)
#define QTF_API extern "C" __declspec(dllexport)
#else
#define QTF_API extern "C" __attribute__((visibility("default")))
#endif
