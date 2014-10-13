/*
 * Date: 2012-06-03
 * Author: heizmann@informatik.uni-freiburg.de
 *
 * 2-lex ranking function: f(p, q, *q) = (q, *q)
 *
 */
#include "stdhip2.h"

extern int __VERIFIER_nondet_int(void);

int main() {
	int *p = malloc(1048 * sizeof(int));
	int *q = p;
  //@ dprint;
	while (*q >= 0 && q < p + 1048) 
  /*@
    requires p::int*<_, op, sp> * q::int*<vq, oq, sq>
    ensures true;
   */
	{
		if (__VERIFIER_nondet_int()) {
			q++;
		} else {
			(*q)--;
		}
	}
	return 0;
}
