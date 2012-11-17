import std.stdio, std.string, std.array, std.algorithm;
import Expressions;


void main()
{
	immutable string[] operators = ["+","-","*","/","%"];
	Expression[] stack;
	
	writeln("Type in a line of text and press enter. (Type ctrl+z and enter to exit)");
	write("<< ");
	
	foreach(line; stdin.byLine())
	{
		// parse input line
		foreach(token; std.array.splitter(line))
		{
			if(find(operators,token)==[]) // not an operator
			{
				stack ~= new LiteralOperand(token.idup);
			}
			else
			{
				auto right = stack.back();
				stack.popBack();
				auto left = stack.back();
				stack.popBack();
				stack ~= new BinaryOperator(token.idup,left,right);
			} // end else
		} // end foreach
		// print output line
		writeln(">> ",stack.back().serialize());
		// prepare for new input
		write("<< ");
	} // end foreach
} // end function main