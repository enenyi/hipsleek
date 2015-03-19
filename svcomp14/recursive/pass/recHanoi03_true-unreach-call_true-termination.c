extern void __VERIFIER_error() __attribute__ ((__noreturn__));

/*
 * recHanoi.c
 *
 *  Created on: 17.07.2013
 *      Author: Stefan Wissert
 */

extern int __VERIFIER_nondet_int(void);

/*
 * This function returns the optimal amount of steps,
 * needed to solve the problem for n-disks
 */
int hanoi(int n)
/*@
  infer [@post_n]
  requires true
  ensures true;
 */
{
    if (n == 1) {
		return 1;
	}
	return 2 * (hanoi(n-1)) + 1;
}

// Expect SUCCESS
// Return SUCCESS

int main()
/*@
  requires true
  ensures res!=1;
*/
{
    int n = __VERIFIER_nondet_int();
    if (n < 1 || n > 31) {
    	return 0;
    }
    int result = hanoi(n);
    if (result >= n) {
        return 0;
    } else {
      return 1;
      //ERROR: __VERIFIER_error();
    }
}


