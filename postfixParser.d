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
import std.array, std.range;
import ast;

Expression parsePostfixExpression(string input)
{
	immutable uint[string] operators = ["+":2,"-":2,"*":2,"/":2,"%":2,"?":3,"!":1,"$":1]; // (operator symbol,#operands) pairs
	Expression[] stack;

	foreach(token; std.array.split(input))
	{
		if(!(token in operators)) // not an operator
		{
			stack ~= new LiteralOperand(token);
		}
		else // an operator
		{
			Expression[] operands = new Expression[operators[token]];
			foreach(ref op; retro(operands))
			{
				op = stack.back();
				stack.popBack();
			} // end foreach
			stack ~= new ExpressionAstNode(token,operands);
		} // end else
	} // end foreach
	if(stack.length == 1)
		return stack.back();
	else
		return null;
} // end function parsePostfixExpression

unittest
{
	immutable test_cases = [
		["2 3 +", "( + , 2, 3)"],
		["2 3 -", "( - , 2, 3)"],
		["2 3 *", "( * , 2, 3)"],
		["2 3 /", "( / , 2, 3)"],
		["2 3 %", "( % , 2, 3)"],
		["2 3 4 ?", "( ? , 2, 3, 4)"],
		["2 !", "( ! , 2)"],
		["2 $", "( $ , 2)"],
		["a b +", "( + , a, b)"],
		["a b + c -", "( - , ( + , a, b), c)"],
		["c a b + -", "( - , c, ( + , a, b))"],
		["2 3 - 3.1 + 2 5 ? 1 ! 2 $ % /", "( / , ( ? , ( + , ( - , 2, 3), 3.1), 2, 5), ( % , ( ! , 1), ( $ , 2)))"],
		["1 ! 2 3 - $ $ ! *", "( * , ( ! , 1), ( ! , ( $ , ( $ , ( - , 2, 3)))))"],
	];

	foreach(test_case; test_cases)
	{
		assert(parsePostfixExpression(test_case[0]).serialize() == test_case[1]);
	} // end foreach
} // end unittest
