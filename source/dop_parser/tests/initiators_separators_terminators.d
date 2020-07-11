module dop_parser.tests.initiators_separators_terminators;

import std.algorithm, std.range, std.exception, std.format;

import dop_parser, test_utilities;

unittest // negative tests with distfix and confix operators and without juxtaposition
{
	immutable infix_operators = ["+":Op(5, Assoc.left), "-":Op(5, Assoc.left),
								"*":Op(6, Assoc.left), "~": Op(7, Assoc.right)];
	immutable prefix_operators = ["$":10, "-":10, "%":10, "~":10];
	immutable postfix_operators = ["!":11, "*":11, "%":11, "~":11];

	immutable paren = Tup("(", ",", ")");
	immutable bracket = Tup("[", ",", "]");
	Tup[string] initiators = ["(":paren, "[":bracket];
	immutable separators = [",":paren, ",":bracket];
	Tup[string] terminators = [")":paren, "]":bracket];

	immutable test_cases = [
		// no prefix, infix or postfix operators. no operands
		// one tokens
		["(", confix_imbalance], [",", missing_separator_left], [")", confix_imbalance],
		["[", confix_imbalance], ["]", confix_imbalance],
		// two tokens
		["( (", confix_imbalance      ], [", (", missing_separator_left], [") (", confix_imbalance],
		["( ,", missing_separator_left], [", ,", missing_separator_left], [") ,", confix_imbalance],
		["( )", ""/* not an error */  ], [", )", missing_separator_left], [") )", confix_imbalance],
		["( [", confix_imbalance      ], [", [", missing_separator_left], [") [", confix_imbalance],
		["( ]", confix_imbalance      ], [", ]", missing_separator_left], [") ]", confix_imbalance],

		["[ (", confix_imbalance      ], ["] (", confix_imbalance      ],
		["[ ,", missing_separator_left], ["] ,", confix_imbalance      ],
		["[ )", confix_imbalance      ], ["] )", confix_imbalance      ],
		["[ [", confix_imbalance      ], ["] [", confix_imbalance      ],
		["[ ]", ""/* not an error */  ], ["] ]", confix_imbalance      ],

		// three tokens
		["( ( (", confix_imbalance      ], ["( , (", missing_separator_left ], ["( ) (", no_op_no_juxtaposition ],
		["( ( ,", missing_separator_left], ["( , ,", missing_separator_left ], ["( ) ,", missing_separator_right],
		["( ( )", confix_imbalance      ], ["( , )", missing_separator_left ], ["( ) )", confix_imbalance       ],
		["( ( [", confix_imbalance      ], ["( , [", missing_separator_left ], ["( ) [", no_op_no_juxtaposition ],
		["( ( ]", confix_imbalance      ], ["( , ]", missing_separator_left ], ["( ) ]", confix_imbalance       ],

		["( [ (", confix_imbalance      ], ["( ] (", confix_imbalance       ],
		["( [ ,", missing_separator_left], ["( ] ,", confix_imbalance       ],
		["( [ )", confix_imbalance      ], ["( ] )", confix_imbalance       ],
		["( [ [", confix_imbalance      ], ["( ] [", confix_imbalance       ],
		["( [ ]", confix_imbalance      ], ["( ] ]", confix_imbalance       ],

		[", ( (", missing_separator_left], [", , (", missing_separator_left ], [", ) (", missing_separator_left],
		[", ( ,", missing_separator_left], [", , ,", missing_separator_left ], [", ) ,", missing_separator_left],
		[", ( )", missing_separator_left], [", , )", missing_separator_left ], [", ) )", missing_separator_left],
		[", ( [", missing_separator_left], [", , [", missing_separator_left ], [", ) [", missing_separator_left],
		[", ( ]", missing_separator_left], [", , ]", missing_separator_left ], [", ) ]", missing_separator_left],

		[", [ (", missing_separator_left], [", ] (", missing_separator_left ],
		[", [ ,", missing_separator_left], [", ] ,", missing_separator_left ],
		[", [ )", missing_separator_left], [", ] )", missing_separator_left ],
		[", [ [", missing_separator_left], [", ] [", missing_separator_left ],
		[", [ ]", missing_separator_left], [", ] ]", missing_separator_left ],

		[") ( (", confix_imbalance      ], [") , (", confix_imbalance       ], [") ) (", confix_imbalance      ],
		[") ( ,", confix_imbalance      ], [") , ,", confix_imbalance       ], [") ) ,", confix_imbalance      ],
		[") ( )", confix_imbalance      ], [") , )", confix_imbalance       ], [") ) )", confix_imbalance      ],
		[") ( [", confix_imbalance      ], [") , [", confix_imbalance       ], [") ) [", confix_imbalance      ],
		[") ( ]", confix_imbalance      ], [") , ]", confix_imbalance       ], [") ) ]", confix_imbalance      ],

		[") [ (", confix_imbalance      ], [") ] (", confix_imbalance       ],
		[") [ ,", confix_imbalance      ], [") ] ,", confix_imbalance       ],
		[") [ )", confix_imbalance      ], [") ] )", confix_imbalance       ],
		[") [ [", confix_imbalance      ], [") ] [", confix_imbalance       ],
		[") [ ]", confix_imbalance      ], [") ] ]", confix_imbalance       ],

		["[ ( (", confix_imbalance      ], ["[ , (", missing_separator_left ], ["[ ) (", confix_imbalance       ],
		["[ ( ,", missing_separator_left], ["[ , ,", missing_separator_left ], ["[ ) ,", confix_imbalance       ],
		["[ ( )", confix_imbalance      ], ["[ , )", missing_separator_left ], ["[ ) )", confix_imbalance       ],
		["[ ( [", confix_imbalance      ], ["[ , [", missing_separator_left ], ["[ ) [", confix_imbalance       ],
		["[ ( ]", confix_imbalance      ], ["[ , ]", missing_separator_left ], ["[ ) ]", confix_imbalance       ],

		["[ [ (", confix_imbalance      ], ["[ ] (", no_op_no_juxtaposition ],
		["[ [ ,", missing_separator_left], ["[ ] ,", missing_separator_right],
		["[ [ )", confix_imbalance      ], ["[ ] )", confix_imbalance       ],
		["[ [ [", confix_imbalance      ], ["[ ] [", no_op_no_juxtaposition ],
		["[ [ ]", confix_imbalance      ], ["[ ] ]", confix_imbalance       ],

		["] ( (", confix_imbalance      ], ["] , (", confix_imbalance       ], ["] ) (", confix_imbalance      ],
		["] ( ,", confix_imbalance      ], ["] , ,", confix_imbalance       ], ["] ) ,", confix_imbalance      ],
		["] ( )", confix_imbalance      ], ["] , )", confix_imbalance       ], ["] ) )", confix_imbalance      ],
		["] ( [", confix_imbalance      ], ["] , [", confix_imbalance       ], ["] ) [", confix_imbalance      ],
		["] ( ]", confix_imbalance      ], ["] , ]", confix_imbalance       ], ["] ) ]", confix_imbalance      ],

		["] [ (", confix_imbalance      ], ["] ] (", confix_imbalance       ],
		["] [ ,", confix_imbalance      ], ["] ] ,", confix_imbalance       ],
		["] [ )", confix_imbalance      ], ["] ] )", confix_imbalance       ],
		["] [ [", confix_imbalance      ], ["] ] [", confix_imbalance       ],
		["] [ ]", confix_imbalance      ], ["] ] ]", confix_imbalance       ],
	];

	runUnitTests!(test_input => collectExceptionMsg(parseInfixExpression(infix_operators, prefix_operators,
													postfix_operators, initiators, separators, terminators, test_input))
	)(test_cases);
} // end unittest
