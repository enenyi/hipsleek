/* Last-Edit:  Wed May 7 10:12:52 1993 by Monica; */
//#include <stdio.h>

/* A job descriptor. */

//#define NULL 0


//#define NEW_JOB        1
//#define UPGRADE_PRIO   2 
//#define BLOCK          3
//#define UNBLOCK        4  
//#define QUANTUM_EXPIRE 5
//#define FINISH         6
//#define FLUSH          7

//#define MAXPRIO 3

//typedef struct _job {
//    struct  _job *next, *prev; /* Next and Previous in job list. */
//    int          val  ;         /* Id-value of program. */
//    short        priority;     /* Its priority. */
//} Ele, *Ele_Ptr;

data node {
	int val;
    int priority;
    node next;
}

//typedef struct list		/* doubly linked list */
//{
//  Ele *first;
//  Ele *last;
//  int    mem_count;		/* member count */
//} List;

ll1<n,S> == self=null & n=0 & S={}
  or self::node<v, _, q> * q::ll1<n-1,S1> & S=union(S1,{v})
	inv n>=0;

lseg1<p, n,S> == self=p & n=0 & S={}
  or self::node<v,_, q> * q::lseg1<p, n-1,S1> & S=union(S1,{v})
	inv n>=0;

lemma self::ll1<n,S> <-> self::lseg1<null,n,S>;
lemma self::lseg1<p,n,S> * p::node<v,_, q>  -> self::lseg1<q,n+1,S1> & S1=union(S,{v});
lemma "V2" self::lseg1<p,n,S> & n = a + b & S=union(S1,S2) & a,b >=0 <-> self::lseg1<r,a,S1> * r::lseg1<p,b,S2>;

node get_first(node x)
  requires x::ll1<n,S>
  ensures x::ll1<n,S> & res=x;
{
  return x;
}

node get_first_seg(node x)
  requires x::lseg1<q,n,S>
  ensures x::lseg1<q, n,S> & res=x;
{
  return x;
}

int get_mem_count(node x)
  requires x::ll1<n,S>
  ensures  x::ll1<n,S> & res=n;

/*-----------------------------------------------------------------------------
  new_ele
     alloates a new element with value as num.
-----------------------------------------------------------------------------*/
node new_ele(int new_num)
  requires true
  ensures res::node<new_num, 0,null>;
{
  return new node(new_num, 0, null);
}

/*-----------------------------------------------------------------------------
  new_list
        allocates, initializes and returns a new list.
        Note that if the argument compare() is provided, this list can be
            made into an ordered list. see insert_ele().
-----------------------------------------------------------------------------*/
node new_list()
  requires true
  ensures res=null;

/*-----------------------------------------------------------------------------
  append_ele
        appends the new_ele to the list. If list is null, a new
	list is created. The modified list is returned.
insert at the tail
-----------------------------------------------------------------------------*/
node append_ele(ref node x, node a, int prio)
  requires x::ll1<n,S> * a::node<v1,v2,null> & v2=prio
  ensures x'::lseg1<a,n,S> * a::node<v1,v2,null> & res=x';

/*-----------------------------------------------------------------------------
  find_nth
        fetches the nth element of the list (count starts at 1)
 -----------------------------------------------------------------------------*/
node find_nth_helper(node l, int j)
  requires l::lseg1<p,n,S> & n>=j & j>=1
  ensures res::lseg1<p,m,S1> * l::lseg1<res,j-1,S2>  & (m=n-j+1) & S = union(S1,S2)
  & res!=null;
{
  if (j>1){
    node r2=find_nth_helper(l.next, j-1);
    return r2;
  }
  else {
     return l;
  }
}

node find_nth(node f_list, int j)
  requires f_list::ll1<n,S> & n>=j & j>=1
  ensures f_list::lseg1<res,j-1,S1> * res::node<v,_,q>
  * q::ll1<n-j,S2> & S=union(S1,{v},S2);
{
  node f_ele;

  f_ele = get_first_seg(f_list);
  f_ele = find_nth_helper(f_ele,j);
  return f_ele;
}

