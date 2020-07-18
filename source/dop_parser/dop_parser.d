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
module dop_parser.dop_parser;

import std.algorithm, std.range, std.exception, std.conv, std.format;
import ast, test_utilities;

enum Assoc {left,right}

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

// Symbolic names for error messages generated by parseInfixExpression
// Note that in order to keep variable names reasonably short, the semantics had
// to be oversimplified and in some situations the name can be misleading. It's
// the string value itself that adequately describes the situation.
package immutable missing_both_operands =
	"There must be an operand in at least one side of an operator sequence!";
package immutable missing_right_operand =
	"Only postfix operators can exist between an operand and a terminator (or separator or end of input)!";
package immutable missing_left_operand =
	"Only prefix operators can exist between an initiator (or separator or start of input) and an operand!";
package immutable no_op_no_juxtaposition =
	"Two consecutive operable expressions, but juxtaposition is not defined!";
package immutable no_infix_no_juxtaposition =
	"Two operands without any infix operator between them, but juxtaposition is not defined!";
package immutable ambiguous_expression =
	"Ambiguous expression: more than one assignment of fixities to operators is possible!";
package immutable no_valid_assignment =
	"A prefix or infix operator cannot appear before a postfix or infix operator without operand(s) between them!";
package immutable ambiguous_juxtaposition =
	"Ambiguous expression: multiple valid positions for juxtaposition operator!";
// Error messages related to confix and distfix operators:
package immutable confix_imbalance =
	"Initiator/Terminator mismatch and/or imbalance!";
package immutable missing_separator_left =
	"A separator must be preceded by an operable expression!";
package immutable missing_separator_right =
	"A separator must be followed by an operable expression!";

