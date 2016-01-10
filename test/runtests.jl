using Base.Test
import LispREPL

# Setup. From Julia base repo.

type FakeTerminal <: Base.Terminals.UnixTerminal
    in_stream::Base.IO
    out_stream::Base.IO
    err_stream::Base.IO
    hascolor::Bool
    raw::Bool
    FakeTerminal(stdin,stdout,stderr,hascolor=true) =
        new(stdin,stdout,stderr,hascolor,false)
end

Base.Terminals.hascolor(t::FakeTerminal) = t.hascolor
Base.Terminals.raw!(t::FakeTerminal, raw::Bool) = t.raw = raw
Base.Terminals.size(t::FakeTerminal) = (24, 80)

function fake_repl()
    # Use pipes so we can easily do blocking reads
    # In the future if we want we can add a test that the right object
    # gets displayed by intercepting the display
    stdin_read,stdin_write = (Base.PipeEndpoint(), Base.PipeEndpoint())
    stdout_read,stdout_write = (Base.PipeEndpoint(), Base.PipeEndpoint())
    stderr_read,stderr_write = (Base.PipeEndpoint(), Base.PipeEndpoint())
    Base.link_pipe(stdin_read,true,stdin_write,true)
    Base.link_pipe(stdout_read,true,stdout_write,true)
    Base.link_pipe(stderr_read,true,stderr_write,true)

    repl = Base.REPL.LineEditREPL(FakeTerminal(stdin_read, stdout_write, stderr_write))
    stdin_write, stdout_read, stderr_read, repl
end

# Writing ^C to the repl will cause sigint, so let's not die on that
ccall(:jl_exit_on_sigint, Void, (Cint,), 0)
stdin_write, stdout_read, stderr_read, repl = fake_repl()

repl.specialdisplay = Base.REPL.REPLDisplay(repl)
repl.history_file = false

repltask = @async Base.REPL.run_repl(repl)

sendrepl(cmd) = write(stdin_write,"inc || wait(b); r = $cmd; notify(c); r\r")

inc = false
b = Condition()
c = Condition()
sendrepl("\"Hello REPL\"")
inc=true
begin
    notify(b)
    wait(c)
end

LispREPL.initrepl(repl)

# Tests.

# Check we can enter lisp mode.
write(stdin_write, ")")
readuntil(stdout_read, "lisp> ")

# Some basic single line tests.
write(stdin_write, "1\n")
readuntil(stdout_read, "lisp> ")
write(stdin_write, "(+ 1 2)\n")
readuntil(stdout_read, "lisp> ")

# More complex multiline entries.
fac_source =
"""
(defn fac [n]
    (if (< n 2)
        1
        (* n (fac (- n 1)))))
"""

write(stdin_write, fac_source)
write(stdin_write, "(def fac_10 (fac 10))\n")
readuntil(stdout_read, "lisp> ")

fib_source =
"""
(defn fib [n]
    (if (< n 2)
        n
        (+ (fib (- n 1))
           (fib (- n 2)))))
"""

write(stdin_write, fib_source)
write(stdin_write, "(def fib_10 (fib 10))\n")
readuntil(stdout_read, "lisp> ")

# Backspace to return to julia mode.
write(stdin_write, "\b")
readuntil(stdout_read, "julia> ")

# Close REPL ^D
write(stdin_write, '\x04')
wait(repltask)

# Test the actual values defined during lisp mode usage.

@test map(fac, 0:10) == map(factorial, 0:10)
@test map(fib, 0:10) == [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55]

@test fac_10 == 3628800
@test fib_10 == 55