node find_nth2(node f_list, int j)
  requires  f_list::ll1<n,S> & j>=1 & n>=1
 case {
  j <= n -> ensures (exists q: f_list::lseg1<res,j-1,S1> * res::node<v,v2,q> * q::ll1<n-j,S2> & v2>=1 & v2<=3 & S=union(S1,{v},S2));
  j > n -> ensures f_list::ll1<n,S> & res=null;
}


/*-----------------------------------------------------------------------------
  del_ele
        deletes the old_ele from the list.
        Note: even if list becomes empty after deletion, the list
	      node is not deallocated.
-----------------------------------------------------------------------------*/
node del_ele(ref node x, node ele)
  requires (exists j,q: x::lseg1<ele,j,S1> * ele::node<v1,v2,q> * q::ll1<m,S2>) 
  ensures x'::lseg1<q,j,S1> * q::ll1<m,S2> * ele::node<v1,v2,q>& v2 >=1 & v2 <= 3 & res=x';


/*-----------------------------------------------------------------------------
   free_ele
       deallocate the ptr. Caution: The ptr should point to an object
       allocated in a single call to malloc.
-----------------------------------------------------------------------------*/
void free_ele(ref node ptr)
  requires ptr::node<_,_,_>
  ensures ptr'= null;
{
    ptr = null;
}

global int alloc_proc_num;
global int num_processes;
//Ele* cur_proc;
global node cur_proc;
//List *prio_queue[/*MAXPRIO*/3+1]; 	/* 0th element unused */
global node prio_queue1;
global node prio_queue2;
global node prio_queue3;
//List *block_queue;
global node block_queue;


void finish_process1(ref node pq1,ref node pq2,ref node pq3, ref node cur_proc, ref int num_processes)
  requires  pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> * cur_proc::ll1<n,S>
 case{
  n3 > 0 ->
    ensures  pq1'::ll1<n1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3-1,S6> & cur_proc' = null & num_processes' = num_processes -1;
  n3<=0 -> case {
      n2>0 -> ensures pq1'::ll1<n1,S4> * pq3'::ll1<n3,S6> * pq2'::ll1<n2-1,S5> & cur_proc' = null & num_processes' = num_processes -1;
  n2<=0 -> case{
    n1>0 -> ensures pq3'::ll1<n3,S6> * pq2'::ll1<n2,S5> * pq1'::ll1<n1-1,S4> & cur_proc' = null & num_processes' = num_processes -1;
        n1<=0 -> ensures pq1'=null &  pq2'= null & pq3'= null & cur_proc' = null & num_processes' = num_processes;
      }
    }
}

void finish_process(ref node pq1,ref node pq2,ref node pq3, ref node cur_proc, ref int num_processes)
  requires  pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> * cur_proc::ll1<n,S>
 case{
  n3 > 0 ->
    ensures  pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2> * pq3'::ll1<n3-1,S6> & cur_proc' = null & num_processes' = num_processes -1 & S6 subset S3;
  n3<=0 -> case {
      n2>0 -> ensures pq1'::ll1<n1,S1> * pq3'::ll1<n3,S3> * pq2'::ll1<n2-1,S5> & cur_proc' = null & num_processes' = num_processes -1 & S5 subset S2;
  n2<=0 -> case{
    n1>0 -> ensures pq3'::ll1<n3,S3> * pq2'::ll1<n2,S2> * pq1'::ll1<n1-1,S4> & cur_proc' = null & num_processes' = num_processes -1 & S4 subset S1;
        n1<=0 -> ensures pq1'=null &  pq2'= null & pq3'= null & cur_proc' = null & num_processes' = num_processes;
      }
    }
}
{
    schedule1();
    if (cur_proc != null)
    {
      free_ele(cur_proc);
      num_processes--;
    }
}