/* Note: right now, the operator, initiator, separator and terminator sets must be disjoint!! */
/* 		 also, only one associativity is expected per precedence level. */
/*		 Last but not least, precedence for prefix and postfix operators is currently ignored. */
/* Note: Should there be an option to interpret "a - b" as "a (- b)"? */
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
	string bnc = to!string(""w ~ cast(wchar)65_535); // workaround to legitimately use noncharacters...
	string enc = to!string(""w ~ cast(wchar)65_534);
	immutable eoe = Tup(bnc,"",enc);
	initiators[bnc] = eoe;
	terminators[enc] = eoe;

	// Data structures required by the algorithm:
	Symbol[] symbols; // used as a stack
	Operator[] stagedOperators;

	// dispatchToken only removes operators from stagedOperators, never inserts.
	void dispatchToken(string token)
	{
		if(token in infixOperators) 			// operator
		{
			enforce(cast(Expression)symbols[$-1],
				"An infix operator must have something to operate on on its left!");
			while(true)
			{
				if(cast(Operator)symbols[$-2])	// operator
				{
					auto previous = cast(Operator)symbols[$-2];
					if(infixOperators[previous.name].priority == infixOperators[token].priority)
						enforce(infixOperators[previous.name].associativity == infixOperators[token].associativity,
							"Currently only one associativity is supported per precedence level!");
					if(infixOperators[previous.name].priority < infixOperators[token].priority ||
						(infixOperators[previous.name].priority == infixOperators[token].priority &&
						 infixOperators[token].associativity == Assoc.right))
					{	// shift
						symbols ~= new Operator(token);
						break;
					}
					else
					{	// reduce
						enforce(cast(Expression)symbols[$-3], // we may have already checked this...
							"An infix operator must have something to operate on on its left!");
						symbols[$-3] = new ExpressionAstNode(previous.name,[cast(Expression)symbols[$-3],cast(Expression)symbols[$-1]]);
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
			// Ideally this should be caught before the parser is called...
			enforce(token !in prefixOperators && token !in postfixOperators,
				"Currently an initiator can't be overloaded as an operator!");
			if(cast(Expression)symbols[$-1])
			{
				assert(null in infixOperators);
				dispatchToken(null);	// handle as infix operator
			}
			// handle possible leading prefix operators
			foreach(operator; stagedOperators)
				enforce(operator.name in prefixOperators,
					"Only prefix operators can exist between an infix operator and an initiator!");
			// shift
			symbols ~= new Initiator(token,stagedOperators);
			stagedOperators = [];
			assert(initiators[token].initiator == token); // Sanity check. It should probably become a precondition.
		}
		else if(token in separators)	// separator
		{
			enforce(cast(Expression)symbols[$-1], missing_separator_left);
			// shift
			symbols ~= new Separator(token);
			assert(separators[token].separator == token); // Sanity check. It should probably become a precondition.
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
					enforce(terminators[token].initiator == topAsInit.name, confix_imbalance);
					break;
				}

				enforce(cast(Expression)symbols[$-1], missing_separator_right);
				if(cast(Operator)symbols[$-2])
				{	// reduce
					enforce(cast(Expression)symbols[$-3], // we may have already checked this...
						"An infix operator must have something to operate on on its left!");
					symbols[$-3] = new ExpressionAstNode(
											(cast(Operator)symbols[$-2]).name,
											[cast(Expression)symbols[$-3], cast(Expression)symbols[$-1]]
									);
					symbols = symbols[0..$-2];
				}
				else if(cast(Separator)symbols[$-2])
				{	// save expression
					enforce((cast(Separator)symbols[$-2]).name == terminators[token].separator,
						"Terminator/separator mismatch or missing terminator!");
					operands = cast(Expression)symbols[$-1] ~ operands;
					symbols = symbols[0..$-2];
				}
				else // Initiator
				{	// save expression
					assert(cast(Initiator)symbols[$-2]); // any syntax errors should have already be emitted by now...
					operands = cast(Expression)symbols[$-1] ~ operands;
					symbols = symbols[0..$-1];
				} // end else
			} // end while
			// reduce possible leading prefix operators
			Operator[] leadingPrefixes = topAsInit.leadingPrefixes;
			Expression temp = new ExpressionAstNode(topAsInit.name,operands);
			while(!leadingPrefixes.empty)
			{
				assert(leadingPrefixes[$-1].name in prefixOperators); // should become a precondition of the Initiator constructor...
				temp = new ExpressionAstNode("pre " ~ leadingPrefixes[$-1].name,[temp]);
				leadingPrefixes = leadingPrefixes[0..$-1];
			} // end while
			// reduce
			symbols[$-1] = temp;
		}
		else							// operand
		{
			assert(token !in prefixOperators && token !in postfixOperators); // should become a precondition of dispatchToken
			if(cast(Expression)symbols[$-1])
			{
				assert(null in infixOperators);
				dispatchToken(null);	// handle as infix operator
			}
			// reduce possible leading prefix operators
			Expression temp = new LiteralOperand(token);
			while(!stagedOperators.empty)
			{
				assert(stagedOperators[$-1].name in prefixOperators);
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
			return;
		} // end if

		assert(!cast(Operator)symbols[$-1]);
		// Since neither token nor top of the stack are operators, there are
		// exactly 4 possibilities:
		if(cast(Initiator)symbols[$-1] || cast(Separator)symbols[$-1])
		{ // preceding token was an initiator or separator
			if(token in terminators || token in separators)
			{ // following token is a terminator or separator
				enforce(stagedOperators.empty, missing_both_operands);
			}
			else
			{ // following token is an initiator or operand
				foreach(operator; stagedOperators)
				{
					enforce(operator.name in prefixOperators, missing_left_operand);
					// reduction will be done later in dispatchToken
				} // end foreach
			} // end else
		}
		else
		{ // preceding token was a terminator or operand
			if(token in terminators || token in separators)
			{ // following token is a terminator or separator
				foreach(operator; stagedOperators)
				{
					enforce(operator.name in postfixOperators, missing_right_operand);
					assert(cast(Expression)symbols[$-1]); // the top of the stack is something we can operate on.
					symbols[$-1] = new ExpressionAstNode("post " ~ operator.name,[cast(Expression)symbols[$-1]]);
				} // end foreach
				stagedOperators = [];
			}
			else
			{ // following token is an initiator or operand
				assert(cast(Expression)symbols[$-1]); // can't be a terminator and we've checked for initiator and separator and there are staged operators.
				long firstNonPost = 0;	// from the left
				while(firstNonPost < stagedOperators.length && stagedOperators[firstNonPost].name in postfixOperators)
					firstNonPost++;
				long lastNonPre = cast(long)stagedOperators.length-1;	// from the left
				while(lastNonPre > -1 && stagedOperators[lastNonPre].name in prefixOperators)
					lastNonPre--;

				enforce(lastNonPre <= firstNonPost, no_valid_assignment);

				// count infix operators inside the range:
				long count = 0, index = -1;
				for(auto i = max(0,lastNonPre) ; i <= min(cast(long)stagedOperators.length-1,firstNonPost) ; i++)
				{
					if(stagedOperators[i].name in infixOperators)
					{
						count++;
						index = i;
					} // end if
				} // end for

				enforce(count <= 1, ambiguous_expression);
				if(count == 1) // a single infix
				{
					// reduce postfix operators
					foreach(i; 0..index)
					{
						assert(cast(Expression)symbols[$-1]); // still an expression (checked above)
						assert(stagedOperators[i].name in postfixOperators); // due to the way index is calculated.
						symbols[$-1] = new ExpressionAstNode("post " ~ stagedOperators[i].name,[cast(Expression)symbols[$-1]]);
					} // end foreach
					assert(stagedOperators[index].name in infixOperators); // due to the way index is calculated.
					dispatchToken(stagedOperators[index].name);
					stagedOperators = stagedOperators[index+1..$];
				}
				else if(count == 0) // juxtaposition
				{
					enforce(null in infixOperators,
						stagedOperators.empty ? no_op_no_juxtaposition : no_infix_no_juxtaposition);
					enforce(firstNonPost-lastNonPre == 1, ambiguous_juxtaposition);
					// reduce postfix operators
					foreach(i; 0..firstNonPost)
					{
						assert(cast(Expression)symbols[$-1]); // still an expression (checked above)
						assert(stagedOperators[i].name in postfixOperators); // due to the way firstNonPost is calculated.
						symbols[$-1] = new ExpressionAstNode("post " ~ stagedOperators[i].name,[cast(Expression)symbols[$-1]]);
					} // end foreach
					dispatchToken(null);
					stagedOperators = stagedOperators[firstNonPost..$];
				} // end if
			} // end else
		} // end else

		dispatchToken(token);
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
