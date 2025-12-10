// Minimal test program to verify Windows runtime environment
// This helps isolate whether the issue is Qt-specific or more fundamental

#include <windows.h>
#include <iostream>

int main(int argc, char* argv[]) {
    // Test basic C++ runtime
    std::cout << "=== Runtime Environment Test ===" << std::endl;
    std::cout << "Basic C++ runtime: OK" << std::endl;

    // Test Windows API
    DWORD version = GetVersion();
    std::cout << "Windows version: " << (version & 0xFF) << "." << ((version >> 8) & 0xFF) << std::endl;

    // Test current directory
    char currentDir[MAX_PATH];
    if (GetCurrentDirectoryA(MAX_PATH, currentDir)) {
        std::cout << "Current directory: " << currentDir << std::endl;
    }

    // Test command line
    std::cout << "Command line args: " << argc << std::endl;
    for (int i = 0; i < argc; i++) {
        std::cout << "  argv[" << i << "]: " << argv[i] << std::endl;
    }

    // Test heap allocation
    void* ptr = malloc(1024);
    if (ptr) {
        std::cout << "Memory allocation: OK" << std::endl;
        free(ptr);
    } else {
        std::cout << "Memory allocation: FAILED" << std::endl;
    }

    std::cout << "=== Runtime test completed ===" << std::endl;
    return 0;
}