void schedule1(ref node cur_proc, ref node pq1, ref node pq2,ref node pq3)
  requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> * cur_proc::ll1<n,S>
 case{
  n3 > 0 ->
    ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2> * pq3'::ll1<n3-1,S6> * cur_proc'::node<v,_,null> & S3=union(S6,{v});
  n3<=0 -> case {
    n2>0 -> ensures  pq1'::ll1<n1,S1> * pq3'::ll1<n3,S3> * pq2'::ll1<n2-1,S5> * cur_proc'::node<v,_,null> & S2=union(S5,{v});
    n2<=0 -> case{
      n1>0 -> ensures pq3'::ll1<n3,S3> * pq2'::ll1<n2,S2> * pq1'::ll1<n1-1,S4> * cur_proc'::node<v,_,null> & S1=union(S4,{v});
      n1<=0 -> ensures pq1'=null &  pq2'= null & pq3'= null & cur_proc' = null;
    }
  }
}

void schedule(ref node cur_proc, ref node pq1, ref node pq2,ref node pq3)
  requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> * cur_proc::ll1<n,S>
 case{
  n3 > 0 ->
    ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2> * pq3'::ll1<n3-1,S6> * cur_proc'::node<v,_,null> & S3=union(S6,{v});
  n3<=0 -> case {
    n2>0 -> ensures  pq1'::ll1<n1,S1> * pq3'::ll1<n3,S3> * pq2'::ll1<n2-1,S5> * cur_proc'::node<v,_,null> & S2=union(S5,{v});
    n2<=0 -> case{
      n1>0 -> ensures pq3'::ll1<n3,S3> * pq2'::ll1<n2,S2> * pq1'::ll1<n1-1,S4> * cur_proc'::node<v,_,null> & S1=union(S4,{v});
      n1<=0 -> ensures pq1'=null &  pq2'= null & pq3'= null & cur_proc' = null;
    }
  }
}
{
    int n;
    cur_proc = null;
    n = get_mem_count(pq3);
    if (n > 0){
      cur_proc = find_nth2(pq3, 1);
      cur_proc.next = null;
      pq3 = del_ele(pq3,  cur_proc);
      return;
    }
    n = get_mem_count(pq2);
    if (n > 0){
      cur_proc = find_nth(pq2, 1);
      cur_proc.next = null;
      pq2 = del_ele(pq2, cur_proc);
      return;
    }
    n = get_mem_count(pq1);
    if (n > 0){
      cur_proc = find_nth(pq1, 1);
      cur_proc.next = null;
      pq1 = del_ele(pq1,  cur_proc);
      return;
    }
}

void do_upgrade_process_prio1(int prio, int ratio, ref node pq1, ref node pq2)
  requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> & ratio >=1
 case {
  n1 > 0 ->  case {
    ratio <= n1  -> ensures pq1'::ll1<n1-1,S3> * pq2'::ll1<n2+1,S4> & union(S1,S2) = union(S3,S4);
    ratio > n1 -> ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2>;
  }
  n1 <= 0 -> ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2>;
}

relation DUG1(bag a, bag b, bag c, bag d).
relation DUG2(bag a, bag b, bag c, bag d).
relation DUG3(bag a, bag b, bag c, bag d).
void do_upgrade_process_prio(int prio, int ratio, ref node pq1, ref node pq2)
 requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> & ratio >=1
 case {
  n1 > 0 ->  case {
    ratio <= n1  -> ensures pq1'::ll1<n1-1,S3> * pq2'::ll1<n2+1,S4> & union(S1,S2) = union(S3,S4);
    ratio > n1 -> ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2>;
  }
  n1 <= 0 -> ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2>;
}
{
  int count;
  int n;
  node proc;
  count = get_mem_count(pq1) ;
  if (count > 0)
    {
      n = ratio;
      proc = find_nth2(pq1, n);
      if (proc != null) {
        proc.next = null;
        pq1 = del_ele(pq1, proc);
        proc.priority = prio;
        pq2 = append_ele(pq2, proc, prio);
      }
    }
}

