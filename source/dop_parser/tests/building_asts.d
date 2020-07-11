module dop_parser.tests.building_asts;

import std.algorithm, std.range, std.exception, std.format;

import dop_parser, test_utilities;

unittest // positive tests
{
	// TODO: add tests related to how operator tables are modified by the parser.
	immutable infix_operators = ["+":Op(5,Assoc.left),"-":Op(5,Assoc.left),"*":Op(6,Assoc.left),"/":Op(6,Assoc.left),
		"=":Op(4,Assoc.right),"+=":Op(4,Assoc.right),",,":Op(3,Assoc.left),"..":Op(7,Assoc.right),"?":Op(10,Assoc.right),
		null:Op(6,Assoc.left)];
	immutable prefix_operators = ["+":1,"-":1,"*":1,"++":1,"--":1,"!":1,"~":1,"?":1];
	immutable postfix_operators = ["++":1,"--":1,"**":1,"?":1];

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
		["foo -- ** ? ++ ~ + bar", "( ? , ( post ** , ( post -- , foo)), ( pre ++ , ( pre ~ , ( pre + , bar))))"],
		// juxtaposition + prefix + postfix
		["a ** ! b", "(  , ( post ** , a), ( pre ! , b))"],
		["a ** ! + b", "(  , ( post ** , a), ( pre ! , ( pre + , b)))"],
		["a ++ ** ! + b", "(  , ( post ** , ( post ++ , a)), ( pre ! , ( pre + , b)))"],
		// juxtaposition + prefix + postfix + tuples
		["a ** ( b )", "(  , ( post ** , a), ( ( , b))"],
		["a ! ( b )", "(  , a, ( pre ! , ( ( , b)))"],
		["( a ) ** b", "(  , ( post ** , ( ( , a)), b)"],
		["( a ) ! b", "(  , ( ( , a), ( pre ! , b))"],
		["a ** ! ( b c )", "(  , ( post ** , a), ( pre ! , ( ( , (  , b, c))))"],
		["( a b ) ** ! c", "(  , ( post ** , ( ( , (  , a, b))), ( pre ! , c))"],
		["a ++ ** ! ~ ( b , c )", "(  , ( post ** , ( post ++ , a)), ( pre ! , ( pre ~ , ( ( , b, c))))"],
		["( a , b ) ++ ** ! ~ c", "(  , ( post ** , ( post ++ , ( ( , a, b))), ( pre ! , ( pre ~ , c)))"],
	];

	runUnitTests!(test_input => parseInfixExpression(infix_operators, prefix_operators, postfix_operators,
													initiators, separators, terminators, test_input).serialize()
	)(test_cases);
} // end unittest
