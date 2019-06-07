using Test
import LispREPL

import REPL: REPL, Terminals

# Setup. From Julia base repo.

mutable struct FakeTerminal <: Terminals.UnixTerminal
    in_stream::Base.IO
    out_stream::Base.IO
    err_stream::Base.IO
    hascolor::Bool
    raw::Bool
    FakeTerminal(stdin,stdout,stderr,hascolor=true) =
        new(stdin,stdout,stderr,hascolor,false)
end

Terminals.hascolor(t::FakeTerminal) = t.hascolor
Terminals.raw!(t::FakeTerminal, raw::Bool) = t.raw = raw
Terminals.size(t::FakeTerminal) = (24, 80)

function fake_repl(@nospecialize(f); options::REPL.Options=REPL.Options(confirm_exit=false))
    # Use pipes so we can easily do blocking reads
    # In the future if we want we can add a test that the right object
    # gets displayed by intercepting the display
    input = Pipe()
    output = Pipe()
    err = Pipe()
    Base.link_pipe!(input, reader_supports_async=true, writer_supports_async=true)
    Base.link_pipe!(output, reader_supports_async=true, writer_supports_async=true)
    Base.link_pipe!(err, reader_supports_async=true, writer_supports_async=true)

    repl = REPL.LineEditREPL(FakeTerminal(input.out, output.in, err.in), true)

    f(input.in, output.out, repl)
    t = @async begin
        close(input.in)
        close(output.in)
        close(err.in)
    end
    @test read(err.out, String) == ""
    #display(read(output.out, String))
    Base.wait(t)
    nothing
end

# Writing ^C to the repl will cause sigint, so let's not die on that
ccall(:jl_exit_on_sigint, Cvoid, (Cint,), 0)
fake_repl() do stdin_write, stdout_read, repl
	@info "Starting REPL"
	repl.specialdisplay = REPL.REPLDisplay(repl)
	repl.history_file = false

	repltask = @async REPL.run_repl(repl)

    global inc = false
    global b = Condition()
    global c = Condition()
    let cmd = "\"Hello REPL\""
        write(stdin_write, "inc || wait(b); r = $cmd; notify(c); r\r")
    end
    inc = true
    notify(b)
    wait(c)

	@info "Init REPL"
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

	@info "Close REPL"

	# Close REPL ^D
	write(stdin_write, '\x04')
	wait(repltask)
end

# Test the actual values defined during lisp mode usage.

@test map(fac, 0:10) == map(factorial, 0:10)
@test map(fib, 0:10) == [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55]

@test fac_10 == 3628800
@test fib_10 == 55
