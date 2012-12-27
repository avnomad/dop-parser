import std.stdio, std.string, std.algorithm, std.array, std.range, std.exception;
import std.conv;

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
		new ExpressionAstNode("-",[new LiteralOperand("b"),new LiteralOperand("2.2")])])).serialize() ==
		"( + , ( * , 5, a), ( - , b, 2.2))");
}

Expression parsePostfixExpression(char[] input)
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


enum Assoc {left,right};

struct Op
{
	int priority;	// default 0
	Assoc associativity; // default Assoc.right

	this(int priority, Assoc associativity)
	{
		this.priority = priority;
		this.associativity = associativity;
	}
}
	

struct Tup
{
	string initiator;
	string seperator;
	string terminator;
	
	this(string initiator, string seperator, string terminator)
	{
		this.initiator = initiator;
		this.seperator = seperator;
		this.terminator = terminator;
	}
}


Expression parseInfixExpression(char[] input)
{
	/* Note: right now, the operator, initiator, seperator and terminator sets must be disjoint!! */
	/* 		 also, only one associativity is expected per precedence level. */
	auto operators = ["+":Op(5,Assoc.left),"-":Op(5,Assoc.left),"*":Op(6,Assoc.left),"/":Op(6,Assoc.left),
		"=":Op(4,Assoc.right),"+=":Op(4,Assoc.right),",,":Op(3,Assoc.left),"..":Op(7,Assoc.right)];
	string bnc = to!string(""w ~ cast(wchar)65535);	// workaround to legitimately use noncharacters...
	string enc = to!string(""w ~ cast(wchar)65534);
	auto paren = Tup("(",",",")"), bracket = Tup("[",",","]"), brace = Tup("{",".","}"), eoe = Tup(bnc,"",enc);
	auto initiators = ["(":paren,"[":bracket,"{":brace,bnc:eoe];
	auto seperators = [",":paren,",":bracket,".":brace];
	auto terminators = [")":paren,"]":bracket,"}":brace,enc:eoe];
	Symbol[] symbols;

	void dispatchToken(char[] token)
	{
		if(token in operators) 			// operator
		{
			enforce(cast(Expression)symbols[$-1]);
			while(true)
			{
				if(cast(Operator)symbols[$-2])	// operator
				{
					auto previous = cast(Operator)symbols[$-2];
					if(operators[previous.name].priority == operators[token].priority)
						enforce(operators[previous.name].associativity == operators[token].associativity);
					if(operators[previous.name].priority < operators[token].priority ||
						(operators[previous.name].priority == operators[token].priority && 
						 operators[token].associativity == Assoc.right))
					{	// shift
						symbols ~= new Operator(token.idup);
						break;
					}
					else
					{	// reduce
						enforce(cast(Expression)symbols[$-3]);
						symbols[$-3] = new ExpressionAstNode((cast(Operator)symbols[$-2]).name,[cast(Expression)symbols[$-3],cast(Expression)symbols[$-1]]);
						symbols = symbols[0..$-2];
					} // end else
				}
				else	// initiator || seperator
				{	// shift
					symbols ~= new Operator(token.idup);
					break;
				}
			} // end while true			
		}
		else if(token in initiators)	// initiator
		{
			enforce(!cast(Expression)symbols[$-1]); // concatenation nor function calls allowed yet!
			// shift
			symbols ~= new Initiator(token.idup);
			enforce(initiators[token].initiator == token);
		}
		else if(token in seperators)	// seperator
		{
			enforce(cast(Expression)symbols[$-1]);
			// shift
			symbols ~= new Seperator(token.idup);
			enforce(seperators[token].seperator == token);
		}
		else if(token in terminators)	// terminator
		{
			Expression[] operands = [];
			Initiator topAsInit;
			
			while(!((topAsInit = cast(Initiator)symbols[$-1]),topAsInit && terminators[token].initiator == topAsInit.name))
			{
				enforce(cast(Expression)symbols[$-1]);
				if(cast(Operator)symbols[$-2])
				{	// reduce
					enforce(cast(Expression)symbols[$-3]);
					symbols[$-3] = new ExpressionAstNode((cast(Operator)symbols[$-2]).name,[cast(Expression)symbols[$-3],cast(Expression)symbols[$-1]]);
					symbols = symbols[0..$-2];
				}
				else if(cast(Seperator)symbols[$-2])
				{	// save expression
					enforce((cast(Seperator)symbols[$-2]).name == terminators[token].seperator);
					operands = cast(Expression)symbols[$-1] ~ operands;
					symbols = symbols[0..$-2];
				}
				else
				{	// save expression
					enforce(cast(Initiator)symbols[$-2]);
					operands = cast(Expression)symbols[$-1] ~ operands;
					symbols = symbols[0..$-1];
				} // end else
			} // end while
			// reduce
			symbols[$-1] = new ExpressionAstNode(topAsInit.name,operands);
		}
		else							// operand
		{
			enforce(!cast(Expression)symbols[$-1]); // concatenation not allowed yet!
			// shift
			symbols ~= new LiteralOperand(token.idup);
		} // end else
	} // end function dispatchToken


	symbols ~= new Initiator(bnc);	// should replace with explicit type/value
		// used as a sentinel to avoid checking for empty stack
	foreach(token; std.array.splitter(input))
	{
		dispatchToken(token);
	} // end foreach
	dispatchToken(enc.dup);	// should match starting sentinel token
	
	
	if(symbols.length == 1)
		return (cast(ExpressionAstNode)symbols.back()).operands[0];
	else
		return null;
} // end function parseInfixExpression

