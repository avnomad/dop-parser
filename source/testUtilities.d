import std.stdio, std.string, std.datetime.stopwatch;

void runUnitTests(alias function_under_test)(const(string[][]) test_cases)
{
	auto sw = StopWatch(AutoStart.yes);
	size_t n_tests_failed = 0;

	foreach(index, test_case; test_cases)
	{
		string actualOutput;
		try
			actualOutput = function_under_test(test_case[0]);
		catch (Exception e)
			actualOutput = e.msg;
		if(actualOutput != test_case[1])
		{
			++n_tests_failed;
			writefln("Test #\33[33m%s\33[0m with input '\33[33m%s\33[0m' \33[31mfailed\33[0m!", index, test_case[0]);
			writefln("    Expected output: '\33[35m%s\33[0m'", test_case[1]);
			writefln("    Actual output:   '\33[35m%s\33[0m'", actualOutput);
			writeln("");
		}
	} // end foreach

	writef("Run \33[34m%5s\33[0m unit test(s) in %s", test_cases.length,
				leftJustify(format!"\33[36m%s\33[0m"(sw.peek), 45, '.'));
	if(n_tests_failed == 0)
		writefln("all tests \33[32mpassed\33[0m!");
	else
	{
		writefln("%s test(s) \33[31mfailed\33[0m!", n_tests_failed);
		assert(false);
	} // end else
} // end function runUnitTests
