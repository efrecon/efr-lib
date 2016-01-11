package require winapi::core

namespace eval ::winapi {
    variable WINAPI
    variable log


}

proc ::winapi::AttachThreadInput { from to attach } {
    return [__AttachThreadInput $from $to [string is true $attach]]
}


# ::winapi::CreateToolhelp32Snapshot -- Process, etc. snapshots
#
#	Takes a snapshot of the specified processes, as well as the
#	heaps, modules, and threads used by these processes
#
# Arguments:
#	flags	The portion of the system to be included in the snapshot
#	pid	Possible process identifier, 0 for all.
#
# Results:
#	Return a handle to the snapshot, to be used with the
#	Process32First/Next, Module32First/Next and Thread32First/Next
#	functions.
#
# Side Effects:
#	None.
proc ::winapi::CreateToolhelp32Snapshot { flags pid } {
    set fl [core::flags $flags [list \
				    *INHERIT        [expr {0x80000000}] \
				    *SNAPALL        [expr {0x0000001f}] \
				    *SNAPHEAPLIST   [expr {0x00000001}] \
				    *SNAPMODULE     [expr {0x00000008}] \
				    *SNAPMODULE32   [expr {0x00000010}] \
				    *SNAPPROCESS    [expr {0x00000002}] \
				    *SNAPTHREAD     [expr {0x00000004}]]]
    return [__CreateToolhelp32Snapshot $fl $pid]
}


# ::winapi::__Thread32Iterate -- Iterate among thread snapshot
#
#	Retrieves information about threads of any process encountered
#	in a system snapshot.
#
# Arguments:
#	hSnap	Handle returned by CreateToolhelp32Snapshot
#	fn	Function to call, First or Next
#
# Results:
#	This procedure returns a list ready for an array set command,
#	the list contains the following keys: ThreadID OwnerProcessID
#	and BasePri.  On error or end, the procedure returns an empty
#	string.
#
# Side Effects:
#	None.
proc ::winapi::__Thread32Iterate { hSnapshot fn } {
    set len [::ffidl::info sizeof ::winapi::THREADENTRY32]
    set buf [binary format "x${len}@0i1" $len]
    set res [__${fn} $hSnapshot buf]
    if { $res } {
	binary scan $buf [::ffidl::info format ::winapi::THREADENTRY32] \
	    dwSize \
	    cntUsag \
	    te32(ThreadID) \
	    te32(OwnerProcessID) \
	    te32(BasePri) \
	    delta \
	    flags

	return [array get te32]
    }

    return ""
}


# ::winapi::Thread32First -- Access first thread of snapshot
#
#	Retrieves information about the first thread of any process
#	encountered in a system snapshot.
#
# Arguments:
#	hSnap	Handle returned by CreateToolhelp32Snapshot
#
# Results:
#	This procedure returns a list ready for an array set command,
#	the list contains the following keys: ThreadID OwnerProcessID
#	and BasePri.  On error or end, the procedure returns an empty
#	string.
#
# Side Effects:
#	None.
proc ::winapi::Thread32First { hSnapshot } {
    return [__Thread32Iterate $hSnapshot Thread32First]
}


# ::winapi::Thread32Next -- Access next thread of snapshot
#
#	Retrieves information about the next thread of any process
#	encountered in a system snapshot.
#
# Arguments:
#	hSnap	Handle returned by CreateToolhelp32Snapshot
#
# Results:
#	This procedure returns a list ready for an array set command,
#	the list contains the following keys: ThreadID OwnerProcessID
#	and BasePri.  On error or end, the procedure returns an empty
#	string.
#
# Side Effects:
#	None.
proc ::winapi::Thread32Next { hSnapshot } {
    return [__Thread32Iterate $hSnapshot Thread32Next]
}


