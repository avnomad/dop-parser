#!/usr/bin/env rdmd

//	Copyright (C) 2012-2013, 2018, 2020 Vaptistis Anogeianakis <nomad@cornercase.gr>
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

import std.stdio, std.string, std.array, std.conv;
import dop_parser;

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
	// Operator tables
	Op[string] infix_operators;
	int[string] prefix_operators;
	int[string] postfix_operators;

	Tup[string] initiators;
	Tup[string] separators;
	Tup[string] terminators;

	//
	// Operator declaration phase.
	//
	writeln("Declare a new operator on each line. An empty line proceeds to the next phase.");
	writeln("The valid declarations have one of the following forms:");
	writeln("    prefix <name>");
	writeln("    postfix <name>");
	writeln("    infix <name> <integer_precedence> <associativity>");
	writeln("    confix <initiator_name> <terminator_name>");
	writeln("    juxtaposition <integer_precedence> <associativity>");
	writeln("    list <initiator_name> <seperator_name> <terminator_name>");
	writeln("<associativity> can be 'left' or 'right'.");
	writeln("Currently prefix operators have higher precedence than postfix operators which\n"
		  ~ "have higher precedence than infix operators. This will change in the future.");
	write("<~ ");

	enum Declaration {prefix, postfix, infix, confix, juxtaposition, list}
	immutable n_arguments = [
		Declaration.prefix:1, Declaration.postfix:1, Declaration.infix:3,
		Declaration.confix:2, Declaration.juxtaposition:2, Declaration.list:3
	];
	foreach(line; stdin.byLineCopy())
	{
		try	{
			auto tokens = std.array.split(line);

			if(tokens.length == 0)
				break;
			else if(n_arguments[to!Declaration(tokens[0])] != tokens.length-1)
				writeln("Incorrect number of arguments for '" ~ tokens[0] ~ "': " ~ to!string(tokens.length-1) ~ ".");
			else
				final switch(to!Declaration(tokens[0]))
				{
					case Declaration.prefix:
						prefix_operators[tokens[1]] = 1; // dummy precedence
						break;
					case Declaration.postfix:
						postfix_operators[tokens[1]] = 1; // dummy precedence
						break;
					case Declaration.infix:
						infix_operators[tokens[1]] = Op(to!int(tokens[2]),to!Assoc(tokens[3]));
						break;
					case Declaration.confix:
						immutable tup = Tup(tokens[1], "", tokens[2]);
						initiators[tokens[1]] = terminators[tokens[2]] = tup;
						break;
					case Declaration.juxtaposition:
						infix_operators[null] = Op(to!int(tokens[1]),to!Assoc(tokens[2]));
						break;
					case Declaration.list:
						immutable tup = Tup(tokens[1], tokens[2], tokens[3]);
						initiators[tokens[1]] = separators[tokens[2]] = terminators[tokens[3]] = tup;
						break;
				} // end switch
		} catch(Exception e) {
			writeln(e.msg);
		}
		write("<~ ");
	} // end foreach

	//
	// Expression parsing phase.
	//
	writeln("Type an expression to parse or " ~ exitMethod ~ " to exit. (whitespace separates tokens)");
	write("<< ");

	foreach(line; stdin.byLineCopy())
	{
		try	{
			// print output line
			auto ast = parseInfixExpression(infix_operators, prefix_operators, postfix_operators,
											initiators, separators, terminators, line);
			writeln(">> ",ast?ast.serialize():"");
		} catch(Exception e) {
			writeln(e.file ~ " (" ~ to!string(e.line) ~ "): " ~ "Syntax error: " ~ e.msg);
		} // end catch

		// prepare for new input
		write("<< ");
	} // end foreach
} // end function main
