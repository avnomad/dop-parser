/**
 * Copyright: (C) 2012-2013, 2018, 2020 Vaptistis Anogeianakis <nomad@cornercase.gr>
 *
 * This file is part of DOP Parser.
 *
 * DOP Parser is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * DOP Parser is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with DOP Parser.  If not, see <http://www.gnu.org/licenses/>.
 */
module test_utilities;
@safe:

import std.stdio, std.string, std.datetime.stopwatch, std.datetime.systime, std.range.primitives, std.traits,
		std.typecons;

@trusted auto resultOf(alias function_to_run, argument_types...)(argument_types arguments)
{
	string actualOutput;
	Throwable thrownObject;
	try
		actualOutput = function_to_run(arguments);
	catch(Throwable thrown)
	{
		thrownObject = thrown;
		actualOutput = thrown.msg;
	} // end catch

	return tuple!("returned_value", "thrown_object")(actualOutput, thrownObject);
}

// Test case numbering is one-based.
// Should only be used in unittest blocks where it's safe to catch AssertErrors.
void runUnitTests(alias function_under_test, Range)(Range test_cases, string file = __FILE__, size_t line = __LINE__)
if (isInputRange!(Unqual!Range))
{
	auto sw = StopWatch(AutoStart.yes);
	size_t n_tests_failed = 0;
	size_t n_tests_total = 0;

	writefln("Started running test suite at %-85s on \33[34m%-28s\33[0m.",
			format!"\33[35m%s\33[0m:\33[33m%s\33[0m"(file, line), Clock.currTime.toSimpleString);
	foreach(test_case; test_cases)
	{
		++n_tests_total;
		auto result = resultOf!function_under_test(test_case[0]);

		if(result.returned_value != test_case[1])
		{
			++n_tests_failed;
			writefln("Test #\33[33m%s\33[0m with input '\33[33m%s\33[0m' \33[31mfailed\33[0m!",
						n_tests_total, test_case[0]);
			writefln("    Expected output: '\33[35m%s\33[0m'", test_case[1]);
			writefln("    Actual output:   '\33[35m%s\33[0m'", result.returned_value);
			if(result.thrown_object)
				writefln("    Throwable originated at: \33[34m%s\33[0m:\33[33m%s\33[0m",
						result.thrown_object.file, result.thrown_object.line);
			writeln();
		}
	} // end foreach

	writef("Finished running \33[34m%5s\33[0m unit test(s) in %s", n_tests_total,
				leftJustify(format!"\33[36m%s\33[0m"(sw.peek), 75, '.'));
	if(n_tests_failed == 0)
		writefln("all tests \33[32mpassed\33[0m!");
	else
	{
		writefln("\33[31m%s\33[0m test(s) \33[31mfailed\33[0m!", n_tests_failed);
		assert(false);
	} // end else
} // end function runUnitTests
