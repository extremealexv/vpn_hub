import sys
import pty
import os
import time

if len(sys.argv) < 3:
    print("Usage: python3 run_ssh.py <password> <command...>")
    sys.exit(1)

password = sys.argv[1]
command = sys.argv[2:]

pid, fd = pty.fork()
if pid == 0:
    os.execvp(command[0], command)
else:
    buffer = b""
    while True:
        try:
            chunk = os.read(fd, 1024)
            if not chunk:
                break
            buffer += chunk
            sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()
            
            # Check for password prompts
            lower_buf = buffer.lower()
            if b"password:" in lower_buf:
                time.sleep(0.1) # Wait a bit for the prompt to settle
                os.write(fd, (password + "\n").encode())
                buffer = b"" # Reset buffer after sending password
                
        except OSError:
            break
    
    _, status = os.waitpid(pid, 0)
    exit_code = os.waitstatus_to_exitcode(status) if hasattr(os, 'waitstatus_to_exitcode') else os.WEXITSTATUS(status)
    sys.exit(exit_code)
