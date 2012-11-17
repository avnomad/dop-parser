import std.stdio, std.string, std.algorithm, std.array;

interface Expression
{
	string serialize();
}

class BinaryOperator : Expression
{
	private string operation;
	private Expression left;
	private Expression right;
	
	this(string op, Expression l, Expression r)
	{
		left = l;
		right = r;
		operation = op;
	}
	
	override string serialize()
	{
		return "(" ~ left.serialize() ~ " " ~ operation ~ " " ~ right.serialize() ~ ")";
	}
}

class LiteralOperand : Expression
{
	private string lexeme;
	
	this(string lex)
	{
		lexeme = lex;
	}
	
	override string serialize()	
	{
		return lexeme;
	}
}
	
unittest
{
	assert((new BinaryOperator("+",
		new BinaryOperator("*",new LiteralOperand("5"),new LiteralOperand("a")),
		new BinaryOperator("-",new LiteralOperand("b"),new LiteralOperand("2.2")))).serialize() ==
		"((5 * a) + (b - 2.2))");
}

Expression parseExpression(char[] input)
{
	immutable string[] operators = ["+","-","*","/","%"];

	Expression[] stack;

	foreach(token; std.array.splitter(input))
	{
		if(find(operators,token)==[]) // not an operator
		{
			stack ~= new LiteralOperand(token.idup);
		}
		else // an operator
		{
			auto right = stack.back();
			stack.popBack();
			auto left = stack.back();
			stack.popBack();
			stack ~= new BinaryOperator(token.idup,left,right);
		} // end else
	} // end foreach
	if(stack.length == 1)
		return stack.back();
	else
		return null;
} // end function parseExpression