# ::winapi::__Module32Iterate -- Iterate among module snapshot
#
#	Retrieves information about modules (DLLs) of any process
#	encountered in a system snapshot.
#
# Arguments:
#	hSnap	Handle returned by CreateToolhelp32Snapshot
#	fn	Function to call, First or Next
#
# Results:
#	This procedure returns a list ready for an array set command,
#	the list contains the following keys: ModuleID ProcessID
#	GlblcntUsage ProccntUsage modBaseAddr modBaseSize hModule
#	ExeModule ExePath.  On error or end, the procedure returns an
#	empty string.
#
# Side Effects:
#	None.
proc ::winapi::__Module32Iterate { hSnapshot fn } {
    set MAX_PATH 260
    set MAX_MODULE_NAME32 255
    set len [expr [::ffidl::info sizeof ::winapi::MODULEENTRY32] \
		 + (($MAX_PATH+$MAX_MODULE_NAME32+1)*[ffidl::info sizeof char])]
    set buf [binary format "x${len}@0i1" $len]
    set res [__${fn} $hSnapshot buf]
    if { $res } {
	binary scan $buf [::ffidl::info format ::winapi::MODULEENTRY32] \
	    dwSize \
	    me32(ModuleID) \
	    me32(ProcessID) \
	    me32(GlblcntUsage) \
	    me32(ProccntUsage) \
	    me32(modBaseAddr) \
	    me32(modBaseSize) \
	    me32(hModule)
	set mlen [expr $MAX_MODULE_NAME32 + 1]
	binary scan $buf \
	    "@[::ffidl::info sizeof ::winapi::MODULEENTRY32]A${mlen}" \
	    me32(ExeModule)
	binary scan $buf \
	    "@[expr [::ffidl::info sizeof ::winapi::MODULEENTRY32]+$mlen]A*" \
	    me32(ExePath)

	return [array get me32]
    }

    return ""
}


# ::winapi::Module32First -- Access first module of snapshot
#
#	Retrieves information about the first module (DLLs) of any
#	process encountered in a system snapshot.
#
# Arguments:
#	hSnap	Handle returned by CreateToolhelp32Snapshot
#
# Results:
#	This procedure returns a list ready for an array set command,
#	the list contains the following keys: ModuleID ProcessID
#	GlblcntUsage ProccntUsage modBaseAddr modBaseSize hModule
#	ExeModule ExePath.  On error or end, the procedure returns an
#	empty string.
#
# Side Effects:
#	None.
proc ::winapi::Module32First { hSnapshot } {
    return [__Module32Iterate $hSnapshot Module32First]
}


# ::winapi::Module32Next -- Access next module of snapshot
#
#	Retrieves information about the next module (DLLs) of any
#	process encountered in a system snapshot.
#
# Arguments:
#	hSnap	Handle returned by CreateToolhelp32Snapshot
#
# Results:
#	This procedure returns a list ready for an array set command,
#	the list contains the following keys: ModuleID ProcessID
#	GlblcntUsage ProccntUsage modBaseAddr modBaseSize hModule
#	ExeModule ExePath.  On error or end, the procedure returns an
#	empty string.
#
# Side Effects:
#	None.
proc ::winapi::Module32Next { hSnapshot } {
    return [__Module32Iterate $hSnapshot Module32Next]
}


# ::winapi::__Process32Iterate -- Iterate among process snapshot
#
#	Retrieves information about any process encountered in a
#	system snapshot.
#
# Arguments:
#	hSnap	Handle returned by CreateToolhelp32Snapshot
#	fn	Function to call, First or Next
#
# Results:
#	This procedure returns a list ready for an array set command,
#	the list contains the following keys: ProcessID DefaultHeapID
#	ModuleID Threads ParentProcessID PriClassBase and ExeFile.  On
#	error or end, the procedure returns an empty string.
#
# Side Effects:
#	None.
proc ::winapi::__Process32Iterate { hSnapshot fn } {
    set MAX_PATH 260
    set len [expr [::ffidl::info sizeof ::winapi::PROCESSENTRY32] \
		 + ($MAX_PATH*[ffidl::info sizeof char])]
    set buf [binary format "x${len}@0i1" $len]
    set res [__${fn} $hSnapshot buf]
    if { $res } {
	binary scan $buf [::ffidl::info format ::winapi::PROCESSENTRY32] \
	    dwSize \
	    cntUsage \
	    pe32(ProcessID) \
	    pe32(DefaultHeapID) \
	    pe32(ModuleID) \
	    pe32(Threads) \
	    pe32(ParentProcessID) \
	    pe32(PriClassBase) \
	    flags
	binary scan $buf "@[::ffidl::info sizeof ::winapi::PROCESSENTRY32]A*" \
	    pe32(ExeFile)

	return [array get pe32]
    }

    return ""
}


