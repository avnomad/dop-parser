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
	assert((new ExpressionAstNode(null,[new LiteralOperand("5"),new LiteralOperand("a")])).serialize() == "(  , 5, a)");
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
	auto infixOperators = ["+":Op(5,Assoc.left),"-":Op(5,Assoc.left),"*":Op(6,Assoc.left),"/":Op(6,Assoc.left),
		"=":Op(4,Assoc.right),"+=":Op(4,Assoc.right),",,":Op(3,Assoc.left),"..":Op(7,Assoc.right),null:Op(6,Assoc.left)];
	auto prefixOperators = ["+":1,"-":1,"*":1,"++":1,"--":1,"!":1,"~":1];
	auto postfixOperators = ["++":1,"--":1,"**":1];
	string bnc = to!string(""w ~ cast(wchar)65535);	// workaround to legitimately use noncharacters...
	string enc = to!string(""w ~ cast(wchar)65534);
	auto paren = Tup("(",",",")"), bracket = Tup("[",",","]"), brace = Tup("{",".","}"), eoe = Tup(bnc,"",enc);
	auto initiators = ["(":paren,"[":bracket,"{":brace,bnc:eoe];
	auto seperators = [",":paren,",":bracket,".":brace];
	auto terminators = [")":paren,"]":bracket,"}":brace,enc:eoe];
	Symbol[] symbols;
	Operator[] stagedOperators;

	// below some enforce calls may need to change to assert...
	void dispatchToken(char[] token)
	{
		if(token in infixOperators) 			// operator
		{
			enforce(cast(Expression)symbols[$-1]);
			while(true)
			{
				if(cast(Operator)symbols[$-2])	// operator
				{
					auto previous = cast(Operator)symbols[$-2];
					if(infixOperators[previous.name].priority == infixOperators[token].priority)
						enforce(infixOperators[previous.name].associativity == infixOperators[token].associativity);
					if(infixOperators[previous.name].priority < infixOperators[token].priority ||
						(infixOperators[previous.name].priority == infixOperators[token].priority &&
						 infixOperators[token].associativity == Assoc.right))
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
			assert(token !in prefixOperators && token !in postfixOperators);	// those cases should be handled outside
			if(cast(Expression)symbols[$-1])
			{
				enforce(null in infixOperators);	// function calls not supported yet!
				dispatchToken(null);	// handle as infix operator
			}
			// handle possible leading prefix operators
			foreach(operator; stagedOperators)
				enforce(operator.name in prefixOperators);
			// shift
			symbols ~= new Initiator(token.idup,stagedOperators);
			stagedOperators = [];
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
			// reduce possible leading prefix operators
			Operator[] leadingPrefixes = topAsInit.leadingPrefixes;
			Expression temp = new ExpressionAstNode(topAsInit.name,operands);
			while(!leadingPrefixes.empty)
			{
				enforce(leadingPrefixes[$-1].name in prefixOperators);
				temp = new ExpressionAstNode("pre " ~ leadingPrefixes[$-1].name,[temp]);
				leadingPrefixes = leadingPrefixes[0..$-1];
			} // end while
			// reduce
			symbols[$-1] = temp;
		}
		else							// operand
		{
			enforce(token !in prefixOperators && token !in postfixOperators);	// those cases should be handled outside
			if(cast(Expression)symbols[$-1])
			{
				enforce(null in infixOperators);
				dispatchToken(null);	// handle as infix operator
			}
			// reduce possible leading prefix operators
			Expression temp = new LiteralOperand(token.idup);
			while(!stagedOperators.empty)
			{
				enforce(stagedOperators[$-1].name in prefixOperators);
				temp = new ExpressionAstNode("pre " ~ stagedOperators[$-1].name,[temp]);
				stagedOperators = stagedOperators[0..$-1];
			} // end while
			// shift
			symbols ~= temp;
		} // end else
	} // end function dispatchToken


	void processToken(char[] token)
	{
		if(token in infixOperators || token in prefixOperators || token in postfixOperators)
		{
			stagedOperators ~= new Operator(token.idup);
		}
		else
		{
			if(!stagedOperators.empty)
			{
				if(cast(Initiator)symbols[$-1] || cast(Seperator)symbols[$-1])
				{
					enforce(token !in seperators && token !in terminators);
				}
				else if(token in seperators || token in terminators)
				{
					foreach(operator; stagedOperators)
					{
						assert(cast(Expression)symbols[$-1]);
						enforce(operator.name in postfixOperators);
						symbols[$-1] = new ExpressionAstNode("post " ~ operator.name,[cast(Expression)symbols[$-1]]);
					} // end foreach
					stagedOperators = [];
				}
				else
				{
					assert(cast(Expression)symbols[$-1]);	// token should be initiator or operand
					int firstNonPost = 0;	// from the left
					while(firstNonPost < stagedOperators.length && stagedOperators[firstNonPost].name in postfixOperators)
						firstNonPost++;
					int lastNonPre = stagedOperators.length-1;	// from the left
					while(lastNonPre > -1 && stagedOperators[lastNonPre].name in prefixOperators)
						lastNonPre--;
					int count = 0;
					int index = -1;
					for(auto i = max(0,lastNonPre) ; i <= min(stagedOperators.length-1,firstNonPost) ; i++)
					{
						if(stagedOperators[i].name in infixOperators)
						{
							count++;
							index = i;
						} // end if
					} // end for
					enforce(count <= 1);	// or else ambiguity
					if(count == 1)
					{
						// reduce postfix operators
						foreach(i; 0..index)
						{
							assert(cast(Expression)symbols[$-1]);
							assert(stagedOperators[i].name in postfixOperators);
							symbols[$-1] = new ExpressionAstNode("post " ~ stagedOperators[i].name,[cast(Expression)symbols[$-1]]);
						} // end foreach
						assert(stagedOperators[index].name in infixOperators);
						dispatchToken(stagedOperators[index].name.dup);
						stagedOperators = stagedOperators[index+1..$];
					}
					else if(count == 0)
					{
						enforce(firstNonPost-lastNonPre == 1);
						// reduce postfix operators
						foreach(i; 0..firstNonPost)
						{
							assert(cast(Expression)symbols[$-1]);
							assert(stagedOperators[i].name in postfixOperators);
							symbols[$-1] = new ExpressionAstNode("post " ~ stagedOperators[i].name,[cast(Expression)symbols[$-1]]);
						} // end foreach
						enforce(null in infixOperators);
						dispatchToken(null);
						stagedOperators = stagedOperators[firstNonPost..$];
					} // end if
				} // end else
			} // end if
			dispatchToken(token);
		} // end else
	} // end function processToken


	symbols ~= new Initiator(bnc,null);	// used as a sentinel to avoid checking for empty stack
	foreach(token; std.array.splitter(input))
	{
		processToken(token);
	} // end foreach
	processToken(enc.dup);	// should match starting sentinel token


	if(symbols.length == 1)
		return (cast(ExpressionAstNode)symbols.back()).operands[0];	// remove the node created for sentinel
	else
		return null;
} // end function parseInfixExpression

unittest
{
	bool check(string input, string output)
	{
		return parseInfixExpression(input.dup).serialize() == output;
	} // end function check

	// basic infix operations
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
	assert(parseInfixExpression("2 + 3 * 4".dup).serialize() == "( + , 2, ( * , 3, 4))");
	assert(parseInfixExpression("2 * 3 + 4".dup).serialize() == "( + , ( * , 2, 3), 4)");
	assert(parseInfixExpression("2 - 3 / 4".dup).serialize() == "( - , 2, ( / , 3, 4))");
	assert(parseInfixExpression("2 / 3 - 4".dup).serialize() == "( - , ( / , 2, 3), 4)");
	assert(parseInfixExpression("2 = 3 .. 4".dup).serialize() == "( = , 2, ( .. , 3, 4))");
	assert(parseInfixExpression("2 .. 3 = 4".dup).serialize() == "( = , ( .. , 2, 3), 4)");
	assert(parseInfixExpression("2 += 3 .. 4".dup).serialize() == "( += , 2, ( .. , 3, 4))");
	assert(parseInfixExpression("2 .. 3 += 4".dup).serialize() == "( += , ( .. , 2, 3), 4)");
	assert(parseInfixExpression("a += b = 3 * b + 2".dup).serialize() == "( += , a, ( = , b, ( + , ( * , 3, b), 2)))");
	// tuples
	assert(parseInfixExpression("( )".dup).serialize() == "( ( )");
	assert(parseInfixExpression("[ ]".dup).serialize() == "( [ )");
	assert(parseInfixExpression("{ }".dup).serialize() == "( { )");
	assert(parseInfixExpression("( 2 )".dup).serialize() == "( ( , 2)");
	assert(parseInfixExpression("[ 2 ]".dup).serialize() == "( [ , 2)");
	assert(parseInfixExpression("{ 2 }".dup).serialize() == "( { , 2)");
	assert(parseInfixExpression("( 2 , 3 )".dup).serialize() == "( ( , 2, 3)");
	assert(parseInfixExpression("[ 2 , 3 ]".dup).serialize() == "( [ , 2, 3)");
	assert(parseInfixExpression("{ 2 . 3 }".dup).serialize() == "( { , 2, 3)");
	assert(parseInfixExpression("( 2 , 3 , 4 )".dup).serialize() == "( ( , 2, 3, 4)");
	assert(parseInfixExpression("[ 2 , 3 , 4 ]".dup).serialize() == "( [ , 2, 3, 4)");
	assert(parseInfixExpression("{ 2 . 3 . 4 }".dup).serialize() == "( { , 2, 3, 4)");
	assert(parseInfixExpression("( a + b )".dup).serialize() == "( ( , ( + , a, b))");
	assert(parseInfixExpression("[ a + b ]".dup).serialize() == "( [ , ( + , a, b))");
	assert(parseInfixExpression("{ a + b }".dup).serialize() == "( { , ( + , a, b))");
	assert(parseInfixExpression("( a + b , 3 )".dup).serialize() == "( ( , ( + , a, b), 3)");
	assert(parseInfixExpression("[ a + b , 3 ]".dup).serialize() == "( [ , ( + , a, b), 3)");
	assert(parseInfixExpression("{ a + b . 3 }".dup).serialize() == "( { , ( + , a, b), 3)");
	assert(parseInfixExpression("( a + b , 3 , 4 )".dup).serialize() == "( ( , ( + , a, b), 3, 4)");
	assert(parseInfixExpression("[ a + b , 3 , 4 ]".dup).serialize() == "( [ , ( + , a, b), 3, 4)");
	assert(parseInfixExpression("{ a + b . 3 . 4 }".dup).serialize() == "( { , ( + , a, b), 3, 4)");
	assert(parseInfixExpression("( a + b , c .. d )".dup).serialize() == "( ( , ( + , a, b), ( .. , c, d))");
	assert(parseInfixExpression("[ a + b , c .. d ]".dup).serialize() == "( [ , ( + , a, b), ( .. , c, d))");
	assert(parseInfixExpression("{ a + b . c .. d }".dup).serialize() == "( { , ( + , a, b), ( .. , c, d))");
	assert(parseInfixExpression("( a + b , c .. d , 4 )".dup).serialize() == "( ( , ( + , a, b), ( .. , c, d), 4)");
	assert(parseInfixExpression("[ a + b , c .. d , 4 ]".dup).serialize() == "( [ , ( + , a, b), ( .. , c, d), 4)");
	assert(parseInfixExpression("{ a + b . c .. d . 4 }".dup).serialize() == "( { , ( + , a, b), ( .. , c, d), 4)");
	assert(parseInfixExpression("( a + b , c .. d , e * f )".dup).serialize() == "( ( , ( + , a, b), ( .. , c, d), ( * , e, f))");
	assert(parseInfixExpression("[ a + b , c .. d , e * f ]".dup).serialize() == "( [ , ( + , a, b), ( .. , c, d), ( * , e, f))");
	assert(parseInfixExpression("{ a + b . c .. d . e * f }".dup).serialize() == "( { , ( + , a, b), ( .. , c, d), ( * , e, f))");
	// grouping
	assert(parseInfixExpression("( a + b ) + c".dup).serialize() == "( + , ( ( , ( + , a, b)), c)");
	assert(parseInfixExpression("( a - b ) - c".dup).serialize() == "( - , ( ( , ( - , a, b)), c)");
	assert(parseInfixExpression("a + ( b + c )".dup).serialize() == "( + , a, ( ( , ( + , b, c)))");
	assert(parseInfixExpression("a - ( b - c )".dup).serialize() == "( - , a, ( ( , ( - , b, c)))");
	assert(parseInfixExpression("[ a + b ] + c".dup).serialize() == "( + , ( [ , ( + , a, b)), c)");
	assert(parseInfixExpression("[ a - b ] - c".dup).serialize() == "( - , ( [ , ( - , a, b)), c)");
	assert(parseInfixExpression("a + [ b + c ]".dup).serialize() == "( + , a, ( [ , ( + , b, c)))");
	assert(parseInfixExpression("a - [ b - c ]".dup).serialize() == "( - , a, ( [ , ( - , b, c)))");
	assert(parseInfixExpression("{ a + b } + c".dup).serialize() == "( + , ( { , ( + , a, b)), c)");
	assert(parseInfixExpression("{ a - b } - c".dup).serialize() == "( - , ( { , ( - , a, b)), c)");
	assert(parseInfixExpression("a + { b + c }".dup).serialize() == "( + , a, ( { , ( + , b, c)))");
	assert(parseInfixExpression("a - { b - c }".dup).serialize() == "( - , a, ( { , ( - , b, c)))");
	// nested tuples
	assert(parseInfixExpression("2 + ( a , ( b , c ) )".dup).serialize() == "( + , 2, ( ( , a, ( ( , b, c)))");
	// basic juxtaposition
	assert(parseInfixExpression("a b".dup).serialize() == "(  , a, b)");
	assert(parseInfixExpression("a b c".dup).serialize() == "(  , (  , a, b), c)");
	assert(parseInfixExpression("a b * c".dup).serialize() == "( * , (  , a, b), c)");
	assert(parseInfixExpression("a * b c".dup).serialize() == "(  , ( * , a, b), c)");
	assert(parseInfixExpression("a + b c".dup).serialize() == "( + , a, (  , b, c))");
	assert(parseInfixExpression("a b + c".dup).serialize() == "( + , (  , a, b), c)");
	// juxtaposition + tuples
	assert(parseInfixExpression("a ( b )".dup).serialize() == "(  , a, ( ( , b))");
	assert(parseInfixExpression("( a ) b".dup).serialize() == "(  , ( ( , a), b)");
	assert(parseInfixExpression("a ( b c )".dup).serialize() == "(  , a, ( ( , (  , b, c)))");
	assert(parseInfixExpression("( a b ) c".dup).serialize() == "(  , ( ( , (  , a, b)), c)");
	assert(parseInfixExpression("a ( b , c )".dup).serialize() == "(  , a, ( ( , b, c))");
	assert(parseInfixExpression("( a , b ) c".dup).serialize() == "(  , ( ( , a, b), c)");
	// basic postfix operations
	assert(parseInfixExpression("a ++".dup).serialize() == "( post ++ , a)");
	assert(parseInfixExpression("a --".dup).serialize() == "( post -- , a)");
	assert(parseInfixExpression("a ++ --".dup).serialize() == "( post -- , ( post ++ , a))");
	assert(parseInfixExpression("a -- ++".dup).serialize() == "( post ++ , ( post -- , a))");
	// postfix + tuples
	assert(parseInfixExpression("( a ) ++".dup).serialize() == "( post ++ , ( ( , a))");
	assert(parseInfixExpression("( a ) --".dup).serialize() == "( post -- , ( ( , a))");
	assert(parseInfixExpression("( a ) ++ --".dup).serialize() == "( post -- , ( post ++ , ( ( , a)))");
	assert(parseInfixExpression("( a ) -- ++".dup).serialize() == "( post ++ , ( post -- , ( ( , a)))");
	assert(parseInfixExpression("( a ++ ) --".dup).serialize() == "( post -- , ( ( , ( post ++ , a)))");
	assert(parseInfixExpression("( a -- ) ++".dup).serialize() == "( post ++ , ( ( , ( post -- , a)))");
	// basic prefix operations
	assert(parseInfixExpression("++ a".dup).serialize() == "( pre ++ , a)");
	assert(parseInfixExpression("-- a".dup).serialize() == "( pre -- , a)");
	assert(parseInfixExpression("-- ++ a".dup).serialize() == "( pre -- , ( pre ++ , a))");
	assert(parseInfixExpression("++ -- a".dup).serialize() == "( pre ++ , ( pre -- , a))");
	assert(parseInfixExpression("+ a".dup).serialize() == "( pre + , a)");
	assert(parseInfixExpression("- a".dup).serialize() == "( pre - , a)");
	assert(parseInfixExpression("- + a".dup).serialize() == "( pre - , ( pre + , a))");
	assert(parseInfixExpression("+ - a".dup).serialize() == "( pre + , ( pre - , a))");
	// prefix + tuples
	assert(check("++ ( a )","( pre ++ , ( ( , a))"));
	assert(check("-- ( a )","( pre -- , ( ( , a))"));
	assert(check("-- ++ ( a )","( pre -- , ( pre ++ , ( ( , a)))"));
	assert(check("++ -- ( a )","( pre ++ , ( pre -- , ( ( , a)))"));
	assert(check("-- ( ++ a )","( pre -- , ( ( , ( pre ++ , a)))"));
	assert(check("++ ( -- a )","( pre ++ , ( ( , ( pre -- , a)))"));
	assert(check("+ ( a )","( pre + , ( ( , a))"));
	assert(check("- ( a )","( pre - , ( ( , a))"));
	assert(check("- + ( a )","( pre - , ( pre + , ( ( , a)))"));
	assert(check("+ - ( a )","( pre + , ( pre - , ( ( , a)))"));
	assert(check("- ( + a )","( pre - , ( ( , ( pre + , a)))"));
	assert(check("+ ( - a )","( pre + , ( ( , ( pre - , a)))"));
	// prefix + postfix
	assert(parseInfixExpression("-- a ++".dup).serialize() == "( post ++ , ( pre -- , a))");
	assert(parseInfixExpression("++ a --".dup).serialize() == "( post -- , ( pre ++ , a))");
	assert(parseInfixExpression("-- a ++ --".dup).serialize() == "( post -- , ( post ++ , ( pre -- , a)))");
	assert(parseInfixExpression("++ a -- ++".dup).serialize() == "( post ++ , ( post -- , ( pre ++ , a)))");
	assert(parseInfixExpression("- a ++".dup).serialize() == "( post ++ , ( pre - , a))");
	assert(parseInfixExpression("+ a --".dup).serialize() == "( post -- , ( pre + , a))");
	assert(parseInfixExpression("- a ++ --".dup).serialize() == "( post -- , ( post ++ , ( pre - , a)))");
	assert(parseInfixExpression("+ a -- ++".dup).serialize() == "( post ++ , ( post -- , ( pre + , a)))");
	assert(parseInfixExpression("++ - a ++".dup).serialize() == "( post ++ , ( pre ++ , ( pre - , a)))");
	assert(parseInfixExpression("++ + a --".dup).serialize() == "( post -- , ( pre ++ , ( pre + , a)))");
	assert(parseInfixExpression("++ - a ++ --".dup).serialize() == "( post -- , ( post ++ , ( pre ++ , ( pre - , a))))");
	assert(parseInfixExpression("++ + a -- ++".dup).serialize() == "( post ++ , ( post -- , ( pre ++ , ( pre + , a))))");
	// prefix + postfix + grouping
	assert(parseInfixExpression("( -- a ) ++".dup).serialize() == "( post ++ , ( ( , ( pre -- , a)))");
	assert(parseInfixExpression("++ ( a -- )".dup).serialize() == "( pre ++ , ( ( , ( post -- , a)))");
	assert(parseInfixExpression("-- ( a ++ ) --".dup).serialize() == "( post -- , ( pre -- , ( ( , ( post ++ , a))))");
	assert(parseInfixExpression("++ ( a -- ++ )".dup).serialize() == "( pre ++ , ( ( , ( post ++ , ( post -- , a))))");
	// prefix + postfix + tuples
	assert(parseInfixExpression("-- ( a ++ , b ) --".dup).serialize() == "( post -- , ( pre -- , ( ( , ( post ++ , a), b)))");
	assert(parseInfixExpression("++ ( a -- , b ++ )".dup).serialize() == "( pre ++ , ( ( , ( post -- , a), ( post ++ , b)))");
	// infix + prefix + postfix
	assert(parseInfixExpression("a + + b".dup).serialize() == "( + , a, ( pre + , b))");
	assert(parseInfixExpression("a - + b".dup).serialize() == "( - , a, ( pre + , b))");
	assert(parseInfixExpression("a + - b".dup).serialize() == "( + , a, ( pre - , b))");
	assert(parseInfixExpression("a ++ + + b".dup).serialize() == "( + , ( post ++ , a), ( pre + , b))");
	assert(parseInfixExpression("a ++ - + b".dup).serialize() == "( - , ( post ++ , a), ( pre + , b))");
	assert(parseInfixExpression("a ++ + - b".dup).serialize() == "( + , ( post ++ , a), ( pre - , b))");

	// juxtaposition + prefix + postfix
	assert(parseInfixExpression("a ** ! b".dup).serialize() == "(  , ( post ** , a), ( pre ! , b))");
	assert(parseInfixExpression("a ** ! + b".dup).serialize() == "(  , ( post ** , a), ( pre ! , ( pre + , b)))");
	assert(parseInfixExpression("a ++ ** ! + b".dup).serialize() == "(  , ( post ** , ( post ++ , a)), ( pre ! , ( pre + , b)))");
} // end unittest

/*
	TODO: add the following test case (suggested by u_quark) to the test suite.
		This will require refactoring code to take the symbol table as an argument.

	++ infix L
	++ pre
	% infix
	* infix L
	* post
	p * ++ q % r

*/

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
	string name;
	Operator[] leadingPrefixes;

	this(string name, Operator[] leadingPrefixes)
	{
		this.name = name;
		this.leadingPrefixes = leadingPrefixes;
	}
}

class Seperator : Symbol
{
	mixin Named;
}

/*class Terminator : Symbol
{
	mixin Named;
}*/