void upgrade_process_prio1(int prio, int ratio, ref node pq1, ref node pq2, ref node pq3)
  requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> & prio>0 & prio <=3 & ratio >=1
 case {
  prio = 1 -> case {
    n1 > 0 ->  case {
      ratio <= n1  -> ensures pq1'::ll1<n1-1,S4> * pq2'::ll1<n2+1,S5> * pq3'::ll1<n3,S3> & union(S1,S2)=union(S4,S5);
      ratio > n1 -> ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2> * pq3'::ll1<n3,S3>;
      }
    n1 <= 0 -> ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2> * pq3'::ll1<n3,S3>;
  }
  prio = 2 -> case {
      n2 > 0 -> case {
      ratio <= n2 -> ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2-1,S5> * pq3'::ll1<n3+1,S6> & union(S3,S2)=union(S6,S5);
    ratio > n2 -> ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2> * pq3'::ll1<n3,S3>;
       }
      n2 <= 0 -> ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2> * pq3'::ll1<n3,S3>;
  }
  prio <1 | prio >2 -> ensures pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2> * pq3'::ll1<n3,S3>; 
}

relation UG1(bag a, bag b, bag c, bag a1, bag a2, bag a3).
relation UG2(bag a, bag b, bag c, bag a1, bag a2, bag a3).
relation UG3(bag a, bag b, bag c, bag a1, bag a2, bag a3).
relation UG4(bag a, bag b, bag c, bag a1, bag a2, bag a3).
relation UG5(bag a, bag b, bag c, bag a1, bag a2, bag a3).
relation UG6(bag a, bag b, bag c, bag a1, bag a2, bag a3).
relation UG7(bag a, bag b).
relation UG8(bag a, bag b).
relation UG9(bag a, bag b).
void upgrade_process_prio(int prio, int ratio, ref node pq1, ref node pq2, ref node pq3)
  infer [UG1,UG2, UG3, UG4,UG5,UG6,UG7,UG8,UG9]
  requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> & prio>0 & prio <=3 & ratio >=1
 case {
  prio = 1 -> case {
    n1 > 0 ->  case {
      ratio <= n1  -> ensures pq1'::ll1<n1-1,S4> * pq2'::ll1<n2+1,S5> * pq3'::ll1<n3,S6> & UG1(S1,S2,S3,S4,S5,S6);
      ratio > n1 -> ensures pq1'::ll1<n1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3,S6>  & UG3(S1,S2,S3,S4,S5,S6);
      }
    n1 <= 0 -> ensures pq1'::ll1<n1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3,S6> & UG4(S1,S2,S3,S4,S5,S6);
  }
  prio = 2 -> case {
      n2 > 0 -> case {
      ratio <= n2 -> ensures pq1'::ll1<n1,S4> * pq2'::ll1<n2-1,S5> * pq3'::ll1<n3+1,S6> & UG2(S1,S2,S3,S4,S5,S6);
    ratio > n2 -> ensures pq1'::ll1<n1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3,S6> & UG5(S1,S2,S3,S4,S5,S6);
       }
      n2 <= 0 -> ensures pq1'::ll1<n1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3,S6> & UG6(S1,S2,S3,S4,S5,S6);
  }
  prio <1 | prio >2 -> ensures pq1'::ll1<n1,S01> * pq2'::ll1<n2,S02> * pq3'::ll1<n3,S03> & UG7(S01,S1) & UG8(S02,S2) & UG9(S03,S3); 
}
{
    int count;
    int n;
    node proc;
    node src_queue, dest_queue;

       if (prio >= /*MAXPRIO*/3)
         return;
        if (prio == 1) {
          do_upgrade_process_prio1(prio, ratio, pq1, pq2);
        }
        else if (prio == 2) {
          do_upgrade_process_prio1(prio, ratio, pq2, pq3);
        }
}

void unblock_process1(int ratio, ref node bq, ref node pq1, ref node pq2, ref node pq3)
  requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> & ratio >=1
  case {
  bq != null -> requires bq::ll1<m,S0> & m >0
 case{
    ratio <= m -> ensures bq'::ll1<m-1,S01> * pq1'::ll1<n4,S4> * pq2'::ll1<n5,S5> * pq3'::ll1<n6,S6> & n4+n5+n6=n1+n2+n3+1
      & S01 subset S0;
    ratio > m -> ensures true;
  }
  bq=null -> ensures pq1'::ll1<n1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3,S6> & bq'=null;//
 }