# ::winapi::Process32First -- Access first process of snapshot
#
#	Retrieves information about the first process encountered in a
#	system snapshot.
#
# Arguments:
#	hSnap	Handle returned by CreateToolhelp32Snapshot
#
# Results:
#	This procedure returns a list ready for an array set command,
#	the list contains the following keys: ProcessID DefaultHeapID
#	ModuleID Threads ParentProcessID PriClassBase and ExeFile.  On
#	error or end, the procedure returns an empty string.
#
# Side Effects:
#	None.
proc ::winapi::Process32First { hSnapshot } {
    return [__Process32Iterate $hSnapshot Process32First]
}


# ::winapi::Process32Next -- Access next process of snapshot
#
#	Retrieves information about the first process encountered in a
#	system snapshot.
#
# Arguments:
#	hSnap	Handle returned by CreateToolhelp32Snapshot
#
# Results:
#	This procedure returns a list ready for an array set command,
#	the list contains the following keys: ProcessID DefaultHeapID
#	ModuleID Threads ParentProcessID PriClassBase and ExeFile.  On
#	error or end, the procedure returns an empty string.
#
# Side Effects:
#	None.
proc ::winapi::Process32Next { hSnapshot } {
    return [__Process32Iterate $hSnapshot Process32Next]
}


# ::winapi::OpenProcess -- Opens process
#
#	Opens an existing local process object
#
# Arguments:
#	access	The desired access to the process object.
#	inherit	Handle inheritance
#	pid	Identifier of the local process to be opened
#
# Results:
#	A handle or null.
#
# Side Effects:
#	None.
proc ::winapi::OpenProcess { access inherit pid } {
    set flag [core::flags $access \
		   [list \
			DELETE             [expr {0x00010000}] \
			READ_CONTROL       [expr {0x00020000}] \
			SYNCHRONIZE        [expr {0x00100000}] \
			WRITE_DAC          [expr {0x00040000}] \
			WRITE_OWNER        [expr {0x00080000}] \
			*ALL_ACCESS        [expr {0x1f0fff}] \
			*CREATE_PROCESS    [expr {0x0080}] \
			*CREATE_THREAD     [expr {0x0002}] \
			*DUP_HANDLE        [expr {0x0040}] \
			*QUERY_INFORMATION [expr {0x0400}] \
			*QUERY_LIMITED_INFORMATION    [expr {0x1000}] \
			*SET_INFORMATION   [expr {0x0200}] \
			*SET_QUOTA         [expr {0x0100}] \
			*SUSPEND_RESUME    [expr {0x0800}] \
			*TERMINATE         [expr {0x0001}] \
			*VM_OPERATION      [expr {0x0008}] \
			*VM_READ           [expr {0x0010}] \
			*VM_WRITE          [expr {0x0020}]]]
    return [__OpenProcess $flag [string is true $inherit] $pid]
}


proc ::winapi::WaitForSingleObject { h ms } {
    set res [__WaitForSingleObject $h $ms]
    return [core::tflag $res \
		[list \
		     WAIT_ABANDONED      [expr {0x00000080}] \
		     WAIT_OBJECT_0       [expr {0x00000000}] \
		     WAIT_TIMEOUT        [expr {0x00000102}] \
		     WAIT_FAILED         [expr {0xFFFFFFFF}]]]
}

proc ::winapi::GetExitCodeProcess { h } {
    set len [::ffidl::info sizeof ::winapi::DWORD]
    set buf [binary format "x${len}@0i1" 0]
    if { [__GetExitCodeProcess $h buf] } {
	binary scan $buf i1 code
	if { $code == 259 } {
	    return STILL_ACTIVE
	} else {
	    return $code
	}
    }
    return ""
}

