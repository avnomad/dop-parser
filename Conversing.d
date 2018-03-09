#!/usr/bin/env rdmd

//	Copyright (C) 2012-2013, 2018 Vaptistis Anogeianakis <nomad@cornercase.gr>
/*
 *	This file is part of DOP Parser.
 *
 *	DOP Parser is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.
 *
 *	DOP Parser is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with DOP Parser.  If not, see <http://www.gnu.org/licenses/>.
 */

import std.stdio, std.string;
import Expressions;

version(Windows)
{
	auto exitMethod = "ctrl+z and enter";
}
else
{
	auto exitMethod = "ctrl+d";
}

void main()
{
	writeln("Type in a line of text and press enter. (" ~ exitMethod ~ " to exit)");
	write("<< ");

	foreach(line; stdin.byLine())
	{
		// print output line
		auto ast = parseInfixExpression(line);
		writeln(">> ",ast?ast.serialize():"error: stack not exhausted... or something else!");
		// prepare for new input
		write("<< ");
	} // end foreach
} // end function main
