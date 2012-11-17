import std.stdio, std.string;

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