# ::winapi::__init_process_thread -- Initialise
#
#	This procedure initialises this module by declaring a whole
#	lot of callouts to functions for dealing with processes and
#	threads.  All callouts prefixed by __ will be internals for
#	which wrappers are provided.
#
# Arguments:
#	None.
#
# Results:
#	Boolean describe success or failure.
#
# Side Effects:
#	None.
proc ::winapi::__init_process_thread { } {
    variable WINAPI
    variable log

    # Type defs
    ::ffidl::typedef ::winapi::PROCESSENTRY32 \
	::winapi::DWORD ::winapi::DWORD ::winapi::DWORD ::winapi::ULONG_PTR \
	::winapi::DWORD ::winapi::DWORD ::winapi::DWORD ::winapi::LONG \
	::winapi::DWORD; # + MAX_PATH chars
    ::ffidl::typedef ::winapi::MODULEENTRY32 \
	::winapi::DWORD ::winapi::DWORD ::winapi::DWORD ::winapi::DWORD \
	::winapi::DWORD pointer ::winapi::DWORD \
	::winapi::HANDLE; # + MAX_MODULE_NAME32 + 1 + MAX_PATH chars
    ::ffidl::typedef ::winapi::THREADENTRY32 \
	::winapi::DWORD ::winapi::DWORD ::winapi::DWORD ::winapi::DWORD \
	::winapi::LONG ::winapi::LONG ::winapi::DWORD

    # Threads
    core::api GetCurrentThread {} ::winapi::HANDLE
    core::api GetCurrentThreadId {} ::winapi::DWORD
    core::api GetProcessIdOfThread { ::winapi::HANDLE } ::winapi::DWORD
    core::api GetThreadId { ::winapi::HANDLE } ::winapi::DWORD
    core::api __AttachThreadInput { ::winapi::DWORD ::winapi::DWORD \
				      ::winapi::BOOL } ::winapi::BOOL
    
    # Tool Help Library
    core::api __CreateToolhelp32Snapshot { ::winapi::DWORD ::winapi::DWORD } \
	::winapi::HANDLE
    core::api __Process32First { ::winapi::HANDLE pointer-var } ::winapi::BOOL
    core::api __Process32Next { ::winapi::HANDLE pointer-var } ::winapi::BOOL
    core::api __Module32First { ::winapi::HANDLE pointer-var } ::winapi::BOOL
    core::api __Module32Next { ::winapi::HANDLE pointer-var } ::winapi::BOOL
    core::api __Thread32First { ::winapi::HANDLE pointer-var } ::winapi::BOOL
    core::api __Thread32Next { ::winapi::HANDLE pointer-var } ::winapi::BOOL

    # Processes
    core::api GetProcessVersion { ::winapi::DWORD } ::winapi::DWORD
    core::api GetProcessId { ::winapi::HANDLE } ::winapi::DWORD
    core::api GetCurrentProcessId {} ::winapi::DWORD
    core::api GetCurrentProcess {} ::winapi::HANDLE
    core::api __OpenProcess { ::winapi::DWORD ::winapi::BOOL ::winapi::DWORD } \
	::winapi::HANDLE
    core::api ExitProcess { ::winapi::UINT } int
    core::api TerminateProcess { ::winapi::HANDLE ::winapi::UINT } \
	::winapi::BOOL
    core::api __GetExitCodeProcess { ::winapi::HANDLE pointer-var } \
	::winapi::BOOL

    # Object
    core::api __WaitForSingleObject { ::winapi::HANDLE ::winapi::DWORD } \
	::winapi::DWORD

    # Generic Handles
    core::api CloseHandle { ::winapi::HANDLE } ::winapi::BOOL

    return 1
}

# Now automatically initialises this module, once and only once
# through calling the __init procedure that was just declared above.
::winapi::core::initonce process_thread ::winapi::__init_process_thread

package provide winapi 0.2
