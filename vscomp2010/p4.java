/**
 Problem 4 in VSComp 2010: N-Queens
 @author Vu An Hoa
 @date 24/06/2011
 **/

/** RELATIONS **/

//Queens i & j are not attacking each other
relation AreNotAttackingQueens(int[] b, int i, int j) == 
	(i = j | b[j] != b[i] & b[j] - b[i] != j - i & b[j] - b[i] != i - j).

// Queen i is safe with respect to other queens
relation IsSafeQueen(int[] b, int i) ==
	forall(j : (j < 1 | j >= i | AreNotAttackingQueens(b,i,j))).

// Board b[1..n] is consistent if and only if every queen is safe.
relation IsConsistent(int[] b, int n) ==
	forall(i : (i < 1 | i > n | IsSafeQueen(b,i))).

// DIFFICULT TO WRITE!!!
relation NoSolution(int n) == true.

/** FUNCTIONS **/

// Solve n-queens
// @return 	false if there is no solution
// 			true if there is a solution; in such case, the resulting 
//					array b gives a valid solution
bool nQueens(ref int[] b, int n)
	requires dom(b,1,n)
	ensures (res & IsConsistent(b',n) | !res & NoSolution(n));
{
	return nQueensHelper(b, n, 1);
}

// Back-tracking search algorithm
bool nQueensHelper(ref int[] b, int n, int i)
	requires dom(b,1,n) & 1 <= i <= n+1 & IsConsistent(b,i-1)
	ensures (res & IsConsistent(b',n) | !res & NoSolution(n));
{
	if (i == n + 1) // nothing more to search!
		return true;
	else
		return nQueensHelperHelper(b, n, i, 1);
	// 67357
}

bool nQueensHelperHelper(ref int[] b, int n, int i, int j)
	requires dom(b,1,n) & IsConsistent(b,i-1)
	ensures (res & IsConsistent(b',n) | !res & NoSolution(n));
{
	if (j <= n) {
		b[i] = j; // try putting a queen at (i,j)
		if (IsSafe(b,n,i)) {
			if (nQueensHelper(b,n,i+1)) // safe ==> try the next queen
				return true;
			else // cannot find solution by putting queen at (i,j)
				return nQueensHelperHelper(b, n, i, j + 1);
		}
	}
	// call when j > n i.e. j = n+1 or when (i,j) is not a safe position
	return false;
}

bool IsSafe(int[] b, int n, int i)
	requires dom(b,1,n) & 1 <= i <= n & IsConsistent(b,i-1)
	ensures  (!res | res & IsConsistent(b,i));
/*{
	int j = 1;
	bool result = true;
	while (j < i) 
		requires true
		ensures (!result' | result' & IsConsistent(b,n,i));
	{
		int h = b[i] - b[j];
		if (h == 0 || h == i - j || h == j - i) {
			result = false;
			break;
		}
		j = j + 1;
	}
	return result;
}*/

/*bool IsSafeHelper(int[] b, int n, int i)
	requires dom(b,0,n-1) & 0 <= i <= n-1 & IsConsistent(b,i-1)
	ensures  (!res | res & IsConsistent(b,i));*/
