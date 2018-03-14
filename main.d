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
import dopParser;

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
	immutable infix_operators = ["+":Op(5,Assoc.left),"-":Op(5,Assoc.left),"*":Op(6,Assoc.left),"/":Op(6,Assoc.left),
		"=":Op(4,Assoc.right),"+=":Op(4,Assoc.right),",,":Op(3,Assoc.left),"..":Op(7,Assoc.right),null:Op(6,Assoc.left)];
	immutable prefix_operators = ["+":1,"-":1,"*":1,"++":1,"--":1,"!":1,"~":1];
	immutable postfix_operators = ["++":1,"--":1,"**":1];

	immutable paren = Tup("(",",",")"), bracket = Tup("[",",","]"), brace = Tup("{",".","}");
	Tup[string] initiators = ["(":paren,"[":bracket,"{":brace];
	immutable separators = [",":paren,",":bracket,".":brace];
	Tup[string] terminators = [")":paren,"]":bracket,"}":brace];

	writeln("Type in a line of text and press enter. (" ~ exitMethod ~ " to exit)");
	write("<< ");

	foreach(line; stdin.byLineCopy())
	{
		// print output line
		auto ast = parseInfixExpression(infix_operators, prefix_operators, postfix_operators,
										initiators, separators, terminators, line);
		writeln(">> ",ast?ast.serialize():"error: stack not exhausted... or something else!");
		// prepare for new input
		write("<< ");
	} // end foreach
} // end function main
