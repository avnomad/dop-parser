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

Expression parsePostfixExpression(char[] input)
{
	immutable uint[string] operators = ["+":2,"-":2,"*":2,"/":2,"%":2,"?":3,"!":1,"$":1]; // (operator symbol,#operands) pairs
	Expression[] stack;

	foreach(token; std.array.split(input))
	{
		if(!(token in operators)) // not an operator
		{
			stack ~= new LiteralOperand(token.idup);
		}
		else // an operator
		{
			Expression[] operands = new Expression[operators[token]];
			foreach(ref op; retro(operands))
			{
				op = stack.back();
				stack.popBack();
			} // end foreach
			stack ~= new ExpressionAstNode(token.idup,operands);
		} // end else
	} // end foreach
	if(stack.length == 1)
		return stack.back();
	else
		return null;
} // end function parsePostfixExpression

unittest
{
	assert(parsePostfixExpression("2 3 +".dup).serialize() == "( + , 2, 3)");
	assert(parsePostfixExpression("2 3 -".dup).serialize() == "( - , 2, 3)");
	assert(parsePostfixExpression("2 3 *".dup).serialize() == "( * , 2, 3)");
	assert(parsePostfixExpression("2 3 /".dup).serialize() == "( / , 2, 3)");
	assert(parsePostfixExpression("2 3 %".dup).serialize() == "( % , 2, 3)");
	assert(parsePostfixExpression("2 3 4 ?".dup).serialize() == "( ? , 2, 3, 4)");
	assert(parsePostfixExpression("2 !".dup).serialize() == "( ! , 2)");
	assert(parsePostfixExpression("2 $".dup).serialize() == "( $ , 2)");
	assert(parsePostfixExpression("a b +".dup).serialize() == "( + , a, b)");
	assert(parsePostfixExpression("a b + c -".dup).serialize() == "( - , ( + , a, b), c)");
	assert(parsePostfixExpression("c a b + -".dup).serialize() == "( - , c, ( + , a, b))");

	assert(parsePostfixExpression("2 3 - 3.1 + 2 5 ? 1 ! 2 $ % /".dup).serialize() ==
			"( / , ( ? , ( + , ( - , 2, 3), 3.1), 2, 5), ( % , ( ! , 1), ( $ , 2)))");
	assert(parsePostfixExpression("1 ! 2 3 - $ $ ! *".dup).serialize() ==
			"( * , ( ! , 1), ( ! , ( $ , ( $ , ( - , 2, 3)))))");
}
