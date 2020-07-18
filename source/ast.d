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

interface Symbol{}
interface Operand : Symbol{}

interface Expression : Operand
{
	string serialize();
}

class ExpressionAstNode : Expression
{
	private string operator;
	private Expression[] iOperands;

	this(string operator, Expression[] operands)
	{
		this.operator = operator;
		this.iOperands = operands;
	}

	override string serialize()
	{
		string s = "( " ~ operator ~ " ";
		foreach(op; iOperands)
		{
			s ~= ", " ~ op.serialize();
		}
		return s ~ ")";
	}

	@property inout(Expression)[] operands() inout
	{
		return iOperands;
	}
}

class LiteralOperand : Expression
{
	private string lexeme;

	this(string lexeme)
	{
		this.lexeme = lexeme;
	}

	override string serialize()
	{
		return lexeme;
	}
}

unittest
{
	assert((new ExpressionAstNode("+",[
		new ExpressionAstNode("*",[new LiteralOperand("5"),new LiteralOperand("a")]),
		new ExpressionAstNode("-",[new LiteralOperand("b"),new LiteralOperand("2.2")])
	])).serialize() == "( + , ( * , 5, a), ( - , b, 2.2))");
	assert((new ExpressionAstNode(null,[
		new LiteralOperand("5"),
		new LiteralOperand("a")
	])).serialize() == "(  , 5, a)");
}
