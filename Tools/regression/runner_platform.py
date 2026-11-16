"""OS process accounting and nonblocking worker-slot locks for run_all.py."""

import ctypes
import errno
import os
import signal
import sys

WINDOWS = os.name == "nt"
if WINDOWS:
    import msvcrt
else:
    import fcntl


def try_lock(guard, windows=WINDOWS, locker=None):
    guard.seek(0)
    try:
        if windows:
            (locker or msvcrt.locking)(guard.fileno(), 2, 1)  # LK_NBLCK
        else:
            (locker or fcntl.flock)(guard.fileno(), 2 | 4)  # LOCK_EX | LOCK_NB
    except OSError as error:
        if error.errno in (errno.EACCES, errno.EAGAIN, errno.EDEADLK):
            return False
        raise
    return True


def kill(child, windows=WINDOWS):
    try:
        if windows:
            child.kill()
        else:
            os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


class MemoryCounters(ctypes.Structure):
    _fields_ = [("cb", ctypes.c_uint32), ("PageFaultCount", ctypes.c_uint32)] + [
        (name, ctypes.c_size_t) for name in (
            "PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage",
            "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage")]


def windows_usage(handle, memory_api=None, times_api=None):
    try:
        memory_api = memory_api or ctypes.windll.psapi.GetProcessMemoryInfo
        times_api = times_api or ctypes.windll.kernel32.GetProcessTimes
        memory = MemoryCounters()
        memory.cb = ctypes.sizeof(memory)
        created, exited, kernel, user = (ctypes.c_uint64() for _ in range(4))
        memory_ok = memory_api(ctypes.c_void_p(int(handle)), ctypes.byref(memory), memory.cb)
        times_ok = times_api(ctypes.c_void_p(int(handle)), *map(ctypes.byref, (created, exited, kernel, user)))
        return (memory.PeakPagefileUsage / (1 << 20) if memory_ok else None,
                (kernel.value + user.value) / 10_000_000 if times_ok else None)
    except (OSError, AttributeError):
        return None, None


def wait(child, windows=WINDOWS):
    if windows:
        child.wait()
        return windows_usage(child._handle)
    _, status, usage = os.wait4(child.pid, 0)
    child.returncode = os.waitstatus_to_exitcode(status)
    divisor = (1 << 20) if sys.platform == "darwin" else 1024
    return usage.ru_maxrss / divisor, usage.ru_utime + usage.ru_stime