void unblock_process(int ratio, ref node bq, ref node pq1, ref node pq2, ref node pq3)
  requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> & ratio >=1
  case {
  bq != null -> requires bq::ll1<m,S0> & m >0
 case{
    ratio <= m -> ensures bq'::ll1<m-1,S01> * pq1'::ll1<n4,S4> * pq2'::ll1<n5,S5> * pq3'::ll1<n6,S6> & n4+n5+n6=n1+n2+n3+1
      & S01 subset S0;
    ratio > m -> ensures true;
  }
  bq=null -> ensures pq1'::ll1<n1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3,S6> & bq'=null;//
 }
{
    int count;
    int n;
    node proc;
    int prio;
    if (bq != null)
    {
      count = get_mem_count(bq);
      n = ratio;
      proc = find_nth2(bq, n);
      if (proc != null) {
	    /* append to appropriate prio queue */
	    prio = proc.priority;
        if (prio == 1){
          bq = del_ele(bq, proc);
          proc.next = null;
          pq1 = append_ele(pq1, proc, prio);}
        else if (prio == 2){
          bq = del_ele(bq, proc);
          proc.next = null;
          pq2 = append_ele(pq2, proc, prio);}
        else if (prio == 3){
          bq = del_ele(bq, proc);
          proc.next = null;
          pq3 = append_ele(pq3, proc,prio);}
      }
    }
}

void quantum_expire1(ref node cur_proc, ref node pq1, ref node pq2, ref node pq3)
  requires cur_proc::ll1<n,S0> * pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3>
 case {
  n1+n2+n3>0 -> ensures  true;
  n1+n2+n3<=0 -> ensures true;
}
{
    int prio;
    schedule1(cur_proc, pq1, pq2,pq3);
    if (cur_proc != null)
    {
      prio = cur_proc.priority;
       if (prio == 1)
         pq1 = append_ele(pq1, cur_proc, prio);
        if (prio == 2)
          pq2 = append_ele(pq2, cur_proc, prio);
        if (prio == 3)
          pq3 = append_ele(pq3, cur_proc, prio);
    }
}

void block_process1(ref node cur_proc, ref node block_queue, ref node pq1, ref node pq2, ref node pq3)
  requires cur_proc::ll1<n,S01> * block_queue::ll1<n,S02> * pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3>
 case {
  n1+n2+n3 > 0 -> ensures block_queue'::ll1<n+1,S021> * pq1'::ll1<n4,S4> * pq2'::ll1<n5,S5> * pq3'::ll1<n6,S6> &
    n1+n2+n3=n4+n5+n6+1 & S02 subset S021 & cur_proc'!=null;
  n1+n2+n3 <= 0 -> ensures block_queue'::ll1<n,S02> * pq1'::ll1<n1,S1> * pq2'::ll1<n2,S2> * pq3'::ll1<n3,S3> & cur_proc' = null;
}

relation BP1(bag a, bag b).
relation BP2(bag a, bag b).
relation BP3(bag a, bag b).
relation BP4(bag a, bag b).
relation BP5(bag a, bag b).
void block_process(ref node cur_proc, ref node block_queue, ref node pq1, ref node pq2, ref node pq3)
  infer [BP1,BP2,BP3,BP4,BP5]
  requires cur_proc::ll1<n,S01> * block_queue::ll1<n,S02> * pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3>
 case {
  n1+n2+n3 > 0 -> ensures block_queue'::ll1<n+1,S021> * pq1'::ll1<n4,S4> * pq2'::ll1<n5,S5> * pq3'::ll1<n6,S6> &
    n1+n2+n3=n4+n5+n6+1 & BP1(S02,S021) & cur_proc'!=null;
 n1+n2+n3 <= 0 -> ensures block_queue'::ll1<n,S021> * pq1'::ll1<n1,S11> * pq2'::ll1<n2,S21> * pq3'::ll1<n3,S31> & cur_proc' = null
  & BP2(S021,S02) & BP3(S11,S1) & BP4(S21,S2) & BP5(S31,S3);
}
{
    schedule1(cur_proc, pq1, pq2,pq3);
    if (cur_proc != null)
    {
      block_queue = append_ele(block_queue, cur_proc, cur_proc.priority);
    }
}

