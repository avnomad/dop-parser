/**
 * Copyright: (C) 2012-2013, 2018, 2020 Vaptistis Anogeianakis <nomad@cornercase.gr>
 *
 * This file is part of DOP Parser.
 *
 * DOP Parser is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * DOP Parser is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with DOP Parser.  If not, see <http://www.gnu.org/licenses/>.
 */
module dop_parser.tests.operators_juxtaposition_enabled;

import std.algorithm, std.range, std.exception, std.format;

import dop_parser, test_utilities, dop_parser.tests.operators_common;

unittest // negative tests with juxtaposition
{
	immutable infix_operators = ["+":Op(5, Assoc.left), "-":Op(5, Assoc.left), "*":Op(6, Assoc.left),
								 "~": Op(7, Assoc.right), null:Op(8,Assoc.left)];
	immutable prefix_operators = ["$":10, "-":10, "%":10, "~":10];
	immutable postfix_operators = ["!":11, "*":11, "%":11, "~":11];
	immutable all_operators = array(filter!("a !is null")(multiwayUnion([
		sort(infix_operators.keys),
		sort(prefix_operators.keys),
		sort(postfix_operators.keys)
	])));

	Tup[string] initiators;
	immutable Tup[string] separators;
	Tup[string] terminators;

	// only operators (1-4)
	runUnitTests!(
		test_input => collectExceptionMsg(parseInfixExpression(infix_operators, prefix_operators, postfix_operators,
																initiators, separators, terminators, test_input))
	)(chain(
		all_operators,
		map!(s => format!"%(%s%| %)"(s))(cartesianProduct(all_operators,all_operators)),
		map!(s => format!"%(%s%| %)"(s))(cartesianProduct(all_operators,all_operators,all_operators)),
		map!(s => format!"%(%s%| %)"(s))(cartesianProduct(all_operators,all_operators,all_operators,all_operators))
	).map!(s => [s, missing_both_operands]));

	immutable test_cases = [
		// one operator and one operand
		["a +", missing_right_operand],
		["+ a", missing_left_operand],
		["a $", missing_right_operand],
		["! a", missing_left_operand],
		["a -", missing_right_operand],
		["* a", missing_left_operand],

		// two operands
		["a b", ""/* not an error */],

		// three operands
		["a b 0", ""/* not an error */],

		// two operands and one operator
		["a b +", missing_right_operand], ["a + b", ""/* not an error */],    ["+ a b", missing_left_operand],
		["a b $", missing_right_operand], ["a $ b", ""/* not an error */],    ["$ a b", ""/* not an error */],
		["a b !", ""/* not an error */],  ["a ! b", ""/* not an error */],    ["! a b", missing_left_operand],
		["a b -", missing_right_operand], ["a - b", ""/* not an error */],    ["- a b", ""/* not an error */],
		["a b *", ""/* not an error */],  ["a * b", ""/* not an error */],    ["* a b", missing_left_operand],
		["a b %", ""/* not an error */],  ["a % b", ambiguous_juxtaposition], ["% a b", ""/* not an error */],
		["a b ~", ""/* not an error */],  ["a ~ b", ""/* not an error */],    ["~ a b", ""/* not an error */],

		// one operand and two operators
		["a + +", missing_right_operand], ["+ a +", missing_left_operand],  ["+ + a", missing_left_operand],
		["a + $", missing_right_operand], ["+ a $", missing_left_operand],  ["+ $ a", missing_left_operand],
		["a + !", missing_right_operand], ["+ a !", missing_left_operand],  ["+ ! a", missing_left_operand],
		["a + -", missing_right_operand], ["+ a -", missing_left_operand],  ["+ - a", missing_left_operand],
		["a + *", missing_right_operand], ["+ a *", missing_left_operand],  ["+ * a", missing_left_operand],
		["a + %", missing_right_operand], ["+ a %", missing_left_operand],  ["+ % a", missing_left_operand],
		["a + ~", missing_right_operand], ["+ a ~", missing_left_operand],  ["+ ~ a", missing_left_operand],
		["a $ +", missing_right_operand], ["$ a +", missing_right_operand], ["$ + a", missing_left_operand],
		["a $ $", missing_right_operand], ["$ a $", missing_right_operand], ["$ $ a", ""/* not an error */],
		["a $ !", missing_right_operand], ["$ a !", ""/* not an error */],  ["$ ! a", missing_left_operand],
		["a $ -", missing_right_operand], ["$ a -", missing_right_operand], ["$ - a", ""/* not an error */],
		["a $ *", missing_right_operand], ["$ a *", ""/* not an error */],  ["$ * a", missing_left_operand],
		["a $ %", missing_right_operand], ["$ a %", ""/* not an error */],  ["$ % a", ""/* not an error */],
		["a $ ~", missing_right_operand], ["$ a ~", ""/* not an error */],  ["$ ~ a", ""/* not an error */],
		["a ! +", missing_right_operand], ["! a +", missing_left_operand],  ["! + a", missing_left_operand],
		["a ! $", missing_right_operand], ["! a $", missing_left_operand],  ["! $ a", missing_left_operand],
		["a ! !", ""/* not an error */],  ["! a !", missing_left_operand],  ["! ! a", missing_left_operand],
		["a ! -", missing_right_operand], ["! a -", missing_left_operand],  ["! - a", missing_left_operand],
		["a ! *", ""/* not an error */],  ["! a *", missing_left_operand],  ["! * a", missing_left_operand],
		["a ! %", ""/* not an error */],  ["! a %", missing_left_operand],  ["! % a", missing_left_operand],
		["a ! ~", ""/* not an error */],  ["! a ~", missing_left_operand],  ["! ~ a", missing_left_operand],
		["a - +", missing_right_operand], ["- a +", missing_right_operand], ["- + a", missing_left_operand],
		["a - $", missing_right_operand], ["- a $", missing_right_operand], ["- $ a", ""/* not an error */],
		["a - !", missing_right_operand], ["- a !", ""/* not an error */],  ["- ! a", missing_left_operand],
		["a - -", missing_right_operand], ["- a -", missing_right_operand], ["- - a", ""/* not an error */],
		["a - *", missing_right_operand], ["- a *", ""/* not an error */],  ["- * a", missing_left_operand],
		["a - %", missing_right_operand], ["- a %", ""/* not an error */],  ["- % a", ""/* not an error */],
		["a - ~", missing_right_operand], ["- a ~", ""/* not an error */],  ["- ~ a", ""/* not an error */],
		["a * +", missing_right_operand], ["* a +", missing_left_operand],  ["* + a", missing_left_operand],
		["a * $", missing_right_operand], ["* a $", missing_left_operand],  ["* $ a", missing_left_operand],
		["a * !", ""/* not an error */],  ["* a !", missing_left_operand],  ["* ! a", missing_left_operand],
		["a * -", missing_right_operand], ["* a -", missing_left_operand],  ["* - a", missing_left_operand],
		["a * *", ""/* not an error */],  ["* a *", missing_left_operand],  ["* * a", missing_left_operand],
		["a * %", ""/* not an error */],  ["* a %", missing_left_operand],  ["* % a", missing_left_operand],
		["a * ~", ""/* not an error */],  ["* a ~", missing_left_operand],  ["* ~ a", missing_left_operand],
		["a % +", missing_right_operand], ["% a +", missing_right_operand], ["% + a", missing_left_operand],
		["a % $", missing_right_operand], ["% a $", missing_right_operand], ["% $ a", ""/* not an error */],
		["a % !", ""/* not an error */],  ["% a !", ""/* not an error */],  ["% ! a", missing_left_operand],
		["a % -", missing_right_operand], ["% a -", missing_right_operand], ["% - a", ""/* not an error */],
		["a % *", ""/* not an error */],  ["% a *", ""/* not an error */],  ["% * a", missing_left_operand],
		["a % %", ""/* not an error */],  ["% a %", ""/* not an error */],  ["% % a", ""/* not an error */],
		["a % ~", ""/* not an error */],  ["% a ~", ""/* not an error */],  ["% ~ a", ""/* not an error */],
		["a ~ +", missing_right_operand], ["~ a +", missing_right_operand], ["~ + a", missing_left_operand],
		["a ~ $", missing_right_operand], ["~ a $", missing_right_operand], ["~ $ a", ""/* not an error */],
		["a ~ !", ""/* not an error */],  ["~ a !", ""/* not an error */],  ["~ ! a", missing_left_operand],
		["a ~ -", missing_right_operand], ["~ a -", missing_right_operand], ["~ - a", ""/* not an error */],
		["a ~ *", ""/* not an error */],  ["~ a *", ""/* not an error */],  ["~ * a", missing_left_operand],
		["a ~ %", ""/* not an error */],  ["~ a %", ""/* not an error */],  ["~ % a", ""/* not an error */],
		["a ~ ~", ""/* not an error */],  ["~ a ~", ""/* not an error */],  ["~ ~ a", ""/* not an error */],

		// four operands
		["a 1 b 0", ""/* not an error */],

		// three operands one operator
		["a b c +", missing_right_operand],   ["a b + c", ""/* not an error */],
		["a b c $", missing_right_operand],   ["a b $ c", ""/* not an error */],
		["a b c !", ""/* not an error */],    ["a b ! c", ""/* not an error */],
		["a b c -", missing_right_operand],   ["a b - c", ""/* not an error */],
		["a b c *", ""/* not an error */],    ["a b * c", ""/* not an error */],
		["a b c %", ""/* not an error */],    ["a b % c", ambiguous_juxtaposition],
		["a b c ~", ""/* not an error */],    ["a b ~ c", ""/* not an error */],

		["a + b c", ""/* not an error */],    ["+ a b c", missing_left_operand],
		["a $ b c", ""/* not an error */],    ["$ a b c", ""/* not an error */],
		["a ! b c", ""/* not an error */],    ["! a b c", missing_left_operand],
		["a - b c", ""/* not an error */],    ["- a b c", ""/* not an error */],
		["a * b c", ""/* not an error */],    ["* a b c", missing_left_operand],
		["a % b c", ambiguous_juxtaposition], ["% a b c", ""/* not an error */],
		["a ~ b c", ""/* not an error */],    ["~ a b c", ""/* not an error */],

		// two operands two operators
		["a b + +", missing_right_operand],   ["a + b +", missing_right_operand],
		["a b + $", missing_right_operand],   ["a + b $", missing_right_operand],
		["a b + !", missing_right_operand],   ["a + b !", ""/* not an error */],
		["a b + -", missing_right_operand],   ["a + b -", missing_right_operand],
		["a b + *", missing_right_operand],   ["a + b *", ""/* not an error */],
		["a b + %", missing_right_operand],   ["a + b %", ""/* not an error */],
		["a b + ~", missing_right_operand],   ["a + b ~", ""/* not an error */],
		["a b $ +", missing_right_operand],   ["a $ b +", missing_right_operand],
		["a b $ $", missing_right_operand],   ["a $ b $", missing_right_operand],
		["a b $ !", missing_right_operand],   ["a $ b !", ""/* not an error */],
		["a b $ -", missing_right_operand],   ["a $ b -", missing_right_operand],
		["a b $ *", missing_right_operand],   ["a $ b *", ""/* not an error */],
		["a b $ %", missing_right_operand],   ["a $ b %", ""/* not an error */],
		["a b $ ~", missing_right_operand],   ["a $ b ~", ""/* not an error */],
		["a b ! +", missing_right_operand],   ["a ! b +", missing_right_operand],
		["a b ! $", missing_right_operand],   ["a ! b $", missing_right_operand],
		["a b ! !", ""/* not an error */],    ["a ! b !", ""/* not an error */],
		["a b ! -", missing_right_operand],   ["a ! b -", missing_right_operand],
		["a b ! *", ""/* not an error */],    ["a ! b *", ""/* not an error */],
		["a b ! %", ""/* not an error */],    ["a ! b %", ""/* not an error */],
		["a b ! ~", ""/* not an error */],    ["a ! b ~", ""/* not an error */],
		["a b - +", missing_right_operand],   ["a - b +", missing_right_operand],
		["a b - $", missing_right_operand],   ["a - b $", missing_right_operand],
		["a b - !", missing_right_operand],   ["a - b !", ""/* not an error */],
		["a b - -", missing_right_operand],   ["a - b -", missing_right_operand],
		["a b - *", missing_right_operand],   ["a - b *", ""/* not an error */],
		["a b - %", missing_right_operand],   ["a - b %", ""/* not an error */],
		["a b - ~", missing_right_operand],   ["a - b ~", ""/* not an error */],
		["a b * +", missing_right_operand],   ["a * b +", missing_right_operand],
		["a b * $", missing_right_operand],   ["a * b $", missing_right_operand],
		["a b * !", ""/* not an error */],    ["a * b !", ""/* not an error */],
		["a b * -", missing_right_operand],   ["a * b -", missing_right_operand],
		["a b * *", ""/* not an error */],    ["a * b *", ""/* not an error */],
		["a b * %", ""/* not an error */],    ["a * b %", ""/* not an error */],
		["a b * ~", ""/* not an error */],    ["a * b ~", ""/* not an error */],
		["a b % +", missing_right_operand],   ["a % b +", ambiguous_juxtaposition],
		["a b % $", missing_right_operand],   ["a % b $", ambiguous_juxtaposition],
		["a b % !", ""/* not an error */],    ["a % b !", ambiguous_juxtaposition],
		["a b % -", missing_right_operand],   ["a % b -", ambiguous_juxtaposition],
		["a b % *", ""/* not an error */],    ["a % b *", ambiguous_juxtaposition],
		["a b % %", ""/* not an error */],    ["a % b %", ambiguous_juxtaposition],
		["a b % ~", ""/* not an error */],    ["a % b ~", ambiguous_juxtaposition],
		["a b ~ +", missing_right_operand],   ["a ~ b +", missing_right_operand],
		["a b ~ $", missing_right_operand],   ["a ~ b $", missing_right_operand],
		["a b ~ !", ""/* not an error */],    ["a ~ b !", ""/* not an error */],
		["a b ~ -", missing_right_operand],   ["a ~ b -", missing_right_operand],
		["a b ~ *", ""/* not an error */],    ["a ~ b *", ""/* not an error */],
		["a b ~ %", ""/* not an error */],    ["a ~ b %", ""/* not an error */],
		["a b ~ ~", ""/* not an error */],    ["a ~ b ~", ""/* not an error */],

		["a + + b", no_valid_assignment],     ["+ a b +", missing_left_operand],
		["a + $ b", ""/* not an error */],    ["+ a b $", missing_left_operand],
		["a + ! b", no_valid_assignment],     ["+ a b !", missing_left_operand],
		["a + - b", ""/* not an error */],    ["+ a b -", missing_left_operand],
		["a + * b", no_valid_assignment],     ["+ a b *", missing_left_operand],
		["a + % b", ""/* not an error */],    ["+ a b %", missing_left_operand],
		["a + ~ b", ""/* not an error */],    ["+ a b ~", missing_left_operand],
		["a $ + b", no_valid_assignment],     ["$ a b +", missing_right_operand],
		["a $ $ b", ""/* not an error */],    ["$ a b $", missing_right_operand],
		["a $ ! b", no_valid_assignment],     ["$ a b !", ""/* not an error */],
		["a $ - b", ""/* not an error */],    ["$ a b -", missing_right_operand],
		["a $ * b", no_valid_assignment],     ["$ a b *", ""/* not an error */],
		["a $ % b", ""/* not an error */],    ["$ a b %", ""/* not an error */],
		["a $ ~ b", ""/* not an error */],    ["$ a b ~", ""/* not an error */],
		["a ! + b", ""/* not an error */],    ["! a b +", missing_left_operand],
		["a ! $ b", ""/* not an error */],    ["! a b $", missing_left_operand],
		["a ! ! b", ""/* not an error */],    ["! a b !", missing_left_operand],
		["a ! - b", ""/* not an error */],    ["! a b -", missing_left_operand],
		["a ! * b", ""/* not an error */],    ["! a b *", missing_left_operand],
		["a ! % b", ambiguous_juxtaposition], ["! a b %", missing_left_operand],
		["a ! ~ b", ""/* not an error */],    ["! a b ~", missing_left_operand],
		["a - + b", no_valid_assignment],     ["- a b +", missing_right_operand],
		["a - $ b", ""/* not an error */],    ["- a b $", missing_right_operand],
		["a - ! b", no_valid_assignment],     ["- a b !", ""/* not an error */],
		["a - - b", ""/* not an error */],    ["- a b -", missing_right_operand],
		["a - * b", no_valid_assignment],     ["- a b *", ""/* not an error */],
		["a - % b", ""/* not an error */],    ["- a b %", ""/* not an error */],
		["a - ~ b", ""/* not an error */],    ["- a b ~", ""/* not an error */],
		["a * + b", ""/* not an error */],    ["* a b +", missing_left_operand],
		["a * $ b", ""/* not an error */],    ["* a b $", missing_left_operand],
		["a * ! b", ""/* not an error */],    ["* a b !", missing_left_operand],
		["a * - b", ambiguous_expression],    ["* a b -", missing_left_operand],
		["a * * b", ""/* not an error */],    ["* a b *", missing_left_operand],
		["a * % b", ""/* not an error */],    ["* a b %", missing_left_operand],
		["a * ~ b", ambiguous_expression],    ["* a b ~", missing_left_operand],
		["a % + b", ""/* not an error */],    ["% a b +", missing_right_operand],
		["a % $ b", ambiguous_juxtaposition], ["% a b $", missing_right_operand],
		["a % ! b", ""/* not an error */],    ["% a b !", ""/* not an error */],
		["a % - b", ""/* not an error */],    ["% a b -", missing_right_operand],
		["a % * b", ""/* not an error */],    ["% a b *", ""/* not an error */],
		["a % % b", ambiguous_juxtaposition], ["% a b %", ""/* not an error */],
		["a % ~ b", ""/* not an error */],    ["% a b ~", ""/* not an error */],
		["a ~ + b", ""/* not an error */],    ["~ a b +", missing_right_operand],
		["a ~ $ b", ""/* not an error */],    ["~ a b $", missing_right_operand],
		["a ~ ! b", ""/* not an error */],    ["~ a b !", ""/* not an error */],
		["a ~ - b", ambiguous_expression],    ["~ a b -", missing_right_operand],
		["a ~ * b", ""/* not an error */],    ["~ a b *", ""/* not an error */],
		["a ~ % b", ""/* not an error */],    ["~ a b %", ""/* not an error */],
		["a ~ ~ b", ambiguous_expression],    ["~ a b ~", ""/* not an error */],

		["+ a + b", missing_left_operand],    ["+ + a b", missing_left_operand],
		["+ a $ b", missing_left_operand],    ["+ $ a b", missing_left_operand],
		["+ a ! b", missing_left_operand],    ["+ ! a b", missing_left_operand],
		["+ a - b", missing_left_operand],    ["+ - a b", missing_left_operand],
		["+ a * b", missing_left_operand],    ["+ * a b", missing_left_operand],
		["+ a % b", missing_left_operand],    ["+ % a b", missing_left_operand],
		["+ a ~ b", missing_left_operand],    ["+ ~ a b", missing_left_operand],
		["$ a + b", ""/* not an error */],    ["$ + a b", missing_left_operand],
		["$ a $ b", ""/* not an error */],    ["$ $ a b", ""/* not an error */],
		["$ a ! b", ""/* not an error */],    ["$ ! a b", missing_left_operand],
		["$ a - b", ""/* not an error */],    ["$ - a b", ""/* not an error */],
		["$ a * b", ""/* not an error */],    ["$ * a b", missing_left_operand],
		["$ a % b", ambiguous_juxtaposition], ["$ % a b", ""/* not an error */],
		["$ a ~ b", ""/* not an error */],    ["$ ~ a b", ""/* not an error */],
		["! a + b", missing_left_operand],    ["! + a b", missing_left_operand],
		["! a $ b", missing_left_operand],    ["! $ a b", missing_left_operand],
		["! a ! b", missing_left_operand],    ["! ! a b", missing_left_operand],
		["! a - b", missing_left_operand],    ["! - a b", missing_left_operand],
		["! a * b", missing_left_operand],    ["! * a b", missing_left_operand],
		["! a % b", missing_left_operand],    ["! % a b", missing_left_operand],
		["! a ~ b", missing_left_operand],    ["! ~ a b", missing_left_operand],
		["- a + b", ""/* not an error */],    ["- + a b", missing_left_operand],
		["- a $ b", ""/* not an error */],    ["- $ a b", ""/* not an error */],
		["- a ! b", ""/* not an error */],    ["- ! a b", missing_left_operand],
		["- a - b", ""/* not an error */],    ["- - a b", ""/* not an error */],
		["- a * b", ""/* not an error */],    ["- * a b", missing_left_operand],
		["- a % b", ambiguous_juxtaposition], ["- % a b", ""/* not an error */],
		["- a ~ b", ""/* not an error */],    ["- ~ a b", ""/* not an error */],
		["* a + b", missing_left_operand],    ["* + a b", missing_left_operand],
		["* a $ b", missing_left_operand],    ["* $ a b", missing_left_operand],
		["* a ! b", missing_left_operand],    ["* ! a b", missing_left_operand],
		["* a - b", missing_left_operand],    ["* - a b", missing_left_operand],
		["* a * b", missing_left_operand],    ["* * a b", missing_left_operand],
		["* a % b", missing_left_operand],    ["* % a b", missing_left_operand],
		["* a ~ b", missing_left_operand],    ["* ~ a b", missing_left_operand],
		["% a + b", ""/* not an error */],    ["% + a b", missing_left_operand],
		["% a $ b", ""/* not an error */],    ["% $ a b", ""/* not an error */],
		["% a ! b", ""/* not an error */],    ["% ! a b", missing_left_operand],
		["% a - b", ""/* not an error */],    ["% - a b", ""/* not an error */],
		["% a * b", ""/* not an error */],    ["% * a b", missing_left_operand],
		["% a % b", ambiguous_juxtaposition], ["% % a b", ""/* not an error */],
		["% a ~ b", ""/* not an error */],    ["% ~ a b", ""/* not an error */],
		["~ a + b", ""/* not an error */],    ["~ + a b", missing_left_operand],
		["~ a $ b", ""/* not an error */],    ["~ $ a b", ""/* not an error */],
		["~ a ! b", ""/* not an error */],    ["~ ! a b", missing_left_operand],
		["~ a - b", ""/* not an error */],    ["~ - a b", ""/* not an error */],
		["~ a * b", ""/* not an error */],    ["~ * a b", missing_left_operand],
		["~ a % b", ambiguous_juxtaposition], ["~ % a b", ""/* not an error */],
		["~ a ~ b", ""/* not an error */],    ["~ ~ a b", ""/* not an error */],
	];

	runUnitTests!(test_input => collectExceptionMsg(parseInfixExpression(infix_operators, prefix_operators,
													postfix_operators, initiators, separators, terminators, test_input))
	)(test_cases ~ common_test_cases);
} // end unittest
