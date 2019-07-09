if(CMAKE_CXX_COMPILER_ID STREQUAL GNU)
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS 7)
    message(FATAL_ERROR "GCC 7+ required due to C++17 requirements")
  endif()
endif()

#Check Includes
include(CheckIncludeFiles)
include(CheckIncludeFileCXX)
include(CheckFunctionExists)

check_function_exists(fallocate CEPH_HAVE_FALLOCATE)
check_function_exists(posix_fadvise HAVE_POSIX_FADVISE)
check_function_exists(posix_fallocate HAVE_POSIX_FALLOCATE)
check_function_exists(syncfs HAVE_SYS_SYNCFS)
check_function_exists(sync_file_range HAVE_SYNC_FILE_RANGE)
check_function_exists(pwritev HAVE_PWRITEV)
check_function_exists(splice CEPH_HAVE_SPLICE)
check_function_exists(getgrouplist HAVE_GETGROUPLIST)
if(NOT APPLE)
  check_function_exists(fdatasync HAVE_FDATASYNC)
endif()
check_function_exists(strerror_r HAVE_Strerror_R)
check_function_exists(name_to_handle_at HAVE_NAME_TO_HANDLE_AT)
check_function_exists(pipe2 HAVE_PIPE2)
check_function_exists(accept4 HAVE_ACCEPT4)

include(CMakePushCheckState)
cmake_push_check_state(RESET)
set(CMAKE_REQUIRED_LIBRARIES pthread)
check_function_exists(pthread_spin_init HAVE_PTHREAD_SPINLOCK)
check_function_exists(pthread_set_name_np HAVE_PTHREAD_SET_NAME_NP)
check_function_exists(pthread_get_name_np HAVE_PTHREAD_GET_NAME_NP)
check_function_exists(pthread_setname_np HAVE_PTHREAD_SETNAME_NP)
check_function_exists(pthread_getname_np HAVE_PTHREAD_GETNAME_NP)
check_function_exists(pthread_rwlockattr_setkind_np HAVE_PTHREAD_RWLOCKATTR_SETKIND_NP)
cmake_pop_check_state()

check_function_exists(eventfd HAVE_EVENTFD)
check_function_exists(getprogname HAVE_GETPROGNAME)

CHECK_INCLUDE_FILES("linux/types.h" HAVE_LINUX_TYPES_H)
CHECK_INCLUDE_FILES("linux/version.h" HAVE_LINUX_VERSION_H)
CHECK_INCLUDE_FILES("arpa/nameser_compat.h" HAVE_ARPA_NAMESER_COMPAT_H)
CHECK_INCLUDE_FILES("sys/mount.h" HAVE_SYS_MOUNT_H)
CHECK_INCLUDE_FILES("sys/param.h" HAVE_SYS_PARAM_H)
CHECK_INCLUDE_FILES("sys/types.h" HAVE_SYS_TYPES_H)
CHECK_INCLUDE_FILES("sys/vfs.h" HAVE_SYS_VFS_H)
CHECK_INCLUDE_FILES("sys/prctl.h" HAVE_SYS_PRCTL_H)
CHECK_INCLUDE_FILES("execinfo.h" HAVE_EXECINFO_H)
if(LINUX)
  CHECK_INCLUDE_FILES("sched.h" HAVE_SCHED)
endif()
CHECK_INCLUDE_FILES("valgrind/helgrind.h" HAVE_VALGRIND_HELGRIND_H)

include(CheckTypeSize)
set(CMAKE_EXTRA_INCLUDE_FILES "linux/types.h")
CHECK_TYPE_SIZE(__be16 __BE16) 
CHECK_TYPE_SIZE(__be32 __BE32) 
CHECK_TYPE_SIZE(__be64 __BE64) 
CHECK_TYPE_SIZE(__le16 __LE16) 
CHECK_TYPE_SIZE(__le32 __LE32) 
CHECK_TYPE_SIZE(__le64 __LE64) 
CHECK_TYPE_SIZE(__u8 __U8) 
CHECK_TYPE_SIZE(__u16 __U16) 
CHECK_TYPE_SIZE(__u32 __U32) 
CHECK_TYPE_SIZE(__u64 __U64) 
CHECK_TYPE_SIZE(__s8 __S8) 
CHECK_TYPE_SIZE(__s16 __S16) 
CHECK_TYPE_SIZE(__s32 __S32) 
CHECK_TYPE_SIZE(__s64 __S64) 
unset(CMAKE_EXTRA_INCLUDE_FILES)

include(CheckSymbolExists)
check_symbol_exists(res_nquery "resolv.h" HAVE_RES_NQUERY)
check_symbol_exists(F_SETPIPE_SZ "linux/fcntl.h" CEPH_HAVE_SETPIPE_SZ)
check_symbol_exists(__func__ "" HAVE_FUNC)
check_symbol_exists(__PRETTY_FUNCTION__ "" HAVE_PRETTY_FUNC)
check_symbol_exists(getentropy "unistd.h" HAVE_GETENTROPY)

include(CheckCXXSourceCompiles)
check_cxx_source_compiles("
  #include <string.h>
  int main() { char x = *strerror_r(0, &x, sizeof(x)); return 0; }
  " STRERROR_R_CHAR_P)

include(CheckStructHasMember)
CHECK_STRUCT_HAS_MEMBER("struct stat" st_mtim.tv_nsec sys/stat.h
  HAVE_STAT_ST_MTIM_TV_NSEC LANGUAGE C)
CHECK_STRUCT_HAS_MEMBER("struct stat" st_mtimespec.tv_nsec sys/stat.h
  HAVE_STAT_ST_MTIMESPEC_TV_NSEC LANGUAGE C)

if(CMAKE_SYSTEM_PROCESSOR STREQUAL CMAKE_HOST_SYSTEM_PROCESSOR)
  include(CheckCXXSourceRuns)
  cmake_push_check_state()
  set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} -std=c++17")
  check_cxx_source_runs("
#include <cstdint>
#include <iterator>
#include <arpa/inet.h>

uint32_t load(char* p, size_t offset)
{
  return *reinterpret_cast<uint32_t*>(p + offset);
}

bool good(uint32_t lhs, uint32_t small_endian)
{
  uint32_t rhs;
  if (ntohl(0xdeadbeaf) == 0xdeadbeaf) {
    return lhs == ntohl(small_endian);
  } else {
    return lhs == small_endian;
  }
}

int main(int argc, char **argv)
{
  char a1[] = \"ABCDEFG\";
  uint32_t a2[] = {0x44434241,
                   0x45444342,
                   0x46454443,
                   0x47464544};
  for (size_t i = 0; i < std::size(a2); i++) {
    if (!good(load(a1, i), a2[i])) {
      return 1;
    }
  }
}"
    HAVE_UNALIGNED_ACCESS)
  cmake_pop_check_state()
  if(NOT HAVE_UNALIGNED_ACCESS)
    message(FATAL_ERROR "Unaligned access is required")
  endif()
else(CMAKE_SYSTEM_PROCESSOR STREQUAL CMAKE_HOST_SYSTEM_PROCESSOR)
  message(STATUS "Assuming unaligned access is supported")
endif(CMAKE_SYSTEM_PROCESSOR STREQUAL CMAKE_HOST_SYSTEM_PROCESSOR)