node new_process(int prio, ref int alloc_proc_num, ref int num_processes)
  requires prio>0 & prio<=3
  ensures res::node<alloc_proc_num+1, prio, null>
  & (num_processes'= num_processes+1) &
             (alloc_proc_num' = alloc_proc_num+1);
{
    node proc;
    alloc_proc_num = alloc_proc_num + 1;
    proc = new_ele(alloc_proc_num);
    proc.priority = prio;
    num_processes++;
    return proc;
}

void add_process1(int prio, ref int alloc_proc_num, ref int num_processes, ref node pq1, ref node pq2, ref node pq3)
    requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> & prio>0 & prio<=3
     case {
      prio = 1 -> ensures  pq1'::ll1<n1+1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3,S6> & (num_processes'= num_processes+1) &
             (alloc_proc_num' = alloc_proc_num+1) & S5=S2 & S6=S3 & S4=union(S1, {alloc_proc_num+1});
    prio = 2 -> ensures  pq1'::ll1<n1,S4> * pq2'::ll1<n2+1,S5> * pq3'::ll1<n3,S6> & (num_processes'= num_processes+1) &
             (alloc_proc_num' = alloc_proc_num+1)& S4=S1 & S6=S3 & S5=union(S2, {alloc_proc_num+1});
              prio = 3 -> ensures  pq1'::ll1<n1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3+1,S6> & (num_processes'= num_processes+1) &
             (alloc_proc_num' = alloc_proc_num+1) & S4=S1 & S5=S2 & S6=union(S3, {alloc_proc_num+1});
    prio <= 0 | prio >3 -> ensures pq1'=pq1 & pq2'=pq2 & pq3'=pq3 & (num_processes'= num_processes) &
             (alloc_proc_num' = alloc_proc_num) & flow __error;
 }

relation AP1(bag a1, bag b1, bag c1, bag a2, bag b2, bag c2, int d).
relation AP2(bag a1, bag b1, bag c1, bag a2, bag b2, bag c2, int d).
relation AP3(bag a1, bag b1, bag c1, bag a2, bag b2, bag c2, int d).
void add_process(int prio, ref int alloc_proc_num, ref int num_processes, ref node pq1, ref node pq2, ref node pq3)
    infer [AP1,AP2,AP3]
    requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> & prio>0 & prio<=3
     case {
      prio = 1 -> ensures  pq1'::ll1<n1+1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3,S6> & (num_processes'= num_processes+1) &
             (alloc_proc_num' = alloc_proc_num+1) & AP1(S1,S2,S3,S4,S5,S6,alloc_proc_num);
    prio = 2 -> ensures  pq1'::ll1<n1,S4> * pq2'::ll1<n2+1,S5> * pq3'::ll1<n3,S6> & (num_processes'= num_processes+1) &
             (alloc_proc_num' = alloc_proc_num+1)& AP2(S1,S2,S3,S4,S5,S6,alloc_proc_num);
              prio = 3 -> ensures  pq1'::ll1<n1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3+1,S6> & (num_processes'= num_processes+1) &
             (alloc_proc_num' = alloc_proc_num+1) & AP3(S1,S2,S3,S4,S5,S6,alloc_proc_num);
    prio <= 0 | prio >3 -> ensures pq1'=pq1 & pq2'=pq2 & pq3'=pq3 & (num_processes'= num_processes) &
             (alloc_proc_num' = alloc_proc_num) & flow __error;
 }
{
    node proc;
    if (prio == 1){
       proc = new_process(prio,alloc_proc_num, num_processes);
       pq1 = append_ele(pq1, proc, proc.priority);
    }
    if (prio == 2){
      proc = new_process(prio,alloc_proc_num, num_processes);
      pq2 = append_ele(pq2, proc, proc.priority);
    }
    if (prio == 3){
       proc = new_process(prio,alloc_proc_num, num_processes);
       pq3 = append_ele(pq3, proc, proc.priority);
    }
}

node init_prio_queue_helper1(node queue,int prio,int i,int n)
  requires queue::ll1<i,S1> & prio>0 & prio<=3 & n >= 0 & i<=n
  ensures res::ll1<n,S3>;
{
  node proc;
  if (i >= n) return queue;
  proc = new_process(prio, alloc_proc_num, num_processes);
  queue = append_ele(queue, proc,prio);
  i = i+1;
  return init_prio_queue_helper1(queue, prio, i, n);
}

void init_prio_queue(int prio, int num_proc, ref node pq1, ref node pq2, ref node pq3)
         requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> & prio>0 & prio<=3 & num_proc>=0
  case {
           prio = 1 -> ensures pq1'::ll1<num_proc,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<n3,S6> ;
  prio = 2 -> ensures pq1'::ll1<n1,S4> * pq2'::ll1<num_proc,S5> * pq3'::ll1<n3,S6> ;
                                         prio = 3 -> ensures pq1'::ll1<n1,S4> * pq2'::ll1<n2,S5> * pq3'::ll1<num_proc,S6> ;
  prio <= 0 | prio >3 -> ensures true;
}
{
    node queue = null;
    int i;

    i = 0;
    queue = init_prio_queue_helper1(queue, prio, i, num_proc);
     if (prio == 1)
      pq1 = queue;
    if (prio == 2)
      pq2 = queue;
    if (prio == 3)
      pq3 = queue;
}

void initialize()
  requires true
  ensures alloc_proc_num' = 0 & num_processes' = 0;
{
    alloc_proc_num = 0;
    num_processes = 0;
}

void main_helper(int i, int maxprio, ref node pq1, ref node pq2, ref node pq3)
  requires pq1::ll1<n1,S1> * pq2::ll1<n2,S2> * pq3::ll1<n3,S3> & i >= 0 & i <= maxprio & maxprio = 3
  ensures (exists n4,n5,n6: pq1'::ll1<n4,S4> * pq2'::ll1<n5,S5> * pq3'::ll1<n6,S6>);
{
  if (i>=1){
    init_prio_queue(i, 7, pq1, pq2, pq3);
    i = i -1;
    main_helper(i, maxprio, pq1, pq2, pq3);
  }
}

void main(int argc)
           requires prio_queue1::ll1<n1,S1> * prio_queue2::ll1<n2,S2> * prio_queue3::ll1<n3,S3>
  ensures true;
{
    int command;
    int prio;
    
      initialize();
      prio = 3;
      main_helper(prio, 3, prio_queue1, prio_queue2, prio_queue3);
}


/* A simple input spec:
  
  a.out n3 n2 n1

  where n3, n2, n1 are non-negative integers indicating the number of
  initial processes at priority 3, 2, and 1, respectively.

  The input file is a list of commands of the following kinds:
   (For simplicity, comamnd names are integers (NOT strings)
    
  FINISH            ;; this exits the current process (printing its number)
  NEW_JOB priority  ;; this adds a new process at specified priority
  BLOCK             ;; this adds the current process to the blocked queue
  QUANTUM_EXPIRE    ;; this puts the current process at the end
                    ;;      of its prioqueue
  UNBLOCK ratio     ;; this unblocks a process from the blocked queue
                    ;;     and ratio is used to determine which one

  UPGRADE_PRIO small-priority ratio ;; this promotes a process from
                    ;; the small-priority queue to the next higher priority
                    ;;     and ratio is used to determine which process
 
  FLUSH	            ;; causes all the processes from the prio queues to
                    ;;    exit the system in their priority order

where
 NEW_JOB        1
 UPGRADE_PRIO   2 
 BLOCK          3
 UNBLOCK        4  
 QUANTUM_EXPIRE 5
 FINISH         6
 FLUSH          7
and priority is in        1..3
and small-priority is in  1..2
and ratio is in           0.0..1.0

 The output is a list of numbers indicating the order in which
 processes exit from the system.   

*/