unittest
{
	assert(parseInfixExpression("2".dup).serialize() == "2");
	assert(parseInfixExpression("2 + 3".dup).serialize() == "( + , 2, 3)");
	assert(parseInfixExpression("a - b".dup).serialize() == "( - , a, b)");
	assert(parseInfixExpression("a + b + c".dup).serialize() == "( + , ( + , a, b), c)");
	assert(parseInfixExpression("a - b - c".dup).serialize() == "( - , ( - , a, b), c)");
	assert(parseInfixExpression("a + b - c".dup).serialize() == "( - , ( + , a, b), c)");
	assert(parseInfixExpression("a + b - c + d - e".dup).serialize() == "( - , ( + , ( - , ( + , a, b), c), d), e)");
	assert(parseInfixExpression("a * b * c".dup).serialize() == "( * , ( * , a, b), c)");
	assert(parseInfixExpression("a / b / c".dup).serialize() == "( / , ( / , a, b), c)");
	assert(parseInfixExpression("a * b / c".dup).serialize() == "( / , ( * , a, b), c)");
	assert(parseInfixExpression("a * b / c * d / e".dup).serialize() == "( / , ( * , ( / , ( * , a, b), c), d), e)");
	assert(parseInfixExpression("a = b = c".dup).serialize() == "( = , a, ( = , b, c))");
	assert(parseInfixExpression("a += b += c".dup).serialize() == "( += , a, ( += , b, c))");
	assert(parseInfixExpression("a = b += c".dup).serialize() == "( = , a, ( += , b, c))");
	assert(parseInfixExpression("a = b += c = d += e".dup).serialize() == "( = , a, ( += , b, ( = , c, ( += , d, e))))");
}



interface Symbol{}
interface Operand : Symbol{}

mixin template Named()
{	
	string name;
	
	this(string name)
	{
		this.name = name;
	}
}

class Operator : Symbol
{
	mixin Named;
}

unittest
{
	auto t = new Operator("hello");
	assert(t.name == "hello");
}

class Initiator : Symbol
{
	mixin Named;
}

class Seperator : Symbol
{
	mixin Named;
}

/*class Terminator : Symbol
{
	mixin Named;
}*/
