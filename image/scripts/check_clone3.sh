#!/bin/sh

# Debian 13 uses a glibc that creates threads with the clone3 syscall.
# It expects an ENOSYS error before falling back to the old method.
#
# Docker started returning ENOSYS in 20.10.10. Older versions
# used EPERM instead.

# Check if clone3 is denied. It is syscall 435 on every architecture that both
# Debian 13 and node are available for. Giving it a size of 0 is rejected with
# EINVAL before the kernel creates anything, so this only tells us whether the
# syscall can be reached.
#
# Exit 3 means it was denied. If the status is different, it either passed
# or failed for an unknown reason, and we assume it works.
python3 -c "
import ctypes, errno, sys
libc = ctypes.CDLL(None, use_errno=True)
ctypes.set_errno(0)
libc.syscall(435, None, 0)
sys.exit(3 if ctypes.get_errno() == errno.EPERM else 0)
" 2>/dev/null

if [ $? -ne 3 ]; then
  exit 0
fi

cat >&2 <<'EOF'

=> ERROR: The Docker version is outdated

This version of zodern/meteor uses Debian 13, which requires Docker 20.10.10 or newer.

To fix this, either:

  * Update Docker to 20.10.10 or newer, or
  * Use an older version of zodern/meteor based on Debian 11:
      zodern/meteor:0  (or zodern/meteor:0-root)

Adding "--security-opt seccomp=unconfined" to docker run also works, but only
when running the app. It can not be used for docker build.

EOF

exit 1
