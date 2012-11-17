import std.stdio, std.string, std.algorithm, std.array, std.range;

interface Expression
{
	string serialize();
}

class ExpressionAstNode : Expression
{
	private string iOperator;
	private Expression[] iOperands;
	
	this(string operator, Expression[] operands)
	{
		iOperator = operator;
		iOperands = operands;
	}
	
	override string serialize()
	{
		string s = "( " ~ iOperator ~ " ";
		foreach(op; iOperands)
		{
			s ~= ", " ~ op.serialize();
		}
		return s ~ ")";
	}
}

class LiteralOperand : Expression
{
	private string iLexeme;
	
	this(string lexeme)
	{
		iLexeme = lexeme;
	}
	
	override string serialize()	
	{
		return iLexeme;
	}
}
	
unittest
{
	assert((new ExpressionAstNode("+",[
		new ExpressionAstNode("*",[new LiteralOperand("5"),new LiteralOperand("a")]),
		new ExpressionAstNode("-",[new LiteralOperand("b"),new LiteralOperand("2.2")])])).serialize() ==
		"( + , ( * , 5, a), ( - , b, 2.2))");
}

Expression parseExpression(char[] input)
{
	immutable uint[string] operators = ["+":2,"-":2,"*":2,"/":2,"%":2,"?":3,"!":1,"$":1]; // (operator symbol,#operands) pairs
	Expression[] stack;

	foreach(token; std.array.splitter(input))
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
} // end function parseExpression

unittest
{
	assert(parseExpression("2 3 +".dup).serialize() == "( + , 2, 3)");
	assert(parseExpression("2 3 -".dup).serialize() == "( - , 2, 3)");
	assert(parseExpression("2 3 *".dup).serialize() == "( * , 2, 3)");
	assert(parseExpression("2 3 /".dup).serialize() == "( / , 2, 3)");
	assert(parseExpression("2 3 %".dup).serialize() == "( % , 2, 3)");
	assert(parseExpression("2 3 4 ?".dup).serialize() == "( ? , 2, 3, 4)");
	assert(parseExpression("2 !".dup).serialize() == "( ! , 2)");
	assert(parseExpression("2 $".dup).serialize() == "( $ , 2)");
	assert(parseExpression("a b +".dup).serialize() == "( + , a, b)");
	assert(parseExpression("a b + c -".dup).serialize() == "( - , ( + , a, b), c)");
	assert(parseExpression("c a b + -".dup).serialize() == "( - , c, ( + , a, b))");

	assert(parseExpression("2 3 - 3.1 + 2 5 ? 1 ! 2 $ % /".dup).serialize() == 
			"( / , ( ? , ( + , ( - , 2, 3), 3.1), 2, 5), ( % , ( ! , 1), ( $ , 2)))");
	assert(parseExpression("1 ! 2 3 - $ $ ! *".dup).serialize() == 
			"( * , ( ! , 1), ( ! , ( $ , ( $ , ( - , 2, 3)))))");
}






