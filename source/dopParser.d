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

import std.algorithm, std.range, std.exception, std.conv;
import ast;

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
	string separator;
	string terminator;

	this(string initiator, string separator, string terminator)
	{
		this.initiator = initiator;
		this.separator = separator;
		this.terminator = terminator;
	}
}

/* Note: right now, the operator, initiator, separator and terminator sets must be disjoint!! */
/* 		 also, only one associativity is expected per precedence level. */
/*		 Last but not least, precedence for prefix and postfix operators is currently ignored. */
Expression parseInfixExpression(
	const Op[string] infixOperators,
	const int[string] prefixOperators,
	const int[string] postfixOperators,
	Tup[string] initiators,
	const Tup[string] separators,
	Tup[string] terminators,
	string input)
{
	// Modify tables to treat start- and end-of-input as a confix operator.
	string bnc = to!string(""w ~ cast(wchar)65535);	// workaround to legitimately use noncharacters...
	string enc = to!string(""w ~ cast(wchar)65534);
	immutable eoe = Tup(bnc,"",enc);
	initiators[bnc] = eoe;
	terminators[enc] = eoe;
	
	// Data structures required by the algorithm:
	Symbol[] symbols; // used as a stack
	Operator[] stagedOperators;

	// below some enforce calls may need to change to assert...
	void dispatchToken(string token)
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
						symbols ~= new Operator(token);
						break;
					}
					else
					{	// reduce
						enforce(cast(Expression)symbols[$-3]);
						symbols[$-3] = new ExpressionAstNode((cast(Operator)symbols[$-2]).name,[cast(Expression)symbols[$-3],cast(Expression)symbols[$-1]]);
						symbols = symbols[0..$-2];
					} // end else
				}
				else	// initiator || separator
				{	// shift
					symbols ~= new Operator(token);
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
			symbols ~= new Initiator(token,stagedOperators);
			stagedOperators = [];
			enforce(initiators[token].initiator == token);
		}
		else if(token in separators)	// separator
		{
			enforce(cast(Expression)symbols[$-1]);
			// shift
			symbols ~= new Separator(token);
			enforce(separators[token].separator == token);
		}
		else if(token in terminators)	// terminator
		{
			Expression[] operands = [];
			Initiator topAsInit;

			while(true)
			{
				topAsInit = cast(Initiator)symbols[$-1];
				if(topAsInit)
				{
					enforce(terminators[token].initiator == topAsInit.name, "Initiator/Terminator mismatch and/or imbalance!");
					break;
				}

				enforce(cast(Expression)symbols[$-1]);
				if(cast(Operator)symbols[$-2])
				{	// reduce
					enforce(cast(Expression)symbols[$-3]);
					symbols[$-3] = new ExpressionAstNode((cast(Operator)symbols[$-2]).name,[cast(Expression)symbols[$-3],cast(Expression)symbols[$-1]]);
					symbols = symbols[0..$-2];
				}
				else if(cast(Separator)symbols[$-2])
				{	// save expression
					enforce((cast(Separator)symbols[$-2]).name == terminators[token].separator);
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
				enforce(null in infixOperators,
					"Two consecutive operands and juxtaposition is not defined!");
				dispatchToken(null);	// handle as infix operator
			}
			// reduce possible leading prefix operators
			Expression temp = new LiteralOperand(token);
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


	void processToken(string token)
	{
		if(token in infixOperators || token in prefixOperators || token in postfixOperators)
		{
			stagedOperators ~= new Operator(token);
		}
		else
		{
			if(!stagedOperators.empty)
			{
				if(cast(Initiator)symbols[$-1] || cast(Separator)symbols[$-1])
				{
					enforce(token !in separators && token !in terminators,
						"There must be an operand in at least one side of an operator sequence!");
				}
				else if(token in separators || token in terminators)
				{
					foreach(operator; stagedOperators)
					{
						assert(cast(Expression)symbols[$-1]);
						enforce(operator.name in postfixOperators,
							"Only postfix operators can exist between an operand and a separator or terminator or end of input!");
						symbols[$-1] = new ExpressionAstNode("post " ~ operator.name,[cast(Expression)symbols[$-1]]);
					} // end foreach
					stagedOperators = [];
				}
				else
				{
					assert(cast(Expression)symbols[$-1]);	// token should be initiator or operand
					long firstNonPost = 0;	// from the left
					while(firstNonPost < stagedOperators.length && stagedOperators[firstNonPost].name in postfixOperators)
						firstNonPost++;
					long lastNonPre = stagedOperators.length-1;	// from the left
					while(lastNonPre > -1 && stagedOperators[lastNonPre].name in prefixOperators)
						lastNonPre--;
					long count = 0;
					long index = -1;
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
						dispatchToken(stagedOperators[index].name);
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
	foreach(token; std.array.split(input))
	{
		processToken(token);
	} // end foreach
	processToken(enc);	// should match starting sentinel token

	enforce(symbols.length == 1, "Stack not exhausted!");
	// remove the node created for sentinel
	auto operands = (cast(ExpressionAstNode)symbols.back()).operands;
	return operands.length?operands[0]:null;
} // end function parseInfixExpression

unittest // positive tests
{
	// TODO: add tests related to how operator tables are modified by the parser.
	immutable infix_operators = ["+":Op(5,Assoc.left),"-":Op(5,Assoc.left),"*":Op(6,Assoc.left),"/":Op(6,Assoc.left),
		"=":Op(4,Assoc.right),"+=":Op(4,Assoc.right),",,":Op(3,Assoc.left),"..":Op(7,Assoc.right),null:Op(6,Assoc.left)];
	immutable prefix_operators = ["+":1,"-":1,"*":1,"++":1,"--":1,"!":1,"~":1];
	immutable postfix_operators = ["++":1,"--":1,"**":1];

	immutable paren = Tup("(",",",")"), bracket = Tup("[",",","]"), brace = Tup("{",".","}");
	Tup[string] initiators = ["(":paren,"[":bracket,"{":brace];
	immutable separators = [",":paren,",":bracket,".":brace];
	Tup[string] terminators = [")":paren,"]":bracket,"}":brace];
	
	immutable test_cases = [
		// basic infix operations
		["2", "2"],
		["2 + 3", "( + , 2, 3)"],
		["a - b", "( - , a, b)"],
		["a + b + c", "( + , ( + , a, b), c)"],
		["a - b - c", "( - , ( - , a, b), c)"],
		["a + b - c", "( - , ( + , a, b), c)"],
		["a + b - c + d - e", "( - , ( + , ( - , ( + , a, b), c), d), e)"],
		["a * b * c", "( * , ( * , a, b), c)"],
		["a / b / c", "( / , ( / , a, b), c)"],
		["a * b / c", "( / , ( * , a, b), c)"],
		["a * b / c * d / e", "( / , ( * , ( / , ( * , a, b), c), d), e)"],
		["a = b = c", "( = , a, ( = , b, c))"],
		["a += b += c", "( += , a, ( += , b, c))"],
		["a = b += c", "( = , a, ( += , b, c))"],
		["a = b += c = d += e", "( = , a, ( += , b, ( = , c, ( += , d, e))))"],
		["2 + 3 * 4", "( + , 2, ( * , 3, 4))"],
		["2 * 3 + 4", "( + , ( * , 2, 3), 4)"],
		["2 - 3 / 4", "( - , 2, ( / , 3, 4))"],
		["2 / 3 - 4", "( - , ( / , 2, 3), 4)"],
		["2 = 3 .. 4", "( = , 2, ( .. , 3, 4))"],
		["2 .. 3 = 4", "( = , ( .. , 2, 3), 4)"],
		["2 += 3 .. 4", "( += , 2, ( .. , 3, 4))"],
		["2 .. 3 += 4", "( += , ( .. , 2, 3), 4)"],
		["a += b = 3 * b + 2", "( += , a, ( = , b, ( + , ( * , 3, b), 2)))"],
		// tuples
		["( )", "( ( )"],
		["[ ]", "( [ )"],
		["{ }", "( { )"],
		["( 2 )", "( ( , 2)"],
		["[ 2 ]", "( [ , 2)"],
		["{ 2 }", "( { , 2)"],
		["( 2 , 3 )", "( ( , 2, 3)"],
		["[ 2 , 3 ]", "( [ , 2, 3)"],
		["{ 2 . 3 }", "( { , 2, 3)"],
		["( 2 , 3 , 4 )", "( ( , 2, 3, 4)"],
		["[ 2 , 3 , 4 ]", "( [ , 2, 3, 4)"],
		["{ 2 . 3 . 4 }", "( { , 2, 3, 4)"],
		["( a + b )", "( ( , ( + , a, b))"],
		["[ a + b ]", "( [ , ( + , a, b))"],
		["{ a + b }", "( { , ( + , a, b))"],
		["( a + b , 3 )", "( ( , ( + , a, b), 3)"],
		["[ a + b , 3 ]", "( [ , ( + , a, b), 3)"],
		["{ a + b . 3 }", "( { , ( + , a, b), 3)"],
		["( a + b , 3 , 4 )", "( ( , ( + , a, b), 3, 4)"],
		["[ a + b , 3 , 4 ]", "( [ , ( + , a, b), 3, 4)"],
		["{ a + b . 3 . 4 }", "( { , ( + , a, b), 3, 4)"],
		["( a + b , c .. d )", "( ( , ( + , a, b), ( .. , c, d))"],
		["[ a + b , c .. d ]", "( [ , ( + , a, b), ( .. , c, d))"],
		["{ a + b . c .. d }", "( { , ( + , a, b), ( .. , c, d))"],
		["( a + b , c .. d , 4 )", "( ( , ( + , a, b), ( .. , c, d), 4)"],
		["[ a + b , c .. d , 4 ]", "( [ , ( + , a, b), ( .. , c, d), 4)"],
		["{ a + b . c .. d . 4 }", "( { , ( + , a, b), ( .. , c, d), 4)"],
		["( a + b , c .. d , e * f )", "( ( , ( + , a, b), ( .. , c, d), ( * , e, f))"],
		["[ a + b , c .. d , e * f ]", "( [ , ( + , a, b), ( .. , c, d), ( * , e, f))"],
		["{ a + b . c .. d . e * f }", "( { , ( + , a, b), ( .. , c, d), ( * , e, f))"],
		// grouping
		["( a + b ) + c", "( + , ( ( , ( + , a, b)), c)"],
		["( a - b ) - c", "( - , ( ( , ( - , a, b)), c)"],
		["a + ( b + c )", "( + , a, ( ( , ( + , b, c)))"],
		["a - ( b - c )", "( - , a, ( ( , ( - , b, c)))"],
		["[ a + b ] + c", "( + , ( [ , ( + , a, b)), c)"],
		["[ a - b ] - c", "( - , ( [ , ( - , a, b)), c)"],
		["a + [ b + c ]", "( + , a, ( [ , ( + , b, c)))"],
		["a - [ b - c ]", "( - , a, ( [ , ( - , b, c)))"],
		["{ a + b } + c", "( + , ( { , ( + , a, b)), c)"],
		["{ a - b } - c", "( - , ( { , ( - , a, b)), c)"],
		["a + { b + c }", "( + , a, ( { , ( + , b, c)))"],
		["a - { b - c }", "( - , a, ( { , ( - , b, c)))"],
		// nested tuples
		["2 + ( a , ( b , c ) )", "( + , 2, ( ( , a, ( ( , b, c)))"],
		// basic juxtaposition
		["a b", "(  , a, b)"],
		["a b c", "(  , (  , a, b), c)"],
		["a b * c", "( * , (  , a, b), c)"],
		["a * b c", "(  , ( * , a, b), c)"],
		["a + b c", "( + , a, (  , b, c))"],
		["a b + c", "( + , (  , a, b), c)"],
		// juxtaposition + tuples
		["a ( b )", "(  , a, ( ( , b))"],
		["( a ) b", "(  , ( ( , a), b)"],
		["a ( b c )", "(  , a, ( ( , (  , b, c)))"],
		["( a b ) c", "(  , ( ( , (  , a, b)), c)"],
		["a ( b , c )", "(  , a, ( ( , b, c))"],
		["( a , b ) c", "(  , ( ( , a, b), c)"],
		// basic postfix operations
		["a ++", "( post ++ , a)"],
		["a --", "( post -- , a)"],
		["a ++ --", "( post -- , ( post ++ , a))"],
		["a -- ++", "( post ++ , ( post -- , a))"],
		// postfix + tuples
		["( a ) ++", "( post ++ , ( ( , a))"],
		["( a ) --", "( post -- , ( ( , a))"],
		["( a ) ++ --", "( post -- , ( post ++ , ( ( , a)))"],
		["( a ) -- ++", "( post ++ , ( post -- , ( ( , a)))"],
		["( a ++ ) --", "( post -- , ( ( , ( post ++ , a)))"],
		["( a -- ) ++", "( post ++ , ( ( , ( post -- , a)))"],
		// basic prefix operations
		["++ a", "( pre ++ , a)"],
		["-- a", "( pre -- , a)"],
		["-- ++ a", "( pre -- , ( pre ++ , a))"],
		["++ -- a", "( pre ++ , ( pre -- , a))"],
		["+ a", "( pre + , a)"],
		["- a", "( pre - , a)"],
		["- + a", "( pre - , ( pre + , a))"],
		["+ - a", "( pre + , ( pre - , a))"],
		// prefix + tuples
		["++ ( a )", "( pre ++ , ( ( , a))"],
		["-- ( a )", "( pre -- , ( ( , a))"],
		["-- ++ ( a )", "( pre -- , ( pre ++ , ( ( , a)))"],
		["++ -- ( a )", "( pre ++ , ( pre -- , ( ( , a)))"],
		["-- ( ++ a )", "( pre -- , ( ( , ( pre ++ , a)))"],
		["++ ( -- a )", "( pre ++ , ( ( , ( pre -- , a)))"],
		["+ ( a )", "( pre + , ( ( , a))"],
		["- ( a )", "( pre - , ( ( , a))"],
		["- + ( a )", "( pre - , ( pre + , ( ( , a)))"],
		["+ - ( a )", "( pre + , ( pre - , ( ( , a)))"],
		["- ( + a )", "( pre - , ( ( , ( pre + , a)))"],
		["+ ( - a )", "( pre + , ( ( , ( pre - , a)))"],
		// prefix + postfix
		["-- a ++", "( post ++ , ( pre -- , a))"],
		["++ a --", "( post -- , ( pre ++ , a))"],
		["-- a ++ --", "( post -- , ( post ++ , ( pre -- , a)))"],
		["++ a -- ++", "( post ++ , ( post -- , ( pre ++ , a)))"],
		["- a ++", "( post ++ , ( pre - , a))"],
		["+ a --", "( post -- , ( pre + , a))"],
		["- a ++ --", "( post -- , ( post ++ , ( pre - , a)))"],
		["+ a -- ++", "( post ++ , ( post -- , ( pre + , a)))"],
		["++ - a ++", "( post ++ , ( pre ++ , ( pre - , a)))"],
		["++ + a --", "( post -- , ( pre ++ , ( pre + , a)))"],
		["++ - a ++ --", "( post -- , ( post ++ , ( pre ++ , ( pre - , a))))"],
		["++ + a -- ++", "( post ++ , ( post -- , ( pre ++ , ( pre + , a))))"],
		// prefix + postfix + grouping
		["( -- a ) ++", "( post ++ , ( ( , ( pre -- , a)))"],
		["++ ( a -- )", "( pre ++ , ( ( , ( post -- , a)))"],
		["-- ( a ++ ) --", "( post -- , ( pre -- , ( ( , ( post ++ , a))))"],
		["++ ( a -- ++ )", "( pre ++ , ( ( , ( post ++ , ( post -- , a))))"],
		// prefix + postfix + tuples
		["-- ( a ++ , b ) --", "( post -- , ( pre -- , ( ( , ( post ++ , a), b)))"],
		["++ ( a -- , b ++ )", "( pre ++ , ( ( , ( post -- , a), ( post ++ , b)))"],
		// infix + prefix + postfix
		["a + + b", "( + , a, ( pre + , b))"],
		["a - + b", "( - , a, ( pre + , b))"],
		["a + - b", "( + , a, ( pre - , b))"],
		["a ++ + + b", "( + , ( post ++ , a), ( pre + , b))"],
		["a ++ - + b", "( - , ( post ++ , a), ( pre + , b))"],
		["a ++ + - b", "( + , ( post ++ , a), ( pre - , b))"],

		// juxtaposition + prefix + postfix
		["a ** ! b", "(  , ( post ** , a), ( pre ! , b))"],
		["a ** ! + b", "(  , ( post ** , a), ( pre ! , ( pre + , b)))"],
		["a ++ ** ! + b", "(  , ( post ** , ( post ++ , a)), ( pre ! , ( pre + , b)))"],
	];

	foreach(test_case; test_cases)
	{
		assert(parseInfixExpression(infix_operators, prefix_operators, postfix_operators,
			initiators, separators, terminators, test_case[0]).serialize() == test_case[1]);
	} // end foreach
} // end unittest

unittest // negative tests
{
	immutable infix_operators = ["++":Op(8,Assoc.left),"%":Op(4,Assoc.right),"*":Op(2,Assoc.left),"/":Op(6,Assoc.left)];
	immutable prefix_operators = ["++":6];
	immutable postfix_operators = ["*":0];
	
	Tup[string] initiators;
	immutable Tup[string] separators;
	Tup[string] terminators;
	
	assert(collectExceptionMsg(parseInfixExpression(infix_operators, prefix_operators, 
		postfix_operators, initiators, separators, terminators, "p * ++ q % r".dup)
	) == "Enforcement failed");
} // end unittest


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
	assert(new Operator("hello").name == "hello");
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

class Separator : Symbol
{
	mixin Named;
}

/*class Terminator : Symbol
{
	mixin Named;
}*/
