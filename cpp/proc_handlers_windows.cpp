#include <windows.h>
#include <TlHelp32.h>
#include <cstdint>
#include <tchar.h>

#pragma comment(lib, "user32.lib")

// Get the process ID of a running process
DWORD get_process_id(const wchar_t* process_name) {
	DWORD process_id = 0;

	HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, NULL);
	if (snapshot == INVALID_HANDLE_VALUE) {
		return process_id;
	}

	PROCESSENTRY32W entry = {};
	entry.dwSize = sizeof(decltype(entry));

	if (Process32FirstW(snapshot, &entry) == TRUE) {
		// Check if the first handle is the one we want
		if (_wcsicmp(process_name, entry.szExeFile) == 0) {
			process_id = entry.th32ProcessID;
		}
		else {
			while (Process32NextW(snapshot, &entry) == TRUE) {
				if (_wcsicmp(process_name, entry.szExeFile) == 0) {
					process_id = entry.th32ProcessID;
					break;
				}
			}
		}
	}

	CloseHandle(snapshot);

	return process_id;
}

BOOL CALLBACK EnumWindowsProc(HWND current_hwnd, LPARAM lparam) {
    DWORD process_id = *reinterpret_cast<DWORD *>(lparam);
    DWORD current_process_id;
    HWND *hwnd_ptr = reinterpret_cast<HWND *>(lparam + sizeof(DWORD));

    GetWindowThreadProcessId(current_hwnd, &current_process_id);
    if (current_process_id == process_id) {
        *hwnd_ptr = current_hwnd;
        return FALSE;
    }
    return TRUE;
}

// Get window hwnd from pid
extern "C" HWND get_hwnd(DWORD process_id) {
    HWND hwnd = NULL;
    DWORD data_array[2];
    data_array[0] = process_id;
    data_array[1] = NULL;

    EnumWindows(EnumWindowsProc, reinterpret_cast<LPARAM>(data_array)); // Pass data array as LPARAM

    return (HWND)data_array[1];
}

// Get the base address of a module loaded in a process
std::uintptr_t get_module_base(const DWORD pid, const wchar_t* module_name) {
	std::uintptr_t module_base = 0;

	// Snap shot of process' modules (dlls)
	HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, pid);
	if (snapshot == INVALID_HANDLE_VALUE) {
		return module_base;
	}

	MODULEENTRY32W entry = {};
	entry.dwSize = sizeof(decltype(entry));

	if (Module32FirstW(snapshot, &entry) == TRUE) {
		if (wcsstr(module_name, entry.szModule) != nullptr) { // the logic is probably fixed here
			module_base = reinterpret_cast<std::uintptr_t>(entry.modBaseAddr);
		}
		else {
			while (Module32NextW(snapshot, &entry) == TRUE) {
				if (wcsstr(module_name, entry.szModule) != nullptr) {
					module_base = reinterpret_cast<std::uintptr_t>(entry.modBaseAddr);
					break;
				}
			}
		}
	}

	CloseHandle(snapshot);

	return module_base;
}